# ==============================================================================
# 04_rate_trends.R
# Lights Out, Profits Up — Georgia Power Report
#
# PURPOSE: EIA Form 861 rate trend analysis for Georgia Power and Georgia state.
#
# Metrics:
#   - GA Power residential rate trend over report_year_range
#   - Statewide comparison: IOU vs. cooperative vs. municipal residential rates
#   - Annualized rate of change and cumulative percent change
#   - Burden implication: how much does the rate increase add to a typical
#     residential customer's annual bill?
#
# DATA NOTE: Uses cleaned EIA 861 data. Columns use cleaned names:
#   year (not data_year), residential_rate_cents_per_kwh (pre-calculated),
#   residential_customers (not count), residential_kwh, residential_revenue_usd
# ==============================================================================

source("R/01_setup_and_data_prep.R")
source("R/00_visual_styling.R")

library(scales)

# ==============================================================================
# TARGET UTILITY RATE TREND
# ==============================================================================

target_rate_trend <- target_eia_sales %>%
  group_by(year) %>%
  summarize(
    rate                 = weighted.mean(residential_rate_cents_per_kwh,
                                         residential_customers, na.rm = TRUE),
    total_residential_kwh       = sum(residential_kwh, na.rm = TRUE),
    total_residential_customers = sum(residential_customers, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(year) %>%
  mutate(
    rate_change_pct = 100 * ((rate / lag(rate)) - 1),
    rate_index      = 100 * (rate / rate[year == base_year])
  )

# Cumulative change over the full report period
rate_start <- target_rate_trend %>% filter(year == min(report_year_range)) %>% pull(rate)
rate_end   <- target_rate_trend %>% filter(year == max(report_year_range)) %>% pull(rate)
rate_cumulative_pct_change <- 100 * ((rate_end / rate_start) - 1)
rate_annualized_change <- 100 * ((rate_end / rate_start)^(1 / (max(report_year_range) - min(report_year_range))) - 1)

cat("\n--- RATE CHANGE SUMMARY ---\n")
cat(glue("{utility_name} residential rate {min(report_year_range)}-{max(report_year_range)}:\n"))
cat(glue("  From: {round(rate_start, 2)} cents/kWh\n"))
cat(glue("  To:   {round(rate_end, 2)} cents/kWh\n"))
cat(glue("  Cumulative change: +{round(rate_cumulative_pct_change, 1)}%\n"))
cat(glue("  Annualized change: +{round(rate_annualized_change, 1)}%/year\n"))

# ==============================================================================
# STATEWIDE COMPARISON: IOU vs. COOPERATIVE vs. MUNICIPAL
# ==============================================================================

state_rate_by_ownership <- state_eia_sales %>%
  group_by(year, ownership) %>%
  summarize(
    rate        = weighted.mean(residential_rate_cents_per_kwh,
                                residential_customers, na.rm = TRUE),
    total_count = sum(residential_customers, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  filter(!is.na(rate), !is.infinite(rate)) %>%
  mutate(
    ownership_label = case_when(
      str_detect(tolower(ownership), "investor") ~ "Investor-Owned",
      str_detect(tolower(ownership), "cooperat") ~ "Cooperative",
      str_detect(tolower(ownership), "municipal|political") ~ "Municipal/Public",
      TRUE ~ ownership
    )
  ) %>%
  group_by(year, ownership_label) %>%
  summarize(
    rate        = weighted.mean(rate, total_count, na.rm = TRUE),
    total_count = sum(total_count, na.rm = TRUE),
    .groups = "drop"
  )

# Percent change by ownership type
state_rate_change <- state_rate_by_ownership %>%
  group_by(ownership_label) %>%
  filter(year %in% c(min(report_year_range), max(report_year_range))) %>%
  arrange(year) %>%
  summarize(
    rate_start = first(rate),
    rate_end   = last(rate),
    pct_change = 100 * ((rate_end / rate_start) - 1),
    .groups = "drop"
  )

print(state_rate_change)

# ==============================================================================
# TARGET UTILITY VS. STATE AVERAGE
# ==============================================================================

rate_comparison <- state_rate_by_ownership %>%
  bind_rows(
    target_rate_trend %>%
      transmute(
        year            = year,
        ownership_label = glue("{utility_name} (IOU)"),
        rate            = rate,
        total_count     = total_residential_customers
      )
  )

# ==============================================================================
# BILL IMPACT CALCULATION
# ==============================================================================

avg_annual_kwh <- target_eia_sales %>%
  group_by(year) %>%
  summarize(
    avg_kwh_per_customer = sum(residential_kwh, na.rm = TRUE) /
                           sum(residential_customers, na.rm = TRUE),
    .groups = "drop"
  )

bill_impact <- target_rate_trend %>%
  left_join(avg_annual_kwh, by = "year") %>%
  mutate(
    annual_bill_usd        = (rate / 100) * avg_kwh_per_customer,
    annual_bill_change_usd = annual_bill_usd - lag(annual_bill_usd)
  )

cat("\n--- BILL IMPACT (typical residential customer) ---\n")
bill_impact %>%
  filter(!is.na(annual_bill_change_usd)) %>%
  select(year, rate, avg_kwh_per_customer, annual_bill_usd, annual_bill_change_usd) %>%
  print()

# ==============================================================================
# PLOTS
# ==============================================================================

ownership_colors <- c(
  "Investor-Owned"   = "#002E55",
  "Cooperative"      = "#40916C",
  "Municipal/Public" = "#969EA4"
)
target_color <- "#CFA43A"
names(target_color) <- glue("{utility_name} (IOU)")
ownership_colors <- c(ownership_colors, target_color)

# Line chart: rate trends by ownership type + target utility
plot_rate_trends <- rate_comparison %>%
  filter(!is.na(rate), total_count > 0) %>%
  ggplot(aes(x = year, y = rate, color = ownership_label, linewidth = ownership_label)) +
  geom_line() +
  geom_point(size = 2) +
  scale_color_manual(
    values = ownership_colors,
    breaks = c(glue("{utility_name} (IOU)"), "Investor-Owned", "Cooperative", "Municipal/Public")
  ) +
  scale_linewidth_manual(
    values = setNames(
      c(2, 1, 1, 1),
      c(glue("{utility_name} (IOU)"), "Investor-Owned", "Cooperative", "Municipal/Public")
    ),
    guide = "none"
  ) +
  scale_x_continuous(breaks = report_year_range) +
  scale_y_continuous(expand = c(0, 0), limits = c(0, NA)) +
  theme_lopu() +
  labs(
    title    = glue("Residential electricity rates — {state_abbrev}"),
    subtitle = glue("{utility_name} vs. other utility types, {min(report_year_range)}–{max(report_year_range)}"),
    x        = "",
    y        = "Average rate (cents/kWh)",
    color    = "",
    caption  = "EIA Form 861"
  )

ggsave(
  glue("plots/{today_fmt}-eia_rate_trends_by_ownership.png"),
  plot   = plot_rate_trends,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# Bar chart: cumulative percent change by ownership type
plot_rate_pct_change <- state_rate_change %>%
  bind_rows(tibble(
    ownership_label = glue("{utility_name} (IOU)"),
    rate_start      = rate_start,
    rate_end        = rate_end,
    pct_change      = rate_cumulative_pct_change
  )) %>%
  mutate(ownership_label = fct_reorder(ownership_label, pct_change)) %>%
  ggplot(aes(x = ownership_label, y = pct_change, fill = ownership_label)) +
  geom_col() +
  geom_hline(yintercept = 0, linewidth = 0.4, color = "grey40") +
  scale_fill_manual(values = ownership_colors, guide = "none") +
  coord_flip() +
  theme_lopu() +
  labs(
    title    = glue("Cumulative residential rate change — {state_abbrev}"),
    subtitle = glue("{min(report_year_range)}–{max(report_year_range)}"),
    x        = "",
    y        = "Percent change (%)",
    caption  = "EIA Form 861"
  )

ggsave(
  glue("plots/{today_fmt}-eia_rate_pct_change_ownership.png"),
  plot   = plot_rate_pct_change,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# ==============================================================================
# SAVE OUTPUTS
# ==============================================================================

save_output(target_rate_trend,       "eia_target_utility_rate_trend")
save_output(state_rate_by_ownership, "eia_state_rate_by_ownership")
save_output(state_rate_change,       "eia_state_rate_change_summary")
save_output(bill_impact,             "eia_bill_impact")

message("Script 04 complete.")

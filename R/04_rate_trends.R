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
    annual_bill_usd         = (rate / 100) * avg_kwh_per_customer,
    annual_bill_change_usd  = annual_bill_usd - lag(annual_bill_usd),
    monthly_bill_usd        = annual_bill_usd / 12,
    monthly_bill_change_usd = monthly_bill_usd - lag(monthly_bill_usd)
  )

cat("\n--- BILL IMPACT (typical residential customer) ---\n")
bill_impact %>%
  filter(!is.na(annual_bill_change_usd)) %>%
  select(year, rate, avg_kwh_per_customer, annual_bill_usd, annual_bill_change_usd,
         monthly_bill_usd, monthly_bill_change_usd) %>%
  print()

# ==============================================================================
# 1,000 kWh BENCHMARK COMPARISON
# Georgia Watch (Aug 2025) reports a GA Power customer using 1,000 kWh/month
# pays $43 more than in 2022. Compare that to what EIA's blended avg rate
# would imply for the same usage level.
# ==============================================================================

benchmark_kwh_monthly <- 1000

benchmark_bill <- target_rate_trend %>%
  mutate(
    benchmark_monthly_bill     = (rate / 100) * benchmark_kwh_monthly,
    benchmark_change_from_2022 = benchmark_monthly_bill -
      benchmark_monthly_bill[year == 2022]
  )

cat("\n--- 1,000 kWh BENCHMARK (EIA blended rate vs. reported bill) ---\n")
cat("At EIA's avg rate, a 1,000 kWh/month customer would pay:\n")
benchmark_bill %>%
  select(year, rate, benchmark_monthly_bill, benchmark_change_from_2022) %>%
  print()
cat(glue("\nEIA-implied increase (2022-2024): +${round(benchmark_bill %>% filter(year == 2024) %>% pull(benchmark_change_from_2022), 2)}/month\n"))
cat("Reported increase (2022-2025):   +$43/month (Georgia Watch, Aug 2025)\n")
cat("Gap reflects: tiered seasonal pricing, Plant Vogtle surcharge, fuel cost\n")
cat("recovery, environmental compliance rider, fixed charges, and Jan 2025 hike.\n")

# ==============================================================================
# BRIDGING COMPARISON: EIA vs. REPORTED BILL
# ==============================================================================

eia_benchmark_2022 <- benchmark_bill %>% filter(year == 2022) %>% pull(benchmark_monthly_bill)
eia_benchmark_2024 <- benchmark_bill %>% filter(year == 2024) %>% pull(benchmark_monthly_bill)
eia_rate_2022      <- benchmark_bill %>% filter(year == 2022) %>% pull(rate)
eia_rate_2024      <- benchmark_bill %>% filter(year == 2024) %>% pull(rate)
eia_monthly_2024   <- bill_impact %>% filter(year == 2024) %>% pull(monthly_bill_usd)

bridging_comparison <- tibble(
  metric = c(
    "time_period",
    "rate_metric",
    "monthly_usage_basis",
    "rate_2022_cents_per_kwh",
    "rate_2024_cents_per_kwh",
    "eia_rate_change_pct_2022_2024",
    "eia_rate_change_pct_2020_2024",
    "monthly_bill_eia_avg_customer_2024",
    "monthly_bill_benchmark_2022",
    "monthly_bill_benchmark_2024",
    "monthly_increase_eia_benchmark",
    "monthly_bill_reported_2025",
    "monthly_increase_reported",
    "bill_gap_explanation"
  ),
  eia_analysis = c(
    "2020-2024",
    "blended avg rate (cents/kWh)",
    glue("{round(bill_impact %>% filter(year == 2024) %>% pull(avg_kwh_per_customer) / 12)} kWh (actual avg)"),
    as.character(round(eia_rate_2022, 2)),
    as.character(round(eia_rate_2024, 2)),
    as.character(round(100 * (eia_rate_2024 / eia_rate_2022 - 1), 1)),
    as.character(round(rate_cumulative_pct_change, 1)),
    as.character(round(eia_monthly_2024, 2)),
    as.character(round(eia_benchmark_2022, 2)),
    as.character(round(eia_benchmark_2024, 2)),
    as.character(round(eia_benchmark_2024 - eia_benchmark_2022, 2)),
    "NA",
    "NA",
    "NA"
  ),
  reported_article = c(
    "2022-2025",
    "actual monthly bill ($)",
    "1,000 kWh (fixed benchmark)",
    "NA",
    "NA",
    "NA",
    "NA",
    "NA",
    "NA",
    "NA",
    "NA",
    "171",
    "43",
    "tiered seasonal pricing, Plant Vogtle surcharge, fuel cost recovery, fixed charges, Jan 2025 hike"
  ),
  source = c(
    rep("EIA Form 861 / Georgia Watch (Aug 2025)", 2),
    rep("EIA Form 861", 9),
    rep("Georgia Watch (Aug 2025)", 2),
    "Analysis"
  )
)

# ==============================================================================
# COUNTERFACTUAL RATE ANALYSIS: GA Power vs. Non-IOU (Coop + Municipal)
# ==============================================================================

# 1a. Customer-weighted blended non-IOU rate by year
non_iou_rate_by_year <- state_rate_by_ownership %>%
  filter(ownership_label %in% c("Cooperative", "Municipal/Public")) %>%
  group_by(year) %>%
  summarize(
    non_iou_rate      = weighted.mean(rate, total_count, na.rm = TRUE),
    non_iou_customers = sum(total_count, na.rm = TRUE)
  ) %>%
  ungroup()

# 1b. Individual coop/muni rates wide for the join
ownership_rates_wide <- state_rate_by_ownership %>%
  filter(ownership_label %in% c("Cooperative", "Municipal/Public")) %>%
  select(year, ownership_label, rate) %>%
  pivot_wider(names_from = ownership_label, values_from = rate) %>%
  clean_names()  # → cooperative, municipal_public

# 1c. Join and compute counterfactual costs + excess
counterfactual_analysis <- target_rate_trend %>%
  rename(actual_rate = rate) %>%
  left_join(non_iou_rate_by_year %>% select(year, non_iou_rate), by = "year") %>%
  left_join(ownership_rates_wide, by = "year") %>%
  left_join(avg_annual_kwh, by = "year") %>%
  mutate(
    actual_cost_b                 = actual_rate / 100 * total_residential_kwh / 1e9,
    counterfactual_cost_non_iou_b = non_iou_rate / 100 * total_residential_kwh / 1e9,
    annual_excess_non_iou_b       = actual_cost_b - counterfactual_cost_non_iou_b,
    cumulative_excess_non_iou_b   = cumsum(annual_excess_non_iou_b),
    annual_excess_per_customer    = (actual_rate - non_iou_rate) / 100 * avg_kwh_per_customer
  ) %>%
  select(
    year, actual_rate, cooperative, municipal_public, non_iou_rate,
    total_residential_kwh, total_residential_customers,
    actual_cost_b, counterfactual_cost_non_iou_b,
    annual_excess_non_iou_b, cumulative_excess_non_iou_b,
    annual_excess_per_customer
  )

# 1d. Console summary
cf_latest  <- counterfactual_analysis %>% filter(year == max(year))
cf_base    <- counterfactual_analysis %>% filter(year == min(year))
cat("\n--- COUNTERFACTUAL RATE ANALYSIS ---\n")
cat(glue("{utility_name} vs. non-IOU (coop + municipal) rates:\n"))
cat(glue("  {min(report_year_range)} rate differential: {round(cf_base$actual_rate - cf_base$non_iou_rate, 2)} cents/kWh\n"))
cat(glue("  {max(report_year_range)} rate differential: {round(cf_latest$actual_rate - cf_latest$non_iou_rate, 2)} cents/kWh\n"))
cat(glue("  Annual excess ({max(report_year_range)}): ${round(cf_latest$annual_excess_non_iou_b, 2)}B\n"))
cat(glue("  Cumulative excess ({min(report_year_range)}-{max(report_year_range)}): ${round(cf_latest$cumulative_excess_non_iou_b, 2)}B\n"))
cat(glue("  Per-customer annual excess ({max(report_year_range)}): ${round(cf_latest$annual_excess_per_customer, 0)}\n"))

save_output(counterfactual_analysis, "eia_counterfactual_rate_analysis")

# 1e. Grouped bar chart: actual vs. counterfactual annual cost + cumulative excess line
plot_counterfactual <- counterfactual_analysis %>%
  select(year, actual_cost_b, counterfactual_cost_non_iou_b) %>%
  pivot_longer(
    cols      = c(actual_cost_b, counterfactual_cost_non_iou_b),
    names_to  = "cost_type",
    values_to = "cost_b"
  ) %>%
  mutate(
    cost_label = case_when(
      cost_type == "actual_cost_b"                 ~ glue("Actual ({utility_name})"),
      cost_type == "counterfactual_cost_non_iou_b" ~ "Counterfactual (non-IOU rates)"
    )
  ) %>%
  ggplot(aes(x = year)) +
  geom_col(aes(y = cost_b, fill = cost_label), position = "dodge") +
  geom_line(
    data      = counterfactual_analysis,
    aes(y = cumulative_excess_non_iou_b, color = "Cumulative excess"),
    linewidth = 1.5
  ) +
  geom_point(
    data = counterfactual_analysis,
    aes(y = cumulative_excess_non_iou_b, color = "Cumulative excess"),
    size = 3
  ) +
  scale_fill_manual(
    values = setNames(
      c(lopu_navy, lopu_green),
      c(glue("Actual ({utility_name})"), "Counterfactual (non-IOU rates)")
    )
  ) +
  scale_color_manual(values = c("Cumulative excess" = lopu_red)) +
  scale_x_continuous(breaks = report_year_range) +
  scale_y_continuous(labels = dollar_format(suffix = "B"), expand = c(0, 0), limits = c(0, NA)) +
  theme_lopu() +
  labs(
    title    = glue("What {utility_name} customers paid vs. non-IOU rates"),
    subtitle = glue("Annual residential cost, {min(report_year_range)}–{max(report_year_range)}"),
    x        = "",
    y        = "Total residential cost ($B)",
    fill     = "",
    color    = "",
    caption  = "EIA Form 861"
  )

ggsave(
  glue("plots/{today_fmt}-eia_counterfactual_rate_comparison.png"),
  plot   = plot_counterfactual,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

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
save_output(benchmark_bill,          "eia_benchmark_1000kwh")
save_output(bridging_comparison,     "eia_vs_reported_bill_comparison")

message("Script 04 complete.")

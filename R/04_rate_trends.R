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
library(showtext)
library(sysfonts)

font_add_google("Inter", "Inter")
font_add_google("Bitter", "Bitter")
showtext_auto()

# Google Slides-compatible theme (matches Archive/visual_styling.R and 06a)
gslide_theme <- theme(
  panel.background   = element_rect(fill = "white", color = NA),
  plot.background    = element_rect(fill = "white", color = NA),
  text               = element_text(family = "Inter"),
  plot.title         = element_text(family = "Bitter", size = 48, lineheight = 0.5),
  plot.subtitle      = element_text(family = "Bitter", size = 36, lineheight = 0.5),
  axis.title.y       = element_text(family = "Inter", size = 32),
  axis.title.x       = element_text(family = "Inter", size = 32),
  axis.text          = element_text(family = "Inter", size = 16),
  axis.text.x        = element_text(size = 24),
  axis.text.y        = element_text(size = 24),
  plot.margin        = margin(5, 5, 5, 0),
  strip.text         = element_text(family = "Inter", size = 16),
  legend.position    = "bottom",
  legend.title       = element_text(size = 24),
  legend.text        = element_text(size = 22),
  legend.margin      = margin(t = 0, b = 0, l = -100),
  panel.grid.major.y = element_blank(),
  panel.grid.minor.y = element_blank(),
  plot.caption       = element_text(family = "Inter", color = "grey50", size = 20,
                                    hjust = 1, vjust = 0)
)

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
# MUNI & COOP RATE COMPARISON: GA Power vs. Municipal & Cooperative utilities
# ==============================================================================

# 1a. Customer-weighted blended Muni & Coop rate by year
muni_coop_rate_by_year <- state_rate_by_ownership %>%
  filter(ownership_label %in% c("Cooperative", "Municipal/Public")) %>%
  group_by(year) %>%
  summarize(
    muni_coop_rate      = weighted.mean(rate, total_count, na.rm = TRUE),
    muni_coop_customers = sum(total_count, na.rm = TRUE)
  ) %>%
  ungroup()

# 1b. Individual coop/muni rates wide for the join
ownership_rates_wide <- state_rate_by_ownership %>%
  filter(ownership_label %in% c("Cooperative", "Municipal/Public")) %>%
  select(year, ownership_label, rate) %>%
  pivot_wider(names_from = ownership_label, values_from = rate) %>%
  clean_names()  # → cooperative, municipal_public

# 1c. Join and compute Muni & Coop costs + excess
counterfactual_analysis <- target_rate_trend %>%
  rename(actual_rate = rate) %>%
  left_join(muni_coop_rate_by_year %>% select(year, muni_coop_rate), by = "year") %>%
  left_join(ownership_rates_wide, by = "year") %>%
  left_join(avg_annual_kwh, by = "year") %>%
  mutate(
    actual_cost_b                  = actual_rate / 100 * total_residential_kwh / 1e9,
    muni_coop_cost_b               = muni_coop_rate / 100 * total_residential_kwh / 1e9,
    annual_excess_b                = actual_cost_b - muni_coop_cost_b,
    cumulative_excess_b            = cumsum(annual_excess_b),
    annual_excess_per_customer     = (actual_rate - muni_coop_rate) / 100 * avg_kwh_per_customer,
    cumulative_excess_per_customer = cumsum(annual_excess_per_customer)
  ) %>%
  select(
    year, actual_rate, cooperative, municipal_public, muni_coop_rate,
    total_residential_kwh, total_residential_customers,
    actual_cost_b, muni_coop_cost_b,
    annual_excess_b, cumulative_excess_b,
    annual_excess_per_customer, cumulative_excess_per_customer
  )

# 1d. Console summary
cf_latest  <- counterfactual_analysis %>% filter(year == max(year))
cf_base    <- counterfactual_analysis %>% filter(year == min(year))
cat("\n--- MUNI & COOP RATE COMPARISON ---\n")
cat(glue("{utility_name} vs. Muni & Coop rates:\n"))
cat(glue("  {min(report_year_range)} rate differential: {round(cf_base$actual_rate - cf_base$muni_coop_rate, 2)} cents/kWh\n"))
cat(glue("  {max(report_year_range)} rate differential: {round(cf_latest$actual_rate - cf_latest$muni_coop_rate, 2)} cents/kWh\n"))
cat(glue("  Annual excess ({max(report_year_range)}): ${round(cf_latest$annual_excess_b, 2)}B\n"))
cat(glue("  Cumulative excess ({min(report_year_range)}-{max(report_year_range)}): ${round(cf_latest$cumulative_excess_b, 2)}B\n"))
cat(glue("  Per-customer annual excess ({max(report_year_range)}): ${round(cf_latest$annual_excess_per_customer, 0)}\n"))
cat(glue("  Cumulative per-customer excess ({min(report_year_range)}-{max(report_year_range)}): ~${round(cf_latest$cumulative_excess_per_customer, 0)}\n"))

save_output(counterfactual_analysis, "eia_muni_coop_rate_comparison")

# 1e. Chart A — Per-customer excess (primary report figure)
total_per_customer_excess <- round(cf_latest$cumulative_excess_per_customer)

plot_excess_per_customer <- counterfactual_analysis %>%
  ggplot(aes(x = year, y = annual_excess_per_customer)) +
  geom_col(fill = lopu_gold) +
  geom_text(
    aes(label = dollar(annual_excess_per_customer, accuracy = 1)),
    vjust = -0.5, size = 3.5, color = "grey20"
  ) +
  annotate(
    "text",
    x        = min(report_year_range),
    y        = Inf,
    label    = glue("5-year total: ~${total_per_customer_excess} per customer"),
    size     = 4, fontface = "bold", color = "grey30",
    hjust    = 0, vjust    = 1.5
  ) +
  scale_x_continuous(breaks = report_year_range) +
  scale_y_continuous(labels = dollar_format(), limits = c(0, NA), expand = expansion(mult = c(0, 0.18))) +
  theme_lopu() +
  labs(
    title    = glue("How much more each {utility_name} customer paid"),
    subtitle = glue("Annual excess vs. Muni & Coop rates, {min(report_year_range)}–{max(report_year_range)}"),
    x        = "",
    y        = "Excess cost per customer ($/year)",
    caption  = "EIA Form 861"
  )

ggsave(
  glue("plots/{today_fmt}-eia_excess_per_customer.png"),
  plot   = plot_excess_per_customer,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# ==============================================================================
# PLOTS
# ==============================================================================

# Graduated red palette — darkest for GA Power, lightest for Cooperative
rate_bar_colors <- c(
  "Georgia Power Co" = "#C8102E",
  "Municipal"        = "#E94B3C",
  "Cooperative"      = "#F7A9A0"
)

# Bar chart: cumulative percent change — 3 bars only (GA Power, Municipal, Coop)
rate_change_bars <- state_rate_change %>%
  filter(ownership_label %in% c("Cooperative", "Municipal/Public")) %>%
  mutate(ownership_label = case_when(
    ownership_label == "Municipal/Public" ~ "Municipal",
    TRUE ~ ownership_label
  )) %>%
  bind_rows(tibble(
    ownership_label = "Georgia Power Co",
    rate_start      = rate_start,
    rate_end        = rate_end,
    pct_change      = rate_cumulative_pct_change
  )) %>%
  mutate(ownership_label = fct_reorder(ownership_label, pct_change))

plot_rate_pct_change <- rate_change_bars %>%
  ggplot(aes(x = pct_change, y = ownership_label, fill = ownership_label)) +
  geom_bar(stat = "identity") +
  scale_fill_manual(values = rate_bar_colors) +
  geom_text(
    aes(label = paste0(sprintf("%.1f", pct_change), "%")),
    hjust = 1.2, fontface = "bold", size = 16, color = "white"
  ) +
  theme_minimal() +
  gslide_theme +
  theme(legend.position = "none") +
  labs(
    title    = glue("{utility_name} Co increases rates by {round(rate_cumulative_pct_change)}%"),
    subtitle = glue("{utility_name} increases residential rates ~2x more than other utilities"),
    x        = glue("Weighted Mean Residential Electric Rate Percent Change ({min(report_year_range)}–{max(report_year_range)})"),
    y        = "",
    caption  = glue("EIA Form 861, {min(report_year_range)}–{max(report_year_range)}")
  )

ggsave(
  glue("plots/{today_fmt}-eia_rate_pct_change_ownership.png"),
  plot   = plot_rate_pct_change,
  width  = 7.5, height = 5, dpi = 350, units = "in",
  bg     = "white"
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

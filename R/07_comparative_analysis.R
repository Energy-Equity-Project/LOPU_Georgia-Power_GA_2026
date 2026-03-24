# ==============================================================================
# 07_comparative_analysis.R
# Lights Out, Profits Up — Georgia Power Report
#
# PURPOSE: The headline "Lights Out, Profits Up" juxtaposition analysis.
# Reads outputs from scripts 02-06 and produces indexed trend comparisons,
# ratio analyses, and the summary table for the report narrative.
#
# MUST RUN LAST — depends on outputs/ CSVs from all prior scripts.
#
# Key outputs:
#   - Indexed trend chart: normalize key metrics to base year (= 100)
#     showing residential rates, disconnections, CEO comp, dividends, market cap
#   - Ratio analysis: hardship growth vs. financial growth
#   - Summary comparison table
# ==============================================================================

source("R/01_setup_and_data_prep.R")
source("R/00_visual_styling.R")

library(scales)
library(patchwork)

# ==============================================================================
# LOAD OUTPUTS FROM PRIOR SCRIPTS
# ==============================================================================

load_output <- function(pattern) {
  f <- list.files("outputs", pattern = pattern, full.names = TRUE)
  if (length(f) == 0) {
    message(glue("No output found matching '{pattern}' — skipping."))
    return(NULL)
  }
  read.csv(f[[1]])
}

rate_trend              <- load_output("eia_target_utility_rate_trend")
disconn_rate            <- load_output("disconnection_rate_annual")
financials_idx          <- load_output("iou_financials_indexed")
ceo_comp_trend          <- load_output("iou_ceo_compensation_trend")
dividend_annual         <- load_output("iou_dividend_annual")
stock_annual            <- load_output("iou_stock_annual_summary")
tsr_data                <- load_output("iou_tsr")
dividend_payouts        <- load_output("iou_dividend_payouts")
customer_vs_shareholder <- load_output("iou_customer_vs_shareholder")
pulse_stats             <- load_output("pulse_summary_statistics")

# ==============================================================================
# BUILD INDEXED COMPARISON TABLE
# Index all available metrics to base_year = 100
# Note: rate_trend uses 'year' column (cleaned EIA); disconn_rate uses 'data_year'
# ==============================================================================

index_series <- function(df, year_col, value_col, label) {
  if (is.null(df)) return(NULL)
  base_val <- df %>% filter(.data[[year_col]] == base_year) %>% pull(!!value_col)
  if (length(base_val) == 0 || is.na(base_val) || base_val == 0) {
    message(glue("Cannot index '{label}' — no base year value for {base_year}"))
    return(NULL)
  }
  df %>%
    filter(.data[[year_col]] %in% report_year_range) %>%
    transmute(
      year   = .data[[year_col]],
      metric = label,
      index  = 100 * (.data[[value_col]] / base_val)
    )
}

indexed_series <- bind_rows(
  index_series(rate_trend,        "year",      "rate",                     glue("{utility_name_short} residential rate")),
  index_series(disconn_rate,      "data_year", "disconnection_rate_pct",   "Disconnection rate"),
  index_series(financials_idx,    "year",      "revenue",                  "Utility revenue"),
  index_series(financials_idx,    "year",      "net_income",               "Net income"),
  index_series(ceo_comp_trend,    "year",      "total_compensation",       "CEO total compensation"),
  index_series(dividend_annual,   "year",      "annual_dividend_per_share","Dividends per share"),
  index_series(dividend_payouts,  "year",      "total_payout_b",           "Total dividend payout"),
  index_series(tsr_data,          "year",      "total_return_pct",         "Annual TSR"),
  index_series(stock_annual,      "year",      "market_cap_b",             "Market cap")
) %>%
  filter(!is.na(index))

# ==============================================================================
# INDEXED TREND CHART — the headline visualization
# ==============================================================================

color_map <- c(
  setNames(lopu_gold, glue("{utility_name_short} residential rate")),
  lopu_color_map
)

hardship_metrics  <- c(glue("{utility_name_short} residential rate"), "Disconnection rate")
financial_metrics <- setdiff(unique(indexed_series$metric), hardship_metrics)

plot_hardship <- indexed_series %>%
  filter(metric %in% hardship_metrics) %>%
  ggplot(aes(x = year, y = index, color = metric)) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "grey60") +
  geom_line(linewidth = 1.5) +
  geom_point(size = 3) +
  scale_color_manual(values = color_map) +
  scale_x_continuous(breaks = report_year_range) +
  scale_y_continuous(breaks = seq(80, 160, 10), expand = c(0.02, 0)) +
  theme_lopu() +
  labs(
    title    = "Lights Out: energy hardship metrics",
    subtitle = glue("Indexed to {base_year} = 100"),
    x        = "",
    y        = "Index (base year = 100)",
    color    = ""
  )

plot_financial <- indexed_series %>%
  filter(metric %in% financial_metrics) %>%
  ggplot(aes(x = year, y = index, color = metric)) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "grey60") +
  geom_line(linewidth = 1.5) +
  geom_point(size = 3) +
  scale_color_manual(values = color_map) +
  scale_x_continuous(breaks = report_year_range) +
  scale_y_continuous(breaks = seq(80, 200, 20), expand = c(0.02, 0)) +
  theme_lopu() +
  labs(
    title    = "Profits Up: utility financial metrics",
    subtitle = glue("Indexed to {base_year} = 100"),
    x        = "",
    y        = "Index (base year = 100)",
    color    = "",
    caption  = "EIA Form 861, SEC EDGAR, Yahoo Finance / tidyquant, Household Pulse Survey"
  )

plot_indexed_combined <- plot_hardship / plot_financial

ggsave(
  glue("plots/{today_fmt}-lopu_indexed_comparison.png"),
  plot   = plot_indexed_combined,
  width  = 7.5, height = 10, dpi = 350, units = "in"
)

# ==============================================================================
# RATIO ANALYSIS: hardship growth vs. financial growth
# ==============================================================================

if (nrow(indexed_series) > 0) {
  ratio_summary <- indexed_series %>%
    filter(year %in% c(min(report_year_range), max(report_year_range))) %>%
    group_by(metric) %>%
    arrange(year) %>%
    summarize(
      start_index = first(index),
      end_index   = last(index),
      pct_change  = last(index) - first(index),
      .groups     = "drop"
    ) %>%
    mutate(
      category = case_when(
        metric %in% hardship_metrics ~ "Hardship",
        TRUE                          ~ "Financial"
      )
    ) %>%
    arrange(category, desc(pct_change))

  cat("\n--- INDEXED CHANGE SUMMARY (base year to latest year) ---\n")
  print(ratio_summary)

  save_output(ratio_summary, "lopu_ratio_summary")
}

# ==============================================================================
# SUMMARY COMPARISON TABLE (for report narrative)
# ==============================================================================

summary_table <- tibble(
  category = character(),
  metric   = character(),
  value    = character(),
  note     = character()
)

# Hardship metrics
if (!is.null(rate_trend)) {
  latest_rate <- rate_trend %>% filter(year == max(year)) %>% pull(rate)
  start_rate  <- rate_trend %>% filter(year == min(year)) %>% pull(rate)
  summary_table <- summary_table %>%
    bind_rows(tibble(
      category = "Energy affordability",
      metric   = "Residential electricity rate change",
      value    = glue("+{round(100 * (latest_rate/start_rate - 1), 1)}% ({min(report_year_range)}–{max(report_year_range)})"),
      note     = glue("{round(start_rate, 2)} → {round(latest_rate, 2)} cents/kWh")
    ))
}

if (!is.null(pulse_stats)) {
  any_insecurity <- pulse_stats %>%
    filter(hardship == "any_energy_issues") %>%
    pull(mean_pct) %>%
    round(1)
  summary_table <- summary_table %>%
    bind_rows(tibble(
      category = "Energy insecurity",
      metric   = "Avg. share experiencing any energy insecurity",
      value    = glue("{any_insecurity}%"),
      note     = "Household Pulse Survey average across survey waves"
    ))
}

# Financial metrics
if (!is.null(financials_idx)) {
  fin_latest <- financials_idx %>% filter(year == max(year))
  fin_base   <- financials_idx %>% filter(year == base_year)
  summary_table <- summary_table %>%
    bind_rows(tibble(
      category = "Utility financials",
      metric   = "Revenue change",
      value    = glue("+{round(fin_latest$revenue_index - 100, 1)}% vs. {base_year}"),
      note     = "SEC EDGAR 10-K"
    )) %>%
    bind_rows(tibble(
      category = "Utility financials",
      metric   = "Net income change",
      value    = glue("+{round(fin_latest$net_income_index - 100, 1)}% vs. {base_year}"),
      note     = "SEC EDGAR 10-K"
    ))
}

# Shareholder return metrics (from Section A of script 06)
if (!is.null(tsr_data)) {
  latest_tsr <- tsr_data %>% filter(year == max(year)) %>% pull(cumulative_return_pct)
  summary_table <- summary_table %>%
    bind_rows(tibble(
      category = "Shareholder returns",
      metric   = glue("Cumulative TSR ({min(report_year_range)}–{max(report_year_range)})"),
      value    = glue("+{round(latest_tsr, 1)}%"),
      note     = "Capital gain (unadjusted close) + dividend yield; Yahoo Finance"
    ))
}

if (!is.null(dividend_payouts)) {
  latest_payouts <- dividend_payouts %>% filter(year == max(year))
  summary_table <- summary_table %>%
    bind_rows(tibble(
      category = "Shareholder returns",
      metric   = glue("Cumulative dividend payouts ({min(report_year_range)}–{max(report_year_range)})"),
      value    = dollar(latest_payouts$cumulative_payout_b, accuracy = 0.1, suffix = "B"),
      note     = "Yahoo Finance (dividends); stockanalysis.com (shares outstanding)"
    ))
}

# Customer vs. shareholder contrast (requires script 04 + script 06 Section A)
if (!is.null(customer_vs_shareholder)) {
  latest_cs <- customer_vs_shareholder %>% filter(year == max(year))
  summary_table <- summary_table %>%
    bind_rows(tibble(
      category = "Customer vs. shareholder",
      metric   = glue("Cumulative customer excess vs. {base_year} rates"),
      value    = dollar(latest_cs$cumulative_customer_excess_b, accuracy = 0.1, suffix = "B"),
      note     = glue("Total extra paid by customers vs. {base_year} rates; EIA Form 861")
    )) %>%
    bind_rows(tibble(
      category = "Customer vs. shareholder",
      metric   = "Ratio: dividend payouts to customer excess",
      value    = glue("{round(latest_cs$cumulative_payout_b / latest_cs$cumulative_customer_excess_b, 1)}x"),
      note     = "For every $1 of excess paid by customers, shareholders received $Xx in dividends"
    ))

  save_output(customer_vs_shareholder, "lopu_customer_vs_shareholder_summary")
}

cat("\n--- REPORT SUMMARY TABLE ---\n")
print(summary_table)

# ==============================================================================
# SAVE OUTPUTS
# ==============================================================================

save_output(indexed_series, "lopu_indexed_series")
save_output(summary_table,  "lopu_summary_table")

message("Script 07 complete — LOPU analysis finished.")
message(glue("Outputs in outputs/ and plots/ with prefix {today_fmt}"))

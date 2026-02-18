# ==============================================================================
# 06_iou_financial_performance.R
# Lights Out, Profits Up — Georgia Power Report
#
# PURPOSE: "Profits Up" — Southern Company / Georgia Power financial performance.
#
# Metrics:
#   - Revenue and net income trends (from SEC 10-K)
#   - Profit margin over time
#   - Dividend payout trend (total and per-share)
#   - Capital expenditures / rate base growth
#   - Market cap and P/E ratio (from stock data)
#   - C-suite compensation: CEO and CFO (from DEF 14A)
#   - Charitable contributions (if available in 10-K)
#
# Data requirements (in data/ folder):
#   - 10k_southern_company_2020-2024.csv — manually extracted from SEC EDGAR 10-K
#   - def14a_southern_company_2020-2024.csv — exec comp from proxy statement
#   - Stock data loaded from ../../../Data/financial_markets/iou_stock/SO/
#     via iou_stock_collector.R in eep-pipeline-core
#
# See eep-pipeline-core/collectors/iou_financials_collector.md for extraction
# instructions, CSV schemas, and the line items to pull from each filing.
# ==============================================================================

source("R/01_setup_and_data_prep.R")
source("R/00_visual_styling.R")

library(scales)
library(tidyquant)

# ==============================================================================
# CHECK DATA AVAILABILITY
# ==============================================================================

if (is.null(financials_10k)) {
  message("No 10-K data found. Collect financials per iou_financials_collector.md and rerun.")
  stop("Script 06 requires 10-K financial data.")
}

# ==============================================================================
# REVENUE AND NET INCOME TRENDS (from 10-K)
# ==============================================================================

financials <- financials_10k %>%
  filter(year %in% report_year_range) %>%
  arrange(year) %>%
  mutate(
    profit_margin_pct = 100 * (net_income / revenue),
    revenue_b         = revenue / 1e9,
    net_income_b      = net_income / 1e9
  )

base_financials <- financials %>% filter(year == base_year)

financials_indexed <- financials %>%
  mutate(
    revenue_index    = 100 * (revenue      / base_financials$revenue),
    net_income_index = 100 * (net_income   / base_financials$net_income),
    dividends_index  = 100 * (dividends_paid / base_financials$dividends_paid)
  )

cat("\n--- FINANCIAL PERFORMANCE SUMMARY ---\n")
financials %>%
  select(year, revenue_b, net_income_b, profit_margin_pct,
         dividends_paid, capex) %>%
  print()

# ==============================================================================
# STOCK DATA — MARKET CAP AND P/E RATIO
# ==============================================================================

stock_file <- list.files(path_iou_stock, pattern = "\\.csv$", full.names = TRUE)

if (length(stock_file) > 0) {
  stock_raw <- read_csv(stock_file[[1]], show_col_types = FALSE) %>%
    clean_names()

  stock_annual <- stock_raw %>%
    mutate(year = year(date)) %>%
    filter(year %in% report_year_range) %>%
    group_by(year) %>%
    summarize(
      avg_adjusted_price = mean(adjusted, na.rm = TRUE),
      annual_return_pct  = 100 * ((last(adjusted) / first(adjusted)) - 1),
      .groups = "drop"
    )

  if ("shares_outstanding" %in% colnames(financials_10k)) {
    stock_annual <- stock_annual %>%
      left_join(financials_10k %>% select(year, shares_outstanding), by = "year") %>%
      mutate(market_cap_b = (avg_adjusted_price * shares_outstanding) / 1e9)
  } else {
    message("shares_outstanding not in 10-K data — market cap not calculated. Add to 10-K extract.")
    stock_annual <- stock_annual %>% mutate(market_cap_b = NA_real_)
  }

  if ("eps" %in% colnames(financials_10k)) {
    stock_annual <- stock_annual %>%
      left_join(financials_10k %>% select(year, eps), by = "year") %>%
      mutate(pe_ratio = avg_adjusted_price / eps)
  } else {
    stock_annual <- stock_annual %>% mutate(pe_ratio = NA_real_)
  }

  save_output(stock_annual, "iou_stock_annual_summary")
} else {
  message(glue("No stock data found at {path_iou_stock}. Run iou_stock_collector.R first."))
  stock_annual <- NULL
}

# ==============================================================================
# DIVIDEND ANALYSIS
# ==============================================================================

if (!is.null(stock_annual)) {
  dividend_data <- tq_get(ticker, get = "dividends",
                           from = glue("{min(report_year_range)}-01-01"),
                           to   = glue("{max(report_year_range)}-12-31"))

  if (!is.null(dividend_data) && nrow(dividend_data) > 0) {
    dividend_annual <- dividend_data %>%
      mutate(year = year(date)) %>%
      filter(year %in% report_year_range) %>%
      group_by(year) %>%
      summarize(
        annual_dividend_per_share = sum(value, na.rm = TRUE),
        dividend_payments_count   = n(),
        .groups = "drop"
      )

    dividend_annual <- dividend_annual %>%
      left_join(stock_annual %>% select(year, avg_adjusted_price), by = "year") %>%
      mutate(dividend_yield_pct = 100 * (annual_dividend_per_share / avg_adjusted_price))

    save_output(dividend_annual, "iou_dividend_annual")
  } else {
    message(glue("No dividend data returned for ticker {ticker} via tidyquant."))
    dividend_annual <- NULL
  }
} else {
  dividend_annual <- NULL
}

# ==============================================================================
# EXECUTIVE COMPENSATION (from DEF 14A)
# ==============================================================================

if (!is.null(financials_def14a)) {
  exec_comp <- financials_def14a %>%
    filter(year %in% report_year_range) %>%
    arrange(year, desc(total_compensation))

  ceo_comp <- exec_comp %>%
    filter(str_detect(tolower(title), "chief executive|ceo")) %>%
    group_by(year) %>%
    slice_max(total_compensation, n = 1) %>%
    ungroup() %>%
    mutate(
      comp_index = 100 * (total_compensation / total_compensation[year == base_year]),
      comp_m     = total_compensation / 1e6
    )

  cat("\n--- CEO COMPENSATION TREND ---\n")
  ceo_comp %>% select(year, executive_name, comp_m) %>% print()

  save_output(exec_comp, "iou_exec_compensation")
  save_output(ceo_comp,  "iou_ceo_compensation_trend")
} else {
  message("No DEF 14A exec comp data found.")
  ceo_comp <- NULL
}

# ==============================================================================
# PLOTS
# ==============================================================================

# Revenue and net income trend
plot_financials <- financials %>%
  select(year, revenue_b, net_income_b) %>%
  pivot_longer(c(revenue_b, net_income_b),
               names_to = "metric", values_to = "value_b") %>%
  mutate(
    metric_label = case_when(
      metric == "revenue_b"    ~ "Revenue",
      metric == "net_income_b" ~ "Net income"
    )
  ) %>%
  ggplot(aes(x = year, y = value_b, color = metric_label)) +
  geom_line(linewidth = 1.5) +
  geom_point(size = 3) +
  scale_color_manual(values = c("Revenue" = "#002E55", "Net income" = "#CFA43A")) +
  scale_x_continuous(breaks = report_year_range) +
  scale_y_continuous(labels = dollar_format(suffix = "B"), expand = c(0, 0), limits = c(0, NA)) +
  theme_lopu() +
  labs(
    title    = glue("{utility_name} revenue and net income"),
    subtitle = glue("{parent_company}, {min(report_year_range)}–{max(report_year_range)}"),
    x        = "",
    y        = "USD (billions)",
    color    = "",
    caption  = "SEC EDGAR 10-K"
  )

ggsave(
  glue("plots/{today_fmt}-iou_revenue_net_income.png"),
  plot   = plot_financials,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# Profit margin trend
plot_margin <- financials %>%
  ggplot(aes(x = year, y = profit_margin_pct)) +
  geom_line(color = "#094094", linewidth = 1.5) +
  geom_point(color = "#094094", size = 3) +
  geom_hline(yintercept = 0, linewidth = 0.4, color = "grey40") +
  scale_x_continuous(breaks = report_year_range) +
  scale_y_continuous(expand = c(0.02, 0)) +
  theme_lopu() +
  labs(
    title   = glue("{utility_name} profit margin"),
    x       = "",
    y       = "Net profit margin (%)",
    caption = "SEC EDGAR 10-K"
  )

ggsave(
  glue("plots/{today_fmt}-iou_profit_margin.png"),
  plot   = plot_margin,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# CEO comp trend (if available)
if (!is.null(ceo_comp)) {
  plot_ceo_comp <- ceo_comp %>%
    ggplot(aes(x = year, y = comp_m)) +
    geom_col(fill = "#7A6C4F") +
    scale_x_continuous(breaks = report_year_range) +
    scale_y_continuous(labels = dollar_format(suffix = "M"), expand = c(0, 0), limits = c(0, NA)) +
    theme_lopu() +
    labs(
      title   = glue("{utility_name} CEO total compensation"),
      x       = "",
      y       = "Total compensation (USD millions)",
      caption = "SEC EDGAR DEF 14A (Summary Compensation Table)"
    )

  ggsave(
    glue("plots/{today_fmt}-iou_ceo_compensation.png"),
    plot   = plot_ceo_comp,
    width  = 7.5, height = 5, dpi = 350, units = "in"
  )
}

# ==============================================================================
# SAVE OUTPUTS
# ==============================================================================

save_output(financials,         "iou_financials_annual")
save_output(financials_indexed, "iou_financials_indexed")

message("Script 06 complete.")

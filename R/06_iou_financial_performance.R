# ==============================================================================
# 06_iou_financial_performance.R
# Lights Out, Profits Up — Georgia Power Report
#
# PURPOSE: "Profits Up" — Southern Company / Georgia Power financial performance.
#
# Architecture: Two independent sections.
#
#   Section A — Stock & Dividend Analysis
#   Runs with locally collected CSV data. No 10-K dependency.
#   Data: Data/financial_markets/iou_stock/SO/ (collected via iou_stock_collector.R)
#   Outputs: 5 CSVs + 4 plots
#
#   Section B — 10-K & DEF 14A Analysis
#   Runs only when data/10k_*.csv is present. Skips gracefully if missing.
#   Outputs: 2 CSVs + 2 plots + 1 optional CEO comp plot
#
# Section A metrics:
#   - Annual stock prices (unadjusted + adjusted)
#   - Annual dividend per share
#   - Total shareholder return (TSR): capital gain + dividend yield
#   - Cumulative TSR
#   - Dividend payouts (DPS × shares outstanding)
#   - Cumulative dividend payouts
#   - Dividend yield (annual %)
#   - Market capitalization
#   - Customer bill impact contrast (vs. script 04 rate trend output)
# ==============================================================================

source("R/01_setup_and_data_prep.R")
source("R/00_visual_styling.R")

library(scales)

# ==============================================================================
# HELPER: load a prior-script output CSV by filename pattern
# ==============================================================================

load_output <- function(pattern) {
  f <- list.files("outputs", pattern = pattern, full.names = TRUE)
  if (length(f) == 0) {
    message(glue("No output found matching '{pattern}' — skipping."))
    return(NULL)
  }
  read.csv(f[[1]])
}

# ==============================================================================
# SECTION A — STOCK & DIVIDEND ANALYSIS (runs with available local data)
# ==============================================================================

# --- A1: Load stock prices ---
# Expects: symbol, date, open, high, low, close (unadjusted), volume, adjusted
stock_prices_file <- list.files(path_iou_stock,
                                 pattern = paste0(ticker, "_stock_prices"),
                                 full.names = TRUE)

if (length(stock_prices_file) == 0) {
  stop(glue("Stock prices CSV not found in {path_iou_stock}. Run iou_stock_collector.R first."))
}

stock_prices <- read.csv(stock_prices_file[[1]]) %>%
  mutate(date = as.Date(date))

# --- A2: Load dividends ---
# Expects: symbol, date, value (per-share dividend amount)
dividends_file <- list.files(path_iou_stock,
                              pattern = paste0(ticker, "_dividends"),
                              full.names = TRUE)

if (length(dividends_file) == 0) {
  stop(glue("Dividends CSV not found in {path_iou_stock}. Run iou_stock_collector.R first."))
}

dividends_raw <- read.csv(dividends_file[[1]]) %>%
  mutate(date = as.Date(date))

# --- A3: Load shares outstanding ---
# Expects: ticker, year, shares_outstanding (in millions)
shares_file <- list.files(path_iou_stock,
                           pattern = paste0(ticker, "_shares_outstanding"),
                           full.names = TRUE)

if (length(shares_file) == 0) {
  stop(glue("Shares outstanding CSV not found in {path_iou_stock}. Run iou_stock_collector.R first."))
}

shares_outstanding <- read.csv(shares_file[[1]])

# --- A4: Annual stock metrics ---
# Compute annual averages and start/end prices.
# Unadjusted close tracks the nominal share price (used for capital gain in TSR).
# Adjusted close accounts for dividends and splits (used for market cap and yield).
stock_annual <- stock_prices %>%
  mutate(year = as.integer(format(date, "%Y"))) %>%
  filter(year %in% report_year_range) %>%
  group_by(year) %>%
  summarize(
    avg_close          = mean(close, na.rm = TRUE),    # unadjusted annual avg close
    start_close        = first(close),                 # first trading day close (unadjusted)
    end_close          = last(close),                  # last trading day close (unadjusted)
    avg_adjusted_price = mean(adjusted, na.rm = TRUE), # split/dividend-adjusted avg (for cap/yield)
    annual_return_pct  = 100 * (last(adjusted) / first(adjusted) - 1) # adjusted price-only return
  ) %>%
  ungroup()

# --- A5: Annual dividend per share ---
# Sum all quarterly payments within each calendar year.
# SO pays quarterly; four payments per year (e.g., Feb, May, Aug, Nov).
dividend_annual <- dividends_raw %>%
  mutate(year = as.integer(format(date, "%Y"))) %>%
  filter(year %in% report_year_range) %>%
  group_by(year) %>%
  summarize(
    annual_dividend_per_share = sum(value, na.rm = TRUE), # total DPS for the year
    dividend_payments_count   = n()                        # number of quarterly payments
  ) %>%
  ungroup()

# --- A6 & A7: Total Shareholder Return (TSR) and Cumulative Return ---
# TSR methodology: unadjusted close for capital gain + raw dividends for yield.
# This produces a clean decomposition suitable for a stacked bar chart.
# - Capital gain: price appreciation from Jan 1 to Dec 31 (unadjusted close)
# - Dividend yield component: DPS / start-of-year price (not avg, per TSR convention)
# - Cumulative return: compound all annual TSRs (geometric chaining)
tsr <- stock_annual %>%
  left_join(dividend_annual, by = "year") %>%
  mutate(
    # Capital gain: % change in unadjusted close from first to last trading day
    capital_gain_pct       = 100 * (end_close - start_close) / start_close,
    # Dividend yield component: annual DPS relative to start-of-year price
    dividend_yield_tsr_pct = 100 * (annual_dividend_per_share / start_close),
    # Total shareholder return = price appreciation + dividend income
    total_return_pct       = capital_gain_pct + dividend_yield_tsr_pct
  ) %>%
  arrange(year) %>%
  mutate(
    # Compound annual TSRs: (1 + r1)(1 + r2)... − 1, expressed as %
    cumulative_return_pct = 100 * (cumprod(1 + total_return_pct / 100) - 1)
  )

# --- A8 & A9: Dividend payouts — total dollars flowing to shareholders ---
# Total payout = DPS × shares outstanding (millions → billions: divide by 1000)
dividend_payouts <- dividend_annual %>%
  left_join(shares_outstanding %>% select(year, shares_outstanding), by = "year") %>%
  rename(shares_millions = shares_outstanding) %>%
  arrange(year) %>%
  mutate(
    # Total annual dividend payout across all shareholders, in billions
    total_payout_b      = annual_dividend_per_share * shares_millions / 1000,
    # Running cumulative total since base year
    cumulative_payout_b = cumsum(total_payout_b)
  )

# --- A10 & A11: Add dividend yield and market cap to stock_annual ---
# Market cap = avg adjusted price × shares outstanding (millions → billions)
# Dividend yield = annual DPS / avg adjusted price (annual %)
stock_annual <- stock_annual %>%
  left_join(dividend_annual %>% select(year, annual_dividend_per_share), by = "year") %>%
  left_join(shares_outstanding %>% select(year, shares_outstanding), by = "year") %>%
  rename(shares_millions = shares_outstanding) %>%
  mutate(
    dividend_yield_pct = 100 * (annual_dividend_per_share / avg_adjusted_price),
    # market cap in billions: price × millions of shares ÷ 1000
    market_cap_b       = avg_adjusted_price * shares_millions / 1000
  )

# --- A12: Customer bill impact contrast ---
# Load script 04 rate trend output to compute aggregate excess paid vs. 2020 base rates.
# Methodology: excess = (rate_year − rate_2020) / 100 × total_kwh_year
# This isolates the rate increase effect, controlling for changes in electricity usage.
rate_trend <- load_output("eia_target_utility_rate_trend")

if (!is.null(rate_trend)) {
  base_rate <- rate_trend %>% filter(year == base_year) %>% pull(rate)

  customer_vs_shareholder <- rate_trend %>%
    filter(year %in% report_year_range) %>%
    left_join(dividend_payouts %>% select(year, total_payout_b, cumulative_payout_b), by = "year") %>%
    arrange(year) %>%
    mutate(
      # Average annual bill per residential customer: rate × avg kWh per customer
      avg_customer_bill            = rate / 100 * total_residential_kwh / total_residential_customers,
      # Total extra paid by all customers vs. what they would have paid at 2020 rates
      total_customer_excess_b      = (rate - base_rate) / 100 * total_residential_kwh / 1e9,
      # Running cumulative excess since base year (2020 excess = 0)
      cumulative_customer_excess_b = cumsum(total_customer_excess_b)
    ) %>%
    select(year, avg_customer_bill, total_customer_excess_b, cumulative_customer_excess_b,
           total_payout_b, cumulative_payout_b)
} else {
  message("Rate trend output not found — customer vs. shareholder contrast not computed.")
  customer_vs_shareholder <- NULL
}

# ==============================================================================
# SECTION A — SAVE OUTPUT CSVs
# ==============================================================================

save_output(stock_annual,    "iou_stock_annual_summary")
save_output(dividend_annual, "iou_dividend_annual")
save_output(
  tsr %>% select(year, start_close, end_close, annual_dividend_per_share,
                 capital_gain_pct, dividend_yield_tsr_pct, total_return_pct,
                 cumulative_return_pct),
  "iou_tsr"
)
save_output(dividend_payouts, "iou_dividend_payouts")

if (!is.null(customer_vs_shareholder)) {
  save_output(customer_vs_shareholder, "iou_customer_vs_shareholder")
}

# ==============================================================================
# SECTION A — PLOTS
# ==============================================================================

# --- Plot 1: Dividend per share trend (bar chart) ---
plot_dividend_per_share <- dividend_annual %>%
  ggplot(aes(x = year, y = annual_dividend_per_share)) +
  geom_col(fill = lopu_teal) +
  geom_text(aes(label = dollar(annual_dividend_per_share, accuracy = 0.01)),
            vjust = -0.4, size = 3.5, color = "grey30") +
  scale_x_continuous(breaks = report_year_range) +
  scale_y_continuous(
    labels = dollar_format(),
    expand = c(0, 0),
    limits = c(0, max(dividend_annual$annual_dividend_per_share) * 1.18)
  ) +
  theme_lopu() +
  labs(
    title    = glue("{parent_company} annual dividend per share"),
    subtitle = glue("{min(report_year_range)}–{max(report_year_range)}"),
    x        = "",
    y        = "Annual dividend per share (USD)",
    caption  = "Source: Yahoo Finance"
  )

ggsave(
  glue("plots/{today_fmt}-iou_dividend_per_share.png"),
  plot = plot_dividend_per_share,
  width = 7.5, height = 5, dpi = 350, units = "in"
)

# --- Plot 2: TSR decomposition — stacked bar (capital gain + dividend yield) ---
# Shows annual TSR broken into two components; total labeled above each bar.
tsr_plot_data <- tsr %>%
  select(year, capital_gain_pct, dividend_yield_tsr_pct) %>%
  pivot_longer(c(capital_gain_pct, dividend_yield_tsr_pct),
               names_to  = "component",
               values_to = "return_pct") %>%
  mutate(
    component_label = case_when(
      component == "capital_gain_pct"       ~ "Capital gain",
      component == "dividend_yield_tsr_pct" ~ "Dividend yield"
    )
  )

plot_tsr <- ggplot(tsr_plot_data, aes(x = year, y = return_pct, fill = component_label)) +
  geom_col(position = "stack") +
  geom_hline(yintercept = 0, linewidth = 0.4, color = "grey40") +
  geom_text(
    data        = tsr,
    aes(x = year, y = total_return_pct,
        label = paste0(round(total_return_pct, 1), "%")),
    inherit.aes = FALSE,
    vjust       = -0.5, size = 3.5, color = "grey30"
  ) +
  scale_fill_manual(values = c("Capital gain" = lopu_navy, "Dividend yield" = lopu_teal)) +
  scale_x_continuous(breaks = report_year_range) +
  scale_y_continuous(labels = function(x) paste0(round(x, 0), "%"), expand = c(0.12, 0)) +
  theme_lopu() +
  labs(
    title    = glue("{parent_company} total shareholder return"),
    subtitle = glue("Capital gain + dividend yield, {min(report_year_range)}–{max(report_year_range)}"),
    x        = "",
    y        = "Annual return (%)",
    fill     = "",
    caption  = "Source: Yahoo Finance. Capital gain uses unadjusted close prices."
  )

ggsave(
  glue("plots/{today_fmt}-iou_tsr_decomposition.png"),
  plot = plot_tsr,
  width = 7.5, height = 5, dpi = 350, units = "in"
)

# --- Plot 3: Cumulative dividend payouts — bars + cumulative line overlay ---
# Bars show annual payout; line tracks running total since base year.
plot_dividend_payouts <- dividend_payouts %>%
  ggplot(aes(x = year)) +
  geom_col(aes(y = total_payout_b), fill = lopu_teal, alpha = 0.85) +
  geom_line(aes(y = cumulative_payout_b), color = lopu_blue, linewidth = 1.4) +
  geom_point(aes(y = cumulative_payout_b), color = lopu_blue, size = 3) +
  geom_text(
    aes(y = cumulative_payout_b,
        label = dollar(cumulative_payout_b, accuracy = 0.1, suffix = "B")),
    vjust = -0.6, size = 3.2, color = lopu_blue
  ) +
  scale_x_continuous(breaks = report_year_range) +
  scale_y_continuous(
    name     = "Annual payout ($ billions)",
    labels   = dollar_format(suffix = "B"),
    expand   = c(0, 0),
    limits   = c(0, max(dividend_payouts$cumulative_payout_b) * 1.15)
  ) +
  theme_lopu() +
  labs(
    title    = glue("{parent_company} dividend payouts to shareholders"),
    subtitle = glue("Bars = annual payout; line = cumulative since {min(report_year_range)}"),
    x        = "",
    caption  = "Source: Yahoo Finance (dividends); stockanalysis.com (shares outstanding)"
  )

ggsave(
  glue("plots/{today_fmt}-iou_dividend_payouts.png"),
  plot = plot_dividend_payouts,
  width = 7.5, height = 5, dpi = 350, units = "in"
)

# --- Plot 4: Customer vs. shareholder contrast ---
# Grouped bars comparing cumulative excess bills (vs. 2020 rates) to cumulative dividends.
# Highlights the distributional tension: who bears rising costs vs. who benefits.
if (!is.null(customer_vs_shareholder)) {
  plot_customer_vs_shareholder <- customer_vs_shareholder %>%
    select(year, cumulative_customer_excess_b, cumulative_payout_b) %>%
    pivot_longer(c(cumulative_customer_excess_b, cumulative_payout_b),
                 names_to  = "series",
                 values_to = "value_b") %>%
    mutate(
      series_label = case_when(
        series == "cumulative_customer_excess_b" ~ "Cumulative customer excess\n(vs. 2020 rates)",
        series == "cumulative_payout_b"           ~ "Cumulative shareholder\ndividend payouts"
      )
    ) %>%
    ggplot(aes(x = year, y = value_b, fill = series_label)) +
    geom_col(position = "dodge") +
    scale_fill_manual(values = c(
      "Cumulative customer excess\n(vs. 2020 rates)"   = lopu_red,
      "Cumulative shareholder\ndividend payouts"         = lopu_teal
    )) +
    scale_x_continuous(breaks = report_year_range) +
    scale_y_continuous(
      labels = dollar_format(suffix = "B"),
      expand = c(0, 0),
      limits = c(0, NA)
    ) +
    theme_lopu() +
    labs(
      title    = glue("{utility_name} customers vs. {parent_company} shareholders"),
      subtitle = glue(
        "Cumulative excess bills (vs. 2020 rates) and cumulative dividends, ",
        "{min(report_year_range)}–{max(report_year_range)}"
      ),
      x        = "",
      y        = "Cumulative total ($ billions)",
      fill     = "",
      caption  = "Customer excess: EIA Form 861. Dividend payouts: Yahoo Finance, stockanalysis.com"
    )

  ggsave(
    glue("plots/{today_fmt}-iou_customer_vs_shareholder.png"),
    plot = plot_customer_vs_shareholder,
    width = 7.5, height = 5, dpi = 350, units = "in"
  )
}

message("Section A complete: stock/dividend analysis — 5 CSVs + 4 plots saved.")

# ==============================================================================
# SECTION B — 10-K ANALYSIS (skips if data not yet collected)
# ==============================================================================

if (is.null(financials_10k)) {
  message("Section B skipped: no 10-K data in data/. Collect per iou_financials_collector.md and rerun.")
} else {

  # Revenue and net income trends from SEC EDGAR 10-K
  financials <- financials_10k %>%
    filter(year %in% report_year_range) %>%
    arrange(year) %>%
    mutate(
      # Net profit margin: share of revenue that becomes net income
      profit_margin_pct = 100 * (net_income / revenue),
      revenue_b         = revenue / 1e9,
      net_income_b      = net_income / 1e9
    )

  base_financials <- financials %>% filter(year == base_year)

  # Index all financial metrics to base year = 100 for trend comparison
  financials_indexed <- financials %>%
    mutate(
      revenue_index    = 100 * (revenue        / base_financials$revenue),
      net_income_index = 100 * (net_income      / base_financials$net_income),
      dividends_index  = 100 * (dividends_paid  / base_financials$dividends_paid),
      # Payout ratio: share of net income returned to shareholders as dividends
      payout_ratio_pct = 100 * (dividends_paid  / net_income)
    )

  cat("\n--- FINANCIAL PERFORMANCE SUMMARY ---\n")
  financials %>%
    select(year, revenue_b, net_income_b, profit_margin_pct) %>%
    print()

  # Revenue and net income trend plot
  plot_financials <- financials %>%
    select(year, revenue_b, net_income_b) %>%
    pivot_longer(c(revenue_b, net_income_b),
                 names_to  = "metric",
                 values_to = "value_b") %>%
    mutate(
      metric_label = case_when(
        metric == "revenue_b"    ~ "Revenue",
        metric == "net_income_b" ~ "Net income"
      )
    ) %>%
    ggplot(aes(x = year, y = value_b, color = metric_label)) +
    geom_line(linewidth = 1.5) +
    geom_point(size = 3) +
    scale_color_manual(values = c("Revenue" = lopu_navy, "Net income" = lopu_gold)) +
    scale_x_continuous(breaks = report_year_range) +
    scale_y_continuous(labels = dollar_format(suffix = "B"), expand = c(0, 0), limits = c(0, NA)) +
    theme_lopu() +
    labs(
      title    = glue("{parent_company} revenue and net income"),
      subtitle = glue("{min(report_year_range)}–{max(report_year_range)}"),
      x        = "",
      y        = "USD (billions)",
      color    = "",
      caption  = "SEC EDGAR 10-K"
    )

  ggsave(
    glue("plots/{today_fmt}-iou_revenue_net_income.png"),
    plot = plot_financials,
    width = 7.5, height = 5, dpi = 350, units = "in"
  )

  # Profit margin trend plot
  plot_margin <- financials %>%
    ggplot(aes(x = year, y = profit_margin_pct)) +
    geom_line(color = lopu_blue, linewidth = 1.5) +
    geom_point(color = lopu_blue, size = 3) +
    geom_hline(yintercept = 0, linewidth = 0.4, color = "grey40") +
    scale_x_continuous(breaks = report_year_range) +
    scale_y_continuous(expand = c(0.02, 0)) +
    theme_lopu() +
    labs(
      title   = glue("{parent_company} profit margin"),
      x       = "",
      y       = "Net profit margin (%)",
      caption = "SEC EDGAR 10-K"
    )

  ggsave(
    glue("plots/{today_fmt}-iou_profit_margin.png"),
    plot = plot_margin,
    width = 7.5, height = 5, dpi = 350, units = "in"
  )

  save_output(financials,         "iou_financials_annual")
  save_output(financials_indexed, "iou_financials_indexed")

  message("Section B complete: 10-K analysis — 2 CSVs + 2 plots saved.")

} # end Section B

# ==============================================================================
# EXECUTIVE COMPENSATION (DEF 14A) — runs independently of 10-K
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
      # Index CEO pay to base year = 100 for indexed trend chart
      comp_index = 100 * (total_compensation / total_compensation[year == base_year]),
      # Convert to millions for readability
      comp_m     = total_compensation / 1e6
    )

  cat("\n--- CEO COMPENSATION TREND ---\n")
  ceo_comp %>% select(year, executive_name, comp_m) %>% print()

  plot_ceo_comp <- ceo_comp %>%
    ggplot(aes(x = year, y = comp_m)) +
    geom_col(fill = lopu_tan) +
    scale_x_continuous(breaks = report_year_range) +
    scale_y_continuous(labels = dollar_format(suffix = "M"), expand = c(0, 0), limits = c(0, NA)) +
    theme_lopu() +
    labs(
      title   = glue("{parent_company} CEO total compensation"),
      x       = "",
      y       = "Total compensation (USD millions)",
      caption = "SEC EDGAR DEF 14A (Summary Compensation Table)"
    )

  ggsave(
    glue("plots/{today_fmt}-iou_ceo_compensation.png"),
    plot = plot_ceo_comp,
    width = 7.5, height = 5, dpi = 350, units = "in"
  )

  save_output(exec_comp, "iou_exec_compensation")
  save_output(ceo_comp,  "iou_ceo_compensation_trend")
} else {
  message("DEF 14A: no exec comp data found in data/. Skipping CEO compensation analysis.")
  ceo_comp <- NULL
}

message("Script 06 complete.")

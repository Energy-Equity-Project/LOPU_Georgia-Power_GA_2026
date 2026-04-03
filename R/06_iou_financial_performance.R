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

# Use the last file alphabetically — the one with the highest end year
stock_prices <- read.csv(tail(sort(stock_prices_file), 1)) %>%
  mutate(date = as.Date(date))

# --- A2: Load dividends ---
# Expects: symbol, date, value (per-share dividend amount)
dividends_file <- list.files(path_iou_stock,
                              pattern = paste0(ticker, "_dividends"),
                              full.names = TRUE)

if (length(dividends_file) == 0) {
  stop(glue("Dividends CSV not found in {path_iou_stock}. Run iou_stock_collector.R first."))
}

# Use the last file alphabetically — the one with the highest end year
dividends_raw <- read.csv(tail(sort(dividends_file), 1)) %>%
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
  filter(year %in% stock_year_range) %>%
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
  filter(year %in% stock_year_range) %>%
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

message("Section A complete: stock/dividend analysis — 5 CSVs saved.")

# ==============================================================================
# SECTION B — 10-K ANALYSIS (skips if data not yet collected)
# ==============================================================================

if (is.null(financials_10k)) {
  message("Section B skipped: no 10-K data in data/. Collect per iou_financials_collector.md and rerun.")
} else {

  # Revenue and net income trends from SEC EDGAR 10-K
  financials <- financials_10k %>%
    arrange(year) %>%
    mutate(
      # Net profit margin: share of revenue that becomes net income
      profit_margin_pct = 100 * (net_income / revenue),
      revenue_b         = revenue / 1e9,
      net_income_b      = net_income / 1e9
    )

  base_financials <- financials %>% filter(year == min(year))

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

  save_output(financials,         "iou_financials_annual")
  save_output(financials_indexed, "iou_financials_indexed")

  message("Section B complete: 10-K analysis — 2 CSVs saved.")

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

  save_output(exec_comp, "iou_exec_compensation")
  save_output(ceo_comp,  "iou_ceo_compensation_trend")
} else {
  message("DEF 14A: no exec comp data found in data/. Skipping CEO compensation analysis.")
  ceo_comp <- NULL
}

message("Script 06 complete.")

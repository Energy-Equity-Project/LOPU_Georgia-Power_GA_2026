# Southern Company Financial Analysis (2020-2025)
# Analyzing utility profits alongside rate increases for energy justice advocacy

# Load required libraries
library(tidyverse)
library(quantmod)
library(lubridate)
library(scales)
library(patchwork)
library(tidyquant)  # Enhanced quantmod wrapper with better data access

source("visual_styling.R")

# Create output directories
dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
dir.create("plots", recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# PART 1: DATA COLLECTION
# ============================================================================

# Southern Company ticker symbol
ticker <- "SO"

# Define date range (2020-2025)
start_date <- "2020-01-01"
end_date <- "2025-12-31"

# -----------------------------------------------------------------------------
# 1.1: Download Stock Price Data
# -----------------------------------------------------------------------------

cat("Downloading stock price data for Southern Company...\n")

# Download stock data
stock_data <- tq_get(ticker, 
                     get = "stock.prices",
                     from = start_date, 
                     to = end_date)

# Save raw stock data
write_csv(stock_data, "data/raw/southern_company_stock_prices.csv")
cat("✓ Stock price data saved\n")

# -----------------------------------------------------------------------------
# 1.2: Download Dividend Data
# -----------------------------------------------------------------------------

cat("Downloading dividend data...\n")

dividend_data <- tq_get(ticker, 
                        get = "dividends",
                        from = start_date,
                        to = end_date) %>%
  rename(dividends = value) %>%
  mutate(year = year(date)) %>%
  filter(year >= 2020, year <= 2025) %>%
  group_by(year) %>%
  summarise(
    total_dividends = sum(dividends),
    .groups = "drop"
  )

write_csv(dividend_data, "data/raw/southern_company_dividends.csv")
cat("✓ Dividend data saved\n")

# -----------------------------------------------------------------------------
# 1.4: Alternative - Use quantmod's getQuote for current data
# and calculate historical estimates
# -----------------------------------------------------------------------------

cat("\nDownloading current financial snapshot...\n")

# Get current quote with fundamental data
current_quote <- getQuote(ticker, what = yahooQF(c(
  "Name",
  "Last Trade (Price Only)",
  "Market Capitalization",
  "Earnings/Share",
  "P/E Ratio",
  "Dividend/Share",
  "Dividend Yield"
)))

write_csv(current_quote, "data/raw/southern_company_current_quote.csv")
cat("✓ Current quote data saved\n")

# -----------------------------------------------------------------------------
# 1.5: Manual Construction of Financial Time Series
# Based on publicly available data and estimates
# -----------------------------------------------------------------------------

cat("\nConstructing financial time series from market data...\n")

# Calculate annual metrics from stock data
annual_stock_metrics <- stock_data %>%
  mutate(year = year(date)) %>%
  filter(year >= 2020, year <= 2025) %>%
  group_by(year) %>%
  summarise(
    avg_price = mean(close),
    start_price = first(adjusted),
    end_price = last(adjusted),
    avg_volume = mean(volume)
  ) %>%
  ungroup()

# ============================================================================
# PART 2: DATA PROCESSING
# ============================================================================

# -----------------------------------------------------------------------------
# 2.1: Process Stock Data for Total Shareholder Return
# -----------------------------------------------------------------------------

cat("\nCalculating Total Shareholder Return...\n")

# Calculate annual returns
tsr_data <- annual_stock_metrics %>%
  mutate(
    capital_gain = (end_price - start_price) / start_price * 100
  ) %>%
  left_join(dividend_data, by = "year") %>%
  mutate(
    dividend_yield = (total_dividends / start_price) * 100,
    total_return = capital_gain + dividend_yield,
    cumulative_return = cumprod(1 + total_return/100) * 100 - 100
  )

write_csv(tsr_data, "data/processed/southern_company_tsr.csv")
cat("✓ Total Shareholder Return calculated\n")

# ============================================================================
# PART 3: VISUALIZATIONS (ECONOMIST STYLE)
# ============================================================================

cat("\nCreating visualizations...\n")

# Economist-style theme
theme_economist_custom <- function() {
  theme_minimal() +
    theme(
      # Text
      text = element_text(family = "sans", color = "#1a1a1a"),
      plot.title = element_text(size = 14, face = "bold", hjust = 0, 
                                margin = margin(b = 10)),
      plot.subtitle = element_text(size = 10, color = "#666666", hjust = 0,
                                   margin = margin(b = 15)),
      plot.caption = element_text(size = 8, color = "#999999", hjust = 0,
                                  margin = margin(t = 15)),
      
      # Axes
      axis.title = element_text(size = 9, color = "#666666"),
      axis.text = element_text(size = 8, color = "#666666"),
      axis.ticks = element_line(color = "#cccccc", linewidth = 0.3),
      
      # Grid
      panel.grid.major = element_line(color = "#e0e0e0", linewidth = 0.3),
      panel.grid.minor = element_blank(),
      
      # Legend
      legend.position = "top",
      legend.text = element_text(size = 8),
      legend.title = element_blank(),
      
      # Margins
      plot.margin = margin(20, 20, 20, 20)
    )
}

# Economist color palette
economist_colors <- c(
  "#0C7BDC",  # Primary blue
  "#E74C3C",  # Red
  "#27AE60",  # Green
  "#F39C12",  # Orange
  "#9B59B6",  # Purple
  "#1ABC9C"   # Teal
)

# Stock price


# -----------------------------------------------------------------------------
# 3.2: Total Shareholder Return
# -----------------------------------------------------------------------------

p2 <- tsr_data %>%
  select(year, total_return, capital_gain, dividend_yield) %>%
  pivot_longer(-c(year, total_return), names_to = "return_source", values_to = "return") %>%
  mutate(return_source = gsub("_", " ", return_source)) %>%
  ggplot(aes(x = year, y = return, fill = return_source)) +
  geom_bar(stat = "identity", alpha = 0.7) +
  scale_y_continuous(breaks = seq(0, 26, 2)) +
  scale_fill_manual(values = c("#0C7BDC", "#F39C12")) +
  geom_text(aes(y = total_return, 
                label = paste0(round(total_return, 1), "%")),
            vjust = -1, size = 12, color = "#333333") +
  scale_x_continuous(breaks = 2020:2025) +
  theme_minimal() +
  gslide_theme +
  labs(
    title = "Southern Company: Strong Shareholder Returns ",
    subtitle = "Cumulative shareholder 5 year return of 102%",
    x = NULL,
    y = "Annual Return (%)",
    fill = "",
    caption = "Source: Market data via tidyquant"
  )
  

ggsave(
  "plots/total_shareholder_return.png",
  p2,
  width = 10,
  height = 6,
  dpi = 300,
  bg = "white"
)
cat("✓ Total shareholder return visualization saved\n")



# Source: https://stockanalysis.com/stocks/so/financials/balance-sheet/
shares_outstanding <- data.frame(
  year = c(2020, 2021, 2022, 2023, 2024, 2025),
  shares_millions = c(1057, 1060, 1089, 1091, 1097, 1101)
)

annual_dividend_summary <- dividend_data %>%
  rename(total_dividends_per_share = total_dividends) %>%
  left_join(shares_outstanding, by = "year") %>%
  mutate(
    # Total payout in millions of dollars
    total_payout_millions = total_dividends_per_share * shares_millions,
    
    # Cumulative total since 2020
    cumulative_payout_millions = cumsum(total_payout_millions)
  )

dividend_payout_plot <- annual_dividend_summary %>%
  mutate(total_payout_billions = total_payout_millions/1e3) %>%
  ggplot(aes(x = year, y = total_payout_billions)) +
  geom_bar(stat = "identity", fill = "#E74C3C") +
  geom_text(aes(y = total_payout_billions,
                label = paste0("$", round(total_payout_billions, 1), "bn")),
            vjust = -1, size = 12, color = "#333333") +
  scale_x_continuous(breaks = seq(2020, 2025, 1)) +
  scale_y_continuous(breaks = seq(0, 3.5, 0.5)) +
  theme_minimal() +
  gslide_theme +
  labs(
    title = "Billions in divididends paid to Southern Company shareholders",
    subtitle = "$17.8 billion in cumulative divididend payouts (2020-2025)",
    x = "",
    y = "Annual Dividend Payout ($ billion)",
    caption = "Source: https://stockanalysis.com/stocks/so/financials/balance-sheet/"
  )

dividend_payout_plot

ggsave(
  "plots/total_divididend_payout.png",
  dividend_payout_plot,
  width = 10,
  height = 6,
  dpi = 300,
  bg = "white"
)

so_stock_plot <- stock_data %>%
  ggplot(aes(x = date, y = adjusted)) +
  geom_line(color = "#E74C3C") +
  theme_minimal() +
  gslide_theme +
  theme(
    plot.caption = element_text(family = "Inter", color = "grey50", size = 20, hjust = 1, vjust = 0)
  ) +
  labs(
    title = "Southern Company stock soars",
    subtitle = "Southern Company stock increases 76% (2020-2025)",
    x = "",
    y = "Adjusted Stock Price ($)",
    caption = "Source: Yahoo Finance, stock ticker: SO"
  )

so_stock_plot

ggsave(
  "plots/so_stock_ts.png",
  so_stock_plot,
  width = 10,
  height = 6,
  dpi = 300,
  bg = "white"
)

# ============================================================================
# PART 4: SUMMARY STATISTICS & REPORT
# ============================================================================

cat("\n" %+% strrep("=", 70) %+% "\n")
cat("SOUTHERN COMPANY FINANCIAL ANALYSIS SUMMARY (2020-2025)\n")
cat(strrep("=", 70) %+% "\n\n")

cat("KEY FINDINGS:\n")
cat(strrep("-", 70) %+% "\n")

# Shareholder returns
avg_tsr <- mean(tsr_data$total_return, na.rm = TRUE)
cat(sprintf("• Average Annual Shareholder Return: %.1f%%\n", avg_tsr))
cat(sprintf("  Cumulative 5-year return: %.1f%%\n\n", 
            tsr_data$cumulative_return[5]))



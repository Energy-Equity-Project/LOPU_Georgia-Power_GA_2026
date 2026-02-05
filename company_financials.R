# ==============================================================================
# Southern Company (SO) Stock Performance Analysis vs. S&P 500
# Period: 2020-2025
# Purpose: Energy justice research on utility financial performance
# ==============================================================================

# Load libraries ---------------------------------------------------------------
library(tidyverse)
library(quantmod)
library(lubridate)
library(scales)

# Set options
options(scipen = 999)  # Disable scientific notation

# Fetch stock data -------------------------------------------------------------
# Southern Company (Georgia Power parent)
getSymbols("SO", from = "2020-01-01", to = "2025-12-31", auto.assign = TRUE)

# S&P 500 for benchmark comparison
getSymbols("^GSPC", from = "2020-01-01", to = "2025-12-31", auto.assign = TRUE)

# Convert to data frames -------------------------------------------------------
so_df <- data.frame(
  date = index(SO),
  price = as.numeric(SO$SO.Adjusted),
  volume = as.numeric(SO$SO.Volume)
) %>%
  mutate(ticker = "Southern Company")

sp500_df <- data.frame(
  date = index(GSPC),
  price = as.numeric(GSPC$GSPC.Adjusted),
  volume = as.numeric(GSPC$GSPC.Volume)
) %>%
  mutate(ticker = "S&P 500")

# Calculate cumulative returns -------------------------------------------------
calc_returns <- function(df) {
  df %>%
    arrange(date) %>%
    mutate(
      daily_return = (price / lag(price)) - 1,
      cumulative_return = (price / first(price) - 1) * 100  # Percentage
    )
}

so_returns <- calc_returns(so_df)
sp500_returns <- calc_returns(sp500_df)

# Combine for comparison
comparison_df <- bind_rows(so_returns, sp500_returns)

# Annual summary statistics ----------------------------------------------------
annual_summary <- comparison_df %>%
  mutate(year = year(date)) %>%
  group_by(ticker, year) %>%
  summarize(
    start_price = first(price),
    end_price = last(price),
    annual_return = ((end_price / start_price) - 1) * 100,
    avg_daily_volume = mean(volume, na.rm = TRUE),
    volatility = sd(daily_return, na.rm = TRUE) * sqrt(252) * 100,  # Annualized
    .groups = "drop"
  )

print("Annual Performance Summary:")
print(annual_summary)

# Overall period performance ---------------------------------------------------
period_summary <- comparison_df %>%
  group_by(ticker) %>%
  summarize(
    start_date = min(date),
    end_date = max(date),
    total_return = last(cumulative_return),
    .groups = "drop"
  )

print("\nTotal Period Performance (2020-2025):")
print(period_summary)

# Get dividend data ------------------------------------------------------------
so_dividends <- getDividends("SO", from = "2020-01-01", to = "2025-12-31")

dividend_df <- data.frame(
  date = index(so_dividends),
  dividend = as.numeric(so_dividends)
) %>%
  mutate(year = year(date)) %>%
  group_by(year) %>%
  summarize(
    annual_dividend = sum(dividend),
    .groups = "drop"
  )

print("\nSouthern Company Annual Dividends:")
print(dividend_df)

# Visualization 1: Cumulative Returns ------------------------------------------
# Economist-style color palette
economist_colors <- c(
  "Southern Company" = "#E3120B",  # Economist red
  "S&P 500" = "#0C6291"            # Economist blue
)

p1 <- ggplot(comparison_df %>% filter(!is.na(cumulative_return)), 
             aes(x = date, y = cumulative_return, color = ticker)) +
  geom_line(linewidth = 1) +
  scale_color_manual(values = economist_colors) +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  labs(
    title = "Southern Company vs. S&P 500 Performance",
    subtitle = "Cumulative returns, 2020-2025",
    x = NULL,
    y = "Cumulative return",
    color = NULL,
    caption = "Source: Yahoo Finance via quantmod"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(color = "gray30", size = 11),
    legend.position = "top",
    legend.justification = "left",
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank()
  )

print(p1)
ggsave("southern_company_vs_sp500.png", p1, width = 10, height = 6, dpi = 300)

# Visualization 2: Annual Returns Bar Chart -----------------------------------
p2 <- ggplot(annual_summary, aes(x = factor(year), y = annual_return, fill = ticker)) +
  geom_col(position = "dodge", width = 0.7) +
  geom_hline(yintercept = 0, linewidth = 0.5, color = "gray30") +
  scale_fill_manual(values = economist_colors) +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  labs(
    title = "Annual Returns by Year",
    subtitle = "Southern Company vs. S&P 500, 2020-2025",
    x = NULL,
    y = "Annual return",
    fill = NULL,
    caption = "Source: Yahoo Finance via quantmod"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(color = "gray30", size = 11),
    legend.position = "top",
    legend.justification = "left",
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank()
  )

print(p2)
ggsave("annual_returns_comparison.png", p2, width = 10, height = 6, dpi = 300)

# Export data for further analysis ---------------------------------------------
write_csv(comparison_df, "southern_company_stock_data.csv")
write_csv(annual_summary, "annual_performance_summary.csv")
write_csv(dividend_df, "southern_company_dividends.csv")

# Calculate dividend yield -----------------------------------------------------
# Using most recent price and annualized dividend
recent_price <- so_returns %>% 
  filter(date == max(date)) %>% 
  pull(price)

recent_dividend <- dividend_df %>% 
  filter(year == max(year)) %>% 
  pull(annual_dividend)

dividend_yield <- (recent_dividend / recent_price) * 100

cat("\n=== Key Metrics ===\n")
cat(sprintf("Southern Company Current Price: $%.2f\n", recent_price))
cat(sprintf("Annual Dividend (latest): $%.2f\n", recent_dividend))
cat(sprintf("Dividend Yield: %.2f%%\n", dividend_yield))
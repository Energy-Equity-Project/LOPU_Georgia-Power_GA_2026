# ==============================================================================
# 06a_financial_visualizations.R
# Lights Out, Profits Up — Georgia Power Report
#
# PURPOSE: Three standalone visualizations for non-technical audiences.
#   1. Residential rate % change: Georgia Power vs. cooperatives vs. municipals
#   2. Southern Company stock price, 2020–2025 (daily line chart)
#   3. Annual dividend payouts to Southern Company shareholders (bar chart)
#
# STYLING: Matches Archive/visual_styling.R "gslide_theme" — designed for
# Google Slides presentations. Uses Bitter (titles) and Inter (body) fonts
# via showtext, large text sizes, 10"×6" at 300 dpi.
#
# Sources script 01 for config. Does NOT source 00_visual_styling.R — uses
# its own gslide-compatible theme instead.
# Uses Archive stock data (2020–2025) since the main pipeline CSV only
# covers 2020–2024.
# ==============================================================================

source("R/01_setup_and_data_prep.R")

library(scales)
library(showtext)
library(sysfonts)

# ==============================================================================
# FONT + THEME SETUP (matches Archive/visual_styling.R)
# ==============================================================================

font_add_google("Inter", "Inter")
font_add_google("Bitter", "Bitter")
showtext_auto()

# Archive-style theme for Google Slides
gslide_theme <- theme(
  panel.background  = element_rect(fill = "white", color = NA),
  plot.background   = element_rect(fill = "white", color = NA),
  text              = element_text(family = "Inter"),
  plot.title        = element_text(family = "Bitter", size = 48, lineheight = 0.5),
  plot.subtitle     = element_text(family = "Bitter", size = 36, lineheight = 0.5),
  axis.title.y      = element_text(family = "Inter", size = 32),
  axis.title.x      = element_text(family = "Inter", size = 32),
  axis.text         = element_text(family = "Inter", size = 16),
  axis.text.x       = element_text(size = 24),
  axis.text.y       = element_text(size = 24),
  plot.margin       = margin(5, 5, 5, 0),
  strip.text        = element_text(family = "Inter", size = 16),
  legend.position   = "bottom",
  legend.title      = element_text(size = 24),
  legend.text       = element_text(size = 22),
  legend.margin     = margin(t = 0, b = 0, l = -100),
  panel.grid.major.y = element_blank(),
  panel.grid.minor.y = element_blank(),
  plot.caption      = element_text(family = "Inter", color = "grey50", size = 20,
                                    hjust = 1, vjust = 0)
)

# Archive accent color
accent_red <- "#E74C3C"

# ==============================================================================
# PLOT 1: Residential rate percent change (2020–2024)
# Weighted mean rate by ownership type, showing Georgia Power alongside
# cooperative and municipal aggregates.
# ==============================================================================

# Georgia Power rate change (from target_eia_sales loaded in script 01)
gp_rate <- target_eia_sales %>%
  group_by(year) %>%
  summarize(
    rate       = weighted.mean(residential_rate_cents_per_kwh, residential_customers, na.rm = TRUE),
    customers  = sum(residential_customers, na.rm = TRUE)
  ) %>%
  ungroup()

gp_rate_2020 <- gp_rate %>% filter(year == base_year) %>% pull(rate)
gp_rate_2024 <- gp_rate %>% filter(year == max(report_year_range)) %>% pull(rate)
gp_pct_change <- 100 * (gp_rate_2024 / gp_rate_2020 - 1)

# State-wide rates by ownership type (cooperatives and municipals aggregated)
state_by_ownership <- state_eia_sales %>%
  mutate(
    ownership_label = case_when(
      str_detect(tolower(ownership), "cooperat")           ~ "Cooperative",
      str_detect(tolower(ownership), "municipal|political") ~ "Municipal/Public",
      TRUE                                                  ~ NA_character_
    )
  ) %>%
  filter(!is.na(ownership_label)) %>%
  group_by(year, ownership_label) %>%
  summarize(
    rate      = weighted.mean(residential_rate_cents_per_kwh, residential_customers, na.rm = TRUE),
    customers = sum(residential_customers, na.rm = TRUE)
  ) %>%
  ungroup()

# Compute percent change for coops and municipals
ownership_pct_change <- state_by_ownership %>%
  filter(year %in% c(base_year, max(report_year_range))) %>%
  group_by(ownership_label) %>%
  arrange(year) %>%
  summarize(
    rate_2020  = first(rate),
    rate_2024  = last(rate),
    pct_change = 100 * (last(rate) / first(rate) - 1)
  ) %>%
  ungroup()

# Combine into one dataframe for the bar chart
rate_change_bars <- bind_rows(
  tibble(
    utility_type = "Georgia Power",
    pct_change   = gp_pct_change,
    rate_2020    = gp_rate_2020,
    rate_2024    = gp_rate_2024
  ),
  ownership_pct_change %>%
    transmute(
      utility_type = ownership_label,
      pct_change   = pct_change,
      rate_2020    = rate_2020,
      rate_2024    = rate_2024
    )
) %>%
  mutate(utility_type = fct_reorder(utility_type, pct_change))

plot_rate_change <- rate_change_bars %>%
  ggplot(aes(x = utility_type, y = pct_change)) +
  geom_col(width = 0.65, fill = accent_red) +
  geom_text(
    aes(label = paste0("+", round(pct_change, 1), "%")),
    hjust = -0.2, size = 12, color = "#333333"
  ) +
  scale_y_continuous(
    expand = c(0, 0),
    limits = c(0, max(rate_change_bars$pct_change) * 1.3)
  ) +
  coord_flip() +
  theme_minimal() +
  gslide_theme +
  labs(
    title    = "Georgia Power raised rates far more than other utilities",
    subtitle = "Cumulative residential electricity rate change, 2020–2024",
    x        = NULL,
    y        = "Rate change (%)",
    caption  = "Source: EIA Form 861"
  )

ggsave(
  glue("plots/{today_fmt}-rate_change_comparison.png"),
  plot  = plot_rate_change,
  width = 10, height = 6, dpi = 300, units = "in",
  bg    = "white"
)

# ==============================================================================
# PLOT 2: Southern Company stock price, 2020–2025
# Uses Archive daily data which extends through Dec 2025.
# ==============================================================================

stock_full <- read.csv("Archive/data/raw/southern_company_stock_prices.csv") %>%
  mutate(date = as.Date(date))

start_price <- stock_full %>% filter(date == min(date)) %>% pull(adjusted)
end_price   <- stock_full %>% filter(date == max(date)) %>% pull(adjusted)
pct_increase <- round(100 * (end_price / start_price - 1))

plot_stock_price <- stock_full %>%
  ggplot(aes(x = date, y = adjusted)) +
  geom_line(color = accent_red) +
  scale_x_date(
    date_breaks = "1 year",
    date_labels = "%Y",
    expand      = c(0.02, 0)
  ) +
  scale_y_continuous(
    labels = dollar_format(),
    expand = c(0.02, 0)
  ) +
  theme_minimal() +
  gslide_theme +
  labs(
    title    = "Southern Company stock soars",
    subtitle = glue("Southern Company stock increases {pct_increase}% (2020–2025)"),
    x        = NULL,
    y        = "Adjusted Stock Price ($)",
    caption  = "Source: Yahoo Finance, stock ticker: SO"
  )

ggsave(
  glue("plots/{today_fmt}-so_stock_price_2020_2025.png"),
  plot  = plot_stock_price,
  width = 10, height = 6, dpi = 300, units = "in",
  bg    = "white"
)

# ==============================================================================
# PLOT 3: Annual dividend payouts to shareholders (bar chart)
# Uses script 06 output for 2020–2024, plus Archive dividend data for 2025.
# 2025 shares outstanding (1,101M) from stockanalysis.com, hardcoded in
# Archive/southern_co_financials.R.
# ==============================================================================

load_output <- function(pattern) {
  f <- list.files("outputs", pattern = pattern, full.names = TRUE)
  if (length(f) == 0) {
    message(glue("No output found matching '{pattern}' — skipping."))
    return(NULL)
  }
  read.csv(f[[1]])
}

dividend_payouts <- load_output("iou_dividend_payouts")

if (!is.null(dividend_payouts)) {
  # Add 2025: DPS from Archive dividends, shares from stockanalysis.com
  dividend_payouts_full <- dividend_payouts %>%
    select(year, annual_dividend_per_share, shares_millions, total_payout_b) %>%
    bind_rows(tibble(
      year                      = 2025,
      annual_dividend_per_share = 2.94,
      shares_millions           = 1101,
      total_payout_b            = 2.94 * 1101 / 1000
    ))

  cumulative_total <- sum(dividend_payouts_full$total_payout_b)

  plot_annual_payouts <- dividend_payouts_full %>%
    ggplot(aes(x = year, y = total_payout_b)) +
    geom_bar(stat = "identity", fill = accent_red) +
    geom_text(
      aes(label = paste0("$", round(total_payout_b, 1), "bn")),
      vjust = -1, size = 12, color = "#333333"
    ) +
    scale_x_continuous(breaks = 2020:2025) +
    scale_y_continuous(
      breaks = seq(0, 3.5, 0.5),
      expand = c(0, 0),
      limits = c(0, max(dividend_payouts_full$total_payout_b) * 1.25)
    ) +
    theme_minimal() +
    gslide_theme +
    labs(
      title    = "Billions in dividends paid to Southern Company shareholders",
      subtitle = glue("${round(cumulative_total, 1)} billion in cumulative dividend payouts (2020–2025)"),
      x        = NULL,
      y        = "Annual Dividend Payout ($ billion)",
      caption  = "Source: Yahoo Finance (dividends per share); stockanalysis.com (shares outstanding)"
    )

  ggsave(
    glue("plots/{today_fmt}-so_annual_dividend_payouts.png"),
    plot  = plot_annual_payouts,
    width = 10, height = 6, dpi = 300, units = "in",
    bg    = "white"
  )
}

message("Script 06a complete — 3 visualizations saved to plots/.")

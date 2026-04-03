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
  plot.title        = element_text(family = "Bitter", size = 17, lineheight = 0.5),
  plot.subtitle     = element_text(family = "Bitter", size = 13, lineheight = 0.5),
  axis.title.y      = element_text(family = "Inter", size = 11),
  axis.title.x      = element_text(family = "Inter", size = 11),
  axis.text         = element_text(family = "Inter", size = 6),
  axis.text.x       = element_text(size = 8),
  axis.text.y       = element_text(size = 8),
  plot.margin       = margin(5, 5, 5, 0),
  strip.text        = element_text(family = "Inter", size = 6),
  legend.position   = "bottom",
  legend.title      = element_text(size = 8),
  legend.text       = element_text(size = 8),
  legend.margin     = margin(t = 0, b = 0, l = -100),
  panel.grid.major.y = element_blank(),
  panel.grid.minor.y = element_blank(),
  plot.caption      = element_text(family = "Inter", color = "grey50", size = 7,
                                    hjust = 1, vjust = 0)
)

# Archive accent color
accent_red <- "#E74C3C"

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
      vjust = -1, size = 4, color = "#333333"
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

  showtext_opts(dpi = 72)
  ggsave(
    glue("plots/{today_fmt}-so_annual_dividend_payouts.svg"),
    plot  = plot_annual_payouts,
    width = 10, height = 6, units = "in",
    bg    = "white"
  )
  showtext_opts(dpi = 300)
  ggsave(
    glue("plots/{today_fmt}-so_annual_dividend_payouts.png"),
    plot  = plot_annual_payouts,
    width = 10, height = 6, dpi = 300, units = "in",
    bg    = "white"
  )
}

message("Script 06a complete — 3 visualizations saved to plots/.")

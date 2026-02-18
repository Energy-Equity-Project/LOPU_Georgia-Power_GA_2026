# ==============================================================================
# 00_visual_styling.R
# Lights Out, Profits Up — [Utility Name] Report
#
# PURPOSE: Centralized color palettes and ggplot theme for the LOPU report.
# Source this file in scripts 02–07 after sourcing 01_setup_and_data_prep.R.
#
# Usage (top of each analysis script):
#   source("R/01_setup_and_data_prep.R")
#   source("R/00_visual_styling.R")
#
# DYNAMIC PALETTE ENTRIES: two palettes need a utility-specific entry added at
# runtime (after utility_name / utility_name_short are set in script 01):
#
#   Script 04 — add target utility to ownership_colors:
#     ownership_colors[glue("{utility_name} (IOU)")] <- lopu_gold
#
#   Script 07 — build full indexed chart color map:
#     color_map <- c(
#       setNames(lopu_gold, glue("{utility_name_short} residential rate")),
#       lopu_color_map
#     )
# ==============================================================================

# ==============================================================================
# NAMED COLOR CONSTANTS
# ==============================================================================

lopu_navy    <- "#002E55"   # primary — IOU, revenue, disconnection lines
lopu_blue    <- "#094094"   # secondary — net income, severity (some months)
lopu_blue_lt <- "#1577BF"   # tertiary — market cap, frequency (1-2 months)
lopu_gold    <- "#CFA43A"   # accent — target utility rate, CEO comp, all hardships
lopu_red     <- "#EB5757"   # hardship alert — disconnection rate, enrollment gap
lopu_green   <- "#40916C"   # positive — enrolled, cooperatives
lopu_teal    <- "#3A7F7A"   # dividends, unsafe temp
lopu_tan     <- "#7A6C4F"   # forgo essentials, CEO comp (indexed)
lopu_blue_dk <- "#1F4E79"   # deep navy — owner burden, forgo essentials (line)
lopu_gray    <- "#969EA4"   # neutral — municipal/public, did not report
lopu_gray_lt <- "#DEE7E4"   # light — never response

# ==============================================================================
# PULSE SURVEY PALETTES
# ==============================================================================

# Frequency response severity (stacked area charts in script 02)
severity_colors <- c(
  "Almost every month" = lopu_navy,
  "Some months"        = lopu_blue,
  "1 or 2 months"      = lopu_blue_lt,
  "Never"              = lopu_gray_lt,
  "Did not report"     = lopu_gray
)

# Binary insecurity co-occurrence (line chart in script 02)
hardship_colors <- c(
  "any_unable_bill"   = lopu_tan,
  "any_forgo_needs"   = lopu_blue_dk,
  "any_unsafe_temp"   = lopu_teal,
  "any_energy_issues" = lopu_blue,
  "all_energy_issues" = lopu_gold
)

# Display labels for hardship variable names (used in script 02 plot)
hardship_labels <- c(
  "any_unable_bill"   = "Unable to\npay bill",
  "any_forgo_needs"   = "Forgo\nessentials",
  "any_unsafe_temp"   = "Kept home at\nunsafe temp",
  "any_energy_issues" = "Experienced\nat least 1",
  "all_energy_issues" = "Experienced\nall 3"
)

# ==============================================================================
# BURDEN / LEAD PALETTE
# ==============================================================================

# Tenure groups (script 03 burden by FPL chart)
burden_tenure_colors <- c(
  "Owner"         = lopu_blue_dk,
  "Renter"        = lopu_gold,
  "Other/Unknown" = lopu_gray
)

# ==============================================================================
# RATE / OWNERSHIP PALETTE
# ==============================================================================

# Utility ownership types — base entries only.
# In script 04, add the target utility entry dynamically:
#   ownership_colors[glue("{utility_name} (IOU)")] <- lopu_gold
ownership_colors <- c(
  "Investor-Owned"   = lopu_navy,
  "Cooperative"      = lopu_green,
  "Municipal/Public" = lopu_gray
)

# ==============================================================================
# PROGRAM ENROLLMENT PALETTE
# ==============================================================================

# Enrolled vs. eligible-but-not-enrolled (script 05 bar chart)
enrollment_colors <- c(
  "Enrolled"                  = lopu_green,
  "Eligible but not enrolled" = lopu_red
)

# ==============================================================================
# RACIAL MAJORITY PALETTE (script 03)
# ==============================================================================

# Majority BIPOC vs. majority white census tracts
racial_majority_colors <- c(
  "Majority BIPOC"  = lopu_red,
  "Majority white"  = lopu_blue_dk
)

# ==============================================================================
# INDEXED COMPARISON PALETTE (script 07)
# ==============================================================================

# Static entries for the indexed trend chart.
# In script 07, prepend the utility-specific rate entry:
#   color_map <- c(
#     setNames(lopu_gold, glue("{utility_name_short} residential rate")),
#     lopu_color_map
#   )
lopu_color_map <- c(
  "Disconnection rate"      = lopu_red,
  "Utility revenue"         = lopu_navy,
  "Net income"              = lopu_blue,
  "CEO total compensation"  = lopu_tan,
  "Dividends per share"     = lopu_teal,
  "Market cap"              = lopu_blue_lt
)

# ==============================================================================
# GGPLOT THEME
# ==============================================================================

# Drop-in replacement for theme_minimal() with consistent LOPU styling.
# Use as: ggplot(...) + theme_lopu() + labs(...)
theme_lopu <- function() {
  theme_minimal() +
    theme(
      panel.background = element_rect(fill = "white", color = NA),
      plot.background  = element_rect(fill = "white", color = NA),
      panel.grid.minor = element_blank(),
      legend.position  = "bottom",
      legend.title     = element_blank(),
      plot.caption     = element_text(color = "grey50", size = 8, hjust = 1)
    )
}

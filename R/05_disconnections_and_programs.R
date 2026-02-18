# ==============================================================================
# 05_disconnections_and_programs.R
# Lights Out, Profits Up — Georgia Power Report
#
# PURPOSE: Disconnection rate analysis and affordability program enrollment gap.
#
# This is the most variable script across reports — data availability differs
# significantly by state and utility. Blocks marked # DATA REQUIRED must be
# customized once data is in hand.
#
# Metrics:
#   - Annual disconnection rate: disconnections / residential customers
#   - Seasonal patterns (if monthly data is available)
#   - Affordability program enrollment vs. estimated eligible population
#   - "Participation gap": eligible households not enrolled
#
# Data sources (in data/README.md):
#   - Disconnections: EJL Disconnection Dashboard (preferred) or GA PSC
#   - Enrollment: utility affordability program filings or PUC reports
#   - Eligible population: derived from DOE LEAD income data
# ==============================================================================

source("R/01_setup_and_data_prep.R")
source("R/00_visual_styling.R")

library(scales)

# ==============================================================================
# DISCONNECTION RATE
# ==============================================================================

# DATA REQUIRED: disconnections loaded in script 01 from data/disconnections_*.csv
# Expected columns: data_year, [month if available], residential_disconnections

if (is.null(disconnections)) {
  message("No disconnection data found. Populate data/ and rerun.")
  stop("Script 05 requires disconnection data.")
}

# Customer counts from cleaned EIA 861 (residential only)
residential_counts <- target_eia_sales %>%
  group_by(year) %>%
  summarize(residential_customers = sum(residential_customers, na.rm = TRUE),
            .groups = "drop") %>%
  rename(data_year = year)

# Annual disconnection rate
disconnection_rate <- disconnections %>%
  group_by(data_year) %>%
  summarize(
    total_disconnections = sum(residential_disconnections, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(residential_counts, by = "data_year") %>%
  mutate(
    disconnection_rate_pct = 100 * (total_disconnections / residential_customers)
  ) %>%
  filter(data_year %in% report_year_range)

cat("\n--- DISCONNECTION RATE SUMMARY ---\n")
print(disconnection_rate)

# ==============================================================================
# SEASONAL PATTERNS (if monthly data is available)
# ==============================================================================

# DATA REQUIRED: monthly disconnection data needs a 'month' column
# Comment out this block if only annual data is available.

if ("month" %in% colnames(disconnections)) {
  monthly_disconnections <- disconnections %>%
    filter(data_year %in% report_year_range) %>%
    group_by(data_year, month) %>%
    summarize(
      residential_disconnections = sum(residential_disconnections, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      month_date = as.Date(glue("{data_year}-{str_pad(month, 2, pad = '0')}-01"))
    )

  plot_seasonal <- monthly_disconnections %>%
    ggplot(aes(x = month_date, y = residential_disconnections)) +
    geom_line(color = "#002E55", linewidth = 1) +
    geom_point(color = "#002E55", size = 2) +
    scale_x_date(date_labels = "%b %y") +
    scale_y_continuous(labels = comma, expand = c(0, 0), limits = c(0, NA)) +
    theme_lopu() +
    labs(
      title   = glue("Monthly residential disconnections — {utility_name}"),
      x       = "",
      y       = "Disconnections",
      caption = "Source: see data/README.md"
    )

  ggsave(
    glue("plots/{today_fmt}-disconnections_monthly.png"),
    plot   = plot_seasonal,
    width  = 7.5, height = 5, dpi = 350, units = "in"
  )
} else {
  message("No monthly disconnection data — skipping seasonal plot.")
}

# ==============================================================================
# AFFORDABILITY PROGRAM ENROLLMENT & PARTICIPATION GAP
# ==============================================================================

# DATA REQUIRED: program_enrollment loaded in script 01 from data/program_enrollment_*.csv
# Expected columns: program_name, data_year, enrolled_count

# Estimate eligible population from LEAD (households at 0-200% FPL in territory)
eligible_population <- lead_territory %>%
  filter(fpl150 %in% c("0-100%", "100-150%", "150-200%")) %>%
  summarize(eligible_units = sum(units, na.rm = TRUE)) %>%
  pull(eligible_units)

cat(glue("\nEstimated eligible households (0-200% FPL): {scales::comma(eligible_population)}\n"))

if (!is.null(program_enrollment)) {
  enrollment_summary <- program_enrollment %>%
    filter(data_year %in% report_year_range) %>%
    group_by(data_year) %>%
    summarize(
      total_enrolled = sum(enrolled_count, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      eligible_population = eligible_population,
      participation_rate  = 100 * (total_enrolled / eligible_population),
      participation_gap   = eligible_population - total_enrolled
    )

  cat("\n--- PROGRAM ENROLLMENT SUMMARY ---\n")
  print(enrollment_summary)

  # Bar chart: enrolled vs. eligible
  enrollment_chart_data <- enrollment_summary %>%
    filter(data_year == max(data_year)) %>%
    pivot_longer(c(total_enrolled, participation_gap),
                 names_to = "group", values_to = "count") %>%
    mutate(
      group_label = case_when(
        group == "total_enrolled"    ~ "Enrolled",
        group == "participation_gap" ~ "Eligible but not enrolled"
      )
    )

  plot_enrollment <- enrollment_chart_data %>%
    ggplot(aes(x = "", y = count, fill = group_label)) +
    geom_col() +
    scale_fill_manual(
      values = c("Enrolled" = "#40916C", "Eligible but not enrolled" = "#EB5757")
    ) +
    scale_y_continuous(labels = comma, expand = c(0, 0)) +
    coord_flip() +
    theme_lopu() +
    labs(
      title    = glue("Affordability program enrollment — {utility_name}"),
      subtitle = glue("Latest available year: {max(enrollment_summary$data_year)}"),
      x        = "",
      y        = "Households",
      fill     = "",
      caption  = "Enrollment: utility/PUC filing. Eligible: DOE LEAD (0-200% FPL)."
    )

  ggsave(
    glue("plots/{today_fmt}-program_enrollment_gap.png"),
    plot   = plot_enrollment,
    width  = 7.5, height = 5, dpi = 350, units = "in"
  )

  save_output(enrollment_summary, "program_enrollment_summary")
} else {
  message("No program enrollment data found — skipping enrollment analysis.")
}

# ==============================================================================
# DISCONNECTION RATE TREND PLOT
# ==============================================================================

plot_disconnection_rate <- disconnection_rate %>%
  ggplot(aes(x = data_year, y = disconnection_rate_pct)) +
  geom_line(color = "#002E55", linewidth = 1.5) +
  geom_point(color = "#002E55", size = 3) +
  scale_x_continuous(breaks = report_year_range) +
  scale_y_continuous(expand = c(0, 0), limits = c(0, NA)) +
  theme_lopu() +
  labs(
    title    = glue("Residential disconnection rate — {utility_name}"),
    subtitle = glue("Disconnections per 100 residential customers, {min(report_year_range)}–{max(report_year_range)}"),
    x        = "",
    y        = "Disconnection rate (%)",
    caption  = "Disconnections: EJL Dashboard / GA PSC. Customers: EIA Form 861."
  )

ggsave(
  glue("plots/{today_fmt}-disconnection_rate_trend.png"),
  plot   = plot_disconnection_rate,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# ==============================================================================
# SAVE OUTPUTS
# ==============================================================================

save_output(disconnection_rate, "disconnection_rate_annual")

message("Script 05 complete.")

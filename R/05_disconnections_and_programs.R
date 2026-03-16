# ==============================================================================
# 05_disconnections_and_programs.R
# Lights Out, Profits Up — Georgia Power Report
#
# PURPOSE: Disconnection rate analysis and affordability program enrollment gap.
#
# Data source: EJL Disconnection Dashboard (cleaned by eep-pipeline-core).
# Monthly data loaded and filtered in script 01.
#
# Metrics:
#   - Annual disconnection rate: disconnections / residential customers
#   - Seasonal patterns (monthly time series)
#   - Reconnection ratio: reconnections / disconnections
#   - Affordability program enrollment vs. estimated eligible population
# ==============================================================================

source("R/01_setup_and_data_prep.R")
source("R/00_visual_styling.R")

library(scales)

# ==============================================================================
# GUARD: disconnection data required
# ==============================================================================

if (is.null(disconnections)) {
  message("No disconnection data found. Populate Cleaned_Data/ejl_disconnection_dashboard/ and rerun.")
  stop("Script 05 requires disconnection data.")
}

# ==============================================================================
# ANNUAL DISCONNECTION RATE
# ==============================================================================

# Customer counts from cleaned EIA 861 (residential only)
residential_counts <- target_eia_sales %>%
  group_by(year) %>%
  summarize(residential_customers = sum(residential_customers, na.rm = TRUE)) %>%
  ungroup() %>%
  rename(data_year = year)

# Sum valid months only; flag partial years
disconnection_annual <- disconnections %>%
  filter(data_quality == "valid") %>%
  group_by(data_year) %>%
  summarize(
    total_disconnections = sum(residential_disconnections, na.rm = TRUE),
    total_reconnections  = sum(residential_reconnections, na.rm = TRUE),
    valid_months         = n()
  ) %>%
  ungroup() %>%
  mutate(partial_year = valid_months < 12) %>%
  left_join(residential_counts, by = "data_year") %>%
  mutate(disconnection_rate_pct = 100 * (total_disconnections / residential_customers)) %>%
  filter(data_year %in% report_year_range)

cat("\n--- ANNUAL DISCONNECTION RATE ---\n")
print(disconnection_annual)

# ==============================================================================
# SUPPLEMENTAL: 2025 data (outside report_year_range)
# ==============================================================================

disconnection_2025 <- disconnections %>%
  filter(data_year == 2025, data_quality == "valid") %>%
  summarize(
    total_disconnections = sum(residential_disconnections, na.rm = TRUE),
    total_reconnections  = sum(residential_reconnections, na.rm = TRUE),
    valid_months         = n()
  ) %>%
  ungroup()

if (nrow(disconnection_2025) > 0 && disconnection_2025$valid_months > 0) {
  cat("\n--- 2025 SUPPLEMENTAL (partial year, outside report period) ---\n")
  print(disconnection_2025)
}

# ==============================================================================
# SEASONAL PATTERNS (monthly time series)
# ==============================================================================

monthly_disconnections <- disconnections %>%
  filter(data_year %in% report_year_range, !is.na(month)) %>%
  group_by(data_year, month) %>%
  summarize(
    residential_disconnections = sum(residential_disconnections, na.rm = TRUE),
    data_quality = first(data_quality)
  ) %>%
  ungroup() %>%
  mutate(
    month_date = as.Date(glue("{data_year}-{str_pad(month, 2, pad = '0')}-01"))
  )

plot_seasonal <- monthly_disconnections %>%
  ggplot(aes(x = month_date, y = residential_disconnections)) +
  geom_line(color = "#002E55", linewidth = 1) +
  geom_point(
    aes(shape = data_quality),
    color = "#002E55", size = 2
  ) +
  scale_shape_manual(
    values = c("valid" = 16, "moratorium_na" = 1, "incomplete_reporting" = 4),
    guide  = "none"
  ) +
  scale_x_date(date_labels = "%b %y") +
  scale_y_continuous(labels = comma, expand = c(0, 0), limits = c(0, NA)) +
  theme_lopu() +
  labs(
    title   = glue("Monthly residential disconnections — {utility_name}"),
    x       = "",
    y       = "Disconnections",
    caption = "Source: EJL Disconnection Dashboard. Open circles = COVID moratorium (NA). X = incomplete reporting."
  )

ggsave(
  glue("plots/{today_fmt}-disconnections_monthly.png"),
  plot   = plot_seasonal,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# ==============================================================================
# DISCONNECTIONS & RECONNECTIONS TIME SERIES (2020–2025, with moratorium shading)
# ==============================================================================

# Build monthly series including 2025
monthly_full <- disconnections %>%
  filter(!is.na(month)) %>%
  group_by(data_year, month, data_quality) %>%
  summarize(
    disconnections = sum(residential_disconnections, na.rm = TRUE),
    reconnections  = sum(residential_reconnections, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  mutate(
    month_date = as.Date(glue("{data_year}-{str_pad(month, 2, pad = '0')}-01"))
  )

# Pivot to long format for two-line plot
monthly_long <- monthly_full %>%
  filter(data_quality == "valid") %>%
  pivot_longer(
    cols      = c(disconnections, reconnections),
    names_to  = "metric",
    values_to = "count"
  ) %>%
  mutate(
    metric = case_when(
      metric == "disconnections" ~ "Disconnections",
      metric == "reconnections"  ~ "Reconnections"
    )
  )

# COVID moratorium shading bounds
moratorium_start <- as.Date("2020-03-15")
moratorium_end   <- as.Date("2020-06-30")

plot_disconn_reconn <- monthly_long %>%
  ggplot(aes(x = month_date, y = count, color = metric)) +
  annotate(
    "rect",
    xmin = moratorium_start, xmax = moratorium_end,
    ymin = -Inf, ymax = Inf,
    fill = lopu_gray_lt, alpha = 0.6
  ) +
  annotate(
    "text",
    x = moratorium_start + (moratorium_end - moratorium_start) / 2,
    y = Inf, vjust = 1.5,
    label = "COVID\nmoratorium",
    size = 2.8, color = "grey40", fontface = "italic"
  ) +
  geom_line(linewidth = 1) +
  scale_color_manual(
    values = c("Disconnections" = lopu_red, "Reconnections" = lopu_teal)
  ) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "6 months") +
  scale_y_continuous(labels = comma, expand = c(0, 0), limits = c(0, NA)) +
  theme_lopu() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(
    title    = glue("Monthly disconnections & reconnections — {utility_name}"),
    subtitle = "2020–2025 (through latest available month)",
    x        = "",
    y        = "Customers",
    caption  = paste0(
      "Source: EJL Disconnection Dashboard. ",
      "Shaded region = COVID moratorium (no disconnection data). ",
      "2025 data through August."
    )
  )

ggsave(
  glue("plots/{today_fmt}-disconnections_reconnections_monthly.png"),
  plot   = plot_disconn_reconn,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# ==============================================================================
# RECONNECTION RATIO ANALYSIS
# ==============================================================================

reconnection_ratio <- disconnection_annual %>%
  filter(total_disconnections > 0) %>%
  mutate(reconnection_ratio = total_reconnections / total_disconnections) %>%
  select(data_year, total_disconnections, total_reconnections, reconnection_ratio, partial_year)

cat("\n--- RECONNECTION RATIO ---\n")
print(reconnection_ratio)

plot_reconnection <- reconnection_ratio %>%
  ggplot(aes(x = data_year, y = reconnection_ratio)) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "grey60") +
  geom_line(color = lopu_teal, linewidth = 1.5) +
  geom_point(
    aes(shape = partial_year),
    color = lopu_teal, size = 3
  ) +
  scale_shape_manual(
    values = c("FALSE" = 16, "TRUE" = 1),
    labels = c("FALSE" = "Full year", "TRUE" = "Partial year"),
    name   = ""
  ) +
  scale_x_continuous(breaks = report_year_range) +
  scale_y_continuous(expand = c(0.05, 0)) +
  theme_lopu() +
  labs(
    title    = glue("Reconnection ratio — {utility_name}"),
    subtitle = "Reconnections per disconnection (1.0 = full reconnection)",
    x        = "",
    y        = "Reconnection ratio",
    caption  = "Source: EJL Disconnection Dashboard. Open circles = partial year data."
  )

ggsave(
  glue("plots/{today_fmt}-reconnection_ratio.png"),
  plot   = plot_reconnection,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# ==============================================================================
# DISCONNECTION RATE TREND PLOT
# ==============================================================================

plot_disconnection_rate <- disconnection_annual %>%
  ggplot(aes(x = data_year, y = disconnection_rate_pct)) +
  geom_line(color = "#002E55", linewidth = 1.5) +
  geom_point(
    aes(shape = partial_year),
    color = "#002E55", size = 3
  ) +
  scale_shape_manual(
    values = c("FALSE" = 16, "TRUE" = 1),
    labels = c("FALSE" = "Full year", "TRUE" = "Partial year"),
    name   = ""
  ) +
  scale_x_continuous(breaks = report_year_range) +
  scale_y_continuous(expand = c(0, 0), limits = c(0, NA)) +
  theme_lopu() +
  labs(
    title    = glue("Residential disconnection rate — {utility_name}"),
    subtitle = glue("Disconnections per 100 residential customers, {min(report_year_range)}–{max(report_year_range)}"),
    x        = "",
    y        = "Disconnection rate (%)",
    caption  = paste0(
      "Disconnections: EJL Disconnection Dashboard (valid months only). ",
      "Customers: EIA Form 861.\n",
      "2020: COVID moratorium — Jan–Jun NA; Jul–Dec valid. ",
      "2024: Oct–Dec incomplete reporting excluded."
    )
  )

ggsave(
  glue("plots/{today_fmt}-disconnection_rate_trend.png"),
  plot   = plot_disconnection_rate,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# ==============================================================================
# AFFORDABILITY PROGRAM ENROLLMENT & PARTICIPATION GAP
# ==============================================================================

eligible_population <- lead_territory %>%
  filter(fpl150 %in% c("0-100%", "100-150%", "150-200%")) %>%
  summarize(eligible_units = sum(units, na.rm = TRUE)) %>%
  pull(eligible_units)

cat(glue("\nEstimated eligible households (0-200% FPL): {scales::comma(eligible_population)}\n"))

if (!is.null(program_enrollment)) {
  enrollment_summary <- program_enrollment %>%
    filter(data_year %in% report_year_range) %>%
    group_by(data_year) %>%
    summarize(total_enrolled = sum(enrolled_count, na.rm = TRUE)) %>%
    ungroup() %>%
    mutate(
      eligible_population = eligible_population,
      participation_rate  = 100 * (total_enrolled / eligible_population),
      participation_gap   = eligible_population - total_enrolled
    )

  cat("\n--- PROGRAM ENROLLMENT SUMMARY ---\n")
  print(enrollment_summary)

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
# SAVE OUTPUTS
# ==============================================================================

save_output(disconnection_annual,  "disconnection_rate_annual")
save_output(monthly_disconnections, "disconnection_monthly")
save_output(reconnection_ratio,    "reconnection_ratio_annual")

message("Script 05 complete.")

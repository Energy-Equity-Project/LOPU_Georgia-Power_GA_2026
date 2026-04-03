# ==============================================================================
# archived_plots.R
# Lights Out, Profits Up — Georgia Power Report
#
# PURPOSE: Archive of removed plot code from the main pipeline scripts.
# These plots were removed to reduce the pipeline to the 8 final visualizations
# needed for the report. All data processing and CSV outputs are preserved in
# the parent scripts.
#
# To restore a plot, source the relevant parent script first, then run the
# code block below.
#
# Organized by source script.
# ==============================================================================


# ==============================================================================
# FROM: R/02_energy_insecurity.R
# Removed: pulse_unable_pay_bill.png, pulse_forego_essentials.png,
#          pulse_unsafe_temp.png, pulse_cooccurrence.png
# Requires: source("R/01_setup_and_data_prep.R"); source("R/02_energy_insecurity.R")
# ==============================================================================

severity_colors <- c(
  "Almost every month" = "#002E55",
  "Some months"        = "#094094",
  "1 or 2 months"      = "#1577BF",
  "Never"              = "#DEE7E4",
  "Did not report"     = "#969EA4"
)

hardship_colors <- c(
  "any_unable_bill"   = "#7A6C4F",
  "any_forgo_needs"   = "#1F4E79",
  "any_unsafe_temp"   = "#3A7F7A",
  "any_energy_issues" = "#094094",
  "all_energy_issues" = "#CFA43A"
)

hardship_labels <- c(
  "any_unable_bill"   = "Unable to\npay bill",
  "any_forgo_needs"   = "Forgo\nessentials",
  "any_unsafe_temp"   = "Kept home at\nunsafe temp",
  "any_energy_issues" = "Experienced\nat least 1",
  "all_energy_issues" = "Experienced\nall 3"
)

# Stacked area: unable to pay bill frequency
plot_unable_pay <- unable_pay_bill %>%
  filter(answer_desc != "Did not report") %>%
  mutate(answer_desc = droplevels(answer_desc)) %>%
  ggplot(aes(x = survey_date, y = percent, fill = answer_desc)) +
  geom_area(na.rm = TRUE) +
  scale_x_date(date_labels = "%b %y", expand = c(0, 5)) +
  scale_y_continuous(breaks = seq(0, 100, 10), expand = c(0, 0)) +
  coord_cartesian(ylim = c(0, 100)) +
  scale_fill_manual(values = severity_colors) +
  theme_lopu() +
  labs(
    title   = glue("Unable to pay energy bill — {utility_name_short} service territory, {state_abbrev}"),
    x       = "",
    y       = "Percent (%)",
    fill    = "",
    caption = "Household Pulse Survey, US Census"
  )

ggsave(
  glue("plots/{today_fmt}-pulse_unable_pay_bill.png"),
  plot   = plot_unable_pay,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# Stacked area: forgoing household essentials
plot_forego <- forego_essentials %>%
  filter(answer_desc != "Did not report") %>%
  mutate(answer_desc = droplevels(answer_desc)) %>%
  ggplot(aes(x = survey_date, y = percent, fill = answer_desc)) +
  geom_area(na.rm = TRUE) +
  scale_x_date(date_labels = "%b %y", expand = c(0, 5)) +
  scale_y_continuous(breaks = seq(0, 100, 10), expand = c(0, 0)) +
  coord_cartesian(ylim = c(0, 100)) +
  scale_fill_manual(values = severity_colors) +
  theme_lopu() +
  labs(
    title   = glue("Forgoing household essentials — {utility_name_short} service territory, {state_abbrev}"),
    x       = "",
    y       = "Percent (%)",
    fill    = "",
    caption = "Household Pulse Survey, US Census"
  )

ggsave(
  glue("plots/{today_fmt}-pulse_forego_essentials.png"),
  plot   = plot_forego,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# Stacked area: unsafe temperatures
plot_unsafe_temp <- hse_temp_dist %>%
  filter(answer_desc != "Did not report") %>%
  mutate(answer_desc = droplevels(answer_desc)) %>%
  ggplot(aes(x = survey_date, y = percent, fill = answer_desc)) +
  geom_area(na.rm = TRUE) +
  scale_x_date(date_labels = "%b %y", expand = c(0, 5)) +
  scale_y_continuous(breaks = seq(0, 100, 10), expand = c(0, 0)) +
  coord_cartesian(ylim = c(0, 100)) +
  scale_fill_manual(values = severity_colors) +
  theme_lopu() +
  labs(
    title   = glue("Home at unsafe temperature — {utility_name_short} service territory, {state_abbrev}"),
    x       = "",
    y       = "Percent (%)",
    fill    = "",
    caption = "Household Pulse Survey, US Census"
  )

ggsave(
  glue("plots/{today_fmt}-pulse_unsafe_temp.png"),
  plot   = plot_unsafe_temp,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# Line chart: co-occurrence trends
plot_cooccurrence <- cooccurrence %>%
  mutate(
    hardship_label = factor(hardship_labels[hardship], levels = hardship_labels)
  ) %>%
  ggplot(aes(x = survey_date, y = pct, color = hardship_label)) +
  geom_point(size = 2) +
  geom_line(linewidth = 1.5) +
  scale_x_date(date_labels = "%b %y", expand = c(0, 5)) +
  scale_y_continuous(limits = c(0, 60), breaks = seq(0, 60, 10), expand = c(0, 0)) +
  scale_color_manual(
    values = setNames(hardship_colors, hardship_labels),
    breaks = hardship_labels
  ) +
  theme_lopu() +
  labs(
    title   = glue("Energy insecurity rates — {utility_name_short} service territory, {state_abbrev}"),
    x       = "",
    y       = "Percent (%)",
    color   = "",
    caption = "Household Pulse Survey, US Census"
  )

ggsave(
  glue("plots/{today_fmt}-pulse_cooccurrence.png"),
  plot   = plot_cooccurrence,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)


# ==============================================================================
# FROM: R/03a_fpl_poverty_analysis.R
# Removed: fpl_poverty_comparison.png
# Requires: source("R/01_setup_and_data_prep.R"); source("R/03a_fpl_poverty_analysis.R")
# ==============================================================================

plot_fpl_comparison <- fpl_poverty_summary %>%
  ggplot(aes(x = geography, y = pct_below_fpl)) +
  geom_col(fill = "#1F4E79", width = 0.5) +
  geom_errorbar(
    aes(
      ymin = pct_below_fpl - (100 * moe_below_fpl / total_households),
      ymax = pct_below_fpl + (100 * moe_below_fpl / total_households)
    ),
    width = 0.15, color = "#555555"
  ) +
  scale_y_continuous(
    labels = scales::label_percent(scale = 1, accuracy = 0.1),
    expand = c(0, 0)
  ) +
  coord_cartesian(ylim = c(0, NA)) +
  theme_lopu() +
  labs(
    title   = glue("Households below 100% FPL — {state_name} vs. {utility_name_short} territory ({acs_year} ACS)"),
    x       = NULL,
    y       = "Share of households below 100% FPL",
    caption = glue("ACS 5-year estimates, {acs_year}. Table B17017. Error bars = 90% MOE.")
  )

ggsave(
  glue("plots/{today_fmt}-fpl_poverty_comparison.png"),
  plot   = plot_fpl_comparison,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)


# ==============================================================================
# FROM: R/03b_burden_racial_disparities.R
# Removed: lead_burden_by_race_fpl.png, lead_heag_by_race.png
# Requires: source("R/01_setup_and_data_prep.R"); source("R/03b_burden_racial_disparities.R")
# ==============================================================================

# Grouped bar — Energy burden by race x FPL tier (primary finding)
plot_burden_by_race_fpl <- lead_burden_by_race_fpl %>%
  ggplot(aes(x = fpl150, y = wgt_mean_burden, fill = racial_majority)) +
  geom_col(position = "dodge") +
  geom_hline(yintercept = 6, linetype = "dashed", color = "black", linewidth = 0.7) +
  annotate("text", x = 4.5, y = 6.4, label = "6% threshold",
           hjust = 0, size = 3.2, color = "black") +
  scale_fill_manual(values = racial_majority_colors) +
  scale_y_continuous(
    labels = scales::label_percent(scale = 1, accuracy = 0.1),
    expand = c(0, 0)
  ) +
  coord_cartesian(ylim = c(0, NA)) +
  theme_lopu() +
  labs(
    title   = glue("Energy burden by income level and tract racial composition — {utility_name_short} territory (2024 est.)"),
    x       = "Income (% of Federal Poverty Level)",
    y       = "Weighted mean energy burden (%)",
    caption = "DOE LEAD v4 (2022); projected to 2024 via EIA 861 rate change and ACS B19013 income growth.\nTract classification: >=50% non-white-NH units = \"Majority BIPOC\" (ecological measure)."
  )

ggsave(
  glue("plots/{today_fmt}-lead_burden_by_race_fpl.png"),
  plot   = plot_burden_by_race_fpl,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# Bar — HEAG per household by racial majority
plot_heag_by_race <- lead_heag_by_race %>%
  ggplot(aes(x = racial_majority, y = avg_gap_per_hh_annual, fill = racial_majority)) +
  geom_col(width = 0.5) +
  scale_fill_manual(values = racial_majority_colors, guide = "none") +
  scale_y_continuous(
    labels = scales::label_dollar(accuracy = 1),
    expand = c(0, 0)
  ) +
  coord_cartesian(ylim = c(0, NA)) +
  theme_lopu() +
  labs(
    title   = glue("Average home energy affordability gap per household — {utility_name_short} territory (2024 est.)"),
    x       = NULL,
    y       = "Avg. annual affordability gap ($/year)",
    caption = "DOE LEAD v4 (2022); projected to 2024. Gap = excess cost above 6% affordability threshold.\nTract classification: >=50% non-white-NH units = \"Majority BIPOC\" (ecological measure)."
  )

ggsave(
  glue("plots/{today_fmt}-lead_heag_by_race.png"),
  plot   = plot_heag_by_race,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)


# ==============================================================================
# FROM: R/04_rate_trends.R
# Removed: eia_rate_trends_by_ownership.png, eia_total_excess_all_customers.png
# Requires: source("R/01_setup_and_data_prep.R"); source("R/04_rate_trends.R")
# ==============================================================================

# System-wide excess (supplementary policy figure)
total_excess_b <- round(cf_latest$cumulative_excess_b, 1)

plot_total_excess <- counterfactual_analysis %>%
  mutate(annual_excess_m = annual_excess_b * 1000) %>%
  ggplot(aes(x = year, y = annual_excess_m)) +
  geom_col(fill = lopu_navy) +
  geom_text(
    aes(label = paste0("$", round(annual_excess_m), "M")),
    vjust = -0.5, size = 3.5, color = "grey20"
  ) +
  annotate(
    "text",
    x        = min(report_year_range),
    y        = Inf,
    label    = glue("5-year total: ${total_excess_b} billion"),
    size     = 4, fontface = "bold", color = "grey30",
    hjust    = 0, vjust    = 1.5
  ) +
  scale_x_continuous(breaks = report_year_range) +
  scale_y_continuous(
    labels  = function(x) paste0("$", round(x), "M"),
    limits  = c(0, NA),
    expand  = expansion(mult = c(0, 0.18))
  ) +
  theme_lopu() +
  labs(
    title    = glue("Total excess paid by all {utility_name} residential customers"),
    subtitle = glue("Compared to Muni & Coop rates, {min(report_year_range)}-{max(report_year_range)}"),
    x        = "",
    y        = "Total excess ($M)",
    caption  = "EIA Form 861"
  )

ggsave(
  glue("plots/{today_fmt}-eia_total_excess_all_customers.png"),
  plot   = plot_total_excess,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# Line chart: rate trends by ownership type + target utility (with gap ribbon)
ribbon_data <- counterfactual_analysis %>%
  select(year, ymin = muni_coop_rate, ymax = actual_rate)
rate_gap_latest <- round(cf_latest$actual_rate - cf_latest$muni_coop_rate, 2)

plot_rate_trends <- rate_comparison %>%
  filter(!is.na(rate), total_count > 0) %>%
  ggplot(aes(x = year, y = rate, color = ownership_label, linewidth = ownership_label)) +
  geom_ribbon(
    data        = ribbon_data,
    aes(x = year, ymin = ymin, ymax = ymax),
    fill        = lopu_gold,
    alpha       = 0.15,
    inherit.aes = FALSE
  ) +
  geom_line() +
  geom_point(size = 2) +
  annotate(
    "text",
    x        = max(report_year_range) - 0.1,
    y        = cf_latest$muni_coop_rate + (cf_latest$actual_rate - cf_latest$muni_coop_rate) / 2,
    label    = glue("Rate gap:\n{rate_gap_latest}c/kWh"),
    size     = 3, color = "grey30", hjust = 1, fontface = "italic"
  ) +
  scale_color_manual(
    values = ownership_colors,
    breaks = c(glue("{utility_name} (IOU)"), "Investor-Owned", "Cooperative", "Municipal/Public")
  ) +
  scale_linewidth_manual(
    values = setNames(
      c(2, 1, 1, 1),
      c(glue("{utility_name} (IOU)"), "Investor-Owned", "Cooperative", "Municipal/Public")
    ),
    guide = "none"
  ) +
  scale_x_continuous(breaks = report_year_range) +
  scale_y_continuous(expand = c(0, 0), limits = c(0, NA)) +
  theme_lopu() +
  labs(
    title    = glue("Residential electricity rates — {state_abbrev}"),
    subtitle = glue("{utility_name} vs. other utility types, {min(report_year_range)}-{max(report_year_range)}"),
    x        = "",
    y        = "Average rate (cents/kWh)",
    color    = "",
    caption  = "EIA Form 861"
  )

ggsave(
  glue("plots/{today_fmt}-eia_rate_trends_by_ownership.png"),
  plot   = plot_rate_trends,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)


# ==============================================================================
# FROM: R/05_disconnections_and_programs.R
# Removed: disconnections_monthly.png, reconnection_ratio.png,
#          disconnection_rate_trend.png, program_enrollment_gap.png
# Requires: source("R/01_setup_and_data_prep.R"); source("R/05_disconnections_and_programs.R")
# ==============================================================================

# Monthly disconnections only (seasonal pattern)
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

# Reconnection ratio trend
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

# Disconnection rate trend
plot_disconnection_rate <- disconnection_annual %>%
  filter(!is.na(disconnection_rate_pct)) %>%
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
    subtitle = glue("Disconnections per 100 residential customers, {min(report_year_range)}-{max(report_year_range)}"),
    x        = "",
    y        = "Disconnection rate (%)",
    caption  = paste0(
      "Disconnections: EJL Disconnection Dashboard (valid months only). ",
      "Customers: EIA Form 861.\n",
      "2020: COVID moratorium — Jan-Jun NA; Jul-Dec valid. ",
      "2024: Oct-Dec incomplete reporting excluded."
    )
  )

ggsave(
  glue("plots/{today_fmt}-disconnection_rate_trend.png"),
  plot   = plot_disconnection_rate,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# Affordability program enrollment gap
# Note: only runs when program_enrollment data is available.
# enrollment_summary must exist from the parent script's if-block.
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


# ==============================================================================
# FROM: R/06_iou_financial_performance.R
# Removed: iou_dividend_per_share.png, iou_tsr_decomposition.png,
#          iou_dividend_payouts.png, iou_customer_vs_shareholder.png,
#          iou_revenue_net_income.png, iou_profit_margin.png,
#          iou_ceo_compensation.png
# Requires: source("R/01_setup_and_data_prep.R"); source("R/06_iou_financial_performance.R")
# ==============================================================================

# Dividend per share trend (bar chart)
plot_dividend_per_share <- dividend_annual %>%
  ggplot(aes(x = year, y = annual_dividend_per_share)) +
  geom_col(fill = lopu_teal) +
  geom_text(aes(label = dollar(annual_dividend_per_share, accuracy = 0.01)),
            vjust = -0.4, size = 3.5, color = "grey30") +
  scale_x_continuous(breaks = stock_year_range) +
  scale_y_continuous(
    labels = dollar_format(),
    expand = c(0, 0),
    limits = c(0, max(dividend_annual$annual_dividend_per_share) * 1.18)
  ) +
  theme_lopu() +
  labs(
    title    = glue("{parent_company} annual dividend per share"),
    subtitle = glue("{min(stock_year_range)}-{max(stock_year_range)}"),
    x        = "",
    y        = "Annual dividend per share (USD)",
    caption  = "Source: Yahoo Finance"
  )

ggsave(
  glue("plots/{today_fmt}-iou_dividend_per_share.png"),
  plot = plot_dividend_per_share,
  width = 7.5, height = 5, dpi = 350, units = "in"
)

# TSR decomposition — stacked bar (capital gain + dividend yield)
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
  scale_x_continuous(breaks = stock_year_range) +
  scale_y_continuous(labels = function(x) paste0(round(x, 0), "%"), expand = c(0.12, 0)) +
  theme_lopu() +
  labs(
    title    = glue("{parent_company} total shareholder return"),
    subtitle = glue("Capital gain + dividend yield, {min(stock_year_range)}-{max(stock_year_range)}"),
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

# Cumulative dividend payouts — bars + cumulative line overlay
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
  scale_x_continuous(breaks = stock_year_range) +
  scale_y_continuous(
    name     = "Annual payout ($ billions)",
    labels   = dollar_format(suffix = "B"),
    expand   = c(0, 0),
    limits   = c(0, max(dividend_payouts$cumulative_payout_b) * 1.15)
  ) +
  theme_lopu() +
  labs(
    title    = glue("{parent_company} dividend payouts to shareholders"),
    subtitle = glue("Bars = annual payout; line = cumulative since {min(stock_year_range)}"),
    x        = "",
    caption  = "Source: Yahoo Finance (dividends); stockanalysis.com (shares outstanding)"
  )

ggsave(
  glue("plots/{today_fmt}-iou_dividend_payouts.png"),
  plot = plot_dividend_payouts,
  width = 7.5, height = 5, dpi = 350, units = "in"
)

# Customer vs. shareholder contrast
# Note: only runs when customer_vs_shareholder data is available.
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
      "{min(report_year_range)}-{max(stock_year_range)}"
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

# Revenue and net income trend (Section B — requires financials_10k data)
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
  scale_x_continuous(breaks = financials$year) +
  scale_y_continuous(labels = dollar_format(suffix = "B"), expand = c(0, 0), limits = c(0, NA)) +
  theme_lopu() +
  labs(
    title    = glue("{parent_company} revenue and net income"),
    subtitle = glue("{min(financials$year)}-{max(financials$year)}"),
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

# Profit margin trend (Section B — requires financials_10k data)
plot_margin <- financials %>%
  ggplot(aes(x = year, y = profit_margin_pct)) +
  geom_line(color = lopu_blue, linewidth = 1.5) +
  geom_point(color = lopu_blue, size = 3) +
  geom_hline(yintercept = 0, linewidth = 0.4, color = "grey40") +
  scale_x_continuous(breaks = financials$year) +
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

# CEO total compensation (DEF 14A — requires financials_def14a data)
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


# ==============================================================================
# FROM: R/06a_financial_visualizations.R
# Removed: rate_change_comparison.png, so_stock_price_2020_2025.png
# Requires: source("R/01_setup_and_data_prep.R"); source("R/06a_financial_visualizations.R")
# Note: gslide_theme and accent_red must be defined (see 06a header).
# ==============================================================================

# PLOT 1: Residential rate percent change (2020-2024)
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
    subtitle = "Cumulative residential electricity rate change, 2020-2024",
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

# PLOT 2: Southern Company stock price, 2020-2025
stock_full <- read.csv("Archive/data/raw/southern_company_stock_prices.csv") %>%
  mutate(date = as.Date(date))

start_price  <- stock_full %>% filter(date == min(date)) %>% pull(adjusted)
end_price    <- stock_full %>% filter(date == max(date)) %>% pull(adjusted)
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
    subtitle = glue("Southern Company stock increases {pct_increase}% (2020-2025)"),
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
# FROM: R/07_comparative_analysis.R
# Removed: lopu_indexed_comparison.png
# Requires: source("R/01_setup_and_data_prep.R"); source("R/07_comparative_analysis.R")
# ==============================================================================

color_map <- c(
  setNames(lopu_gold, glue("{utility_name_short} residential rate")),
  lopu_color_map
)

plot_hardship <- indexed_series %>%
  filter(metric %in% hardship_metrics) %>%
  ggplot(aes(x = year, y = index, color = metric)) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "grey60") +
  geom_line(linewidth = 1.5) +
  geom_point(size = 3) +
  scale_color_manual(values = color_map) +
  scale_x_continuous(breaks = report_year_range) +
  scale_y_continuous(breaks = seq(80, 160, 10), expand = c(0.02, 0)) +
  theme_lopu() +
  labs(
    title    = "Lights Out: energy hardship metrics",
    subtitle = glue("Indexed to {base_year} = 100"),
    x        = "",
    y        = "Index (base year = 100)",
    color    = ""
  )

plot_financial <- indexed_series %>%
  filter(metric %in% financial_metrics) %>%
  ggplot(aes(x = year, y = index, color = metric)) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "grey60") +
  geom_line(linewidth = 1.5) +
  geom_point(size = 3) +
  scale_color_manual(values = color_map) +
  scale_x_continuous(breaks = report_year_range) +
  scale_y_continuous(breaks = seq(80, 200, 20), expand = c(0.02, 0)) +
  theme_lopu() +
  labs(
    title    = "Profits Up: utility financial metrics",
    subtitle = glue("Indexed to {base_year} = 100"),
    x        = "",
    y        = "Index (base year = 100)",
    color    = "",
    caption  = "EIA Form 861, SEC EDGAR, Yahoo Finance / tidyquant, Household Pulse Survey"
  )

plot_indexed_combined <- plot_hardship / plot_financial

ggsave(
  glue("plots/{today_fmt}-lopu_indexed_comparison.png"),
  plot   = plot_indexed_combined,
  width  = 7.5, height = 10, dpi = 350, units = "in"
)

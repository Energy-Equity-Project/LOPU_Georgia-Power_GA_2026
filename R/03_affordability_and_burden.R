# ==============================================================================
# 03_affordability_and_burden.R
# Lights Out, Profits Up — Georgia Power Report
#
# PURPOSE: DOE LEAD energy burden analysis and Home Energy Affordability Gap
# (HEAG) calculation for Georgia Power's service territory.
#
# Metrics:
#   - Energy burden by FPL tier and tenure (owners vs. renters)
#   - Share of households above the 6% affordability threshold
#   - Home Energy Affordability Gap: total additional cost burden for
#     households above the 6% threshold
#   - Racial disparity in burden: majority-BIPOC vs. majority-white tracts
#   - Optional: choropleth map of burden by census tract
#
# DATA NOTE: Uses cleaned LEAD data. Pre-computed per-unit averages:
#   avg_electricity_cost, avg_gas_cost, avg_other_fuel_cost (annual, $/year)
#   avg_income (annual, $/year), fip (census tract GEOID), fpl150, ten (tenure)
# ==============================================================================

source("R/01_setup_and_data_prep.R")
source("R/00_visual_styling.R")

# ==============================================================================
# PREPARE LEAD DATA
# Use territory-filtered LEAD for Georgia Power (service territory crosswalk
# is active in script 01 — Georgia has many co-ops and municipals).
# ==============================================================================

lead_analysis <- lead_territory

# FPL tier ordering (DOE LEAD v4 labels)
fpl_levels <- c(
  "0-100%", "100-150%", "150-200%",
  "200-400%", "400%+"
)

lead_clean <- lead_analysis %>%
  filter(!is.na(avg_income), avg_income > 0) %>%
  mutate(
    # Total annual energy cost from pre-computed averages (all avg_* are annual, $/year)
    annual_energy_cost  = avg_electricity_cost + avg_gas_cost + avg_other_fuel_cost,
    # avg_income from LEAD is annual household income
    annual_income       = avg_income,
    # Energy burden as percent of income
    energy_burden_pct   = 100 * (annual_energy_cost / annual_income),
    # FPL tier as ordered factor
    fpl150 = factor(fpl150, levels = fpl_levels),
    # Tenure grouping (cleaned LEAD uses "OWN"/"RENT" in ten column)
    tenure_group = case_when(
      str_detect(tolower(ten), "own")  ~ "Owner",
      str_detect(tolower(ten), "ren") ~ "Renter",
      TRUE                             ~ "Other/Unknown"
    )
  ) %>%
  filter(energy_burden_pct >= 0, energy_burden_pct < 100)   # remove implausible values

# ==============================================================================
# PROJECT LEAD 2022 BASELINE TO 2024
# Electricity costs adjusted via EIA rate multiplier (2022→2024).
# Gas and other fuel costs held at 2022 baseline (no projection data).
# Income adjusted via ACS tract-level median income growth (B19013, 2022→2024).
# acs_income_growth and elec_rate_multiplier are computed in script 01.
# ==============================================================================

lead_projected <- lead_clean %>%
  left_join(acs_income_growth %>% select(GEOID, income_growth_factor),
            by = c("fip" = "GEOID")) %>%
  mutate(
    income_growth_factor       = replace_na(income_growth_factor, 1),
    est_electricity_cost_2024  = avg_electricity_cost * elec_rate_multiplier,
    est_annual_energy_cost_2024 = est_electricity_cost_2024 + avg_gas_cost + avg_other_fuel_cost,
    est_income_2024            = annual_income * income_growth_factor,
    est_burden_2024            = 100 * (est_annual_energy_cost_2024 / est_income_2024)
  ) %>%
  filter(est_burden_2024 >= 0, est_burden_2024 < 100)

# ==============================================================================
# ENERGY BURDEN BY FPL TIER
# ==============================================================================

burden_by_fpl <- lead_clean %>%
  group_by(fpl150) %>%
  summarize(
    median_burden   = median(energy_burden_pct, na.rm = TRUE),
    wgt_mean_burden = weighted.mean(energy_burden_pct, units, na.rm = TRUE),
    total_units     = sum(units, na.rm = TRUE),
    pct_above_6     = 100 * (sum(units[energy_burden_pct > 6], na.rm = TRUE) / sum(units, na.rm = TRUE)),
    .groups = "drop"
  )

# ==============================================================================
# ENERGY BURDEN BY FPL TIER × TENURE
# ==============================================================================

burden_by_fpl_tenure <- lead_clean %>%
  group_by(fpl150, tenure_group) %>%
  summarize(
    median_burden   = median(energy_burden_pct, na.rm = TRUE),
    wgt_mean_burden = weighted.mean(energy_burden_pct, units, na.rm = TRUE),
    total_units     = sum(units, na.rm = TRUE),
    pct_above_6     = 100 * (sum(units[energy_burden_pct > 6], na.rm = TRUE) / sum(units, na.rm = TRUE)),
    .groups = "drop"
  )

# ==============================================================================
# PROJECTED ENERGY BURDEN BY FPL TIER AND TENURE (2024)
# ==============================================================================

burden_by_fpl_projected <- lead_projected %>%
  group_by(fpl150) %>%
  summarize(
    median_burden   = median(est_burden_2024, na.rm = TRUE),
    wgt_mean_burden = weighted.mean(est_burden_2024, units, na.rm = TRUE),
    total_units     = sum(units, na.rm = TRUE),
    pct_above_6     = 100 * (sum(units[est_burden_2024 > 6], na.rm = TRUE) / sum(units, na.rm = TRUE)),
    .groups = "drop"
  )

burden_by_fpl_tenure_projected <- lead_projected %>%
  group_by(fpl150, tenure_group) %>%
  summarize(
    median_burden   = median(est_burden_2024, na.rm = TRUE),
    wgt_mean_burden = weighted.mean(est_burden_2024, units, na.rm = TRUE),
    total_units     = sum(units, na.rm = TRUE),
    pct_above_6     = 100 * (sum(units[est_burden_2024 > 6], na.rm = TRUE) / sum(units, na.rm = TRUE)),
    .groups = "drop"
  )

# ==============================================================================
# HOME ENERGY AFFORDABILITY GAP (HEAG)
# The total additional annual cost that households above 6% burden would need
# covered to reduce their energy burden to the 6% affordability threshold.
# ==============================================================================

heag_data <- lead_clean %>%
  filter(energy_burden_pct > 6) %>%
  mutate(
    affordable_cost = 0.06 * annual_income,
    excess_cost     = annual_energy_cost - affordable_cost,
    excess_cost     = pmax(excess_cost, 0)
  )

heag_summary <- heag_data %>%
  group_by(fpl150) %>%
  summarize(
    households_above_6pct   = sum(units, na.rm = TRUE),
    total_gap_annual_usd    = sum(excess_cost * units, na.rm = TRUE),
    avg_gap_per_hh_annual   = weighted.mean(excess_cost, units, na.rm = TRUE)
  ) %>%
  ungroup()

heag_total <- heag_data %>%
  summarize(
    households_above_6pct  = sum(units, na.rm = TRUE),
    total_gap_annual_usd   = sum(excess_cost * units, na.rm = TRUE),
    avg_gap_per_hh_annual  = weighted.mean(excess_cost, units, na.rm = TRUE)
  )

cat("\n--- HOME ENERGY AFFORDABILITY GAP SUMMARY (2022 baseline) ---\n")
cat(glue("Total households above 6% burden: {scales::comma(heag_total$households_above_6pct)}\n"))
cat(glue("Total annual gap: ${scales::dollar(heag_total$total_gap_annual_usd)}\n"))
cat(glue("Average gap per household/annual: ${round(heag_total$avg_gap_per_hh_annual, 0)}\n"))

# ==============================================================================
# PROJECTED HEAG (2024)
# ==============================================================================

heag_data_projected <- lead_projected %>%
  filter(est_burden_2024 > 6) %>%
  mutate(
    affordable_cost = 0.06 * est_income_2024,
    excess_cost     = est_annual_energy_cost_2024 - affordable_cost,
    excess_cost     = pmax(excess_cost, 0)
  )

heag_summary_projected <- heag_data_projected %>%
  group_by(fpl150) %>%
  summarize(
    households_above_6pct   = sum(units, na.rm = TRUE),
    total_gap_annual_usd    = sum(excess_cost * units, na.rm = TRUE),
    avg_gap_per_hh_annual   = weighted.mean(excess_cost, units, na.rm = TRUE)
  ) %>%
  ungroup()

heag_total_projected <- heag_data_projected %>%
  summarize(
    households_above_6pct  = sum(units, na.rm = TRUE),
    total_gap_annual_usd   = sum(excess_cost * units, na.rm = TRUE),
    avg_gap_per_hh_annual  = weighted.mean(excess_cost, units, na.rm = TRUE)
  )

cat("\n--- HOME ENERGY AFFORDABILITY GAP SUMMARY (2024 projected) ---\n")
cat(glue("Total households above 6% burden: {scales::comma(heag_total_projected$households_above_6pct)}\n"))
cat(glue("Total annual gap: ${scales::dollar(heag_total_projected$total_gap_annual_usd)}\n"))
cat(glue("Average gap per household/annual: ${round(heag_total_projected$avg_gap_per_hh_annual, 0)}\n"))

# ==============================================================================
# PROJECTED HEAG — 0-150% FPL ONLY (2024)
# ==============================================================================

heag_fpl0to150_projected <- heag_data_projected %>%
  filter(fpl150 %in% c("0-100%", "100-150%")) %>%
  summarize(
    fpl_range             = "0-150%",
    households_above_6pct = sum(units, na.rm = TRUE),
    total_gap_annual_usd  = sum(excess_cost * units, na.rm = TRUE),
    avg_gap_per_hh_annual = weighted.mean(excess_cost, units, na.rm = TRUE)
  )

cat("\n--- HEAG: 0-150% FPL ONLY (2024 projected) ---\n")
cat(glue("Households above 6% burden: {scales::comma(heag_fpl0to150_projected$households_above_6pct)}\n"))
cat(glue("Total annual gap: ${scales::dollar(heag_fpl0to150_projected$total_gap_annual_usd)}\n"))
cat(glue("Avg gap per household/yr: ${round(heag_fpl0to150_projected$avg_gap_per_hh_annual, 0)}\n"))

# ==============================================================================
# OPTIONAL: TRACT-LEVEL BURDEN MAP
# ==============================================================================

# burden_colors <- c(
#   "0-3%"   = "#1B4D3E",
#   "3-6%"   = "#40916C",
#   "6-9%"   = "#F2994A",
#   "9-12%"  = "#EB5757",
#   "12-15%" = "#D32F2F",
#   "15-20%" = "#B71C1C",
#   "20+%"   = "#7F0000"
# )
#
# lead_tract_summary <- lead_clean %>%
#   group_by(fip) %>%
#   summarize(
#     wgt_mean_burden = weighted.mean(energy_burden_pct, units, na.rm = TRUE),
#     .groups = "drop"
#   ) %>%
#   mutate(
#     burden_cat = case_when(
#       wgt_mean_burden < 3   ~ "0-3%",
#       wgt_mean_burden < 6   ~ "3-6%",
#       wgt_mean_burden < 9   ~ "6-9%",
#       wgt_mean_burden < 12  ~ "9-12%",
#       wgt_mean_burden < 15  ~ "12-15%",
#       wgt_mean_burden < 20  ~ "15-20%",
#       wgt_mean_burden >= 20 ~ "20+%",
#       TRUE                  ~ NA_character_
#     ),
#     burden_cat = factor(burden_cat,
#                         levels = c("0-3%", "3-6%", "6-9%",
#                                    "9-12%", "12-15%", "15-20%", "20+%"))
#   )
#
# tracts_sf %>%
#   left_join(lead_tract_summary, by = c("GEOID" = "fip")) %>%
#   ggplot(aes(fill = burden_cat)) +
#   geom_sf(color = NA) +
#   scale_fill_manual(values = burden_colors, na.value = "grey90") +
#   theme_minimal() +
#   labs(
#     title   = glue("Energy burden by census tract — {utility_name_short} service territory"),
#     fill    = "Energy burden",
#     caption = "DOE LEAD v4"
#   )
#
# ggsave(
#   glue("plots/{today_fmt}-lead_burden_map.png"),
#   width = 8, height = 6, dpi = 350, units = "in"
# )

# ==============================================================================
# BURDEN BY FPL: BAR CHART
# ==============================================================================

burden_colors_fpl <- c(
  "Owner"         = "#1F4E79",
  "Renter"        = "#CFA43A",
  "Other/Unknown" = "#969EA4"
)

plot_data_fpl <- burden_by_fpl_projected %>%
  mutate(
    above_threshold = wgt_mean_burden > 6,
    label_text = sprintf("%.1f%%", wgt_mean_burden)
  )

plot_burden_by_fpl <- plot_data_fpl %>%
  ggplot(aes(x = fpl150, y = wgt_mean_burden)) +
  geom_col(
    aes(fill = above_threshold),
    width = 0.7
  ) +
  geom_hline(
    yintercept = 6, linewidth = 0.6, color = "#D4622A"
  ) +
  annotate(
    "text", x = Inf, y = 6.6,
    label = "6% — affordable threshold",
    hjust = 1.05, size = 3.2, color = "#D4622A", fontface = "italic"
  ) +
  geom_text(
    aes(
      label = label_text,
      y     = case_when(above_threshold ~ wgt_mean_burden - 1.2, TRUE ~ wgt_mean_burden + 0.6),
      color = above_threshold
    ),
    size = 3.8, fontface = "bold"
  ) +
  scale_fill_manual(
    values = c("TRUE" = lopu_navy, "FALSE" = lopu_gray),
    guide  = "none"
  ) +
  scale_color_manual(
    values = c("TRUE" = "white", "FALSE" = "#333333"),
    guide  = "none"
  ) +
  scale_y_continuous(
    labels = scales::label_percent(scale = 1, accuracy = 1),
    expand = c(0, 0)
  ) +
  coord_cartesian(ylim = c(0, max(plot_data_fpl$wgt_mean_burden) * 1.15), clip = "off") +
  theme_lopu() +
  theme(
    plot.title         = element_text(face = "bold", size = 14, margin = margin(b = 4)),
    plot.subtitle      = element_text(color = "grey40", size = 10, margin = margin(b = 12)),
    panel.grid.major.x = element_blank(),
    axis.title.x       = element_text(margin = margin(t = 8)),
    axis.title.y       = element_text(margin = margin(r = 8)),
    plot.caption       = element_text(color = "grey50", size = 7.5, hjust = 0, margin = margin(t = 12)),
    plot.margin        = margin(t = 5, r = 80, b = 5, l = 5)
  ) +
  labs(
    title    = "Disproportionate Energy Burdens Affect Lower-Income Households",
    subtitle = glue("Weighted mean energy burden by income level — {utility_name_short} territory, {state_abbrev} (2024 est.)"),
    x        = "Federal Poverty Level (%)",
    y        = "Weighted Mean Energy Burden",
    caption  = "Source: DOE LEAD v4 (2022); electricity costs projected to 2024 via EIA 861 rate change; income via ACS B19013."
  )

ggsave(
  glue("plots/{today_fmt}-lead_burden_by_fpl.png"),
  plot   = plot_burden_by_fpl,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# ==============================================================================
# SAVE OUTPUTS
# ==============================================================================

# 2022 baseline outputs
save_output(burden_by_fpl,                       "lead_burden_by_fpl_baseline_2022")
save_output(burden_by_fpl_tenure,                "lead_burden_by_fpl_tenure_baseline_2022")
save_output(heag_summary,                        "lead_heag_by_fpl_baseline_2022")
save_output(heag_total %>% as_tibble(),          "lead_heag_total_baseline_2022")

# 2024 projected outputs
save_output(burden_by_fpl_projected,             "lead_burden_by_fpl_projected_2024")
save_output(burden_by_fpl_tenure_projected,      "lead_burden_by_fpl_tenure_projected_2024")
save_output(heag_summary_projected,              "lead_heag_by_fpl_projected_2024")
save_output(heag_total_projected %>% as_tibble(), "lead_heag_total_projected_2024")
save_output(heag_fpl0to150_projected %>% as_tibble(), "lead_heag_fpl0to150_projected_2024")

message("Script 03 complete.")

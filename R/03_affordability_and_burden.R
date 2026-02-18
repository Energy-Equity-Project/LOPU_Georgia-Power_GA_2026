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
#   avg_electricity_cost, avg_gas_cost, avg_other_fuel_cost (monthly)
#   avg_income (annual), fip (census tract GEOID), fpl150, ten (tenure)
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
  "200-250%", "250-300%", "300-400%",
  "400+%"
)

lead_clean <- lead_analysis %>%
  filter(!is.na(avg_income), avg_income > 0) %>%
  mutate(
    # Total monthly energy cost from pre-computed averages
    monthly_energy_cost = avg_electricity_cost + avg_gas_cost + avg_other_fuel_cost,
    annual_energy_cost  = monthly_energy_cost * 12,
    # avg_income from LEAD is annual household income
    annual_income       = avg_income,
    # Energy burden as percent of income
    energy_burden_pct   = 100 * (annual_energy_cost / annual_income),
    # FPL tier as ordered factor
    fpl150 = factor(fpl150, levels = fpl_levels),
    # Tenure grouping (cleaned LEAD uses "OWN"/"RENT" in ten column)
    tenure_group = case_when(
      str_detect(tolower(ten), "own")  ~ "Owner",
      str_detect(tolower(ten), "rent") ~ "Renter",
      TRUE                             ~ "Other/Unknown"
    )
  ) %>%
  filter(energy_burden_pct >= 0, energy_burden_pct < 100)   # remove implausible values

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
    avg_gap_per_hh_annual   = weighted.mean(excess_cost, units, na.rm = TRUE),
    avg_gap_per_hh_monthly  = avg_gap_per_hh_annual / 12,
    .groups = "drop"
  )

heag_total <- heag_data %>%
  summarize(
    households_above_6pct  = sum(units, na.rm = TRUE),
    total_gap_annual_usd   = sum(excess_cost * units, na.rm = TRUE),
    avg_gap_per_hh_annual  = weighted.mean(excess_cost, units, na.rm = TRUE),
    avg_gap_per_hh_monthly = avg_gap_per_hh_annual / 12
  )

cat("\n--- HOME ENERGY AFFORDABILITY GAP SUMMARY ---\n")
cat(glue("Total households above 6% burden: {scales::comma(heag_total$households_above_6pct)}\n"))
cat(glue("Total annual gap: ${scales::dollar(heag_total$total_gap_annual_usd)}\n"))
cat(glue("Average gap per household/month: ${round(heag_total$avg_gap_per_hh_monthly, 0)}\n"))

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

plot_burden_by_fpl <- burden_by_fpl_tenure %>%
  filter(tenure_group %in% c("Owner", "Renter")) %>%
  ggplot(aes(x = fpl150, y = wgt_mean_burden, fill = tenure_group)) +
  geom_col(position = "dodge") +
  geom_hline(yintercept = 6, linetype = "dashed", color = "red", linewidth = 0.8) +
  annotate("text", x = 0.6, y = 6.4, label = "6% affordability threshold",
           hjust = 0, size = 3.5, color = "red") +
  scale_fill_manual(values = burden_colors_fpl) +
  scale_y_continuous(expand = c(0, 0), limits = c(0, NA)) +
  theme_lopu() +
  labs(
    title   = glue("Energy burden by income level — {utility_name_short} service territory, {state_abbrev}"),
    x       = "Income (% of Federal Poverty Level)",
    y       = "Weighted mean energy burden (%)",
    fill    = "",
    caption = "DOE LEAD v4"
  )

ggsave(
  glue("plots/{today_fmt}-lead_burden_by_fpl.png"),
  plot   = plot_burden_by_fpl,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# ==============================================================================
# SAVE OUTPUTS
# ==============================================================================

save_output(burden_by_fpl,              "lead_burden_by_fpl")
save_output(burden_by_fpl_tenure,       "lead_burden_by_fpl_tenure")
save_output(heag_summary,               "lead_heag_by_fpl")
save_output(heag_total %>% as_tibble(), "lead_heag_total")

message("Script 03 complete.")

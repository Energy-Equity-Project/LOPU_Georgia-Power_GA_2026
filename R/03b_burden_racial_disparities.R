# ==============================================================================
# 03b_burden_racial_disparities.R
# Lights Out, Profits Up — Georgia Power Report
#
# PURPOSE: Analyze energy burden disparities by racial composition of census
# tracts within Georgia Power's service territory. Extends script 03 with the
# racial dimension — does not modify it.
#
# KEY FINDING: Burden by race × FPL tier isolates the racial dimension by
# showing burden differences *within the same income bracket*.
#
# METHODOLOGY NOTE: Tract-level "majority BIPOC/white" classification is an
# ecological measure. Disparities between tract types do not prove individual-
# level differences. See methodology_notes.md.
#
# OUTPUTS (6 CSVs, 3 PNGs):
#   - lead_burden_by_race            (2 rows: Majority BIPOC vs. white)
#   - lead_burden_by_race_fpl        (10 rows: 5 FPL tiers × 2 groups)
#   - lead_heag_by_race              (2 rows)
#   - lead_tract_racial_classification (~1,200 rows)
#   - acs_poverty_by_race_territory  (2 rows: Black, White-NH poverty rates)
#   - acs_income_distribution_by_race (~32 rows: 16 bins × 2 race groups)
# ==============================================================================

source("R/01_setup_and_data_prep.R")
source("R/00_visual_styling.R")
source("../../../Internal/data-pipelines/eep-pipeline-core/collectors/acs_collector.R")

acs_base_path <- "../../../Data/us_census/acs"

# ==============================================================================
# PREPARE LEAD DATA
# Replicates script 03 prep — 03b is independent so it can be sourced alone.
# ==============================================================================

fpl_levels <- c("0-100%", "100-150%", "150-200%", "200-400%", "400%+")

lead_clean <- lead_territory %>%
  filter(!is.na(avg_income), avg_income > 0) %>%
  mutate(
    annual_energy_cost = avg_electricity_cost + avg_gas_cost + avg_other_fuel_cost,
    annual_income      = avg_income,
    energy_burden_pct  = 100 * (annual_energy_cost / annual_income),
    fpl150             = factor(fpl150, levels = fpl_levels)
  ) %>%
  filter(energy_burden_pct >= 0, energy_burden_pct < 100)

lead_projected <- lead_clean %>%
  left_join(
    acs_income_growth %>% select(GEOID, income_growth_factor),
    by = c("fip" = "GEOID")
  ) %>%
  mutate(
    income_growth_factor        = replace_na(income_growth_factor, 1),
    est_electricity_cost_2024   = avg_electricity_cost * elec_rate_multiplier,
    est_annual_energy_cost_2024 = est_electricity_cost_2024 + avg_gas_cost + avg_other_fuel_cost,
    est_income_2024             = annual_income * income_growth_factor,
    est_burden_2024             = 100 * (est_annual_energy_cost_2024 / est_income_2024)
  ) %>%
  filter(est_burden_2024 >= 0, est_burden_2024 < 100)

# ==============================================================================
# TRACT-LEVEL RACIAL CLASSIFICATION
# Aggregate LEAD race columns by census tract (fip) to compute BIPOC share.
# Threshold: ≥50% non-white-NH units → "Majority BIPOC".
# LEAD race columns are housing unit counts at the row level (tract × FPL ×
# tenure × building × fuel); aggregating to tract level is methodologically valid.
# ==============================================================================

lead_tract_racial_classification <- lead_clean %>%
  group_by(fip) %>%
  summarize(
    white_nh_units = sum(white_alone_not_hispanic_or_latino, na.rm = TRUE),
    bipoc_units = sum(
      white_alone_hispanic_or_latino +
        black_or_african_american_alone +
        american_indian_and_alaska_native_alone +
        asian_alone +
        native_hawaiian_and_other_pacific_islander_alone +
        some_other_race_alone +
        two_or_more_races,
      na.rm = TRUE
    ),
    total_race_units = white_nh_units + bipoc_units
  ) %>%
  ungroup() %>%
  mutate(
    pct_bipoc = 100 * bipoc_units / total_race_units,
    racial_majority = case_when(
      pct_bipoc >= 50 ~ "Majority BIPOC",
      TRUE            ~ "Majority white"
    )
  )

# Join classification back to projected LEAD data
lead_projected <- lead_projected %>%
  left_join(
    lead_tract_racial_classification %>% select(fip, racial_majority, pct_bipoc),
    by = "fip"
  )

n_unclassified <- sum(is.na(lead_projected$racial_majority))
if (n_unclassified > 0) {
  message(glue("Note: {n_unclassified} LEAD rows could not be classified (missing tract race data)."))
}

# ==============================================================================
# ENERGY BURDEN BY RACIAL MAJORITY (overall)
# ==============================================================================

lead_burden_by_race <- lead_projected %>%
  filter(!is.na(racial_majority)) %>%
  group_by(racial_majority) %>%
  summarize(
    wgt_mean_burden = weighted.mean(est_burden_2024, units, na.rm = TRUE),
    median_burden   = median(est_burden_2024, na.rm = TRUE),
    total_units     = sum(units, na.rm = TRUE),
    pct_above_6     = 100 * sum(units[est_burden_2024 > 6], na.rm = TRUE) / sum(units, na.rm = TRUE)
  ) %>%
  ungroup()

cat("\n--- ENERGY BURDEN BY RACIAL MAJORITY (2024 projected) ---\n")
print(lead_burden_by_race)

# ==============================================================================
# ENERGY BURDEN BY RACIAL MAJORITY × FPL TIER (KEY FINDING)
# Shows burden differences within the same income bracket, isolating the
# racial dimension from the income dimension.
# ==============================================================================

lead_burden_by_race_fpl <- lead_projected %>%
  filter(!is.na(racial_majority)) %>%
  group_by(racial_majority, fpl150) %>%
  summarize(
    wgt_mean_burden = weighted.mean(est_burden_2024, units, na.rm = TRUE),
    median_burden   = median(est_burden_2024, na.rm = TRUE),
    total_units     = sum(units, na.rm = TRUE),
    pct_above_6     = 100 * sum(units[est_burden_2024 > 6], na.rm = TRUE) / sum(units, na.rm = TRUE)
  ) %>%
  ungroup()

cat("\n--- ENERGY BURDEN BY RACIAL MAJORITY × FPL TIER (2024 projected) ---\n")
print(lead_burden_by_race_fpl)

# ==============================================================================
# HEAG BY RACIAL MAJORITY
# ==============================================================================

heag_data_race <- lead_projected %>%
  filter(!is.na(racial_majority), est_burden_2024 > 6) %>%
  mutate(
    affordable_cost = 0.06 * est_income_2024,
    excess_cost     = pmax(est_annual_energy_cost_2024 - affordable_cost, 0)
  )

lead_heag_by_race <- heag_data_race %>%
  group_by(racial_majority) %>%
  summarize(
    households_above_6pct = sum(units, na.rm = TRUE),
    total_gap_annual_usd  = sum(excess_cost * units, na.rm = TRUE),
    avg_gap_per_hh_annual = weighted.mean(excess_cost, units, na.rm = TRUE)
  ) %>%
  ungroup()

cat("\n--- HEAG BY RACIAL MAJORITY (2024 projected) ---\n")
print(lead_heag_by_race)

# ==============================================================================
# ACS DATA COLLECTION
# Table set A — Poverty status by race (B17001B = Black, B17001H = White-NH)
# Table set B — Household income brackets by race (B19001B = Black, B19001H = White-NH)
# Collected at census tract level, filtered to territory_geoids, aggregated.
#
# NOTE: acs_extract_table_code() strips the race-group letter suffix, so
# B17001B/H are both cached under table "B17001" and B19001B/H under "B19001".
# Use force=TRUE on the primary collection to ensure all variables are fetched
# together rather than hitting a stale partial cache from a previous subset run.
# ==============================================================================

poverty_vars <- c("B17001B_001", "B17001B_002", "B17001H_001", "B17001H_002")
income_vars  <- c(
  paste0("B19001B_", sprintf("%03d", 1:17)),
  paste0("B19001H_", sprintf("%03d", 1:17))
)

# Try 2024 ACS; fall back to 2023 if unavailable.
# Fold year detection into the main collection to avoid partial-cache issues.
acs_year <- 2024
paths_poverty <- tryCatch({
  acs_collect(
    variables = poverty_vars,
    geography = "tract",
    year      = 2024,
    state     = state_abbrev,
    base_path = acs_base_path,
    force     = TRUE   # re-fetch to avoid stale partial-variable cache
  )
}, error = function(e) {
  message("2024 ACS not available — falling back to 2023.\n", e$message)
  acs_year <<- 2023
  acs_collect(
    variables = poverty_vars,
    geography = "tract",
    year      = 2023,
    state     = state_abbrev,
    base_path = acs_base_path
  )
})

paths_income <- acs_collect(
  variables = income_vars,
  geography = "tract",
  year      = acs_year,
  state     = state_abbrev,
  base_path = acs_base_path,
  force     = TRUE   # re-fetch to avoid stale partial-variable cache
)

# ==============================================================================
# READ ACS FILES
# acs_extract_table_code() strips the race-group letter suffix (e.g., "B17001B"
# → "B17001"), so the collector saves all race-specific poverty vars to one file
# and all race-specific income vars to one file. Read each file once, then split
# by variable prefix.
# ==============================================================================

b17001_all <- read.csv(
  paths_poverty$file_path[paths_poverty$table_code == "B17001"],
  stringsAsFactors = FALSE
)
b17001b_raw <- b17001_all %>% filter(str_starts(variable, "B17001B"))
b17001h_raw <- b17001_all %>% filter(str_starts(variable, "B17001H"))

b19001_all <- read.csv(
  paths_income$file_path[paths_income$table_code == "B19001"],
  stringsAsFactors = FALSE
)
b19001b_raw <- b19001_all %>% filter(str_starts(variable, "B19001B"))
b19001h_raw <- b19001_all %>% filter(str_starts(variable, "B19001H"))

# ==============================================================================
# POVERTY BY RACE — filter to territory, aggregate with MOE propagation
# ==============================================================================

process_poverty_by_race <- function(raw_df, race_label, total_var, poverty_var) {
  territory_agg <- raw_df %>%
    filter(GEOID %in% territory_geoids) %>%
    group_by(variable) %>%
    summarize(
      territory_estimate = sum(estimate, na.rm = TRUE),
      territory_moe      = sqrt(sum(moe^2, na.rm = TRUE))
    ) %>%
    ungroup()

  total_row   <- territory_agg %>% filter(variable == total_var)
  poverty_row <- territory_agg %>% filter(variable == poverty_var)

  tibble(
    race_group        = race_label,
    total_households  = total_row$territory_estimate,
    below_poverty     = poverty_row$territory_estimate,
    pct_below_poverty = 100 * poverty_row$territory_estimate / total_row$territory_estimate,
    moe_below_poverty = poverty_row$territory_moe
  )
}

acs_poverty_black    <- process_poverty_by_race(b17001b_raw, "Black or African American alone",
                                                 "B17001B_001", "B17001B_002")
acs_poverty_white_nh <- process_poverty_by_race(b17001h_raw, "White alone, not Hispanic or Latino",
                                                 "B17001H_001", "B17001H_002")

acs_poverty_by_race_territory <- bind_rows(acs_poverty_black, acs_poverty_white_nh) %>%
  mutate(
    acs_year  = acs_year,
    geography = glue("{utility_name} territory")
  ) %>%
  select(geography, acs_year, race_group, total_households,
         below_poverty, pct_below_poverty, moe_below_poverty)

cat("\n--- POVERTY RATE BY RACE IN TERRITORY ---\n")
acs_poverty_by_race_territory %>%
  select(race_group, total_households, pct_below_poverty) %>%
  print()

# ==============================================================================
# INCOME DISTRIBUTION BY RACE — filter to territory, aggregate, compute shares
# ==============================================================================

income_bin_labels <- tibble(
  bin_num        = sprintf("%03d", 2:17),
  income_bracket = c(
    "Less than $10K", "$10K–$14,999",  "$15K–$19,999",  "$20K–$24,999",
    "$25K–$29,999",   "$30K–$34,999",  "$35K–$39,999",  "$40K–$44,999",
    "$45K–$49,999",   "$50K–$59,999",  "$60K–$74,999",  "$75K–$99,999",
    "$100K–$124,999", "$125K–$149,999", "$150K–$199,999", "$200K+"
  ),
  bin_order = 1:16
)

process_income_distribution <- function(raw_df, race_label, total_var) {
  raw_df %>%
    filter(GEOID %in% territory_geoids, variable != total_var) %>%
    group_by(variable) %>%
    summarize(households = sum(estimate, na.rm = TRUE)) %>%
    ungroup() %>%
    mutate(
      race_group = race_label,
      bin_num    = str_extract(variable, "\\d{3}$")
    ) %>%
    left_join(income_bin_labels, by = "bin_num") %>%
    mutate(
      total_hh     = sum(households),
      pct_of_group = 100 * households / total_hh
    ) %>%
    select(race_group, bin_order, income_bracket, households, pct_of_group)
}

income_dist_black    <- process_income_distribution(b19001b_raw, "Black or African American alone",
                                                     "B19001B_001")
income_dist_white_nh <- process_income_distribution(b19001h_raw, "White alone, not Hispanic or Latino",
                                                     "B19001H_001")

acs_income_distribution_by_race <- bind_rows(income_dist_black, income_dist_white_nh) %>%
  arrange(race_group, bin_order) %>%
  mutate(
    acs_year        = acs_year,
    income_bracket  = factor(income_bracket, levels = income_bin_labels$income_bracket)
  )

# ==============================================================================
# PLOT 2: Side-by-side bar — Income distribution by race (ACS)
# ==============================================================================

income_dist_colors <- c(
  "Black or African American alone"       = lopu_red,
  "White alone, not Hispanic or Latino"   = lopu_blue_dk
)

plot_income_dist_by_race <- acs_income_distribution_by_race %>%
  ggplot(aes(x = income_bracket, y = pct_of_group, fill = race_group)) +
  geom_col(position = "dodge") +
  scale_fill_manual(
    values = income_dist_colors,
    labels = c("Black or African American\nalone",
               "White alone, not\nHispanic or Latino")
  ) +
  scale_y_continuous(
    labels = scales::label_percent(scale = 1, accuracy = 0.1),
    expand = c(0, 0)
  ) +
  coord_cartesian(ylim = c(0, NA)) +
  theme_lopu() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 7)) +
  labs(
    title   = glue("Household income distribution by race — {utility_name_short} territory ({acs_year} ACS)"),
    x       = NULL,
    y       = "Share of racial group's households",
    caption = glue("ACS 5-year estimates, {acs_year}. Tables B19001B (Black) and B19001H (White-NH). Territory tracts only.")
  )

ggsave(
  glue("plots/{today_fmt}-acs_income_distribution_by_race.png"),
  plot   = plot_income_dist_by_race,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

ggsave(
  glue("plots/{today_fmt}-acs_income_distribution_by_race.svg"),
  plot   = plot_income_dist_by_race,
  width  = 7.5, height = 5, units = "in"
)

# ==============================================================================
# CONSOLE SUMMARY
# ==============================================================================

cat("\n=== RACIAL DISPARITY ANALYSIS SUMMARY ===\n")
cat("\n[LEAD: Overall burden by racial majority]\n")
for (i in seq_len(nrow(lead_burden_by_race))) {
  row <- lead_burden_by_race[i, ]
  cat(glue(
    "{row$racial_majority}: {round(row$wgt_mean_burden, 1)}% wgt. mean burden; ",
    "{round(row$pct_above_6, 1)}% above 6% threshold ({scales::comma(row$total_units)} units)\n"
  ))
}

cat("\n[HEAG by racial majority]\n")
for (i in seq_len(nrow(lead_heag_by_race))) {
  row <- lead_heag_by_race[i, ]
  cat(glue(
    "{row$racial_majority}: avg gap ${round(row$avg_gap_per_hh_annual, 0)}/yr; ",
    "{scales::comma(row$households_above_6pct)} HH above threshold\n"
  ))
}

cat("\n[ACS: Poverty rate by race in territory]\n")
for (i in seq_len(nrow(acs_poverty_by_race_territory))) {
  row <- acs_poverty_by_race_territory[i, ]
  cat(glue(
    "{row$race_group}: {round(row$pct_below_poverty, 1)}% below poverty ",
    "({scales::comma(row$below_poverty)} of {scales::comma(row$total_households)} HH)\n"
  ))
}

# ==============================================================================
# SAVE OUTPUTS
# ==============================================================================

save_output(lead_burden_by_race,               "lead_burden_by_race")
save_output(lead_burden_by_race_fpl,           "lead_burden_by_race_fpl")
save_output(lead_heag_by_race,                 "lead_heag_by_race")
save_output(lead_tract_racial_classification,  "lead_tract_racial_classification")
save_output(acs_poverty_by_race_territory,     "acs_poverty_by_race_territory")
save_output(
  acs_income_distribution_by_race %>%
    mutate(income_bracket = as.character(income_bracket)),
  "acs_income_distribution_by_race"
)

message(glue("Script 03b complete. ACS year used: {acs_year}."))

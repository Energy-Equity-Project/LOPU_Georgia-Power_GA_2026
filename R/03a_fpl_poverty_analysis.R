# ==============================================================================
# 03a_fpl_poverty_analysis.R
# Lights Out, Profits Up — Georgia Power Report
#
# PURPOSE: Quantify households below 100% of the Federal Poverty Level (FPL),
# both statewide and within Georgia Power's service territory.
#
# ACS TABLE:
#   B17017 — Poverty Status in the Past 12 Months by Household Type
#   - B17017_001: Total households (poverty status determined)
#   - B17017_002: Households with income below poverty level
#
# OUTPUTS:
#   - outputs/[date]-fpl-poverty-households.csv
# ==============================================================================

source("R/01_setup_and_data_prep.R")
source("R/00_visual_styling.R")
source("../../../Internal/data-pipelines/eep-pipeline-core/collectors/acs_collector.R")

acs_base_path <- "../../../Data/us_census/acs"
b17017_vars   <- c("B17017_001", "B17017_002")

# ==============================================================================
# COLLECT B17017 DATA
# Try 2024 (5-year ACS, 2020–2024); fall back to 2023 if unavailable.
# The collector caches files and skips re-download if already in registry.
# ==============================================================================

acs_year <- tryCatch({
  acs_collect(
    variables = b17017_vars,
    geography = "state",
    year      = 2024,
    state     = state_abbrev,
    base_path = acs_base_path
  )
  2024
}, error = function(e) {
  message("2024 ACS not available — falling back to 2023.\n", e$message)
  2023
})

# State-level pull (full state total; collector reuses cache if already present)
paths_state <- acs_collect(
  variables = b17017_vars,
  geography = "state",
  year      = acs_year,
  state     = state_abbrev,
  base_path = acs_base_path
)

# Tract-level pull (needed for territory crosswalk)
paths_tract <- acs_collect(
  variables = b17017_vars,
  geography = "tract",
  year      = acs_year,
  state     = state_abbrev,
  base_path = acs_base_path
)

# ==============================================================================
# READ COLLECTED CSVs
# ==============================================================================

b17017_state <- read.csv(
  paths_state$file_path[paths_state$table_code == "B17017"],
  stringsAsFactors = FALSE
)

b17017_tract <- read.csv(
  paths_tract$file_path[paths_tract$table_code == "B17017"],
  stringsAsFactors = FALSE
)

# Derive state name from ACS data (e.g., "Georgia") — not defined in script 01
state_name <- unique(b17017_state$NAME)

# ==============================================================================
# Q1: STATE-LEVEL POVERTY HOUSEHOLDS
# Pull directly from state-level ACS pull.
# ==============================================================================

state_poverty <- b17017_state %>%
  pivot_wider(
    id_cols     = c(GEOID, NAME),
    names_from  = variable,
    values_from = c(estimate, moe)
  ) %>%
  transmute(
    geography        = state_name,
    total_households = estimate_B17017_001,
    below_100pct_fpl = estimate_B17017_002,
    pct_below_fpl    = 100 * below_100pct_fpl / total_households,
    moe_below_fpl    = moe_B17017_002
  )

cat("\n--- STATE-LEVEL: Households below 100% FPL ---\n")
cat(glue("Geography: {state_poverty$geography}\n"))
cat(glue("Total households: {scales::comma(state_poverty$total_households)}\n"))
cat(glue("Below 100% FPL: {scales::comma(state_poverty$below_100pct_fpl)} ({round(state_poverty$pct_below_fpl, 1)}%)\n"))
cat(glue("MOE: \u00b1{scales::comma(state_poverty$moe_below_fpl)}\n"))

# ==============================================================================
# Q2: GEORGIA POWER SERVICE TERRITORY
# Filter tract-level B17017 to territory_geoids, then aggregate.
# MOE propagation: moe_sum = sqrt(sum(moe^2)), per Census guidelines.
# ==============================================================================

tract_matched <- b17017_tract %>%
  filter(GEOID %in% territory_geoids)

n_matched  <- n_distinct(tract_matched$GEOID)
n_expected <- length(territory_geoids)

if (n_matched < n_expected) {
  message(glue(
    "Note: {n_matched} of {n_expected} territory GEOIDs matched in B17017 tract data. ",
    "Missing tracts may lack poverty status data (group quarters, etc.)."
  ))
}

territory_poverty <- tract_matched %>%
  pivot_wider(
    id_cols     = c(GEOID, NAME),
    names_from  = variable,
    values_from = c(estimate, moe)
  ) %>%
  summarize(
    total_households = sum(estimate_B17017_001, na.rm = TRUE),
    below_100pct_fpl = sum(estimate_B17017_002, na.rm = TRUE),
    # MOE propagation: sqrt of sum of squared MOEs (Census standard method)
    moe_below_fpl    = sqrt(sum(moe_B17017_002^2, na.rm = TRUE))
  ) %>%
  mutate(
    geography     = glue("{utility_name} territory"),
    pct_below_fpl = 100 * below_100pct_fpl / total_households
  ) %>%
  select(geography, total_households, below_100pct_fpl, pct_below_fpl, moe_below_fpl)

cat("\n--- TERRITORY-LEVEL: Households below 100% FPL ---\n")
cat(glue("Geography: {territory_poverty$geography}\n"))
cat(glue("Total households: {scales::comma(territory_poverty$total_households)}\n"))
cat(glue("Below 100% FPL: {scales::comma(territory_poverty$below_100pct_fpl)} ({round(territory_poverty$pct_below_fpl, 1)}%)\n"))
cat(glue("MOE: \u00b1{scales::comma(round(territory_poverty$moe_below_fpl))}\n"))
cat(glue("Tracts matched: {n_matched} of {n_expected} territory GEOIDs\n"))

# ==============================================================================
# COMBINED SUMMARY TABLE
# ==============================================================================

fpl_poverty_summary <- bind_rows(state_poverty, territory_poverty) %>%
  mutate(acs_year = acs_year) %>%
  select(geography, acs_year, total_households, below_100pct_fpl, pct_below_fpl, moe_below_fpl)

# ==============================================================================
# SAVE OUTPUT
# ==============================================================================

save_output(fpl_poverty_summary, "fpl-poverty-households")

message(glue("Script 03a complete. ACS year used: {acs_year}."))

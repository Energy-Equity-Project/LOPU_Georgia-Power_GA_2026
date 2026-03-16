# ==============================================================================
# 01_setup_and_data_prep.R
# Lights Out, Profits Up — Georgia Power Report
#
# PURPOSE: Single customization point for the entire report. Sets all report
# parameters, loads shared data via relative paths, and filters to the target
# utility/state. Every other script begins with source("R/01_setup_and_data_prep.R").
#
# PATH DEPTH NOTE: Report repos live 3 levels deep in the workspace:
#   External/lights_out_profits_up/[repo]/
# All shared data references use ../../../  (3 levels up to workspace root).
#
# DATA NOTE: This report reads from Cleaned_Data/ for EIA 861, DOE LEAD, and
# Household Pulse Survey — not raw files. The template default reads raw data;
# this repo diverges intentionally to use the cleaned pipelines.
# ==============================================================================

library(tidyverse)
library(readxl)
library(janitor)
library(lubridate)
library(sf)
library(glue)

# ==============================================================================
# CUSTOMIZE
# ==============================================================================

utility_name       <- "Georgia Power"
utility_name_short <- "GA Power"
parent_company     <- "Southern Company"
eia_utility_id     <- 7140L
ticker             <- "SO"
cik                <- "0000092122"
state_abbrev       <- "GA"
state_fips         <- 13L
report_year_range  <- 2020:2024
base_year          <- 2020
use_territory_filter <- TRUE   # Georgia has many co-ops/municipals; always TRUE for GA Power
run_racial_disparity <- TRUE   # requires CENSUS_API_KEY in .Renviron

# ==============================================================================
# SHARED DATA PATHS (relative to repo root — do not change)
# ==============================================================================

# Cleaned data paths (EIA, DOE LEAD, Pulse already processed by eep-pipeline-core)
path_eia_861_cleaned  <- "../../../Cleaned_Data/eia/861/"
path_lead_cleaned     <- "../../../Cleaned_Data/doe/lead/"
path_pulse_cleaned    <- "../../../Cleaned_Data/us_census/household_pulse_survey/"

# Raw data paths (no cleaned versions for these sources)
path_gis_territory <- "../../../Data/gis/hflid_ornl/electric-retail-service-territories/electric-retail-service-territories-shapefile/"
path_sec_edgar     <- glue("../../../Data/sec/edgar/{cik}/")
path_iou_stock     <- glue("../../../Data/financial_markets/iou_stock/{ticker}/")
path_iou_stock_cleaned <- "../../../Cleaned_Data/financial_markets/iou_stock/"
path_ejl_disconn         <- "../../../Data/ejl_disconnection_dashboard/"
path_ejl_disconn_cleaned <- "../../../Cleaned_Data/ejl_disconnection_dashboard/"

# ==============================================================================
# LOAD EIA FORM 861 — SALES & RATES DATA (from Cleaned_Data)
# Cleaned file: [date]-eia-861-sales.csv
# Columns: year, utility_number, utility_name, state, ownership,
#          residential_revenue_usd, residential_kwh, residential_customers,
#          residential_rate_cents_per_kwh (plus commercial/industrial/transportation)
# ==============================================================================

eia_sales_file <- list.files(path_eia_861_cleaned,
                              pattern = "eia-861-sales\\.csv$",
                              full.names = TRUE)

if (length(eia_sales_file) == 0) {
  stop("EIA 861 cleaned file not found at ", path_eia_861_cleaned,
       "\nRun eia-861-sales_processor.R in eep-pipeline-core first.")
}

eia_sales <- read_csv(eia_sales_file[[1]], show_col_types = FALSE) %>%
  filter(year %in% report_year_range)

# Filter to target utility and state
target_eia_sales <- eia_sales %>%
  filter(utility_number == eia_utility_id, state == state_abbrev)

# State-level sales for context (all utilities in GA)
state_eia_sales <- eia_sales %>%
  filter(state == state_abbrev)

# ==============================================================================
# LOAD HOUSEHOLD PULSE SURVEY (from Cleaned_Data)
# Cleaned file: [date]-pulse-energy-puf-harmonized.csv
# Columns: survey_wave, survey_year, state_fips, state, person_weight,
#          energy, hse_temp, enrgy_bill, race, tenure, num_kids, income, etc.
# Values are labeled strings (e.g., "almost_every_month", "never") not numeric codes.
# ==============================================================================

pulse_file <- list.files(path_pulse_cleaned,
                          pattern = "pulse-energy-puf-harmonized\\.csv$",
                          full.names = TRUE)

if (length(pulse_file) == 0) {
  stop("Pulse Survey harmonized file not found at ", path_pulse_cleaned,
       "\nRun pulse_processor.R in eep-pipeline-core first.")
}

pulse <- read_csv(pulse_file[[1]], show_col_types = FALSE) %>%
  filter(state == state_abbrev)

# ==============================================================================
# LOAD DOE LEAD DATA (from Cleaned_Data)
# Cleaned file: ga-census_tract-lead-2022.csv
# Columns: fip, fpl150, ten (tenure), units, avg_income,
#          avg_electricity_cost, avg_gas_cost, avg_other_fuel_cost
# Costs are monthly averages per housing unit.
# ==============================================================================

lead_file <- file.path(path_lead_cleaned,
                        glue("{tolower(state_abbrev)}-census_tract-lead-2022.csv"))

if (!file.exists(lead_file)) {
  stop("DOE LEAD cleaned file not found: ", lead_file,
       "\nRun doe-lead_processor.R in eep-pipeline-core first.")
}

lead <- read_csv(lead_file, show_col_types = FALSE)

# ==============================================================================
# SPATIAL CROSSWALK — filter to GA Power service territory
# Georgia has many co-ops and municipals; this crosswalk filters LEAD data
# to census tracts within GA Power's IOU service territory.
# ==============================================================================

if (use_territory_filter) {
  territory_sf <- read_sf(path_gis_territory) %>%
    rename(COMPANY_NAME = NAME) %>%
    # filter(ID == eia_utility_id | NAME == utility_name) %>%
    st_make_valid()

  tracts_sf <- tigris::tracts(state = state_fips, year = 2020, cb = TRUE) %>%
    st_transform(st_crs(territory_sf)) %>%
    st_make_valid()

  # Compute actual intersection polygons and assign each tract to the utility
  # covering the largest share of its area — eliminates over-inclusion of
  # border tracts primarily served by co-ops or municipal utilities.
  # Note: st_intersection() is slower than st_filter but methodologically sound.
  tract_intersections <- tracts_sf %>%
    st_intersection(territory_sf) %>%
    mutate(intersection_area = as.numeric(st_area(geometry)))

  territory_geoids <- tract_intersections %>%
    st_drop_geometry() %>%
    group_by(GEOID) %>%
    slice_max(intersection_area, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    filter(COMPANY_NAME == utility_name | ID == eia_utility_id) %>%
    pull(GEOID)

  # Apply to LEAD data (join on fip = GEOID)
  lead_territory <- lead %>%
    filter(fip %in% territory_geoids)
} else {
  lead_territory <- lead
}

# ==============================================================================
# ACS INCOME GROWTH FACTORS (for burden projection to 2024)
# Loads tract-level median household income (B19013) for 2022 and 2024.
# Computes per-tract income_growth_factor = income_2024 / income_2022.
# Tracts with missing or non-positive ACS values default to growth_factor = 1.
# ==============================================================================

path_acs <- "../../../Data/us_census/acs/"

acs_2022_file <- file.path(path_acs, "2022/tract", glue("B19013_{tolower(state_abbrev)}.csv"))
acs_2024_file <- file.path(path_acs, "2024/tract", glue("B19013_{tolower(state_abbrev)}.csv"))

if (file.exists(acs_2022_file) && file.exists(acs_2024_file)) {
  acs_2022 <- read_csv(acs_2022_file, show_col_types = FALSE) %>%
    filter(variable == "B19013_001") %>%
    select(GEOID, income_2022 = estimate)

  acs_2024 <- read_csv(acs_2024_file, show_col_types = FALSE) %>%
    filter(variable == "B19013_001") %>%
    select(GEOID, income_2024 = estimate)

  acs_income_growth <- acs_2022 %>%
    left_join(acs_2024, by = "GEOID") %>%
    mutate(
      income_growth_factor = case_when(
        is.na(income_2022) | is.na(income_2024) ~ 1,
        income_2022 <= 0                         ~ 1,
        TRUE                                     ~ income_2024 / income_2022
      )
    )
} else {
  message("ACS income files not found — income_growth_factor = 1 for all tracts (no projection).")
  acs_income_growth <- tibble(GEOID = character(), income_2022 = double(),
                               income_2024 = double(), income_growth_factor = double())
}

# Electricity rate multiplier: ratio of 2024 to 2022 residential rate (EIA 861)
rate_2022 <- target_eia_sales %>%
  filter(year == 2022) %>%
  summarize(rate = weighted.mean(residential_rate_cents_per_kwh, residential_customers)) %>%
  pull(rate)

rate_2024 <- target_eia_sales %>%
  filter(year == 2024) %>%
  summarize(rate = weighted.mean(residential_rate_cents_per_kwh, residential_customers)) %>%
  pull(rate)

elec_rate_multiplier <- rate_2024 / rate_2022

# ==============================================================================
# LOAD REPORT-SPECIFIC DATA (from data/)
# ==============================================================================

# Financials from SEC EDGAR (manually extracted — see data/README.md)
financials_10k_file <- list.files("data", pattern = "^10k_", full.names = TRUE)
if (length(financials_10k_file) > 0) {
  financials_10k <- read_csv(financials_10k_file[[1]], show_col_types = FALSE) %>%
    clean_names()
} else {
  message("No 10-K financial data found in data/. Run script 06 after collecting SEC data.")
  financials_10k <- NULL
}

# Executive compensation from DEF 14A (manually extracted)
financials_def14a_file <- list.files("data", pattern = "^def14a_", full.names = TRUE)
if (length(financials_def14a_file) > 0) {
  financials_def14a <- read_csv(financials_def14a_file[[1]], show_col_types = FALSE) %>%
    clean_names()
} else {
  financials_def14a <- NULL
}

# Disconnection data — load from cleaned EJL dashboard; fall back to local data/
ejl_disconn_file <- list.files(path_ejl_disconn_cleaned,
                                pattern = "ejl-disconnection-dashboard\\.csv$",
                                full.names = TRUE)

if (length(ejl_disconn_file) > 0) {
  disconnections <- read.csv(ejl_disconn_file[[1]]) %>%
    filter(utility_name == "Georgia Power", service_type == "Electric") %>%
    rename(
      data_year                = year,
      residential_disconnections = total_disconnections,
      residential_reconnections  = total_reconnections
    ) %>%
    mutate(
      data_quality = case_when(
        is.na(residential_disconnections)      ~ "moratorium_na",
        data_year == 2024 & residential_disconnections < 200 ~ "incomplete_reporting",
        TRUE                                   ~ "valid"
      )
    )
  message(glue("EJL disconnections loaded: {nrow(disconnections)} rows for Georgia Power."))
} else {
  # Fallback: local data/ file (for template compatibility)
  disconn_file <- list.files("data", pattern = "^disconnections_", full.names = TRUE)
  if (length(disconn_file) > 0) {
    disconnections <- read.csv(disconn_file[[1]]) %>%
      clean_names() %>%
      filter(data_year %in% report_year_range)
    message("EJL cleaned data not found — loaded disconnections from local data/ folder.")
  } else {
    message("No disconnection data found. Script 05 will not run completely.")
    disconnections <- NULL
  }
}

# Affordability program enrollment (from GA PSC or utility)
enrollment_file <- list.files("data", pattern = "^program_enrollment_", full.names = TRUE)
if (length(enrollment_file) > 0) {
  program_enrollment <- read_csv(enrollment_file[[1]], show_col_types = FALSE) %>%
    clean_names()
} else {
  program_enrollment <- NULL
}

# ==============================================================================
# OUTPUT HELPERS
# ==============================================================================

today_fmt <- format(Sys.Date(), "%d-%m-%Y")

save_output <- function(df, name) {
  write_csv(df, glue("outputs/{today_fmt}-{name}.csv"))
}

message(glue(
  "Setup complete: {utility_name} ({state_abbrev}), years {min(report_year_range)}-{max(report_year_range)}"
))

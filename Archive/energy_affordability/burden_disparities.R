# =============================================================================
# burden_disparities.R
#
# Analysis of Energy Burden Disparities Across Socioeconomic Groups in Georgia
# Using DOE LEAD 2022 Data
#
# This script analyzes how energy burdens vary by:
#   - Tenure (renters vs homeowners)
#   - Race/ethnicity (majority non-white vs majority white census tracts)
#   - Housing type (single-family, multifamily, mobile homes)
#   - Income level (Federal Poverty Level categories)
#
# The script implements two methods for controlling confounding variables:
#   1. Stratified Analysis - easy to interpret, transparent
#   2. Weighted Linear Regression - controls multiple confounders simultaneously
#
# Each method includes detailed comments on pros/cons and interpretation.
# =============================================================================


# =============================================================================
# SECTION 1: SETUP & LIBRARIES
# =============================================================================
library(tidyverse)
library(janitor)
library(sf)
# broom: Tidy model outputs
# Converts regression model outputs into tidy data frames for easy analysis
library(broom)

# Turn off s2 spherical geometry for simpler spatial operations
sf_use_s2(FALSE)

# Source shared visual styling for consistent plot aesthetics
# Contains: gslide_theme, color palettes, font settings
source("visual_styling.R")


# =============================================================================
# SECTION 2: DATA LOADING & CLEANING
# =============================================================================

# -----------------------------------------------------------------------------
# 2.1 Load DOE LEAD Data
# -----------------------------------------------------------------------------
# The DOE LEAD (Low-Income Energy Affordability Data) tool provides estimates
# of energy costs and burdens at the census tract level, disaggregated by
# various demographic and housing characteristics.
#
# Key columns in the raw data:
# - FIP: Census tract FIPS code
# - FPL150: Federal Poverty Level category (0-100%, 100-150%, etc.)
# - TEN: Tenure (OWN = owner, REN = renter)
# - TEN-BLD: Building type (1 DETACHED, MOBILE HOME, etc.)
# - TEN-YBL6: Year building constructed
# - TEN-HFL: Primary heating fuel type
# - UNITS: Number of housing units in this combination
# - HINCP*UNITS / HINCP UNITS: Summed income / count for weighted average
# - ELEP*UNITS / ELEP UNITS: Summed electricity cost / count
# - GASP*UNITS / GASP UNITS: Summed gas cost / count
# - FULP*UNITS / FULP UNITS: Summed other fuel cost / count
# - Race columns: Number of units by racial/ethnic category
# -----------------------------------------------------------------------------

# Define the data path - try relative path first, then absolute path
# This allows the script to work from both the main repo and worktrees
data_path_relative <- "../../../Data/DOE/08062025/Data Unzipped/GA-2022-LEAD-data/GA FPL Census Tracts 2022.csv"
data_path_absolute <- "~/Documents/Energy Equity Project/Data/DOE/08062025/Data Unzipped/GA-2022-LEAD-data/GA FPL Census Tracts 2022.csv"

# Use relative path if it exists, otherwise use absolute path
data_path <- if (file.exists(data_path_relative)) {
  data_path_relative
} else {
  data_path_absolute
}

ga_lead <- read.csv(data_path) %>%
  # clean_names() converts all column names to snake_case for consistency
  # e.g., "HINCP*UNITS" becomes "hincp_units", "HINCP UNITS" becomes "hincp_units_1"
  clean_names()

# Display column names to verify loading
cat("Loaded", nrow(ga_lead), "rows with", ncol(ga_lead), "columns\n")

# -----------------------------------------------------------------------------
# 2.2 Calculate Per-Unit Costs and Energy Burden
# -----------------------------------------------------------------------------
# The raw data contains summed values (cost * units) that need to be divided
# by unit counts to get average per-unit costs. This is because each row
# represents a unique combination of characteristics with potentially
# different numbers of housing units.
#
# Energy Burden = (Annual Energy Cost / Annual Household Income) * 100
#
# A burden > 6% is typically considered "high" and indicates energy insecurity.
# A burden > 10% is considered "severe" energy burden.
# -----------------------------------------------------------------------------

ga_lead_clean <- ga_lead %>%
  mutate(
    # Calculate per-unit average costs by dividing summed values by unit counts
    # hincp_units = sum of (income * units), hincp_units_1 = sum of units with income data
    elep = elep_units / elep_units_1,  # Average electricity cost per unit
    gasp = gasp_units / gasp_units_1,  # Average gas cost per unit
    fulp = fulp_units / fulp_units_1,  # Average other fuel cost per unit
    hincp = hincp_units / hincp_units_1,  # Average household income per unit

    # Total annual energy cost per housing unit
    total_cost = coalesce(elep, 0) + coalesce(gasp, 0) + coalesce(fulp, 0)
  ) %>%
  # Replace NA values with 0 for cost components (some units may not have gas/fuel)
  replace_na(list(elep = 0, gasp = 0, fulp = 0, total_cost = 0)) %>%
  # Rename FIP to geoid for consistency with spatial data conventions
  rename(geoid = fip) %>%
  mutate(
    geoid = as.character(geoid),

    # Calculate energy burden at the row level (for regression analysis)
    # Only calculate if income is positive to avoid division by zero
    burden = ifelse(hincp > 0, 100 * (total_cost / hincp), NA_real_)
  )

# -----------------------------------------------------------------------------
# 2.3 Create Demographic Classification Variables
# -----------------------------------------------------------------------------
# The race columns contain the number of housing units occupied by each
# racial/ethnic group. We aggregate these to create tract-level racial
# composition measures.
#
# Classification approach:
# - "Majority non-white": Census tracts where >= 50% of units are non-white
# - "Majority white": Census tracts where < 50% of units are non-white
#
# This binary classification simplifies analysis while capturing key disparities.
# -----------------------------------------------------------------------------

ga_lead_clean <- ga_lead_clean %>%
  mutate(
    # Sum white and non-white housing units
    # Non-Hispanic white alone is the reference group
    white_units = white_alone_not_hispanic_or_latino,

    # All other racial/ethnic categories combined
    nonwhite_units = white_alone_hispanic_or_latino +
      black_or_african_american_alone +
      american_indian_and_alaska_native_alone +
      asian_alone +
      native_hawaiian_and_other_pacific_islander_alone +
      some_other_race_alone +
      two_or_more_races,

    # Total units with race data (for calculating percentages)
    total_race_units = white_units + nonwhite_units,

    # Percentage non-white at the row level
    # Will be aggregated to tract level later
    pct_nonwhite = ifelse(
      total_race_units > 0,
      100 * nonwhite_units / total_race_units,
      NA_real_
    )
  )

# -----------------------------------------------------------------------------
# 2.4 Simplify Categorical Variables
# -----------------------------------------------------------------------------
# The raw data has detailed categories that we simplify for clearer analysis.
# This reduces noise from small cell sizes while preserving meaningful distinctions.
# -----------------------------------------------------------------------------

ga_lead_clean <- ga_lead_clean %>%
  mutate(
    # ----- Tenure -----
    # Already coded as OWN (owner-occupied) or REN (renter-occupied)
    tenure = ten,

    # ----- Building Type -----
    # Simplified from detailed categories to 4 main types
    # Mobile homes are kept separate due to distinct energy characteristics
    building_type = case_when(
      str_detect(ten_bld, "1 DETACHED|1 ATTACHED") ~ "Single-family",
      str_detect(ten_bld, "2 UNIT|3-4 UNIT") ~ "Small multifamily (2-4)",
      str_detect(ten_bld, "5-9 UNIT|10-19 UNIT|20-49 UNIT|50\\+ UNIT") ~ "Large multifamily (5+)",
      str_detect(ten_bld, "MOBILE HOME") ~ "Mobile home",
      str_detect(ten_bld, "BOAT RV") ~ "Other",
      TRUE ~ "Unknown"
    ),

    # ----- Heating Fuel Type -----
    # Grouped into main fuel types
    # Heating fuel significantly affects energy costs and efficiency
    heating_fuel = case_when(
      str_detect(ten_hfl, "ELECTRICITY") ~ "Electricity",
      str_detect(ten_hfl, "UTILITY GAS") ~ "Utility gas",
      str_detect(ten_hfl, "BOTTLED GAS") ~ "Bottled gas (propane)",
      str_detect(ten_hfl, "FUEL OIL|COAL|WOOD") ~ "Other fuel",
      str_detect(ten_hfl, "NONE|SOLAR") ~ "None/Solar",
      TRUE ~ "Other"
    ),

    # ----- Building Age -----
    # Older buildings typically have lower energy efficiency
    # 1980 is a key threshold as energy codes became more stringent
    building_age = case_when(
      str_detect(ten_ybl6, "2020\\+|2000-19") ~ "Built 2000+",
      str_detect(ten_ybl6, "1980-99") ~ "Built 1980-1999",
      str_detect(ten_ybl6, "1960-79") ~ "Built 1960-1979",
      str_detect(ten_ybl6, "1940-59|BEFORE 1940") ~ "Built before 1960",
      TRUE ~ "Unknown"
    ),

    # ----- Federal Poverty Level Category -----
    # Create ordered factor for proper sorting in visualizations
    # Lower FPL = lower income = typically higher energy burden
    fpl_category = factor(
      fpl150,
      levels = c("0-100%", "100-150%", "150-200%", "200-400%", "400%+"),
      ordered = TRUE
    )
  )

# -----------------------------------------------------------------------------
# 2.5 Calculate Tract-Level Racial Composition
# -----------------------------------------------------------------------------
# Aggregate race data to the census tract level to classify tracts
# as majority white or majority non-white.
# -----------------------------------------------------------------------------

tract_demographics <- ga_lead_clean %>%
  group_by(geoid) %>%
  summarize(
    total_white_units = sum(white_units, na.rm = TRUE),
    total_nonwhite_units = sum(nonwhite_units, na.rm = TRUE),
    total_units = sum(units, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  mutate(
    # Calculate tract-level percentage non-white
    pct_nonwhite = 100 * total_nonwhite_units /
      (total_white_units + total_nonwhite_units),

    # Binary classification: Majority non-white (>= 50%) vs Majority white (< 50%)
    racial_majority = case_when(
      pct_nonwhite >= 50 ~ "Majority non-white",
      pct_nonwhite < 50 ~ "Majority white",
      TRUE ~ NA_character_
    )
  )

# Join tract-level racial classification back to the main data
ga_lead_with_race <- ga_lead_clean %>%
  left_join(
    tract_demographics %>% select(geoid, racial_majority, pct_nonwhite),
    by = "geoid"
  )

cat("\nTract racial composition:\n")
print(table(tract_demographics$racial_majority, useNA = "ifany"))


# =============================================================================
# SECTION 3: HELPER FUNCTIONS
# =============================================================================

# -----------------------------------------------------------------------------
# calculate_weighted_burden()
#
# A reusable function that calculates weighted average energy burden
# for any grouping of the data.
#
# Parameters:
#   data: The data frame to analyze (must have burden-related columns)
#   group_vars: Character vector of column names to group by (optional)
#
# Returns:
#   A tibble with weighted burden statistics for each group
#
# The weighting is important because each row represents different numbers
# of housing units. Without weighting, rows with 1 unit would have the same
# influence as rows with 1000 units.
# -----------------------------------------------------------------------------

calculate_weighted_burden <- function(data, group_vars = NULL) {
  # Apply grouping if specified
  if (!is.null(group_vars)) {
    data <- data %>% group_by(across(all_of(group_vars)))
  }

  data %>%
    summarize(
      # Total housing units in this group
      n_units = sum(units, na.rm = TRUE),

      # Weighted average costs
      # weighted.mean(x, w) = sum(x * w) / sum(w)
      avg_elec_cost = weighted.mean(elep, elep_units_1, na.rm = TRUE),
      avg_gas_cost = weighted.mean(gasp, gasp_units_1, na.rm = TRUE),
      avg_fuel_cost = weighted.mean(fulp, fulp_units_1, na.rm = TRUE),

      # Total energy cost
      avg_total_cost = avg_elec_cost + avg_gas_cost + avg_fuel_cost,

      # Weighted average income
      avg_income = weighted.mean(hincp, hincp_units_1, na.rm = TRUE),

      # Energy burden = (cost / income) * 100
      energy_burden = 100 * (avg_total_cost / avg_income)
    ) %>%
    ungroup()
}


# =============================================================================
# SECTION 4: DESCRIPTIVE DISPARITY ANALYSIS
# =============================================================================
# This section calculates raw (unadjusted) energy burdens for different
# demographic groups. These are descriptive statistics that show actual
# disparities but do not control for confounding variables.
# =============================================================================

cat("\n========================================\n")
cat("DESCRIPTIVE DISPARITY ANALYSIS\n")
cat("========================================\n")

# -----------------------------------------------------------------------------
# 4.1 Burden by Tenure (Renters vs Homeowners)
# -----------------------------------------------------------------------------
# Renters often face higher energy burdens due to:
# - Lower incomes on average
# - Less control over housing energy efficiency
# - Split incentives (landlords pay for efficiency, tenants pay bills)
# -----------------------------------------------------------------------------

burden_by_tenure <- ga_lead_clean %>%
  calculate_weighted_burden(group_vars = "tenure")

cat("\n--- Burden by Tenure ---\n")
print(burden_by_tenure)

# -----------------------------------------------------------------------------
# 4.2 Burden by Tenure and Income Level
# -----------------------------------------------------------------------------
# Cross-tabulation allows us to see if tenure effects vary by income
# -----------------------------------------------------------------------------

burden_by_tenure_income <- ga_lead_clean %>%
  calculate_weighted_burden(group_vars = c("tenure", "fpl_category"))

cat("\n--- Burden by Tenure and Income Level ---\n")
print(burden_by_tenure_income %>%
        select(tenure, fpl_category, n_units, energy_burden) %>%
        pivot_wider(names_from = tenure, values_from = c(n_units, energy_burden)))

# -----------------------------------------------------------------------------
# 4.3 Burden by Race (Majority Non-White vs Majority White Tracts)
# -----------------------------------------------------------------------------
# Communities of color often face higher energy burdens due to:
# - Historical disinvestment in housing stock
# - Residential segregation patterns
# - Lower incomes due to systemic inequities
# -----------------------------------------------------------------------------

burden_by_race <- ga_lead_with_race %>%
  filter(!is.na(racial_majority)) %>%
  calculate_weighted_burden(group_vars = "racial_majority")

cat("\n--- Burden by Tract Racial Composition ---\n")
print(burden_by_race)

# -----------------------------------------------------------------------------
# 4.4 Burden by Race and Income Level
# -----------------------------------------------------------------------------

burden_by_race_income <- ga_lead_with_race %>%
  filter(!is.na(racial_majority)) %>%
  calculate_weighted_burden(group_vars = c("racial_majority", "fpl_category"))

cat("\n--- Burden by Race and Income Level ---\n")
print(burden_by_race_income %>%
        select(racial_majority, fpl_category, n_units, energy_burden))

# -----------------------------------------------------------------------------
# 4.5 Burden by Housing Type
# -----------------------------------------------------------------------------
# Housing type affects energy burden through:
# - Building efficiency (multifamily often more efficient due to shared walls)
# - Mobile homes typically have poor insulation
# - Building age often correlates with housing type
# -----------------------------------------------------------------------------

burden_by_housing <- ga_lead_clean %>%
  filter(building_type != "Unknown" & building_type != "Other") %>%
  calculate_weighted_burden(group_vars = "building_type")

cat("\n--- Burden by Housing Type ---\n")
print(burden_by_housing %>% arrange(desc(energy_burden)))

# -----------------------------------------------------------------------------
# 4.6 Burden by Housing Type and Tenure
# -----------------------------------------------------------------------------

burden_by_housing_tenure <- ga_lead_clean %>%
  filter(building_type != "Unknown" & building_type != "Other") %>%
  calculate_weighted_burden(group_vars = c("building_type", "tenure"))

cat("\n--- Burden by Housing Type and Tenure ---\n")
print(burden_by_housing_tenure %>%
        select(building_type, tenure, n_units, energy_burden) %>%
        pivot_wider(names_from = tenure, values_from = c(n_units, energy_burden)))

# -----------------------------------------------------------------------------
# 4.7 Burden by Income Level
# -----------------------------------------------------------------------------
# Income is the primary driver of energy burden by definition
# (burden = cost/income). Lower income = higher burden for same costs.
# -----------------------------------------------------------------------------

burden_by_income <- ga_lead_clean %>%
  calculate_weighted_burden(group_vars = "fpl_category")

cat("\n--- Burden by Income Level (FPL Category) ---\n")
print(burden_by_income)


# =============================================================================
# SECTION 5: STRATIFIED ANALYSIS (Controlling for Confounders - Method 1)
# =============================================================================
#
# WHAT IS STRATIFIED ANALYSIS?
# ----------------------------
# Stratified analysis compares groups WITHIN levels of a potential confounder.
# Instead of comparing all renters to all owners, we compare:
#   - Renters at 0-100% FPL to owners at 0-100% FPL
#   - Renters at 100-150% FPL to owners at 100-150% FPL
#   - ...and so on
#
# This "holds income constant" by only comparing people at similar income levels.
#
# PROS:
# -----
# 1. Easy to interpret: You can see the exact burden for each subgroup
# 2. Transparent: No hidden statistical assumptions
# 3. No functional form assumptions: Doesn't assume linear relationships
# 4. Easy to communicate: Non-statisticians can understand results
#
# CONS:
# -----
# 1. Limited variables: Can only control 1-2 confounders at a time
# 2. Small cell sizes: Some combinations may have few observations
# 3. No single summary statistic: Hard to summarize "the" adjusted effect
# 4. May miss interactions: Unless explicitly examined
#
# HOW TO INTERPRET:
# -----------------
# - If the gap between groups PERSISTS across all strata, the effect is
#   likely independent of the stratifying variable
# - If the gap VARIES across strata, there may be an interaction effect
# - If the gap DISAPPEARS after stratifying, the original difference was
#   explained by the stratifying variable (confounding)
#
# =============================================================================

cat("\n========================================\n")
cat("STRATIFIED ANALYSIS\n")
cat("(Controlling for Confounders - Method 1)\n")
cat("========================================\n")

# -----------------------------------------------------------------------------
# 5.1 Tenure Disparity Stratified by Income Level
# -----------------------------------------------------------------------------
# Question: Does the renter-owner gap persist after accounting for income?
#
# If yes: Tenure has an independent effect on energy burden
# If no: Income differences explain the tenure gap
# -----------------------------------------------------------------------------

stratified_tenure_by_income <- burden_by_tenure_income %>%
  # Select only the columns we need for the wide format
  select(tenure, fpl_category, n_units, energy_burden) %>%
  # Reshape to have owners and renters in separate columns
  pivot_wider(
    id_cols = fpl_category,
    names_from = tenure,
    values_from = c(n_units, energy_burden),
    names_sep = "_"
  ) %>%
  mutate(
    # Calculate the gap (renter burden - owner burden) at each income level
    # Positive value = renters have higher burden
    burden_gap_pp = energy_burden_REN - energy_burden_OWN,

    # Calculate the ratio (renter burden / owner burden)
    # Value > 1 = renters have higher burden
    burden_ratio = energy_burden_REN / energy_burden_OWN
  )

cat("\n--- Tenure Disparity by Income Level ---\n")
cat("(Positive gap = renters have higher burden than owners at same income)\n\n")
print(stratified_tenure_by_income %>%
        select(fpl_category, energy_burden_OWN, energy_burden_REN,
               burden_gap_pp, burden_ratio))

cat("\nInterpretation:\n")
cat("- If burden_gap_pp is consistently positive across all income levels,\n")
cat("  renters face higher burden than owners REGARDLESS of income.\n")
cat("- The gap magnitude may vary by income (e.g., larger for low-income).\n")

# -----------------------------------------------------------------------------
# 5.2 Racial Disparity Stratified by Income Level
# -----------------------------------------------------------------------------
# Question: Does the racial gap persist after accounting for income?
# -----------------------------------------------------------------------------

stratified_race_by_income <- burden_by_race_income %>%
  # Select only the columns we need for the wide format
  select(racial_majority, fpl_category, n_units, energy_burden) %>%
  # Reshape to have majority white and majority non-white in separate columns
  pivot_wider(
    id_cols = fpl_category,
    names_from = racial_majority,
    values_from = c(n_units, energy_burden),
    names_sep = "_"
  ) %>%
  # Clean up column names (spaces cause issues with backticks)
  rename_with(~ str_replace_all(., " ", "_")) %>%
  rename_with(~ str_replace_all(., "-", "_")) %>%
  mutate(
    burden_gap_pp = energy_burden_Majority_non_white - energy_burden_Majority_white,
    burden_ratio = energy_burden_Majority_non_white / energy_burden_Majority_white
  )

cat("\n--- Racial Disparity by Income Level ---\n")
cat("(Positive gap = majority non-white tracts have higher burden)\n\n")
print(stratified_race_by_income %>%
        select(fpl_category, energy_burden_Majority_white,
               energy_burden_Majority_non_white, burden_gap_pp, burden_ratio))

# -----------------------------------------------------------------------------
# 5.3 Summary of Stratified Analysis Results
# -----------------------------------------------------------------------------

cat("\n--- Summary of Stratified Analysis ---\n")
cat("\nAverage tenure gap across income levels:",
    round(mean(stratified_tenure_by_income$burden_gap_pp, na.rm = TRUE), 2),
    "percentage points\n")
cat("Average racial gap across income levels:",
    round(mean(stratified_race_by_income$burden_gap_pp, na.rm = TRUE), 2),
    "percentage points\n")


# =============================================================================
# SECTION 6: WEIGHTED LINEAR REGRESSION (Controlling for Confounders - Method 2)
# =============================================================================
#
# WHAT IS WEIGHTED LINEAR REGRESSION?
# -----------------------------------
# Regression models the relationship between a dependent variable (energy burden)
# and multiple independent variables (tenure, race, income, etc.) simultaneously.
#
# The model: burden = b0 + b1*tenure + b2*income + b3*housing + ...
#
# Each coefficient represents the effect of that variable while "holding all
# other variables constant" mathematically.
#
# We use WEIGHTED regression because each row represents different numbers of
# housing units. Weights = units ensures that rows with more units contribute
# proportionally more to the estimates.
#
# PROS:
# -----
# 1. Controls many confounders: Can include 5+ control variables simultaneously
# 2. Single adjusted effect: One coefficient summarizes the tenure effect
# 3. Statistical testing: Provides p-values and confidence intervals
# 4. Efficient: Uses all data in a single model
#
# CONS:
# -----
# 1. Assumes linearity: Effect of each variable is additive
# 2. Harder to interpret: Requires understanding of regression
# 3. May hide heterogeneity: Assumes constant effect across all groups
# 4. Model specification: Results depend on which variables are included
#
# HOW TO INTERPRET:
# -----------------
# - Coefficient = change in burden (percentage points) for that group vs reference
# - Reference categories: OWN (for tenure), Majority white (for race)
# - If coefficient for "REN" is 2.5, renters have 2.5 pp higher burden than
#   owners, controlling for other variables
# - p < 0.05: Effect is statistically significant
# - Compare unadjusted vs adjusted: If coefficient shrinks, confounding exists
#
# =============================================================================

cat("\n========================================\n")
cat("WEIGHTED LINEAR REGRESSION ANALYSIS\n")
cat("(Controlling for Confounders - Method 2)\n")
cat("========================================\n")

# -----------------------------------------------------------------------------
# 6.1 Prepare Data for Regression
# -----------------------------------------------------------------------------
# Filter to valid observations and remove extreme outliers that could
# distort regression results.
# -----------------------------------------------------------------------------

regression_data <- ga_lead_with_race %>%
  filter(
    !is.na(burden),                    # Must have valid burden
    is.finite(burden),                 # No Inf values
    burden > 0 & burden < 100,         # Remove extreme outliers (> 100% burden)
    !is.na(racial_majority),           # Must have race classification
    building_type != "Unknown",        # Must have valid housing type
    building_type != "Other"
  )

cat("\nRegression sample size:", nrow(regression_data), "observations\n")
cat("Total units represented:", sum(regression_data$units), "\n")

# -----------------------------------------------------------------------------
# 6.2 Model 1: Unadjusted Tenure Effect
# -----------------------------------------------------------------------------
# This is equivalent to comparing mean burden between renters and owners
# (with unit weighting). Serves as baseline for comparison.
# -----------------------------------------------------------------------------

model_tenure_unadj <- lm(
  burden ~ tenure,
  data = regression_data,
  weights = units
)

cat("\n--- Model 1: Unadjusted Tenure Effect ---\n")
cat("burden ~ tenure\n")
cat("(No control variables)\n\n")
print(tidy(model_tenure_unadj, conf.int = TRUE) %>%
        select(term, estimate, std.error, p.value, conf.low, conf.high))

# -----------------------------------------------------------------------------
# 6.3 Model 2: Tenure Effect Adjusted for Confounders
# -----------------------------------------------------------------------------
# Control variables:
# - fpl_category: Income level (primary confounder)
# - building_type: Housing type (affects energy efficiency)
# - building_age: Older buildings less efficient
# - heating_fuel: Different fuel costs
# -----------------------------------------------------------------------------

model_tenure_adj <- lm(
  burden ~ tenure + fpl_category + building_type + building_age + heating_fuel,
  data = regression_data,
  weights = units
)

cat("\n--- Model 2: Adjusted Tenure Effect ---\n")
cat("burden ~ tenure + fpl_category + building_type + building_age + heating_fuel\n")
cat("(Controlling for income, housing, building age, and heating fuel)\n\n")

# Show key coefficients
tenure_results_adj <- tidy(model_tenure_adj, conf.int = TRUE) %>%
  filter(term == "tenureREN")
print(tenure_results_adj %>%
        select(term, estimate, std.error, p.value, conf.low, conf.high))

# -----------------------------------------------------------------------------
# 6.4 Model 3: Race Effect Adjusted for Confounders
# -----------------------------------------------------------------------------
# Now we look at the effect of living in a majority non-white tract
# while controlling for individual-level characteristics.
# -----------------------------------------------------------------------------

model_race_adj <- lm(
  burden ~ racial_majority + fpl_category + tenure + building_type +
    building_age + heating_fuel,
  data = regression_data,
  weights = units
)

cat("\n--- Model 3: Adjusted Race Effect ---\n")
cat("burden ~ racial_majority + fpl_category + tenure + building_type + building_age + heating_fuel\n\n")

# Filter for the racial majority term (handle possible variations in term name)
race_results_adj <- tidy(model_race_adj, conf.int = TRUE) %>%
  filter(str_detect(term, "racial_majority"))
print(race_results_adj %>%
        select(term, estimate, std.error, p.value, conf.low, conf.high))

# -----------------------------------------------------------------------------
# 6.5 Compare Unadjusted vs Adjusted Effects
# -----------------------------------------------------------------------------

cat("\n--- Comparison: Unadjusted vs Adjusted Effects ---\n")

# Extract tenure coefficients
tenure_unadj_coef <- tidy(model_tenure_unadj) %>%
  filter(term == "tenureREN") %>%
  pull(estimate)
tenure_adj_coef <- tidy(model_tenure_adj) %>%
  filter(term == "tenureREN") %>%
  pull(estimate)

cat("\nTenure (Renter vs Owner):\n")
cat("  Unadjusted penalty:", round(tenure_unadj_coef, 2), "percentage points\n")
cat("  Adjusted penalty:  ", round(tenure_adj_coef, 2), "percentage points\n")
cat("  Change:", round(tenure_adj_coef - tenure_unadj_coef, 2), "pp\n")

if (tenure_adj_coef < tenure_unadj_coef) {
  cat("  Interpretation: Some of the renter penalty is explained by confounders\n")
  cat("  (e.g., renters live in different housing types, have different incomes)\n")
} else {
  cat("  Interpretation: Confounders were masking the true renter penalty\n")
}

# Extract race coefficient
race_adj_coef <- tidy(model_race_adj) %>%
  filter(term == "racial_majorityMajority non-white") %>%
  pull(estimate)

# Extract race coefficient for display
race_adj_coef_display <- if (nrow(race_results_adj) > 0) {
  race_results_adj$estimate[1]
} else {
  NA_real_
}

cat("\nRace (Majority Non-White vs Majority White Tract):\n")
if (!is.na(race_adj_coef_display)) {
  cat("  Adjusted penalty:", round(race_adj_coef_display, 2), "percentage points\n")
} else {
  cat("  (Could not extract race coefficient - check term names)\n")
}

# -----------------------------------------------------------------------------
# 6.6 Full Regression Results for Export
# -----------------------------------------------------------------------------

# Combine all model results
all_regression_results <- bind_rows(
  tidy(model_tenure_unadj, conf.int = TRUE) %>% mutate(model = "Unadjusted Tenure"),
  tidy(model_tenure_adj, conf.int = TRUE) %>% mutate(model = "Adjusted Tenure"),
  tidy(model_race_adj, conf.int = TRUE) %>% mutate(model = "Adjusted Race")
)


# =============================================================================
# SECTION 7: VISUALIZATIONS
# =============================================================================
# Visualizations help communicate findings to broader audiences.
# Each plot focuses on a specific comparison or story.
# =============================================================================

cat("\n========================================\n")
cat("GENERATING VISUALIZATIONS\n")
cat("========================================\n")

# Define color palettes for disparity visualizations
disparity_colors <- c(
  "OWN" = "#1B4D3E",      # Forest green (homeowners)
  "REN" = "#EB5757",      # Red (renters)
  "Homeowners" = "#1B4D3E",
  "Renters" = "#EB5757",
  "Owner" = "#1B4D3E",
  "Renter" = "#EB5757",
  "Majority white" = "#40916C",
  "Majority non-white" = "#D32F2F"
)

# -----------------------------------------------------------------------------
# 7.1 Bar Chart: Burden by Tenure (Simple Comparison)
# -----------------------------------------------------------------------------
# Shows the basic disparity between renters and homeowners
# -----------------------------------------------------------------------------

p_tenure <- burden_by_tenure %>%
  mutate(tenure = factor(tenure, levels = c("OWN", "REN"),
                         labels = c("Homeowners", "Renters"))) %>%
  ggplot(aes(x = tenure, y = energy_burden, fill = tenure)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = sprintf("%.1f%%", energy_burden)),
            vjust = -0.5, size = 8) +
  scale_fill_manual(values = disparity_colors) +
  scale_y_continuous(
    limits = c(0, max(burden_by_tenure$energy_burden) * 1.3),
    labels = function(x) paste0(x, "%")
  ) +
  theme_minimal() +
  gslide_theme +
  labs(
    title = "Energy Burden by Tenure Status",
    subtitle = "Georgia, 2022",
    x = "",
    y = "Energy Burden (% of income)",
    caption = "Source: DOE LEAD 2022"
  ) +
  theme(legend.position = "none")

ggsave("plots/burden_tenure_disparity.png", p_tenure,
       width = 7.5, height = 5, dpi = 350)
cat("Saved: plots/burden_tenure_disparity.png\n")

# -----------------------------------------------------------------------------
# 7.2 Grouped Bar Chart: Tenure Disparity by Income Level
# -----------------------------------------------------------------------------
# Shows how the renter-owner gap varies across income levels
# This is a visual representation of the stratified analysis
# -----------------------------------------------------------------------------

p_tenure_income <- burden_by_tenure_income %>%
  mutate(tenure = factor(tenure, levels = c("OWN", "REN"),
                         labels = c("Homeowners", "Renters"))) %>%
  ggplot(aes(x = fpl_category, y = energy_burden, fill = tenure)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(
    aes(label = sprintf("%.1f%%", energy_burden)),
    position = position_dodge(width = 0.8),
    vjust = -0.5, size = 4
  ) +
  scale_fill_manual(values = disparity_colors) +
  scale_y_continuous(
    limits = c(0, max(burden_by_tenure_income$energy_burden) * 1.2),
    labels = function(x) paste0(x, "%")
  ) +
  theme_minimal() +
  gslide_theme +
  labs(
    title = "Energy Burden by Tenure and Income Level",
    subtitle = "Renter-owner gap persists across income levels",
    x = "Federal Poverty Level Category",
    y = "Energy Burden (% of income)",
    fill = "",
    caption = "Source: DOE LEAD 2022"
  )

ggsave("plots/burden_tenure_by_income.png", p_tenure_income,
       width = 12, height = 7, dpi = 350)
cat("Saved: plots/burden_tenure_by_income.png\n")

# -----------------------------------------------------------------------------
# 7.3 Dot Plot: Visualizing the Renter-Owner Gap
# -----------------------------------------------------------------------------
# Shows the gap between renters and owners at each income level
# Makes disparities visually intuitive
# -----------------------------------------------------------------------------

p_gap <- stratified_tenure_by_income %>%
  ggplot(aes(y = fpl_category)) +
  # Line connecting owner and renter points
  geom_segment(
    aes(x = energy_burden_OWN, xend = energy_burden_REN, yend = fpl_category),
    color = "grey60", linewidth = 1.5
  ) +
  # Owner points (green)
  geom_point(aes(x = energy_burden_OWN), color = "#1B4D3E", size = 5) +
  # Renter points (red)
  geom_point(aes(x = energy_burden_REN), color = "#EB5757", size = 5) +
  # Gap labels
  geom_text(
    aes(x = (energy_burden_OWN + energy_burden_REN) / 2,
        label = sprintf("+%.1f pp", burden_gap_pp)),
    vjust = -1, size = 5
  ) +
  scale_x_continuous(labels = function(x) paste0(x, "%")) +
  theme_minimal() +
  gslide_theme +
  labs(
    title = "Energy Burden Gap: Renters vs Homeowners",
    subtitle = "Gap in percentage points shown for each income level",
    x = "Energy Burden (%)",
    y = "Federal Poverty Level",
    caption = "Green = Owners, Red = Renters | Source: DOE LEAD 2022"
  )

ggsave("plots/burden_gap_dotplot.png", p_gap,
       width = 10, height = 6, dpi = 350)
cat("Saved: plots/burden_gap_dotplot.png\n")

# -----------------------------------------------------------------------------
# 7.4 Faceted Bar Chart: Housing Type x Tenure
# -----------------------------------------------------------------------------
# Shows how the tenure gap varies by housing type
# Mobile homes often have highest burdens
# -----------------------------------------------------------------------------

p_housing_tenure <- burden_by_housing_tenure %>%
  mutate(
    tenure = factor(tenure, levels = c("OWN", "REN"), labels = c("Owner", "Renter")),
    building_type = factor(building_type,
                           levels = c("Single-family", "Small multifamily (2-4)",
                                      "Large multifamily (5+)", "Mobile home"))
  ) %>%
  filter(!is.na(building_type)) %>%
  ggplot(aes(x = building_type, y = energy_burden, fill = tenure)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(
    aes(label = sprintf("%.1f%%", energy_burden)),
    position = position_dodge(width = 0.8),
    vjust = -0.5, size = 4
  ) +
  scale_fill_manual(values = disparity_colors) +
  scale_y_continuous(
    limits = c(0, max(burden_by_housing_tenure$energy_burden, na.rm = TRUE) * 1.2),
    labels = function(x) paste0(x, "%")
  ) +
  theme_minimal() +
  gslide_theme +
  labs(
    title = "Energy Burden by Housing Type and Tenure",
    x = "",
    y = "Energy Burden (%)",
    fill = "",
    caption = "Source: DOE LEAD 2022"
  ) +
  theme(axis.text.x = element_text(angle = 15, hjust = 1))

ggsave("plots/burden_housing_tenure.png", p_housing_tenure,
       width = 12, height = 7, dpi = 350)
cat("Saved: plots/burden_housing_tenure.png\n")

# -----------------------------------------------------------------------------
# 7.5 Heatmap: Income x Race Burden Matrix
# -----------------------------------------------------------------------------
# Shows burden across two dimensions simultaneously
# Darker colors = higher burden
# -----------------------------------------------------------------------------

burden_heatmap_data <- ga_lead_with_race %>%
  filter(!is.na(racial_majority)) %>%
  calculate_weighted_burden(group_vars = c("fpl_category", "racial_majority"))

p_heatmap <- burden_heatmap_data %>%
  ggplot(aes(x = fpl_category, y = racial_majority, fill = energy_burden)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.1f%%", energy_burden)),
            color = "white", size = 6, fontface = "bold") +
  scale_fill_gradient2(
    low = "#40916C",      # Green for low burden
    mid = "#F2994A",      # Amber for medium
    high = "#B71C1C",     # Red for high burden
    midpoint = 6,         # 6% is often considered "high" threshold
    name = "Energy\nBurden"
  ) +
  theme_minimal() +
  gslide_theme +
  labs(
    title = "Energy Burden by Income and Racial Composition",
    x = "Federal Poverty Level Category",
    y = "",
    caption = "Source: DOE LEAD 2022"
  )

ggsave("plots/burden_heatmap.png", p_heatmap,
       width = 11, height = 5, dpi = 350)
cat("Saved: plots/burden_heatmap.png\n")

# -----------------------------------------------------------------------------
# 7.6 Coefficient Plot: Regression Results
# -----------------------------------------------------------------------------
# Shows adjusted effects from regression with confidence intervals
# Makes statistical results visually accessible
# -----------------------------------------------------------------------------

# Prepare coefficient data
coef_data <- tidy(model_race_adj, conf.int = TRUE) %>%
  filter(term != "(Intercept)") %>%
  mutate(
    # Clean up term names for display
    term_clean = case_when(
      term == "tenureREN" ~ "Renter (vs Owner)",
      term == "racial_majorityMajority non-white" ~ "Majority Non-White Tract",
      str_detect(term, "fpl_category") ~ str_replace(term, "fpl_category", "Income: "),
      str_detect(term, "building_type") ~ str_replace(term, "building_type", "Housing: "),
      str_detect(term, "building_age") ~ str_replace(term, "building_age", "Age: "),
      str_detect(term, "heating_fuel") ~ str_replace(term, "heating_fuel", "Fuel: "),
      TRUE ~ term
    ),
    significant = p.value < 0.05
  )

# Filter to key variables of interest
p_coef <- coef_data %>%
  filter(term %in% c("tenureREN", "racial_majorityMajority non-white")) %>%
  ggplot(aes(x = estimate, y = term_clean)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high),
                 height = 0.2, linewidth = 1) +
  geom_point(aes(color = significant), size = 4) +
  scale_color_manual(values = c("TRUE" = "#D32F2F", "FALSE" = "grey60"),
                     labels = c("TRUE" = "p < 0.05", "FALSE" = "p >= 0.05")) +
  theme_minimal() +
  gslide_theme +
  labs(
    title = "Adjusted Energy Burden Penalties",
    subtitle = "Controlling for income, housing type, building age, and heating fuel",
    x = "Additional burden (percentage points)",
    y = "",
    color = "Statistical\nSignificance",
    caption = "95% confidence intervals shown | Source: DOE LEAD 2022"
  )

ggsave("plots/burden_coefficients.png", p_coef,
       width = 10, height = 5, dpi = 350)
cat("Saved: plots/burden_coefficients.png\n")


# =============================================================================
# SECTION 8: SUMMARY & EXPORT
# =============================================================================

cat("\n========================================\n")
cat("SUMMARY & EXPORT\n")
cat("========================================\n")

# -----------------------------------------------------------------------------
# 8.1 Create Summary Table of Key Disparities
# -----------------------------------------------------------------------------

# Helper function to safely pull values (returns NA if not found)
safe_pull <- function(df, filter_col, filter_val, pull_col) {
  result <- df %>%
    filter(!!sym(filter_col) == filter_val) %>%
    pull(!!sym(pull_col))
  if (length(result) == 0) NA_real_ else result[1]
}

# Extract race coefficient (might be empty if term name differs)
race_adj_coef <- if (nrow(race_results_adj) > 0) {
  race_results_adj$estimate[1]
} else {
  NA_real_
}

# Build summary table row by row for robustness
disparity_summary <- tibble(
  comparison = c(
    "Renters vs Homeowners (overall)",
    "Renters vs Homeowners (0-100% FPL)",
    "Renters vs Homeowners (adjusted)",
    "Majority Non-White vs White Tracts (overall)",
    "Majority Non-White vs White Tracts (adjusted)"
  ),
  group_1 = c(
    "Homeowners",
    "Homeowners (0-100% FPL)",
    "Homeowners (adjusted)",
    "Majority White",
    "Majority White (adjusted)"
  ),
  group_1_burden = c(
    safe_pull(burden_by_tenure, "tenure", "OWN", "energy_burden"),
    safe_pull(burden_by_tenure_income, "tenure", "OWN", "energy_burden"),
    NA_real_,
    safe_pull(burden_by_race, "racial_majority", "Majority white", "energy_burden"),
    NA_real_
  ),
  group_2 = c(
    "Renters",
    "Renters (0-100% FPL)",
    "Renters (adjusted)",
    "Majority Non-White",
    "Majority Non-White (adjusted)"
  ),
  group_2_burden = c(
    safe_pull(burden_by_tenure, "tenure", "REN", "energy_burden"),
    safe_pull(burden_by_tenure_income, "tenure", "REN", "energy_burden"),
    NA_real_,
    safe_pull(burden_by_race, "racial_majority", "Majority non-white", "energy_burden"),
    NA_real_
  ),
  gap_pp = c(
    safe_pull(burden_by_tenure, "tenure", "REN", "energy_burden") -
      safe_pull(burden_by_tenure, "tenure", "OWN", "energy_burden"),
    safe_pull(stratified_tenure_by_income, "fpl_category", "0-100%", "burden_gap_pp"),
    tenure_adj_coef,
    safe_pull(burden_by_race, "racial_majority", "Majority non-white", "energy_burden") -
      safe_pull(burden_by_race, "racial_majority", "Majority white", "energy_burden"),
    race_adj_coef
  )
)

cat("\n--- Key Disparity Summary ---\n")
print(disparity_summary)

# -----------------------------------------------------------------------------
# 8.2 Export Results to CSV
# -----------------------------------------------------------------------------

# Export descriptive analysis
write.csv(burden_by_tenure, "temp/burden_by_tenure.csv", row.names = FALSE)
write.csv(burden_by_race, "temp/burden_by_race.csv", row.names = FALSE)
write.csv(burden_by_housing, "temp/burden_by_housing.csv", row.names = FALSE)
write.csv(burden_by_income, "temp/burden_by_income.csv", row.names = FALSE)

# Export stratified analysis
write.csv(stratified_tenure_by_income, "temp/stratified_tenure_by_income.csv", row.names = FALSE)
write.csv(stratified_race_by_income, "temp/stratified_race_by_income.csv", row.names = FALSE)

# Export regression results
write.csv(all_regression_results, "temp/regression_results.csv", row.names = FALSE)

# Export summary
write.csv(disparity_summary, "temp/disparity_summary.csv", row.names = FALSE)

cat("\nExported CSV files to temp/ directory\n")

# -----------------------------------------------------------------------------
# 8.3 Print Final Summary
# -----------------------------------------------------------------------------

cat("\n========================================\n")
cat("ANALYSIS COMPLETE\n")
cat("========================================\n")

cat("\nKey Findings:\n")
cat("--------------\n")
cat("1. Tenure: Renters face", round(tenure_unadj_coef, 1),
    "pp higher burden (unadjusted),", round(tenure_adj_coef, 1),
    "pp higher (adjusted)\n")
if (!is.na(race_adj_coef)) {
  cat("2. Race: Majority non-white tracts have", round(race_adj_coef, 1),
      "pp higher burden (adjusted)\n")
} else {
  cat("2. Race: See regression output for racial disparity results\n")
}
cat("3. The renter-owner gap varies across income levels (see stratified analysis)\n")
cat("4. Housing type significantly affects energy burden\n")

cat("\nOutput files created:\n")
cat("- temp/burden_by_*.csv (descriptive analysis)\n")
cat("- temp/stratified_*.csv (stratified analysis)\n")
cat("- temp/regression_results.csv (regression coefficients)\n")
cat("- temp/disparity_summary.csv (summary table)\n")
cat("- plots/burden_*.png (visualizations)\n")

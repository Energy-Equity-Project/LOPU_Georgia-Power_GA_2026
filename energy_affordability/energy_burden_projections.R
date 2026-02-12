
library(tidyverse)
library(tidycensus)

# Set Census API key - only needs to run once with install = TRUE
# census_api_key(Sys.getenv("CENSUS_API_KEY"), install = TRUE)

# Get 2022 median household income (baseline - matches DOE LEAD)
income_2022 <- get_acs(
  geography = "tract",
  variables = "B19013_001",  # Median household income
  state = "GA",
  year = 2022,
  survey = "acs5"
) %>%
  select(GEOID, income_2022 = estimate)

write.csv(
  income_2022,
  "temp/acs_income_2022.csv",
  row.names = FALSE
)

# Get 2024 median household income (most recent available)
income_2024 <- get_acs(
  geography = "tract",
  variables = "B19013_001",
  state = "GA",
  year = 2024,
  survey = "acs5"
) %>%
  select(GEOID, income_2024 = estimate)

write.csv(
  income_2024,
  "temp/acs_income_2024.csv",
  row.names = FALSE
)

# Calculate income growth and project to 2025
income_updates <- income_2022 %>%
  left_join(income_2024, by = "GEOID") %>%
  mutate(
    # Calculate annual growth rate (2-year period)
    annual_growth_rate = sqrt(income_2024 / income_2022),
  )

ga_lead_clean <- read.csv("temp/ga_lead_clean.csv") %>%
  mutate(geoid = as.character(geoid))

# Update ga_lead_clean with new income estimates
ga_lead_updated <- ga_lead_clean %>%
  left_join(
    income_updates %>%
      select(GEOID, annual_growth_rate),
    by = c("geoid"="GEOID")
  ) %>%
  mutate(
    # Store original LEAD income for comparison
    income_original = hincp,
    # Update income column with 2025 projection (average annual growth rate forecasted 3 times)
    est_income_2025 = hincp * (annual_growth_rate ^ 3)
  )

# Summary statistics
cat("Income Update Summary:\n")
ga_lead_updated %>%
  summarise(
    mean_income_original = weighted.mean(income_original, hincp_units_1, na.rm = TRUE),
    mean_income_2025 = weighted.mean(est_income_2025, hincp_units_1, na.rm = TRUE)
  )

# Updating electric rates=======================================================
ga_sales_df <- read.csv("temp/ga_sales_df.csv")

ga_power_elec_rate_increase <- ga_sales_df %>%
  filter(utility_name == "Georgia Power Co" &
           customer_class == "residential") %>%
  pull(percent_diff)

ga_power_elec_rate_increase <- 1 + (ga_power_elec_rate_increase / 100)

ga_utilities_tracts <- read.csv("temp/ga_utilities_tracts.csv")

ga_power_updated <- ga_lead_updated %>%
  mutate(geoid = as.numeric(geoid)) %>%
  left_join(
    ga_utilities_tracts,
    by = c("geoid"="GEOID")
  ) %>%
  filter(COMPANY_NAME == "GEORGIA POWER CO") %>%
  mutate(
    elec_original = elep,
    est_elep_2025 = elep * ga_power_elec_rate_increase
  )

ga_power_updated %>%
  summarize(
    units = sum(units, na.rm = TRUE),
    cost_2022 = weighted.mean(elep, elep_units_1, na.rm = TRUE) +
      weighted.mean(gasp, gasp_units_1, na.rm = TRUE) +
      weighted.mean(fulp, fulp_units_1, na.rm = TRUE),
    est_cost_2025 = weighted.mean(est_elep_2025, elep_units_1, na.rm = TRUE) +
      weighted.mean(gasp, gasp_units_1, na.rm = TRUE) +
      weighted.mean(fulp, fulp_units_1, na.rm = TRUE),
    hincp = weighted.mean(hincp, hincp_units_1, na.rm = TRUE),
    est_income_2025 = weighted.mean(est_income_2025, hincp_units_1, na.rm = TRUE)
  ) %>%
  mutate(burden_2022 = 100 * (cost_2022 / hincp),
         burden_2025 = 100 * (est_cost_2025 / est_income_2025))


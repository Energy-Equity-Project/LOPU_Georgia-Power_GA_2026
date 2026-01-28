
library(tidyverse)
library(janitor)
library(sf)

# Turn off s2 spherical geometry
sf_use_s2(FALSE)


# DOE LEAD Energy Burden for GA
ga_lead <- read.csv("../../../Data/DOE/08062025/Data Unzipped/GA-2022-LEAD-data/GA FPL Census Tracts 2022.csv") %>%
  clean_names()

# GA census tracts - US Census
ga_tracts_map <- st_read("../../../Data/GIS/US_Census/Census Tract Shapefiles/2024/tl_2024_13_tract/tl_2024_13_tract.shp")

# Utility service territories
service_territories <- st_read("../../../Data/Electric_Retail_Service_Territories/Electric_Retail_Service_Territories.shp")

ga_utilities_map <- service_territories %>%
  filter(STATE == "GA")

# Fix invalid geometries
ga_tracts_map <- st_make_valid(ga_tracts_map)
ga_utilities_map <- st_make_valid(ga_utilities_map)

ga_utilities_map <- st_transform(ga_utilities_map, st_crs(ga_tracts_map)) %>%
  rename(COMPANY_NAME = NAME)

# Calculate intersections and their areas
tract_territory_intersections <- ga_tracts_map %>%
  st_intersection(ga_utilities_map) %>%
  mutate(
    intersection_area = st_area(geometry),
    intersection_area_sqkm = as.numeric(intersection_area) / 1e6  # Convert to sq km
  )

tract_assignments <- tract_territory_intersections %>%
  st_drop_geometry() %>%  # Work with attribute table only
  group_by(GEOID) %>%  # Assuming GEOID is your tract identifier
  slice_max(intersection_area, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  select(GEOID, COMPANY_NAME)

write.csv(
  tract_assignments,
  "temp/ga_utilities_tracts.csv",
  row.names = FALSE
)

ga_lead_clean <- ga_lead %>%
  # Finding the average energy costs per housing unit
  mutate(elep = elep_units / elep_units_1,
         gasp = gasp_units / gasp_units_1,
         fulp = fulp_units / fulp_units_1,
         hincp = hincp_units / hincp_units_1) %>%
  replace_na(list(elep = 0, gasp = 0, fulp = 0)) %>%
  rename(geoid = fip) %>%
  mutate(geoid = as.character(geoid))

# Georgia summary stats
# energy burden 2.2%
# Average cost $2,190
# Average income $101k
ga_lead_clean %>%
  summarize(
    units = sum(units, na.rm = TRUE),
    cost = weighted.mean(elep, elep_units_1, na.rm = TRUE) +
      weighted.mean(gasp, gasp_units_1, na.rm = TRUE) +
      weighted.mean(fulp, fulp_units_1, na.rm = TRUE),
    hincp = weighted.mean(hincp, hincp_units_1, na.rm = TRUE)
  ) %>%
  mutate(burden = 100 * (cost / hincp))

# Find average energy burden in georgia power compared to the rest of the state
burden_by_utility <- ga_lead_clean %>%
  left_join(
    tract_assignments,
    by = c("geoid"="GEOID")
  ) %>%
  rename(utility = COMPANY_NAME) %>%
  mutate(
    utility = case_when(
      is.na(utility) ~ "Not associated",
      TRUE ~ utility
    )
  ) %>%
  group_by(utility) %>%
  summarize(
    units = sum(units, na.rm = TRUE),
    cost = weighted.mean(elep, elep_units_1, na.rm = TRUE) +
      weighted.mean(gasp, gasp_units_1, na.rm = TRUE) +
      weighted.mean(fulp, fulp_units_1, na.rm = TRUE),
    hincp = weighted.mean(hincp, hincp_units_1, na.rm = TRUE)
  ) %>%
  mutate(burden = 100 * (cost / hincp)) %>%
  ungroup() %>%
  arrange(desc(burden))



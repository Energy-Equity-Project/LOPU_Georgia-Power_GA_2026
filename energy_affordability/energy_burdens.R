
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

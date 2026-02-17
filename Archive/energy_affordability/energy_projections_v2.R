

# Initial projections ie DOE LEAD elec sales increased: 
# Estimated DOE LEAD sales increased = total = $450,335,864
# EIA reported sales for 2024: $4,509,930,600
# A 10x difference
ga_power_updated %>% summarize(est_elep_2025 = sum(est_elep_2025, na.rm = TRUE))
# Number of units as described by DOE LEAD: 1,783,551
# Number of customers as described by EIA: 2,452,488
# 1.375x more customers in EIA data rather than in DOE LEAD
ga_power_updated %>% summarize(units = sum(units, na.rm = TRUE))
eia_sales_df %>% filter(
  data_year == 2024 &
    customer_class == "residential" &
    utility_name == "Georgia Power Co"
)

# Method number 2: use EIA totals and broadcast across DOE LEAD props
eia_ga_power_elep_total <- eia_sales_df %>% filter(
  data_year == 2024 &
    customer_class == "residential" &
    utility_name == "Georgia Power Co"
) %>%
  pull(usd)

eia_ga_power_customer_count_total <- eia_sales_df %>% filter(
  data_year == 2024 &
    customer_class == "residential" &
    utility_name == "Georgia Power Co"
) %>%
  pull(count)

ga_power_v2 <- ga_lead_clean %>%
  mutate(geoid = as.numeric(geoid)) %>%
  left_join(
    ga_utilities_tracts,
    by = c("geoid"="GEOID")
  ) %>%
  filter(COMPANY_NAME == "GEORGIA POWER CO") %>%
  mutate(prop_elep_units_1 = elep_units_1 / sum(elep_units_1, na.rm = TRUE),
         prop_elep_units = elep_units / sum(elep_units, na.rm = TRUE)) %>%
  mutate(eia_est_elep_units = prop_elep_units * eia_ga_power_elep_total,
         eia_est_elep_units_1 = prop_elep_units_1 * eia_ga_power_customer_count_total) %>%
  mutate(eia_est_elep = eia_est_elep_units / eia_est_elep_units_1)

ga_power_v2 %>%
  summarize(
    eia_est_elep_units = sum(eia_est_elep_units, na.rm = TRUE),
    eia_est_elep_units_1 = sum(eia_est_elep_units_1, na.rm = TRUE)
  ) %>%
  mutate(avg_elec_cost = eia_est_elep_units / eia_est_elep_units_1)

ga_power_v2 %>%
  summarize(
    eia_est_elep = weighted.mean(eia_est_elep, eia_est_elep_units_1, na.rm = TRUE)
  )

ga_power_updated %>%
  summarize(
    est_elep_2025_units = sum(est_elep_2025 * elep_units_1, na.rm = TRUE),
    units = sum(units, na.rm = TRUE)
  )
  
ga_power_updated %>%
  summarize(
    est_elep_2025 = sum(est_elep_2025 * elep_units_1, na.rm = TRUE),
    elep_units_1 = sum(elep_units_1, na.rm = TRUE)
  ) %>%
  mutate(avg_cost = est_elep_2025/elep_units_1)

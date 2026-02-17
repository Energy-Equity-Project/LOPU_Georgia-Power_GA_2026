
library(tidyverse)
library(janitor)
library(sf)

source("visual_styling.R")

ga_power_lead_clean <- ga_lead_clean %>%
  mutate(geoid = as.numeric(geoid)) %>%
  filter(
    geoid %in% (ga_utilities_tracts %>%
      filter(
        COMPANY_NAME == "GEORGIA POWER CO"
      ) %>%
        pull(GEOID)
      )
  )

tenure_fpl_burden_plot <- ga_power_lead_clean %>%
  rename(tenure = ten) %>%
  group_by(tenure, fpl150) %>%
  summarize(
    units = sum(units, na.rm = TRUE),
    cost = weighted.mean(elep, elep_units_1, na.rm = TRUE) +
      weighted.mean(gasp, gasp_units_1, na.rm = TRUE) +
      weighted.mean(fulp, fulp_units_1, na.rm = TRUE),
    hincp = weighted.mean(hincp, hincp_units_1, na.rm = TRUE)
  ) %>%
  mutate(burden = 100 * (cost / hincp)) %>%
  ggplot(aes(x = fpl150, y = burden, fill = tenure)) +
  geom_bar(stat = "identity", position = "dodge") +
  theme_minimal() +
  gslide_theme +
  labs(
    title = "Energy burdens between renters and owners are similar",
    x = "Federal Poverty Level",
    y = "Energy Burden",
    caption = "Source: DOE LEAD 2022, (Data Update. 2024)"
  )

tenure_fpl_burden_plot

ggsave(
  "plots/tenure_fpl_burden.png",
  tenure_fpl_burden_plot,
  width = 10,
  height = 6,
  dpi = 300,
  bg = "white"
)

tract_demographics <- ga_power_lead_clean %>%
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
  ) %>%
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
      pct_nonwhite >= 50 ~ "Majority BIPOC",
      pct_nonwhite < 50 ~ "Majority white",
      TRUE ~ NA_character_
    )
  )

race_fpl_burden_plot <- ga_power_lead_clean %>%
  left_join(
    tract_demographics %>%
      select(geoid, racial_majority),
    by = c("geoid")
  ) %>%
  group_by(racial_majority, fpl150) %>%
  summarize(
    units = sum(units, na.rm = TRUE),
    cost = weighted.mean(elep, elep_units_1, na.rm = TRUE) +
      weighted.mean(gasp, gasp_units_1, na.rm = TRUE) +
      weighted.mean(fulp, fulp_units_1, na.rm = TRUE),
    hincp = weighted.mean(hincp, hincp_units_1, na.rm = TRUE)
  ) %>%
  mutate(burden = 100 * (cost / hincp)) %>%
  ggplot(aes(x = fpl150, y = burden, fill = racial_majority)) +
  geom_bar(stat = "identity", position = "dodge") +
  theme_minimal() +
  gslide_theme +
  labs(
    title = "Energy burdens across race are similar",
    x = "Federal Poverty Level",
    y = "Energy Burden",
    fill = "Race",
    caption = "Source: DOE LEAD 2022, (Data Update. 2024)"
  )

race_fpl_burden_plot

ggsave(
  "plots/race_fpl_burden.png",
  race_fpl_burden_plot,
  width = 10,
  height = 6,
  dpi = 300,
  bg = "white"
)



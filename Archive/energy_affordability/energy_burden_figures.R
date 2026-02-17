# Energy Burden Color Palette

# Alternative: More saturated version for emphasis
burden_colors_bold <- c(
  "0-3%"   = "#1B4D3E",  # Forest green
  "3-6%"   = "#40916C",  # Vibrant green
  "6-9%"   = "#F2994A",  # Warm amber
  "9-12%"  = "#EB5757",  # Bright red-orange
  "12-15%" = "#D32F2F",  # Strong red
  "15-20%" = "#B71C1C",  # Deep red
  "20+%"   = "#7F0000"   # Darkest red
)

ga_tracts_map %>%
  left_join(
    ga_lead_clean %>%
      group_by(geoid) %>%
      summarize(
        units = sum(units, na.rm = TRUE),
        cost = weighted.mean(elep, elep_units_1, na.rm = TRUE) +
          weighted.mean(gasp, gasp_units_1, na.rm = TRUE) +
          weighted.mean(fulp, fulp_units_1, na.rm = TRUE),
        hincp = weighted.mean(hincp, hincp_units_1, na.rm = TRUE)
      ) %>%
      mutate(wgt_mean_burden = 100 * (cost / hincp)),
    by = c("GEOID"="geoid")
  ) %>%
  mutate(
    burden_cat = case_when(
      wgt_mean_burden < 3 ~ "0-3%",
      wgt_mean_burden >= 3 & wgt_mean_burden < 6 ~ "3-6%",
      wgt_mean_burden >= 6 & wgt_mean_burden < 9 ~ "6-9%",
      wgt_mean_burden >= 9 & wgt_mean_burden < 12 ~ "9-12%",
      wgt_mean_burden >= 12 & wgt_mean_burden < 15 ~ "12-15%",
      wgt_mean_burden >= 15 & wgt_mean_burden < 20 ~ "15-20%",
      wgt_mean_burden >= 20 ~ "20+%",
      TRUE ~ NA_character_  # Handle any NA values
    ),
    burden_cat = factor(
      burden_cat,
      levels = c("0-3%", "3-6%", "6-9%", "9-12%", "12-15%", "15-20%", "20+%")
    )
  ) %>%
  ggplot(aes(fill = burden_cat)) +
  geom_sf(color = NA) +
  scale_fill_manual(values = burden_colors_bold) +
  theme_minimal() +
  labs(
    title = "Energy burdens (across all incomes)"
  )

ga_tracts_map %>%
  left_join(
    ga_lead_clean %>%
      filter(fpl150 %in% c("0-100%", "100-150%")) %>%
      group_by(geoid) %>%
      summarize(
        units = sum(units, na.rm = TRUE),
        cost = weighted.mean(elep, elep_units_1, na.rm = TRUE) +
          weighted.mean(gasp, gasp_units_1, na.rm = TRUE) +
          weighted.mean(fulp, fulp_units_1, na.rm = TRUE),
        hincp = weighted.mean(hincp, hincp_units_1, na.rm = TRUE)
      ) %>%
      mutate(wgt_mean_burden = 100 * (cost / hincp)),
    by = c("GEOID"="geoid")
  ) %>%
  mutate(
    burden_cat = case_when(
      wgt_mean_burden < 3 ~ "0-3%",
      wgt_mean_burden >= 3 & wgt_mean_burden < 6 ~ "3-6%",
      wgt_mean_burden >= 6 & wgt_mean_burden < 9 ~ "6-9%",
      wgt_mean_burden >= 9 & wgt_mean_burden < 12 ~ "9-12%",
      wgt_mean_burden >= 12 & wgt_mean_burden < 15 ~ "12-15%",
      wgt_mean_burden >= 15 & wgt_mean_burden < 20 ~ "15-20%",
      wgt_mean_burden >= 20 ~ "20+%",
      TRUE ~ NA_character_  # Handle any NA values
    ),
    burden_cat = factor(
      burden_cat,
      levels = c("0-3%", "3-6%", "6-9%", "9-12%", "12-15%", "15-20%", "20+%")
    )
  ) %>%
  ggplot(aes(fill = burden_cat)) +
  geom_sf(color = NA) +
  scale_fill_manual(values = burden_colors_bold) +
  theme_minimal() +
  labs(
    title = "Low income energy burdens (0-150% FPL)"
  )

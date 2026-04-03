# ==============================================================================
# 03d_burden_maps.R
# Lights Out, Profits Up — Georgia Power Report
#
# PURPOSE: Side-by-side choropleth maps of estimated 2024 energy burden by
# census tract — one panel for all households, one for households at 0–150% FPL.
# Shows how burden concentrates geographically and how dramatically worse it is
# for low-income households.
#
# OUTPUTS (1 PNG, 2 CSVs):
#   - lead_burden_map_sidebyside.png  (15" × 7", 350 dpi)
#   - lead_tract_burden_all_hh.csv
#   - lead_tract_burden_low_income.csv
#
# DEPENDENCIES: patchwork (install if needed: install.packages("patchwork"))
# ==============================================================================

source("R/01_setup_and_data_prep.R")
source("R/00_visual_styling.R")

library(patchwork)

# ==============================================================================
# PREPARE LEAD DATA
# Replicates script 03 / 03b LEAD prep — 03d is independent.
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
# AGGREGATE TO TRACT LEVEL
# Two summaries: all households, and households at 0–150% FPL only.
# ==============================================================================

assign_burden_cat <- function(burden_pct) {
  factor(
    case_when(
      burden_pct < 3   ~ "0-3%",
      burden_pct < 6   ~ "3-6%",
      burden_pct < 9   ~ "6-9%",
      burden_pct < 12  ~ "9-12%",
      burden_pct < 15  ~ "12-15%",
      burden_pct < 20  ~ "15-20%",
      burden_pct >= 20 ~ "20+%",
      TRUE             ~ NA_character_
    ),
    levels = c("0-3%", "3-6%", "6-9%", "9-12%", "12-15%", "15-20%", "20+%", "Non-Georgia Power")
  )
}

tract_burden_all <- lead_projected %>%
  group_by(fip) %>%
  summarize(
    wgt_mean_burden = weighted.mean(est_burden_2024, units, na.rm = TRUE),
    total_units     = sum(units, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  mutate(
    fip        = as.character(fip),
    burden_cat = assign_burden_cat(wgt_mean_burden)
  )

tract_burden_low_income <- lead_projected %>%
  filter(fpl150 %in% c("0-100%", "100-150%")) %>%
  group_by(fip) %>%
  summarize(
    wgt_mean_burden = weighted.mean(est_burden_2024, units, na.rm = TRUE),
    total_units     = sum(units, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  mutate(
    fip        = as.character(fip),
    burden_cat = assign_burden_cat(wgt_mean_burden)
  )

# ==============================================================================
# JOIN TO GEOMETRY
# ==============================================================================

territory_tracts <- tracts_sf %>%
  filter(GEOID %in% territory_geoids)

# Bounding box of the territory tracts — used to crop coord_sf to remove
# excess whitespace from the full Georgia state outline.
territory_bbox <- st_bbox(territory_tracts)

burden_cat_levels <- c("0-3%", "3-6%", "6-9%", "9-12%", "12-15%", "15-20%", "20+%", "Non-Georgia Power")

tracts_all_sf <- territory_tracts %>%
  left_join(tract_burden_all, by = c("GEOID" = "fip")) %>%
  mutate(burden_cat = factor(
    case_when(is.na(burden_cat) ~ "Non-Georgia Power", TRUE ~ as.character(burden_cat)),
    levels = burden_cat_levels
  ))

tracts_low_income_sf <- territory_tracts %>%
  left_join(tract_burden_low_income, by = c("GEOID" = "fip")) %>%
  mutate(burden_cat = factor(
    case_when(is.na(burden_cat) ~ "Non-Georgia Power", TRUE ~ as.character(burden_cat)),
    levels = burden_cat_levels
  ))

# ==============================================================================
# GEORGIA STATE OUTLINE
# Used as a grey background to give geographic context behind the territory tracts.
# ==============================================================================

ga_outline <- tigris::states(cb = TRUE, year = 2020) %>%
  filter(STATEFP == "13") %>%
  st_transform(crs = st_crs(tracts_sf))

# Major cities for geographic orientation (5 cities — enough context without clutter)
# Athens excluded (too close to Atlanta at this scale)
# Albany excluded (mostly municipal power, not GA Power territory)
#
# Two sf objects: dots at actual city centers, labels at pre-shifted positions.
# nudge_x/nudge_y cannot be mapped as aesthetics in geom_sf_label, so label
# positions are baked in here. Savannah shifted west to prevent right-edge clipping.
city_dots <- tibble(
  city = c("Atlanta", "Savannah", "Augusta", "Macon", "Columbus"),
  lon  = c(-84.388,   -81.100,    -81.975,   -83.633, -84.988),
  lat  = c( 33.749,    32.084,     33.474,    32.837,   32.461)
) %>%
  st_as_sf(coords = c("lon", "lat"), crs = 4269) %>%
  st_transform(crs = st_crs(tracts_sf))

city_labels <- tibble(
  city = c("Atlanta", "Savannah", "Augusta", "Macon", "Columbus"),
  lon  = c(-84.388,   -81.700,    -81.975,   -83.633, -84.988),
  lat  = c( 33.899,    32.234,     33.624,    32.987,   32.611)
) %>%
  st_as_sf(coords = c("lon", "lat"), crs = 4269) %>%
  st_transform(crs = st_crs(tracts_sf))

# ==============================================================================
# COLOR PALETTE — green → red inflection at 6% affordability threshold
# ==============================================================================

burden_colors <- c(
  "0-3%"             = "#1B4D3E",
  "3-6%"             = "#40916C",
  "6-9%"             = "#F2994A",
  "9-12%"            = "#EB5757",
  "12-15%"           = "#D32F2F",
  "15-20%"           = "#B71C1C",
  "20+%"             = "#7F0000",
  "Non-Georgia Power" = "grey95"
)

# ==============================================================================
# HELPER: build one choropleth panel
# ==============================================================================

build_burden_map <- function(tracts_data, panel_title) {
  ggplot() +
    geom_sf(data = ga_outline, fill = "grey90", color = "grey60", linewidth = 0.3) +
    geom_sf(data = tracts_data, aes(fill = burden_cat), color = NA) +
    # Leader line from Savannah dot to its offset label
    annotate(
      "segment",
      x = -81.100, y = 32.084, xend = -81.700, yend = 32.234,
      color = "grey25", linewidth = 0.25
    ) +
    # Small dot at actual city center (drawn after segment so it sits on top)
    geom_sf(data = city_dots, shape = 16, size = 0.6, color = "grey25") +
    # Label at pre-shifted positions (avoids right-edge clipping for Savannah)
    geom_sf_label(
      data          = city_labels,
      aes(label     = city),
      size          = 1.8,
      color         = "grey25",
      fill          = alpha("white", 0.65),
      fontface      = "bold",
      linewidth     = 0,
      label.padding = unit(0.1, "lines")
    ) +
    scale_fill_manual(
      values = burden_colors,
      labels = c("0-3%", "3-6%", "6-9%", "9-12%", "12-15%", "15-20%", "20+%", "Not\nGeorgia Power"),
      drop   = FALSE,
      name   = "Energy burden"
    ) +
    coord_sf(
      xlim   = c(territory_bbox["xmin"], territory_bbox["xmax"]),
      ylim   = c(territory_bbox["ymin"], territory_bbox["ymax"]),
      expand = FALSE
    ) +
    guides(fill = guide_legend(ncol = 1)) +
    theme_lopu() +
    theme(
      axis.text        = element_blank(),
      axis.ticks       = element_blank(),
      axis.title       = element_blank(),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      plot.title       = element_text(size = 11, hjust = 0.5,
                                      margin = margin(b = 3)),
      legend.text      = element_text(size = 11),
      legend.key.size  = unit(0.4, "cm")
    ) +
    labs(title = panel_title)
}

# ==============================================================================
# COMPOSE SIDE-BY-SIDE MAP
# ==============================================================================

map_all        <- build_burden_map(tracts_all_sf,        "All households")
map_low_income <- build_burden_map(tracts_low_income_sf, "Households at 0\u2013150% FPL")

map_combined <- (map_all | map_low_income) +
  plot_layout(guides = "collect") +
  plot_annotation(
    title   = glue("Energy burden by census tract \u2014 {utility_name_short} territory (2024 est.)"),
    caption = "DOE LEAD v4 (2022), projected to 2024 via EIA 861 and ACS B19013.",
    theme   = theme(
      plot.title   = element_text(size = 11, face = "bold"),
      plot.caption = element_text(color = "grey50", size = 11, hjust = 0),
      plot.margin  = margin(4, 16, 4, 8)
    )
  ) &
  theme(
    legend.position = "right",
    plot.margin     = margin(2, 4, 2, 4)
  )

ggsave(
  glue("plots/{today_fmt}-lead_burden_map_sidebyside.png"),
  plot   = map_combined,
  width  = 6.5, height = 3, dpi = 350, units = "in"
)

ggsave(
  glue("plots/{today_fmt}-lead_burden_map_sidebyside.svg"),
  plot   = map_combined,
  width  = 6.5, height = 3, units = "in"
)

# ==============================================================================
# SAVE OUTPUTS
# ==============================================================================

save_output(tract_burden_all,        "lead_tract_burden_all_hh")
save_output(tract_burden_low_income, "lead_tract_burden_low_income")

message("Script 03d complete.")

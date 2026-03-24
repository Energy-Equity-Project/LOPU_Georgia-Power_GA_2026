# ==============================================================================
# 02a_energy_insecurity_demographics.R
# Lights Out, Profits Up — Georgia Power Report
#
# PURPOSE: Demographic disparity analysis of Pulse Survey energy insecurity
# indicators. Computes weighted insecurity rates by income (FPL tier), race
# (Black vs. White), and household children status — then produces horizontal
# disparity bar charts with Georgia statewide average reference lines.
#
# INDICATORS: any_unable_bill, any_unsafe_temp, any_forgo_needs,
#             any_energy_issues (composite: at least 1 of 3)
#
# METHODOLOGY NOTE: FPL tier assignment uses income bracket midpoints against
# HHS FPL thresholds for the respondent's household size and survey year.
# Income brackets in the Pulse data are wide (e.g., $25–35K); brackets
# straddling two FPL tiers are assigned by midpoint — a known approximation
# documented in methodology_notes.md.
# ==============================================================================

source("R/01_setup_and_data_prep.R")
source("R/00_visual_styling.R")

# ==============================================================================
# INCOME BRACKET MIDPOINTS (USD)
# Maps Pulse income bracket labels to approximate annual household income.
# Brackets: <$25K→$12.5K, $25-35K→$30K, $35-50K→$42.5K, $50-75K→$62.5K,
#            $75-100K→$87.5K, $100-150K→$125K, $150-200K→$175K, $200K+→$225K
# ==============================================================================

income_midpoints <- c(
  "<$25K"     = 12500,
  "$25-35K"   = 30000,
  "$35-50K"   = 42500,
  "$50-75K"   = 62500,
  "$75-100K"  = 87500,
  "$100-150K" = 125000,
  "$150-200K" = 175000,
  "$200K+"    = 225000
)

# ==============================================================================
# HHS FEDERAL POVERTY LEVEL THRESHOLDS (100% FPL by household size)
# Source: HHS 2023 and 2024 poverty guidelines (contiguous US + DC)
# For sizes > 8, add the per-person increment.
# ==============================================================================

fpl_base <- tribble(
  ~household_size, ~fpl_100_2023, ~fpl_100_2024,
  1L,  14580L, 15060L,
  2L,  19720L, 20440L,
  3L,  24860L, 25820L,
  4L,  30000L, 31200L,
  5L,  35140L, 36580L,
  6L,  40280L, 41960L,
  7L,  45420L, 47340L,
  8L,  50560L, 52720L
)

fpl_lookup <- bind_rows(
  fpl_base,
  tibble(
    household_size = 9:15,
    fpl_100_2023   = 50560L + (1:7) * 5140L,
    fpl_100_2024   = 52720L + (1:7) * 5380L
  )
)

# ==============================================================================
# BINARY ENERGY INSECURITY INDICATORS (mirrors script 02 methodology)
# ==============================================================================

hardship_values <- c("almost_every_month", "some_months", "1_or_2_months")

pulse_insecurity <- pulse %>%
  filter(!is.na(enrgy_bill), !is.na(hse_temp), !is.na(energy)) %>%
  mutate(
    any_unable_bill   = enrgy_bill %in% hardship_values,
    any_unsafe_temp   = hse_temp   %in% hardship_values,
    any_forgo_needs   = energy     %in% hardship_values,
    any_energy_issues = any_unable_bill | any_unsafe_temp | any_forgo_needs
  )

# ==============================================================================
# FPL TIER ASSIGNMENT
# Map income bracket label → midpoint → FPL ratio for respondent's household
# size and survey year → assign tier (0–100%, 100–150%, 150–200%, 200%+)
# household_size is capped at 15 for the FPL lookup.
# ==============================================================================

pulse_fpl <- pulse_insecurity %>%
  mutate(
    income_midpoint = income_midpoints[income],
    hh_size_capped  = pmin(as.integer(household_size), 15L)
  ) %>%
  left_join(fpl_lookup, by = c("hh_size_capped" = "household_size")) %>%
  mutate(
    fpl_100 = case_when(
      survey_year == 2023 ~ fpl_100_2023,
      survey_year == 2024 ~ fpl_100_2024,
      TRUE                ~ fpl_100_2024  # default to most recent year
    ),
    fpl_tier = case_when(
      is.na(income_midpoint) | is.na(fpl_100) ~ NA_character_,
      income_midpoint <  fpl_100 * 1.0        ~ "0–100% FPL",
      income_midpoint <  fpl_100 * 1.5        ~ "100–150% FPL",
      income_midpoint <  fpl_100 * 2.0        ~ "150–200% FPL",
      TRUE                                    ~ "200%+ FPL"
    )
  ) %>%
  select(-fpl_100_2023, -fpl_100_2024, -hh_size_capped, -fpl_100)

# Verify FPL tier distribution (majority should be 200%+ given GA median income)
fpl_dist <- pulse_fpl %>%
  filter(!is.na(fpl_tier)) %>%
  group_by(fpl_tier) %>%
  summarize(n_weighted = sum(person_weight, na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(pct = round(100 * n_weighted / sum(n_weighted), 1))

message("FPL tier distribution (weighted %):")
print(fpl_dist)

# ==============================================================================
# STATEWIDE AVERAGES (weighted)
# ==============================================================================

statewide_avg <- pulse_insecurity %>%
  summarize(
    pct_any_unable_bill   = 100 * sum(any_unable_bill   * person_weight, na.rm = TRUE) / sum(person_weight, na.rm = TRUE),
    pct_any_unsafe_temp   = 100 * sum(any_unsafe_temp   * person_weight, na.rm = TRUE) / sum(person_weight, na.rm = TRUE),
    pct_any_forgo_needs   = 100 * sum(any_forgo_needs   * person_weight, na.rm = TRUE) / sum(person_weight, na.rm = TRUE),
    pct_any_energy_issues = 100 * sum(any_energy_issues * person_weight, na.rm = TRUE) / sum(person_weight, na.rm = TRUE),
    n_weighted            = sum(person_weight, na.rm = TRUE)
  )

message("Statewide averages:")
print(statewide_avg)

# ==============================================================================
# SUBGROUP STATISTICS
# Returns one row per group with weighted insecurity rates for all 4 indicators.
# group_col: bare column name (character) already present in df.
# ==============================================================================

compute_subgroup_rates <- function(df, group_col) {
  df %>%
    filter(!is.na(.data[[group_col]])) %>%
    group_by(across(all_of(group_col))) %>%
    summarize(
      pct_any_unable_bill   = 100 * sum(any_unable_bill   * person_weight, na.rm = TRUE) / sum(person_weight, na.rm = TRUE),
      pct_any_unsafe_temp   = 100 * sum(any_unsafe_temp   * person_weight, na.rm = TRUE) / sum(person_weight, na.rm = TRUE),
      pct_any_forgo_needs   = 100 * sum(any_forgo_needs   * person_weight, na.rm = TRUE) / sum(person_weight, na.rm = TRUE),
      pct_any_energy_issues = 100 * sum(any_energy_issues * person_weight, na.rm = TRUE) / sum(person_weight, na.rm = TRUE),
      n_weighted            = sum(person_weight, na.rm = TRUE)
    ) %>%
    ungroup() %>%
    rename(group_label = !!sym(group_col)) %>%
    mutate(group_dimension = group_col)
}

# Race: Black vs. White only (statewide avg serves as reference for other groups)
by_race <- pulse_insecurity %>%
  mutate(race_group = case_when(
    race == "Black" ~ "Black",
    race == "White" ~ "White",
    TRUE            ~ NA_character_
  )) %>%
  compute_subgroup_rates("race_group") %>%
  mutate(group_dimension = "Race")

# Income (FPL tiers)
by_fpl <- pulse_fpl %>%
  compute_subgroup_rates("fpl_tier") %>%
  mutate(group_dimension = "Income (FPL)")

# Household children status
by_children <- pulse_insecurity %>%
  mutate(children_group = case_when(
    num_kids > 0  ~ "With children",
    num_kids == 0 ~ "Without children",
    TRUE          ~ NA_character_
  )) %>%
  compute_subgroup_rates("children_group") %>%
  mutate(group_dimension = "Children")

# Combined subgroup summary (wide format, one row per subgroup)
disparity_summary <- bind_rows(by_race, by_fpl, by_children)

message("Subgroup summary:")
print(disparity_summary %>% select(group_dimension, group_label, pct_any_energy_issues, n_weighted))

# ==============================================================================
# LONG FORMAT TABLE FOR CHARTING AND CSV OUTPUT
# One row per subgroup × indicator, with statewide avg joined for gap calc.
# ==============================================================================

statewide_long <- statewide_avg %>%
  select(pct_any_unable_bill, pct_any_unsafe_temp, pct_any_forgo_needs, pct_any_energy_issues) %>%
  pivot_longer(
    cols      = everything(),
    names_to  = "indicator",
    values_to = "statewide_pct"
  ) %>%
  mutate(indicator = str_remove(indicator, "^pct_"))

disparity_long <- disparity_summary %>%
  pivot_longer(
    cols      = starts_with("pct_"),
    names_to  = "indicator",
    values_to = "pct"
  ) %>%
  mutate(indicator = str_remove(indicator, "^pct_")) %>%
  left_join(statewide_long, by = "indicator") %>%
  mutate(gap_from_avg = pct - statewide_pct) %>%
  select(group_dimension, group_label, indicator, pct, statewide_pct, gap_from_avg, n_weighted)

# ==============================================================================
# SAVE CSV OUTPUT
# ==============================================================================

save_output(disparity_long, "pulse_demographic_disparity_summary")

# ==============================================================================
# HORIZONTAL DISPARITY BAR CHARTS
# One chart per indicator (4 total: 3 individual + 1 composite).
# Layout: horizontal bars sorted high→top, vertical dashed reference line at GA
# statewide average, percentage label at bar tip.
# Color coding: bars exceeding statewide avg = lopu_red; bars at or below = lopu_navy.
# ==============================================================================

indicator_meta <- tibble(
  indicator  = c("any_unable_bill", "any_unsafe_temp", "any_forgo_needs", "any_energy_issues"),
  title      = c(
    "Unable to pay energy bill",
    "Kept home at unsafe temperature",
    "Forgoing household essentials to pay bills",
    "Any energy insecurity (at least 1 of 3 hardships)"
  ),
  file_slug  = c(
    "pulse_disparity_unable_bill",
    "pulse_disparity_unsafe_temp",
    "pulse_disparity_forgo_needs",
    "pulse_disparity_any_insecurity"
  )
)

for (i in seq_len(nrow(indicator_meta))) {

  ind       <- indicator_meta$indicator[i]
  ind_title <- indicator_meta$title[i]
  ind_file  <- indicator_meta$file_slug[i]

  # Group order: Income (FPL) → Race → Children (top to bottom in facet stack).
  # Within each group, sort ascending by pct so the highest bar is at the top
  # of its section after coord_flip.
  group_dim_levels <- c("Income (FPL)", "Race", "Children")

  chart_data <- disparity_long %>%
    filter(indicator == ind) %>%
    mutate(group_dimension = factor(group_dimension, levels = group_dim_levels)) %>%
    arrange(group_dimension, pct) %>%
    mutate(
      group_label = factor(group_label, levels = unique(group_label)),
      bar_color   = case_when(
        pct > statewide_pct ~ lopu_red,
        TRUE                ~ lopu_navy
      )
    )

  avg_pct <- unique(chart_data$statewide_pct)

  # Avg line label placed above the top bar of the top facet (Income (FPL) has 4 bars)
  avg_label_df <- tibble(
    group_dimension = factor("Income (FPL)", levels = group_dim_levels),
    x               = 4.5,   # one step above the 4 FPL bars
    y               = avg_pct,
    label           = glue("GA avg: {round(avg_pct, 1)}%")
  )

  p <- ggplot(chart_data, aes(x = group_label, y = pct, fill = bar_color)) +
    geom_col(width = 0.65) +
    # Reference line at statewide avg (appears vertical after coord_flip)
    geom_hline(
      yintercept = avg_pct,
      linetype   = "dashed",
      color      = lopu_navy,
      linewidth  = 0.8
    ) +
    # Percentage label at bar tip
    geom_text(
      aes(label = paste0(round(pct, 1), "%")),
      hjust = -0.15,
      size  = 3.5,
      color = "grey25"
    ) +
    # Avg reference label — only in the top (Income FPL) facet
    geom_text(
      data         = avg_label_df,
      aes(x = x, y = y, label = label),
      hjust        = 0.5,
      vjust        = -0.3,
      size         = 3,
      color        = lopu_navy,
      inherit.aes  = FALSE
    ) +
    facet_grid(
      rows   = vars(group_dimension),
      scales = "free_y",   # each facet shows only its own category labels
      space  = "free_y"    # panel height proportional to number of bars
    ) +
    coord_flip(clip = "off") +
    scale_fill_identity() +
    scale_y_continuous(
      labels = scales::percent_format(scale = 1, accuracy = 1),
      expand = expansion(mult = c(0, 0.18))
    ) +
    theme_lopu() +
    theme(
      legend.position  = "none",
      axis.text.y      = element_text(size = 10),
      strip.text.y     = element_text(angle = 0, hjust = 0.5, size = 9, face = "bold"),
      panel.spacing    = unit(0.6, "lines"),
      plot.margin      = margin(t = 20, r = 55, b = 10, l = 10)
    ) +
    labs(
      title    = glue("{ind_title} — {utility_name_short}, {state_abbrev}"),
      subtitle = "Weighted share of households experiencing hardship, by demographic group (2023–2024)",
      x        = "",
      y        = "Percent (%)",
      caption  = paste0(
        "Household Pulse Survey, US Census Bureau. ",
        "FPL tiers derived from income bracket midpoints and HHS poverty guidelines. ",
        "Dashed line = GA statewide average. Red bars exceed statewide average."
      )
    )

  ggsave(
    glue("plots/{today_fmt}-{ind_file}.png"),
    plot   = p,
    width  = 7.5, height = 6, dpi = 350, units = "in"
  )

  message(glue("Saved: plots/{today_fmt}-{ind_file}.png"))
}

message("Script 02a complete.")

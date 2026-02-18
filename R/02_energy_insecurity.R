# ==============================================================================
# 02_energy_insecurity.R
# Lights Out, Profits Up — Georgia Power Report
#
# PURPOSE: Household Pulse Survey energy insecurity analysis for Georgia.
# Produces wave-by-wave trend charts and subgroup breakdowns across three
# insecurity dimensions:
#   1. Unable to pay energy bill (enrgy_bill)
#   2. Forgoing household essentials to pay energy bills (energy)
#   3. Keeping home at unsafe/unhealthy temperatures (hse_temp)
#
# DATA NOTE: Uses cleaned harmonized Pulse data. Response values are labeled
# strings ("almost_every_month", "some_months", "1_or_2_months", "never", NA)
# — not numeric codes. person_weight replaces PWEIGHT. survey_wave replaces WEEK.
# ==============================================================================

source("R/01_setup_and_data_prep.R")
source("R/00_visual_styling.R")

library(patchwork)

# ==============================================================================
# MAP SURVEY WAVES TO DATES
# survey_wave column contains values like "week_63", "cycle_01"
# Populate this lookup to attach readable dates for plot x-axes.
# Confirm exact dates at:
# https://www.census.gov/programs-surveys/household-pulse-survey/data.html
# ==============================================================================

wave_dates <- tribble(
  ~survey_wave, ~survey_date
  # Add rows: survey_wave (string from cleaned data), survey_date (Date)
  # Example:
  # "week_63", as.Date("2023-10-18"),
)

if (nrow(wave_dates) > 0) {
  pulse_timed <- pulse %>%
    left_join(wave_dates, by = "survey_wave")
} else {
  # Group by survey_year if wave dates not mapped yet
  pulse_timed <- pulse %>%
    mutate(survey_date = as.Date(glue("{survey_year}-07-01")))
  message("wave_dates not populated — using mid-year date per survey_year. Add wave_dates rows above for finer time resolution.")
}

# ==============================================================================
# BINARY ENERGY INSECURITY INDICATORS
# Cleaned data uses labeled strings: "almost_every_month", "some_months",
# "1_or_2_months" = experienced hardship; "never" = no hardship; NA = missing
# ==============================================================================

hardship_values <- c("almost_every_month", "some_months", "1_or_2_months")

pulse_insecurity <- pulse_timed %>%
  filter(!is.na(enrgy_bill), !is.na(hse_temp), !is.na(energy)) %>%
  mutate(
    any_unable_bill  = enrgy_bill %in% hardship_values,
    any_unsafe_temp  = hse_temp   %in% hardship_values,
    any_forgo_needs  = energy     %in% hardship_values
  ) %>%
  mutate(
    any_energy_issues = any_unable_bill | any_unsafe_temp | any_forgo_needs,
    all_energy_issues = any_unable_bill & any_unsafe_temp & any_forgo_needs,
    num_hardships     = as.integer(any_unable_bill) +
                        as.integer(any_unsafe_temp) +
                        as.integer(any_forgo_needs)
  )

# ==============================================================================
# FREQUENCY DISTRIBUTIONS (for stacked area charts)
# ==============================================================================

freq_levels <- c(
  "Almost every month",
  "Some months",
  "1 or 2 months",
  "Never",
  "Did not report"
)

# Map cleaned string values to display labels
label_response <- function(x) {
  case_when(
    x == "almost_every_month" ~ "Almost every month",
    x == "some_months"        ~ "Some months",
    x == "1_or_2_months"      ~ "1 or 2 months",
    x == "never"              ~ "Never",
    is.na(x)                  ~ "Did not report",
    TRUE                      ~ "Did not report"
  )
}

build_freq_dist <- function(df, question_col, date_col = "survey_date") {
  df %>%
    mutate(answer_desc = factor(label_response(.data[[question_col]]), levels = freq_levels)) %>%
    group_by(across(all_of(c(date_col, "answer_desc")))) %>%
    summarize(wgt = sum(person_weight, na.rm = TRUE), .groups = "drop") %>%
    group_by(across(all_of(date_col))) %>%
    mutate(
      total   = sum(wgt),
      percent = 100 * (wgt / total)
    ) %>%
    ungroup()
}

unable_pay_bill   <- build_freq_dist(pulse_timed %>% filter(!is.na(enrgy_bill)), "enrgy_bill")
forego_essentials <- build_freq_dist(pulse_timed %>% filter(!is.na(energy)),     "energy")
hse_temp_dist     <- build_freq_dist(pulse_timed %>% filter(!is.na(hse_temp)),   "hse_temp")

# ==============================================================================
# CO-OCCURRENCE TRENDS (binary indicators over time)
# ==============================================================================

cooccurrence <- pulse_insecurity %>%
  pivot_longer(
    cols      = c(any_unable_bill, any_unsafe_temp, any_forgo_needs,
                  all_energy_issues, any_energy_issues),
    names_to  = "hardship",
    values_to = "hardship_felt"
  ) %>%
  group_by(survey_date, hardship) %>%
  summarize(
    pct = 100 * (sum(hardship_felt * person_weight, na.rm = TRUE) /
                   sum(person_weight, na.rm = TRUE)),
    .groups = "drop"
  )

# ==============================================================================
# SUBGROUP BREAKDOWNS
# Cleaned data has labeled race/tenure columns.
# race: "White", "Black", "Asian", "Other/Two+" (or similar — confirm in data)
# tenure: "Own", "Rent", "Other"
# ==============================================================================

pulse_subgroups <- pulse_timed %>%
  filter(!is.na(enrgy_bill), !is.na(hse_temp), !is.na(energy)) %>%
  mutate(
    rent_own = case_when(
      str_detect(tolower(tenure), "own")  ~ "Owner",
      str_detect(tolower(tenure), "rent") ~ "Renter",
      TRUE                                ~ "Other/Unknown"
    ),
    race_group = case_when(
      str_detect(tolower(race), "white") ~ "White",
      TRUE                               ~ "BIPOC"
    ),
    children_present = case_when(
      num_kids == 0  ~ "No children",
      num_kids > 0   ~ "Children present",
      TRUE           ~ "Unknown"
    )
  ) %>%
  mutate(
    any_unable_bill   = enrgy_bill %in% hardship_values,
    any_unsafe_temp   = hse_temp   %in% hardship_values,
    any_forgo_needs   = energy     %in% hardship_values,
    any_energy_issues = any_unable_bill | any_unsafe_temp | any_forgo_needs
  )

subgroup_summary <- function(df, group_var) {
  df %>%
    group_by(across(all_of(group_var))) %>%
    summarize(
      pct_any_energy_issues = 100 * (
        sum(any_energy_issues * person_weight, na.rm = TRUE) /
        sum(person_weight, na.rm = TRUE)
      ),
      pct_unable_bill  = 100 * (sum(any_unable_bill * person_weight, na.rm = TRUE) / sum(person_weight, na.rm = TRUE)),
      pct_unsafe_temp  = 100 * (sum(any_unsafe_temp * person_weight, na.rm = TRUE) / sum(person_weight, na.rm = TRUE)),
      pct_forgo_needs  = 100 * (sum(any_forgo_needs * person_weight, na.rm = TRUE) / sum(person_weight, na.rm = TRUE)),
      n_weighted       = sum(person_weight, na.rm = TRUE),
      .groups = "drop"
    )
}

insecurity_by_tenure   <- subgroup_summary(pulse_subgroups, "rent_own")
insecurity_by_race     <- subgroup_summary(pulse_subgroups, "race_group")
insecurity_by_children <- subgroup_summary(pulse_subgroups, "children_present")

# ==============================================================================
# COMPOUNDING INSECURITY
# Map labeled values to ordinal scores for numeric averaging
# ==============================================================================

response_score <- function(x) {
  case_when(
    x == "almost_every_month" ~ 1L,
    x == "some_months"        ~ 2L,
    x == "1_or_2_months"      ~ 3L,
    x == "never"              ~ 4L,
    TRUE                      ~ NA_integer_
  )
}

compounding_insecurity <- pulse_insecurity %>%
  mutate(
    bill_score = response_score(enrgy_bill),
    temp_score = response_score(hse_temp),
    eng_score  = response_score(energy),
    avg_freq   = (bill_score + eng_score + temp_score) / 3
  )

num_hardships_summary <- compounding_insecurity %>%
  group_by(survey_date, num_hardships) %>%
  summarize(
    wgt_avg_freq = weighted.mean(avg_freq, person_weight, na.rm = TRUE),
    wgt          = sum(person_weight, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  group_by(survey_date) %>%
  mutate(pct = 100 * (wgt / sum(wgt, na.rm = TRUE))) %>%
  ungroup() %>%
  group_by(num_hardships) %>%
  summarize(
    wgt_avg_freq = weighted.mean(wgt_avg_freq, wgt, na.rm = TRUE),
    wgt_pct      = weighted.mean(pct, wgt, na.rm = TRUE),
    .groups = "drop"
  )

# ==============================================================================
# SUMMARY STATISTICS (for narrative)
# ==============================================================================

pulse_summary_stats <- cooccurrence %>%
  group_by(hardship) %>%
  summarize(
    mean_pct = mean(pct, na.rm = TRUE),
    max_pct  = max(pct, na.rm = TRUE),
    min_pct  = min(pct, na.rm = TRUE),
    .groups  = "drop"
  )

print(pulse_summary_stats)

# ==============================================================================
# SAVE OUTPUTS
# ==============================================================================

save_output(cooccurrence,           "pulse_cooccurrence_trends")
save_output(insecurity_by_tenure,   "pulse_insecurity_by_tenure")
save_output(insecurity_by_race,     "pulse_insecurity_by_race")
save_output(insecurity_by_children, "pulse_insecurity_by_children")
save_output(num_hardships_summary,  "pulse_num_hardships_summary")
save_output(pulse_summary_stats,    "pulse_summary_statistics")

# ==============================================================================
# PLOTS
# ==============================================================================

severity_colors <- c(
  "Almost every month" = "#002E55",
  "Some months"        = "#094094",
  "1 or 2 months"      = "#1577BF",
  "Never"              = "#DEE7E4",
  "Did not report"     = "#969EA4"
)

hardship_colors <- c(
  "any_unable_bill"   = "#7A6C4F",
  "any_forgo_needs"   = "#1F4E79",
  "any_unsafe_temp"   = "#3A7F7A",
  "any_energy_issues" = "#094094",
  "all_energy_issues" = "#CFA43A"
)

hardship_labels <- c(
  "any_unable_bill"   = "Unable to\npay bill",
  "any_forgo_needs"   = "Forgo\nessentials",
  "any_unsafe_temp"   = "Kept home at\nunsafe temp",
  "any_energy_issues" = "Experienced\nat least 1",
  "all_energy_issues" = "Experienced\nall 3"
)

# Stacked area: unable to pay bill frequency
plot_unable_pay <- unable_pay_bill %>%
  ggplot(aes(x = survey_date, y = percent, fill = answer_desc)) +
  geom_area() +
  scale_x_date(date_labels = "%b %y", expand = c(0, 5)) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 10), expand = c(0, 0)) +
  scale_fill_manual(values = severity_colors, limits = names(severity_colors)) +
  theme_lopu() +
  labs(
    title   = glue("Unable to pay energy bill — {utility_name_short} service territory, {state_abbrev}"),
    x       = "",
    y       = "Percent (%)",
    fill    = "",
    caption = "Household Pulse Survey, US Census"
  )

ggsave(
  glue("plots/{today_fmt}-pulse_unable_pay_bill.png"),
  plot   = plot_unable_pay,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# Stacked area: forgoing household essentials
plot_forego <- forego_essentials %>%
  ggplot(aes(x = survey_date, y = percent, fill = answer_desc)) +
  geom_area() +
  scale_x_date(date_labels = "%b %y", expand = c(0, 5)) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 10), expand = c(0, 0)) +
  scale_fill_manual(values = severity_colors, limits = names(severity_colors)) +
  theme_lopu() +
  labs(
    title   = glue("Forgoing household essentials — {utility_name_short} service territory, {state_abbrev}"),
    x       = "",
    y       = "Percent (%)",
    fill    = "",
    caption = "Household Pulse Survey, US Census"
  )

ggsave(
  glue("plots/{today_fmt}-pulse_forego_essentials.png"),
  plot   = plot_forego,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# Stacked area: unsafe temperatures
plot_unsafe_temp <- hse_temp_dist %>%
  ggplot(aes(x = survey_date, y = percent, fill = answer_desc)) +
  geom_area() +
  scale_x_date(date_labels = "%b %y", expand = c(0, 5)) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 10), expand = c(0, 0)) +
  scale_fill_manual(values = severity_colors, limits = names(severity_colors)) +
  theme_lopu() +
  labs(
    title   = glue("Home at unsafe temperature — {utility_name_short} service territory, {state_abbrev}"),
    x       = "",
    y       = "Percent (%)",
    fill    = "",
    caption = "Household Pulse Survey, US Census"
  )

ggsave(
  glue("plots/{today_fmt}-pulse_unsafe_temp.png"),
  plot   = plot_unsafe_temp,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

# Line chart: co-occurrence trends
plot_cooccurrence <- cooccurrence %>%
  mutate(
    hardship_label = factor(hardship_labels[hardship], levels = hardship_labels)
  ) %>%
  ggplot(aes(x = survey_date, y = pct, color = hardship_label)) +
  geom_point(size = 2) +
  geom_line(linewidth = 1.5) +
  scale_x_date(date_labels = "%b %y", expand = c(0, 5)) +
  scale_y_continuous(limits = c(0, 60), breaks = seq(0, 60, 10), expand = c(0, 0)) +
  scale_color_manual(
    values = setNames(hardship_colors, hardship_labels),
    breaks = hardship_labels
  ) +
  theme_lopu() +
  labs(
    title   = glue("Energy insecurity rates — {utility_name_short} service territory, {state_abbrev}"),
    x       = "",
    y       = "Percent (%)",
    color   = "",
    caption = "Household Pulse Survey, US Census"
  )

ggsave(
  glue("plots/{today_fmt}-pulse_cooccurrence.png"),
  plot   = plot_cooccurrence,
  width  = 7.5, height = 5, dpi = 350, units = "in"
)

message("Script 02 complete.")

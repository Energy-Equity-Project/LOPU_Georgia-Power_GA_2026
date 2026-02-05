
# Libraries=====================================================================
library(tidyverse)
library(patchwork)
library(cowplot)

source("visual_styling.R")

# Understanding variations over time
# How do energy insecurity metrics change over time?

# Average energy insecurity indicators
cooccurence %>%
  filter(hardships == "any_unable_bill") %>%
  summarize(pct = mean(pct, na.rm = TRUE))

cooccurence %>%
  filter(hardships == "any_unable_bill") %>%
  summarize(max_pct = max(pct, na.rm = TRUE))

cooccurence %>%
  filter(hardships == "any_unable_bill") %>%
  summarize(min_pct = min(pct, na.rm = TRUE))

unable_pay_bill %>%
  filter(answer_desc == "Almost every month") %>%
  summarize(pct = mean(percent, na.rm = TRUE))


# How does experiencing more hardships relate to frequency of hardship felt?
num_hardships_freq <- compounding_energy_insecurity %>%
  group_by(date, num_hardships) %>%
  summarize(
    wgt_avg_freq = weighted.mean(avg_freq, PWEIGHT, na.rm = TRUE),
    PWEIGHT = sum(PWEIGHT, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  group_by(date) %>%
  mutate(pct = 100 * (PWEIGHT / sum(PWEIGHT, na.rm = TRUE))) %>%
  ungroup() %>%
  group_by(num_hardships) %>%
  summarize(
    wgt_avg_freq = weighted.mean(wgt_avg_freq, PWEIGHT, na.rm = TRUE),
    wgt_pct = weighted.mean(pct, PWEIGHT, na.rm = TRUE)
  ) %>%
  ungroup()

num_hardships_freq

write.csv(
  num_hardships_freq,
  "temp/num_hardships_and_freq.csv",
  row.names = FALSE
)

# Among households that cannot pay their bills...

# how many forego household necessities
compounding_energy_insecurity %>%
  filter(any_unable_bill == TRUE) %>%
  group_by(any_forgo_needs) %>%
  summarize(PWEIGHT = sum(PWEIGHT, na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(pct = 100 * (PWEIGHT / sum(PWEIGHT, na.rm = TRUE)))

# how many keep homes at unsafe temperatures
compounding_energy_insecurity %>%
  filter(any_unable_bill == TRUE) %>%
  group_by(any_unsafe_temp) %>%
  summarize(PWEIGHT = sum(PWEIGHT, na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(pct = 100 * (PWEIGHT / sum(PWEIGHT, na.rm = TRUE)))

# how many experience multiple hardships
compounding_energy_insecurity %>%
  filter(any_unable_bill == TRUE) %>%
  group_by(num_hardships) %>%
  summarize(PWEIGHT = sum(PWEIGHT, na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(pct = 100 * (PWEIGHT / sum(PWEIGHT, na.rm = TRUE)))

# Among those that forego household necessities...
compounding_energy_insecurity %>%
  filter(any_forgo_needs == TRUE) %>%
  group_by(any_unable_bill) %>%
  summarize(PWEIGHT = sum(PWEIGHT, na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(pct = 100 * (PWEIGHT / sum(PWEIGHT, na.rm = TRUE)))

# Unable to pay energy bill=====================================================
# Pulse Survey Question:
# In the last 12 months, how many times was your household unable to pay an
# energy bill or unable to pay the full bill amount?

# Home at unsafe temperatures
unable_pay_plot <- unable_pay_bill %>%
  ggplot(aes(x = date, y = percent, fill = answer_desc)) +
  geom_area() +
  scale_x_date(breaks = unique(unable_pay_bill$date),
               date_labels = "%b %y",
               expand = c(0, 5)) +
  scale_y_continuous(breaks = seq(0, 100, 10),
                     expand = c(0, 0)) +
  scale_fill_manual(
    values = severity_colors,
    limits = names(severity_colors)
  ) +
  theme_minimal() +
  gslide_theme +
  labs(
    title = "24% of respondents state they are unable to pay their energy bills",
    subtitle = "5% unable to pay \"Almost every month\"",
    # Axis
    x = "",
    y = "Percent (%)",
    # Legend
    fill = "", color = "",
    # caption
    caption = "Household Pulse Survey, US Census, 2024"
  )

unable_pay_plot

ggsave(
  "plots/unable_to_pay_ts.png",
  units = "in",
  width = 7.5,
  height = 5,
  dpi = 350
)

# Forgoing household necessities================================================
# Pulse Survey Question:
# In the last 12 months, how many months did your household reduce or forego
# expenses for basic household necessities, such as medicine or food, in order
# to pay an energy bill?

cooccurence %>%
  filter(hardships == "any_forgo_needs") %>%
  summarize(pct = mean(pct, na.rm = TRUE))

cooccurence %>%
  filter(hardships == "any_forgo_needs") %>%
  summarize(max_pct = max(pct, na.rm = TRUE))

cooccurence %>%
  filter(hardships == "any_forgo_needs") %>%
  summarize(min_pct = min(pct, na.rm = TRUE))

forego_essentials %>%
  filter(answer_desc == "Almost every month") %>%
  summarize(pct = mean(percent, na.rm = TRUE))

# Foregoing household essentials to pay energy bills
forego_essentials_plot <- forego_essentials %>%
  ggplot(aes(x = date, y = percent, fill = answer_desc)) +
  geom_area() +
  scale_x_date(breaks = unique(forego_essentials$date),
               date_labels = "%b %y",
               expand = c(0, 5)) +
  scale_y_continuous(breaks = seq(0, 100, 10),
                     expand = c(0, 0)) +
  scale_fill_manual(
    values = severity_colors,
    limits = names(severity_colors)
  ) +
  theme_minimal() +
  gslide_theme +
  labs(
    title = "35% of respondents state they forwent household needs",
    subtitle = "9% forgo household needs \"Almost every month\"",
    # Axis
    x = "",
    y = "Percent (%)",
    # Legend
    fill = "", color = "",
    # caption
    caption = "Household Pulse Survey, US Census, 2024"
  )

forego_essentials_plot

ggsave(
  "plots/forgoing_hh_needs_ts.png",
  units = "in",
  width = 7.5,
  height = 5,
  dpi = 350
)

# Keeping the homes at unsafe temperatures======================================
# Pulse Survey Question:
# In the last 12 months, how many months did your household keep your home at a
# temperature that you felt was unsafe or unhealthy?

cooccurence %>%
  filter(hardships == "any_unsafe_temp") %>%
  summarize(pct = mean(pct, na.rm = TRUE))

cooccurence %>%
  filter(hardships == "any_unsafe_temp") %>%
  summarize(max_pct = max(pct, na.rm = TRUE))

cooccurence %>%
  filter(hardships == "any_unsafe_temp") %>%
  summarize(min_pct = min(pct, na.rm = TRUE))

hse_temp %>%
  filter(answer_desc == "Almost every month") %>%
  summarize(pct = mean(percent, na.rm = TRUE))

# Home at unsafe temperatures
hse_temp_plot <- hse_temp %>%
  ggplot(aes(x = date, y = percent, fill = answer_desc)) +
  geom_area() +
  scale_x_date(breaks = unique(hse_temp$date),
               date_labels = "%b %y",
               expand = c(0, 5)) +
  scale_y_continuous(breaks = seq(0, 100, 10),
                     expand = c(0, 0)) +
  scale_fill_manual(
    values = severity_colors,
    limits = names(severity_colors)
  ) +
  theme_minimal() +
  gslide_theme +
  labs(
    title = "21% of respondents state they keep homes at unsafe temperatures",
    subtitle = "6% keep homes at unsafe temperatures \"Almost every month\"",
    # Axis
    x = "",
    y = "Percent (%)",
    # Legend
    fill = "", color = "",
    # caption
    caption = "Household Pulse Survey, US Census, 2024"
  )

hse_temp_plot

ggsave(
  "plots/unsafe_temp_ts.png",
  units = "in",
  width = 7.5,
  height = 5,
  dpi = 350
)


# Energy insecurity indicator===================================================
# building a measure of energy insecurity based on how they answered the 3 questions

# How many experience at least 1 energy insecurity indicator
cooccurence %>%
  filter(hardships == "any_energy_issues") %>%
  summarize(pct = mean(pct, na.rm = TRUE))

cooccurence %>%
  filter(hardships == "any_energy_issues")

# How many experience all energy insecurity metrics
cooccurence %>%
  filter(hardships == "all_energy_issues") %>%
  summarize(pct = mean(pct, na.rm = TRUE))

cooccurence %>%
  filter(hardships == "all_energy_issues")

cooccurence_plot <- cooccurence %>%
  mutate(
    hardships = case_when(
      hardships == "all_energy_issues" ~ "Experienced\nall 3",
      hardships == "any_energy_issues" ~ "Experienced\nat least 1",
      hardships == "any_forgo_needs" ~ "Forgo\nessentials",
      hardships == "any_unable_bill" ~ "Unable to\npay bill",
      hardships == "any_unsafe_temp" ~ "Kept home at\nunsafe temp",
      TRUE ~ "error"
    )
  ) %>%
  ggplot(aes(x = date, y = pct, color = hardships)) +
  geom_point(size = 2) +
  geom_line(linewidth = 1.5) +
  scale_x_date(breaks = unique(cooccurence$date),
               date_labels = "%b %y",
               expand = c(0, 5)) +
  scale_y_continuous(limits = c(0, 50), breaks = seq(0, 50, 5),
                     expand = c(0, 0)) +
  scale_color_manual(
    values = risk_colors,
    limits = names(risk_colors)
  ) +
  theme_minimal() +
  gslide_theme +
  theme(
    legend.text = element_text(lineheight = 0.3)
  ) +
  labs(
    title = "44% of respondents experience at least 1 energy insecurity risk",
    subtitle = "10% experience all 3 energy insecurity risks",
    x = "",
    y = "Percent (%)",
    color = "",
    caption = "Household Pulse Survey, US Census, 2024"
  )

cooccurence_plot

ggsave(
  "plots/cooccurrence_ts.png",
  units = "in",
  width = 7.5,
  height = 5,
  dpi = 350
)

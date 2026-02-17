
source("visual_styling.R")

sales_df <- read.csv("temp/eia_sales_df.csv")

customer_class_colors <- c(
  "residential" = "#002E55",
  "commercial" = "#CFA43A",
  "industrial" = "#969EA4"
)

sales_df %>%
  filter(utility_name == "Georgia Power Co" &
           data_year >= 2020) %>%
  ggplot(aes(x = data_year, rate, color = customer_class)) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.5) +
  scale_y_continuous(breaks = seq(0, 16, 1), limits = c(0, 15.5)) +
  scale_color_manual(values = customer_class_colors) +
  theme_minimal() +
  gslide_theme +
  labs(
    x = "",
    y = "Electric Rate (cents per kWh)",
    color = "Customer Class",
    title = "Georgia Power Co Electric Rates",
    caption = "EIA Form 861, 2020-2024"
  )

ggsave(
  "plots/ga_power_elec_rates_2020-2024.png",
  units = "in",
  width = 7.5,
  height = 5,
  dpi = 350
)

ga_sales_df <- read.csv("temp/ga_sales_df.csv")

ga_sales_df %>%
  filter(customer_class == "residential") %>%
  filter(ownership != "Political Subdivision") %>%
  group_by(ownership) %>%
  summarize(
    wgt_rate_change = weighted.mean(rate_difference, customer_count_2024, na.rm = TRUE),
    wgt_rate_change_pct = weighted.mean(percent_diff, customer_count_2024, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  arrange(desc(wgt_rate_change_pct)) %>%
  # Note: Georgia Power is the only IOU operating in GA
  mutate(ownership = case_when(
    ownership == "Investor Owned" ~ "Georgia Power Co",
    TRUE ~ ownership
  )) %>%
  ggplot(aes(x = wgt_rate_change_pct, y = reorder(ownership, wgt_rate_change_pct), fill = ownership)) +
  geom_bar(stat = "identity") +
  scale_fill_manual(values = economist_red_alt) +
  geom_text(aes(label = paste0(sprintf("%.1f", wgt_rate_change_pct), "%")),
            hjust = 1.2,
            fontface = "bold",
            size = 16,
            color = "white") +
  theme_minimal() +
  gslide_theme +
  theme(
    legend.position = "none"
  ) +
  labs(
    title = "Georgia Power Co increases rates by 25%",
    subtitle = "Georgia Power increases residential rates 2x more than other utilities",
    x = "Weighted Mean Residential Electric Rate Percent Change (2020-2024)",
    y = "",
    caption = "EIA Form 861, 2020-2024"
  )

ggsave(
  "plots/ga_power_elec_rate_pct_change_compare_ownership.png",
  units = "in",
  width = 7.5,
  height = 5,
  dpi = 350
)

economist_red_palette <- c(
  "Georgia Power Co" = "#B91C1C",    # Deep red - for highest rates/increases
  "Cooperative" = "#DC2626",       # Classic Economist red
  "Municipal" = "#F87171"          # Lighter red/coral
)

# Alternative ordering emphasizing The Economist signature color
economist_red_alt <- c(
  "Georgia Power Co" = "#C8102E",    # The Economist signature red
  "Municipal" = "#E94B3C",       # Mid-tone red
  "Cooperative" = "#F7A9A0"          # Soft coral
)


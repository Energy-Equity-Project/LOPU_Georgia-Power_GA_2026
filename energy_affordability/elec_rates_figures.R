
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

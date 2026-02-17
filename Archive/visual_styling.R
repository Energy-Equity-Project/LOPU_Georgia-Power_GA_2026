
library(tidyverse)
library(showtext)
library(sysfonts)

# Add the Inter font (you need to do this once)
font_add_google("Inter", "Inter")
font_add_google("Bitter", "Bitter")

# Enable showtext for rendering
showtext_auto()

severity_colors <- c(
  "Almost every month" = "#002E55",
  "Some months"        = "#094094",
  "1 or 2 months"      = "#1577BF",
  "Never"              = "#DEE7E4",
  "Did not report"     = "#969EA4"
)

risk_colors <- c(
  "Forgo\nessentials"                 = "#1F4E79",
  "Kept home at\nunsafe temp"         = "#3A7F7A",
  "Unable to\npay bill"               = "#7A6C4F",
  "Experienced\nat least 1"           = "#094094",
  "Experienced\nall 3"                = "#CFA43A"
)

gslide_theme <- theme(
  # Set white background
  panel.background = element_rect(fill = "white", color = NA),
  plot.background = element_rect(fill = "white", color = NA),
  text = element_text(family = "Inter"),
  plot.title = element_text(family = "Bitter", size = 48, lineheight =  0.5),
  plot.subtitle = element_text(family = "Bitter", size = 36, lineheight =  0.5),
  axis.title.y = element_text(family = "Inter", size = 32),
  axis.title.x = element_text(family = "Inter", size = 32),
  axis.text = element_text(family = "Inter", size = 16),
  axis.text.x = element_text(size = 24),
  axis.text.y = element_text(size = 24),
  plot.margin = margin(5, 5, 5, 0),
  strip.text = element_text(family = "Inter", size = 16),
  legend.position = "bottom",
  legend.title = element_text(size = 24),
  legend.text = element_text(size = 22),
  legend.margin = margin(t = 0, b = 0, l = -100),  # Remove top/bottom margins from legend
  panel.grid.major.y = element_blank(),  # Remove horizontal grid lines
  panel.grid.minor.y = element_blank(),  # Remove minor horizontal grid lines
  plot.caption = element_text(family = "Inter", color = "grey50", size = 20, hjust = 1, vjust = 12)
)

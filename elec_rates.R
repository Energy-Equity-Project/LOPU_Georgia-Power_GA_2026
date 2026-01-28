
# Libraries=====================================================================
library(tidyverse)
library(readxl)
library(janitor)

outdir <- "temp"

# Reading in data
eia_fp <- "../../../Data/EIA/861/Form 861 - unzipped/"

# Get all the file names for sales data
eia_filenames <- list.files(eia_fp, pattern = "^Sales_Ult_Cust_20[0-9][0-9]")

sales <- data.frame()

# Note: to avoid double counting customers:
# Sum parts A, B, C, D for revenue
# only sum parts A, B, D for sales and customer counts
for (curr_filename in eia_filenames) {
  curr_eia <- read_excel(file.path(eia_fp, curr_filename), sheet = "States", .name_repair = "unique_quiet")
  
  # Find residential column
  meta_col_end_idx <- which(tolower(colnames(curr_eia)) == "residential")
  
  print(paste(curr_filename, meta_col_end_idx))
  
  residential <- curr_eia[2:nrow(curr_eia), 1:(meta_col_end_idx+2)] %>%
    row_to_names(row_number = 1) %>%
    clean_names()
  
  commercial <- curr_eia[2:nrow(curr_eia), c(1:(meta_col_end_idx-1), (meta_col_end_idx+3): (meta_col_end_idx+5))] %>%
    row_to_names(row_number = 1) %>%
    clean_names()
  
  industrial <- curr_eia[2:nrow(curr_eia), c(1:(meta_col_end_idx-1), (meta_col_end_idx+6):(meta_col_end_idx+8))] %>%
    row_to_names(row_number = 1) %>%
    clean_names()
  
  curr_sales <- residential %>%
    mutate(customer_class = "residential") %>%
    bind_rows(
      commercial %>%
        mutate(customer_class = "commercial")
    ) %>%
    bind_rows(
      industrial %>%
        mutate(customer_class = "industrial")
    )
  
  # Standardize revenue column name
  if ("thousands_dollars" %in% colnames(curr_sales)) {
    curr_sales <- curr_sales %>%
      rename(thousand_dollars = thousands_dollars)
  }
  
  curr_sales <- curr_sales %>%
    mutate(
      data_year = as.numeric(data_year),
      thousand_dollars = as.numeric(thousand_dollars),
      megawatthours = as.numeric(megawatthours),
      count = as.numeric(count)
    ) %>%
    filter(!is.na(data_year)) %>%
    filter(!(str_detect(utility_name, "Adjustment")))
  
  sales <- sales %>%
    bind_rows(curr_sales)
  
}

sales_customer_counts <- sales %>%
  filter(part != "C" &
           ownership != "Behind the Meter") %>%
  group_by(data_year, state, utility_name, ownership, customer_class) %>%
  summarize(count = sum(count, na.rm = TRUE),
            megawatthours = sum(megawatthours, na.rm = TRUE)) %>%
  ungroup()

sales_revenue <- sales %>%
  filter(ownership != "Behind the Meter") %>%
  group_by(data_year, state, utility_name, ownership, customer_class) %>%
  summarize(thousand_dollars = sum(thousand_dollars, na.rm = TRUE)) %>%
  ungroup()

sales_df <- sales_customer_counts %>%
  full_join(
    sales_revenue,
    by = c("data_year", "state", "utility_name", "ownership", "customer_class")
  )

sales_df <- sales_df %>%
  mutate(usd = thousand_dollars * 1000,
         kwh = megawatthours * 1000) %>%
  mutate(rate = (usd * 100) / kwh)

write.csv(
  sales_df,
  file.path(outdir, "eia_sales_df.csv"),
  row.names = FALSE
)

# Calculate percentages in rates from 2020 to 2024
ga_sales_df <- sales_df %>%
  filter(state == "GA") %>%
  filter(data_year == 2020 |
           data_year == 2024) %>%
  select(data_year, utility_name, ownership, customer_class, rate) %>%
  pivot_wider(names_from = data_year, names_prefix = "rate_", values_from = rate) %>%
  filter(!is.na(rate_2020) & !is.na(rate_2024) &
           !is.infinite(rate_2020) & !is.infinite(rate_2024)) %>%
  mutate(rate_difference = rate_2024 - rate_2020) %>%
  mutate(percent_diff = 100 * (rate_difference / rate_2020)) %>%
  mutate(customer_class = factor(
    customer_class,
    levels = c("commercial", "industrial", "residential")
  )) %>%
  left_join(
    sales_df %>%
      filter(data_year == 2024) %>%
      select(utility_name, ownership, customer_class, customer_count_2024=count),
    by = c("utility_name", "ownership", "customer_class")
  )

write.csv(
  ga_sales_df,
  "temp/ga_sales_df.csv",
  row.names = FALSE
)

# Georgia utilities arranged by percent of residential customers they serve in the state
tmp <- ga_sales_df %>%
  filter(customer_class == "residential") %>%
  mutate(percent_customers = 100 * (customer_count_2024 / sum(customer_count_2024, na.rm = TRUE))) %>%
  arrange(desc(percent_customers))
  


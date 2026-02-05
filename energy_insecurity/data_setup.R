
# Libraries=====================================================================
library(tidyverse)
library(readxl)
library(lubridate)
library(patchwork)
library(cowplot)
library(janitor)

# Reading in files==============================================================

pulse_survey_dir <- "../../../Data/Pulse_Survey/PUF"

# Make sure to take into account for seasonality

# Oct 18 - Oct 30, 2023 (Week 63)
oct_2023 <- read.csv(file.path(pulse_survey_dir, "HPS_Week63_PUF_CSV/pulse2023_puf_63.csv"))
# Jan 9 - Feb 5 (Cycle 1)
jan_2024 <- read.csv(file.path(pulse_survey_dir, "HPS_Phase4Cycle01_PUF_CSV/hps_04_00_01_puf.csv"))
# March 5 - April 1(Cycle 3)
march_2024 <- read.csv(file.path(pulse_survey_dir, "HPS_Phase4Cycle03_PUF_CSV/hps_04_00_03_puf.csv"))
# April 30 - May 27 (Cycle 5)
may_2024 <- read.csv(file.path(pulse_survey_dir, "HPS_Phase4-1Cycle05_PUF_CSV/hps_04_01_05_puf.csv"))
# June 25 - July 22 (Cycle 7)
july_2024 <- read.csv(file.path(pulse_survey_dir, "HPS_Phase4-1Cycle07_PUF_CSV/hps_04_01_07_puf.csv"))
# August 20 - September 16 (Cycle 9)
sept_2024 <- read.csv(file.path(pulse_survey_dir, "HPS_Phase4-2Cycle09_PUF_CSV/hps_04_02_09_puf.csv"))


colnames(oct_2023)[!(colnames(oct_2023) %in% colnames(sept_2024))]
colnames(sept_2024)[!(colnames(sept_2024) %in% colnames(oct_2023))]


# Bringing together pulse survey responses across multiple survey dates
pulse <- oct_2023 %>%
  mutate(
    month = 10,
    year = 2023
  ) %>%
  bind_rows(
    jan_2024 %>%
      mutate(
        month = 1,
        year = 2024
      ) 
  ) %>%
  bind_rows(
    march_2024 %>%
      mutate(
        month = 3,
        year = 2024
      ) 
  ) %>%
  bind_rows(
    may_2024 %>%
      mutate(
        month = 5,
        year = 2024
      ) 
  ) %>%
  bind_rows(
    july_2024 %>%
      mutate(
        month = 7,
        year = 2024
      ) 
  ) %>%
  bind_rows(
    sept_2024 %>%
      mutate(
        month = 9,
        year = 2024
      ) 
  )

# Isolate results specific to Georgia
sc_pulse <- pulse %>%
  filter(EST_ST == 13) %>%
  select(EST_ST, month, year, HSE_TEMP, ENERGY, ENRGY_BILL, PWEIGHT) %>%
  mutate(
    HSE_TEMP = case_when(
      HSE_TEMP == -88 | HSE_TEMP == -99 ~ -1,
      TRUE ~ HSE_TEMP
    ),
    ENERGY = case_when(
      ENERGY == -88 | ENERGY == -99 ~ -1,
      TRUE ~ ENERGY
    ),
    ENRGY_BILL = case_when(
      ENRGY_BILL == -88 | ENRGY_BILL == -99 ~ -1,
      TRUE ~ ENRGY_BILL
    )
  ) %>%
  mutate(date = make_date(year = year, month = month, day = 1))

# Unable to pay energy bill=====================================================
# Pulse Survey Question:
# In the last 12 months, how many times was your household unable to pay an
# energy bill or unable to pay the full bill amount?

# Note: Persons born before 2005
unable_pay_bill <- sc_pulse %>%
  group_by(month, year, ENRGY_BILL) %>%
  summarize(PWEIGHT = sum(PWEIGHT, na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(date = make_date(year = year, month = month, day = 1)) %>%
  mutate(ENRGY_BILL = as.character(ENRGY_BILL)) %>%
  group_by(date) %>%
  mutate(total = sum(PWEIGHT, na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(percent = 100 * (PWEIGHT / total)) %>%
  mutate(
    answer_desc = case_when(
      ENRGY_BILL == "-1" ~ "Did not report",
      ENRGY_BILL == "1" ~ "Almost every month",
      ENRGY_BILL == "2" ~ "Some months",
      ENRGY_BILL == "3" ~ "1 or 2 months",
      ENRGY_BILL == "4" ~ "Never",
      TRUE ~ "Error"
    )
  ) %>%
  mutate(
    answer_desc = factor(
      answer_desc,
      levels = c("Almost every month",
                 "Some months",
                 "1 or 2 months",
                 "Never",
                 "Did not report")
    )
  )

# Forgoing household necessities================================================
# Pulse Survey Question:
# In the last 12 months, how many months did your household reduce or forego
# expenses for basic household necessities, such as medicine or food, in order
# to pay an energy bill?

forego_essentials <- sc_pulse %>%
  group_by(month, year, ENERGY) %>%
  summarize(PWEIGHT = sum(PWEIGHT, na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(date = make_date(year = year, month = month, day = 1)) %>%
  mutate(ENERGY = as.character(ENERGY)) %>%
  group_by(date) %>%
  mutate(total = sum(PWEIGHT, na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(percent = 100 * (PWEIGHT / total)) %>%
  mutate(
    answer_desc = case_when(
      ENERGY == "-1" ~ "Did not report",
      ENERGY == "1" ~ "Almost every month",
      ENERGY == "2" ~ "Some months",
      ENERGY == "3" ~ "1 or 2 months",
      ENERGY == "4" ~ "Never",
      TRUE ~ "Error"
    )
  ) %>%
  mutate(
    answer_desc = factor(
      answer_desc,
      levels = c("Almost every month",
                 "Some months",
                 "1 or 2 months",
                 "Never",
                 "Did not report")
    )
  )

# Keeping the homes at unsafe temperatures======================================
# Pulse Survey Question:
# In the last 12 months, how many months did your household keep your home at a
# temperature that you felt was unsafe or unhealthy?
hse_temp <- sc_pulse %>%
  group_by(date, HSE_TEMP) %>%
  summarize(PWEIGHT = sum(PWEIGHT, na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(HSE_TEMP = as.character(HSE_TEMP)) %>%
  group_by(date) %>%
  mutate(total = sum(PWEIGHT, na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(percent = 100 * (PWEIGHT / total)) %>%
  mutate(
    answer_desc = case_when(
      HSE_TEMP == "-1" ~ "Did not report",
      HSE_TEMP == "1" ~ "Almost every month",
      HSE_TEMP == "2" ~ "Some months",
      HSE_TEMP == "3" ~ "1 or 2 months",
      HSE_TEMP == "4" ~ "Never",
      TRUE ~ "Error"
    )
  ) %>%
  mutate(
    answer_desc = factor(
      answer_desc,
      levels = c("Almost every month",
                 "Some months",
                 "1 or 2 months",
                 "Never",
                 "Did not report")
    )
  )

# Energy insecurity indicator===================================================
# building a measure of energy insecurity based on how they answered the 3 questions

cooccurence <- sc_pulse %>%
  filter(ENRGY_BILL != -1 &
           HSE_TEMP != -1 &
           ENERGY != -1) %>%
  # Summarizing energy insecurity metrics - reducing severity and turning it into a binary figure
  mutate(
    any_unable_bill = ENRGY_BILL %in% c(1, 2, 3),
    any_unsafe_temp = HSE_TEMP %in% c(1, 2, 3),
    any_forgo_needs = ENERGY %in% c(1, 2, 3)
  ) %>%
  mutate(
    all_energy_issues = any_unable_bill & any_unsafe_temp & any_forgo_needs,
    any_energy_issues = any_unable_bill | any_unsafe_temp | any_forgo_needs
  ) %>%
  select(date, any_unable_bill, any_unsafe_temp, any_forgo_needs, all_energy_issues, any_energy_issues, PWEIGHT) %>%
  pivot_longer(c(any_unable_bill, any_unsafe_temp, any_forgo_needs, all_energy_issues, any_energy_issues), names_to = "hardships", values_to = "hardship_felt") %>%
  group_by(date, hardships) %>%
  mutate(total = sum(PWEIGHT, na.rm = TRUE)) %>%
  ungroup() %>%
  group_by(date, hardships) %>%
  summarize(pct = 100 * (sum(hardship_felt * PWEIGHT, na.rm = TRUE) / sum(PWEIGHT))) %>%
  ungroup()

compounding_energy_insecurity <- sc_pulse %>%
  filter(ENRGY_BILL != -1 &
           HSE_TEMP != -1 &
           ENERGY != -1) %>%
  # Summarizing energy insecurity metrics - reducing severity and turning it into a binary figure
  mutate(
    any_unable_bill = ENRGY_BILL %in% c(1, 2, 3),
    any_unsafe_temp = HSE_TEMP %in% c(1, 2, 3),
    any_forgo_needs = ENERGY %in% c(1, 2, 3)
  ) %>%
  mutate(
    num_hardships = any_unable_bill + any_unsafe_temp + any_forgo_needs,
    avg_freq = (ENRGY_BILL + ENERGY + HSE_TEMP) / 3
  )

# Understanding demographic groups' energy insecurity===========================
sc_pulse_groups <- pulse %>%
  filter(EST_ST == 13) %>%
  mutate(
    rent_own = case_when(
      # 1 - Owned by you or someone in your household free and clear
      # 2 - Owned by you or someone in your household with a mortgage loan
      TENURE %in% c(1, 2) ~ "Owners",
      # Rented
      TENURE == 3 ~ "Renters",
      # Occupied without payment of rent
      TENURE == 4 ~ "Other", # occupied without payment of rent
      TENURE %in% c(-88, -99) ~ "Did not report",
      TRUE ~ "error"
    ),
    race = case_when(
      # White Alone
      RRACE == 1 ~ "White alone",
      # 2 - Black alone, 3 - Asian alone, 4 - Any other race alone or race in combination
      RRACE %in% c(2, 3, 4) ~ "BIPOC",
      TRUE ~ "error"
    ),
    children_present = case_when(
      THHLD_NUMKID == 0 ~ "No",
      THHLD_NUMKID > 0 ~ "Yes",
      TRUE ~ "error"
    )
  ) %>%
  mutate(
    HSE_TEMP = case_when(
      HSE_TEMP == -88 | HSE_TEMP == -99 ~ -1,
      TRUE ~ HSE_TEMP
    ),
    ENERGY = case_when(
      ENERGY == -88 | ENERGY == -99 ~ -1,
      TRUE ~ ENERGY
    ),
    ENRGY_BILL = case_when(
      ENRGY_BILL == -88 | ENRGY_BILL == -99 ~ -1,
      TRUE ~ ENRGY_BILL
    )
  ) %>%
  mutate(date = make_date(year = year, month = month, day = 1)) %>%
  # Summarizing energy insecurity metrics - reducing severity and turning it into a binary figure
  mutate(
    any_unable_bill = ENRGY_BILL %in% c(1, 2, 3),
    any_unsafe_temp = HSE_TEMP %in% c(1, 2, 3),
    any_forgo_needs = ENERGY %in% c(1, 2, 3)
  ) %>%
  mutate(
    num_hardships = any_unable_bill + any_unsafe_temp + any_forgo_needs,
    avg_freq = (ENRGY_BILL + ENERGY + HSE_TEMP) / 3
  )


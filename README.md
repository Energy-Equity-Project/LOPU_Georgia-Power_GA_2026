# LOPU — Georgia Power — GA — 2026

> **Lights Out, Profits Up** — Energy Equity Project & Initiative for Energy Justice

## Overview

This report examines the tension between residential energy hardship in Georgia Power's
service territory and the financial performance of its parent company, Southern Company
(NYSE: SO), over 2020–2024. Georgia Power is Georgia's dominant investor-owned utility,
serving roughly 2.7 million residential customers. While the company has raised residential
electricity rates substantially since 2020, it has simultaneously delivered strong revenue
growth, increasing dividends, and multi-million-dollar CEO compensation packages to
Southern Company shareholders.

## Why This Report

Across the country, residential customers are paying substantially more for electricity
than they were five years ago — while investor-owned utilities post record profits and
their CEOs receive tens of millions in annual compensation. This report examines that
tension in Georgia Power's service territory: who is bearing the cost of rising rates,
how severe is the hardship, and how does that compare to what the utility and its
shareholders are taking home.

Low-income households, Black, Hispanic, and Indigenous communities, and residents in
majority-BIPOC census tracts are not affected equally. This report surfaces those
disparities alongside the financial picture.

## Research Questions

- How have residential electricity rates changed in Georgia Power's territory over
  2020–2024, and how do they compare to cooperative and municipal utilities in Georgia?
- How do energy burdens vary across income levels, race, and geography within the
  service territory?
- What share of Georgia households are experiencing energy insecurity — unable to pay
  bills, forgoing necessities, or keeping homes at unsafe temperatures?
- What is the gap between affordability program eligibility and actual enrollment?
- How does residential energy hardship compare to Southern Company's revenue, profits,
  dividends, and executive compensation over the same period?

## Data Sources

See `data/README.md` for report-specific data. Shared data lives in `../../../Data/`
and `../../../Cleaned_Data/`.

| Data | Source | Path |
|------|--------|------|
| Energy insecurity | Household Pulse Survey (cleaned) | `../../../Cleaned_Data/us_census/household_pulse_survey/` |
| Energy burden | DOE LEAD (cleaned) | `../../../Cleaned_Data/doe/lead/` |
| Rate trends | EIA Form 861 (cleaned) | `../../../Cleaned_Data/eia/861/` |
| Disconnections | EJL Dashboard or GA PSC | `data/` |
| IOU financials | SEC EDGAR 10-K | `data/` |
| Executive compensation | SEC DEF 14A (proxy statements) | `data/` |
| Stock performance | Yahoo Finance via tidyquant | `../../../Data/financial_markets/iou_stock/SO/` |

## Running the Analysis

Scripts must be run in order:

```r
source("R/01_setup_and_data_prep.R")
source("R/02_energy_insecurity.R")
source("R/03_affordability_and_burden.R")
source("R/04_rate_trends.R")
source("R/05_disconnections_and_programs.R")
source("R/06_iou_financial_performance.R")
source("R/07_comparative_analysis.R")
```

Results land in `outputs/` (date-prefixed CSVs) and `plots/` (publication-ready PNGs).

**Note:** Scripts 05 and 06 require report-specific data files to be collected first.
See `data/README.md` for the full list of files needed.

## Partners

- **Series partners**: Energy Equity Project (EEP) + Initiative for Energy Justice (IEJ)

## Status

Active — scripts migrated to LOPU template structure (February 2026)

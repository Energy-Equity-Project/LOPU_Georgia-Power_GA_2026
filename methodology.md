# LOPU Series Methodology
# Georgia Power — GA — 2026

*This is a per-report copy of the series-level methodology, expanded with Georgia Power-specific
implementation details. For series-level context, see `lights_out_profits_up/methodology.md`.*

---

## 1. Purpose & Scope

The Lights Out, Profits Up series quantifies — using publicly available, standardized data
sources — the simultaneous trends of worsening residential energy hardship and improving
investor-owned utility (IOU) financial performance within a single service territory.

**This report covers:**

| Field | Value |
|-------|-------|
| Utility | Georgia Power Company |
| Parent company | Southern Company (NYSE: SO) |
| EIA utility ID | 7140 |
| State | Georgia |
| Analysis period | 2020–2024 (stock data extends to 2025) |
| Base year | 2020 |
| Geographic scope | Georgia Power's IOU residential service territory |

**Georgia Power context:** Georgia Power is the state's dominant IOU, serving approximately
2.7 million residential customers. Georgia has significant service territory complexity —
electric cooperatives and municipal utilities serve large portions of the state. All spatial
analyses in this report are filtered to Georgia Power's IOU territory using the GIS crosswalk
described in §5. The `use_territory_filter` flag is set to `TRUE` in `01_setup_and_data_prep.R`.

**Central analytical claim:** The indexed comparison chart (script 07) shows how hardship-side
and financial-side metrics have moved relative to a shared base year (2020). Divergence between
these two sets of trajectories is the core narrative of the report.

The framework measures:
- Energy insecurity, energy burden, and affordability gaps using federal datasets
- Rate trends relative to peer utilities (cooperatives, municipal utilities)
- Disconnection rates and affordability program reach shortfalls
- IOU revenue, profit, executive compensation, and shareholder returns over the same period

---

## 2. Data Sources

### 2.1 DOE LEAD (Low-Income Energy Affordability Data)

| Attribute | Value |
|-----------|-------|
| Publisher | U.S. Department of Energy, Office of Energy Efficiency & Renewable Energy |
| Version used | 2022 (tract-level) |
| Geographic level | Census tract |
| What we extract | `avg_electricity_cost`, `avg_gas_cost`, `avg_other_fuel_cost`, `energy_burden`, `household_count`, `fpl_category`, `tract_geoid` |
| Relative path | `../../../Cleaned_Data/doe/lead/` |
| Coverage | National; all census tracts with residential population |
| Collection status | Collected via shared pipeline |
| Key limitation | 2022 baseline only — does not reflect rate increases after 2022. Projections require additional methodology (see §10.1). |

**Collection instructions:** DOE LEAD data is collected and cleaned by
`eep-pipeline-core/processors/doe-lead_processor.R`. The cleaned file lives at
`Cleaned_Data/doe/lead/ga-census_tract-lead-2022.csv`. If the cleaned file is missing,
re-run the processor script from `eep-pipeline-core/`.

LEAD data is filtered to Georgia Power's service territory using the GIS crosswalk in
script 01 (`lead_territory` object). See §5 for spatial methods.

### 2.2 Household Pulse Survey

| Attribute | Value |
|-----------|-------|
| Publisher | U.S. Census Bureau |
| Geographic level | State (not utility territory) |
| What we extract | Energy insecurity indicators: unable to pay bill (`ENERGY`), unsafe temperature (`TEMPHELP`), foregone necessities (`FORGO`); demographics: `THHLD_NUMPER`, `INCOME`, `RRACE`, `TENURE`, `TCHILDREN`, `SEEING`, `MOBILITY` |
| Relative path | `../../../Cleaned_Data/us_census/household_pulse_survey/` |
| Weight variable | `person_weight` |
| Georgia coverage | 2023–2024 (not 2020–2022; wave dates not mapped — script 02 uses mid-year fallback) |
| Collection status | Collected via shared pipeline |
| Key limitation | State-level precision only. Cannot be disaggregated to utility territory. Question wording changed across survey phases — harmonization applied in pipeline. |

**Collection instructions:** Household Pulse Survey data is collected and cleaned by the
shared pipeline. The cleaned file lives at
`Cleaned_Data/us_census/household_pulse_survey/[date]-pulse-energy-puf-harmonized.csv`.
Script 01 reads the most recent file matching that pattern.

All Pulse Survey estimates are population-weighted using `person_weight`. Percentages represent
the share of adults in households, not the share of households.

### 2.3 EIA Form 861

| Attribute | Value |
|-----------|-------|
| Publisher | U.S. Energy Information Administration |
| Geographic level | Utility (and state) |
| What we extract | Residential revenue (`rev_res`), residential sales in MWh (`sales_res`), residential customer count (`customers_res`) |
| Relative path | `../../../Cleaned_Data/eia/861/` |
| Coverage | All U.S. electric utilities; annual data |
| Data lag | Approximately 1 year (e.g., 2024 data available mid-2025) |
| Collection status | Collected via shared pipeline |
| Key limitation | Revenue and sales reflect total utility billing, not a sample. Rate = revenue / sales. EIA's blended rate does not separately capture tiered pricing, surcharges, or fixed charges (see §10.4 and `methodology_notes.md` §4). |

**Collection instructions:** EIA 861 data is collected and cleaned by
`eep-pipeline-core/processors/eia-861-sales_processor.R`. The cleaned file lives at
`Cleaned_Data/eia/861/[date]-eia-861-sales.csv`. Script 01 reads the most recent file
matching that pattern.

### 2.4 SEC EDGAR — Form 10-K

| Attribute | Value |
|-----------|-------|
| Publisher | U.S. Securities and Exchange Commission |
| CIK (Southern Company) | 0000092122 |
| What we extract | Total revenues, net income, operating income, capital expenditures, total long-term debt, dividends paid per share |
| Path | `data/10k_southern_company_2023-2025.csv` (report-specific; manually extracted) |
| Collection status | Partially collected (2023–2025 filing) |
| Key limitation | Manually extracted from PDF filings — transcription errors are possible. Cross-check each figure against at least one other section of the filing (MD&A or financial statement notes). |

**Collection instructions:** Navigate to SEC EDGAR full-text search, search for CIK
`0000092122`, filter to Form 10-K filings. Extract annual data from the Consolidated
Statements of Income and the Dividends section of the notes. Record in
`data/10k_southern_company_[years].csv` with columns: `year`, `total_revenues_b`,
`net_income_b`, `operating_income_b`, `capex_b`, `long_term_debt_b`, `dividends_per_share`.
See `eep-pipeline-core/collectors/iou_financials_collector.md` for field-level instructions.

### 2.5 SEC EDGAR — DEF 14A (Proxy Statement)

| Attribute | Value |
|-----------|-------|
| Publisher | U.S. Securities and Exchange Commission |
| What we extract | CEO total compensation, other named executive officer (NEO) compensation from the Summary Compensation Table |
| Path | `data/def14a_southern_company_2020-2024.csv` (report-specific; manually extracted) |
| Collection status | Not yet collected |
| Key limitation | Manually extracted. "Total compensation" includes base salary, bonuses, stock awards, option awards, pension value changes, and other compensation — components vary by year and executive. Script 06 skips this section gracefully if the file is absent. |

**Collection instructions:** Navigate to SEC EDGAR, search CIK `0000092122`, filter to
DEF 14A filings. Locate the Summary Compensation Table. Extract CEO and all named executive
officer (NEO) total compensation for each year. Record in
`data/def14a_southern_company_2020-2024.csv` with columns: `year`, `executive_name`,
`title`, `total_compensation`.

### 2.6 Yahoo Finance via tidyquant / local stock CSV

| Attribute | Value |
|-----------|-------|
| Source | Yahoo Finance (collected via `iou_stock_collector.R`) |
| What we extract | Daily closing price, adjusted closing price, dividends per share (quarterly), shares outstanding (annual) |
| Path | `../../../Data/financial_markets/iou_stock/SO/` |
| Collection status | Collected (2020–2025) |
| Key limitation | Yahoo Finance is a secondary source — not the primary disclosure source for dividends or share counts. Use for price and yield approximations. Verify reported dividends against 10-K "dividends paid" line item. |

**Collection instructions:** Run `eep-pipeline-core/collectors/iou_stock_collector.R` with
`ticker = "SO"`. Data lands in `Data/financial_markets/iou_stock/SO/`. Script 01 reads the
most recent stock CSV from that directory.

### 2.7 EJL Disconnection Dashboard

| Attribute | Value |
|-----------|-------|
| Publisher | Energy Justice Lab, Indiana University |
| What we extract | Monthly residential disconnections and reconnections by utility |
| Path | `../../../Cleaned_Data/ejl_disconnection_dashboard/` |
| Coverage | Georgia Power coverage: 2020 (partial) through 2025 (8 months) |
| Collection status | Collected and cleaned |
| Key limitation | Data quality varies by year (see §9 and `methodology_notes.md` §3). EJL's `total_connections` column has a 2024 discontinuity for Georgia Power — EIA 861 customer counts are used as the denominator instead. |

**Collection instructions:** EJL data is cleaned by
`eep-pipeline-core/processors/ejl_disconnection_processor.R`. The cleaned file lives at
`Cleaned_Data/ejl_disconnection_dashboard/[date]-ejl-disconnection-dashboard.csv`. Script 01
filters to Georgia Power (EIA ID 7140) and applies data quality flags.

### 2.8 GIS Service Territories (HFLID ORNL)

| Attribute | Value |
|-----------|-------|
| Publisher | Oak Ridge National Laboratory — Homeland Infrastructure Foundation-Level Data |
| What we extract | Service territory polygon for Georgia Power (filtered by EIA utility ID 7140) |
| Path | `../../../Data/gis/hflid_ornl/electric-retail-service-territories/` |
| Coverage | National; all electric retail service territories |
| Collection status | Collected |
| Key limitation | Boundaries may not perfectly match current service territory; use as an approximation. Verify against most recent EIA Form 861 county service area filing. |

**Collection instructions:** The shapefile is a one-time manual download from the HFLID
ORNL portal. Script 01 reads the shapefile from the path above and filters to Georgia Power
using `OBJECTID` or utility name matching. The `tracts_sf` and `territory_geoids` objects
are produced and passed to downstream scripts.

### 2.9 ACS B19013 — Median Household Income

| Attribute | Value |
|-----------|-------|
| Publisher | U.S. Census Bureau (American Community Survey) |
| Table | B19013_001 — median household income in the past 12 months |
| Geographic level | Census tract |
| Years used | 2022 and 2024 (5-year ACS) |
| Path | `../../../Data/us_census/acs/[year]/tract/` |
| Collection status | Collected via `acs_collector.R` |
| Use case | Income growth factor for energy burden projection (scripts 01, 03, 03d) |

**Collection instructions:** Collected using `eep-pipeline-core/collectors/acs_collector.R`
(via `tidycensus::get_acs()`). Requires `CENSUS_API_KEY` environment variable set in `.Renviron`.
Script 01 reads both years and computes a per-tract income growth factor.

### 2.10 ACS B17017 — Poverty Status by Household Type

| Attribute | Value |
|-----------|-------|
| Publisher | U.S. Census Bureau |
| Table | B17017 — poverty status in the past 12 months by household type |
| Geographic level | Census tract |
| Year used | 2024 (5-year ACS) |
| Path | `../../../Data/us_census/acs/[year]/tract/` |
| Collection status | Collected via `acs_collector.R` |
| Use case | Households below 100% FPL at state and territory level (script 03a) |

### 2.11 ACS B17001B / B17001H — Poverty by Race

| Attribute | Value |
|-----------|-------|
| Publisher | U.S. Census Bureau |
| Tables | B17001B (Black or African American alone), B17001H (White alone, not Hispanic or Latino) |
| Geographic level | Census tract |
| Year used | 2024 (5-year ACS) |
| Path | `../../../Data/us_census/acs/[year]/tract/` |
| Collection status | Collected via `acs_collector.R` |
| Use case | Poverty rate by race for territory-level comparison (script 03b) |

### 2.12 ACS B19001B / B19001H — Income Distribution by Race

| Attribute | Value |
|-----------|-------|
| Publisher | U.S. Census Bureau |
| Tables | B19001B (Black or African American alone), B19001H (White alone, not Hispanic or Latino) |
| Geographic level | Census tract |
| Year used | 2024 (5-year ACS) |
| Path | `../../../Data/us_census/acs/[year]/tract/` |
| Collection status | Collected via `acs_collector.R` |
| Use case | Income distribution by race (16 brackets × 2 groups) for script 03b |

---

## 3. Pipeline Architecture & Integration

### 3.1 Execution Order & Dependencies

Scripts must be run in the following order. Script 01 loads all shared data into the R session;
all downstream scripts depend on the objects it creates.

```
00_visual_styling.R          ← sourced by most scripts; defines theme and colors
01_setup_and_data_prep.R     ← MUST run first; loads all shared data

02_energy_insecurity.R       ─┐
02a_energy_insecurity_demographics.R  ─┤
03_affordability_and_burden.R ─┤  independent of each other;
03a_fpl_poverty_analysis.R   ─┤  all depend on 01
03b_burden_racial_disparities.R ─┤
03d_burden_maps.R            ─┤
04_rate_trends.R             ─┤
05_disconnections_and_programs.R ─┤
06_iou_financial_performance.R ─┤
06a_financial_visualizations.R ─┘

07_comparative_analysis.R    ← MUST run last; reads output CSVs from all scripts above
```

Scripts 02–06a are largely independent of each other but all depend on session objects
produced by script 01. Script 07 reads date-prefixed CSVs from `outputs/` — it does not
use session objects directly.

### 3.2 Session Objects Passed Between Scripts

Script 01 sets the following objects used by downstream scripts:

| Object | Type | Used by |
|--------|------|---------|
| `utility_name` | character | all scripts (labels) |
| `utility_name_short` | character | plots |
| `eia_utility_id` | integer | 04, 05 |
| `ticker` | character | 06 |
| `state_abbrev` | character | 02, 02a |
| `state_fips` | character | 03a, 03b |
| `report_year_range` | integer vector | 02, 04, 05, 06 |
| `base_year` | integer | 06, 07 |
| `today_fmt` | character | all (output file naming) |
| `target_eia_sales` | data frame | 04, 06 |
| `lead_territory` | data frame | 03, 03b, 03d |
| `pulse` | data frame | 02, 02a |
| `ejl_disconn` | data frame | 05 |
| `tracts_sf` | sf object | 03b, 03d |
| `territory_geoids` | character vector | 03a, 03b, 03d |
| `acs_income_growth` | data frame | 03, 03d |
| `elec_rate_multiplier` | numeric | 03, 03d |
| `save_output()` | function | all (writes dated CSVs) |

### 3.3 Script Summary Table

| Script | Purpose | Key inputs | Key outputs |
|--------|---------|-----------|-------------|
| `00_visual_styling.R` | Shared ggplot theme, color palettes | — | `theme_lopu()`, color vectors |
| `01_setup_and_data_prep.R` | Config + data loading | Shared Cleaned_Data/ paths | All session objects above |
| `02_energy_insecurity.R` | Pulse Survey insecurity trends + subgroups | `pulse` | 7 CSVs, 8 PNGs |
| `02a_energy_insecurity_demographics.R` | Demographic disparity bar charts | `pulse` | 1 CSV, 4 PNGs |
| `03_affordability_and_burden.R` | DOE LEAD burden + HEAG (2022 + 2024 projected) | `lead_territory`, `acs_income_growth`, `elec_rate_multiplier` | 8 CSVs, 2 PNGs |
| `03a_fpl_poverty_analysis.R` | ACS B17017 households below 100% FPL | `territory_geoids` | 1 CSV, 1 PNG |
| `03b_burden_racial_disparities.R` | LEAD burden × race; HEAG by race; income dist. by race | `lead_territory`, `territory_geoids` | 6 CSVs, 3 PNGs |
| `03d_burden_maps.R` | Side-by-side tract-level choropleth maps | `lead_territory`, `tracts_sf`, `territory_geoids`, `acs_income_growth`, `elec_rate_multiplier` | 2 CSVs, 1 PNG, 1 SVG |
| `04_rate_trends.R` | EIA 861 rate trends + peer comparison | `target_eia_sales` | 8 CSVs, 2 PNGs |
| `05_disconnections_and_programs.R` | Disconnections + enrollment gap | `ejl_disconn`, `target_eia_sales`, `lead_territory` | 3 CSVs, 2 PNGs |
| `06_iou_financial_performance.R` | Stock, dividends, 10-K financials, exec comp | Stock CSV, `data/10k_*.csv`, `data/def14a_*.csv` | 8–12 CSVs, 4–8 PNGs (data-dependent) |
| `06a_financial_visualizations.R` | Presentation-quality standalone charts | Script 06 output CSVs, stock archive data | 2 PNGs, 1–2 SVGs |
| `07_comparative_analysis.R` | Indexed hardship vs. financial comparison | All `outputs/` CSVs | 4 CSVs, 1 PNG |

### 3.4 Output File Conventions

All CSV and PNG outputs are date-prefixed using the `today_fmt` variable set in script 01
(`format(Sys.Date(), "%d-%m-%Y")`). Files land in:

- `outputs/` — date-prefixed CSVs (e.g., `03-04-2026-lead_burden_by_fpl_projected_2024.csv`)
- `plots/` — publication-ready PNGs and SVGs (e.g., `03-04-2026-lead_burden_map_sidebyside.png`)

Both folders are gitignored. Re-running scripts on a new date produces new-dated files
alongside older ones; the most recent file for each pattern is always used by script 07
and the Rmd briefs.

### 3.5 Graceful Skips for Missing Data

Three sections of the pipeline skip gracefully when required data files are absent:

| Missing file | Script affected | Behavior |
|-------------|----------------|----------|
| `data/10k_*.csv` | `06_iou_financial_performance.R` Section B | Prints message; Section B skipped; Section A runs normally |
| `data/def14a_*.csv` | `06_iou_financial_performance.R` exec comp section | Prints message; exec comp section skipped |
| `data/program_enrollment_*.csv` | `05_disconnections_and_programs.R` | Enrollment gap section skipped |

### 3.6 Narrative Brief Outputs (Rmd files)

Two Rmd files produce standalone `.docx` narrative briefs. These are not part of the main
pipeline execution order — they are rendered on demand after the relevant R scripts have run.

| File | Depends on | Output |
|------|-----------|--------|
| `R/03b_research_brief.Rmd` | `03b_burden_racial_disparities.R` outputs | `outputs/[date]-racial_disparities_brief.docx` |
| `R/03c_projected_burden_brief.Rmd` | `03_affordability_and_burden.R` outputs | `outputs/[date]-projected_burden_brief.docx` |

**To render:** Open the `.Rmd` file in RStudio and click the Knit button, or run:

```r
rmarkdown::render("R/03b_research_brief.Rmd")
rmarkdown::render("R/03c_projected_burden_brief.Rmd")
```

The `knit:` YAML function handles output directory and date-prefixed file naming automatically.
Both briefs require the `flextable` package for Word-compatible tables.

---

## 4. Key Metrics & Calculations

### 4.1 Energy Burden

**Formula:**
```
energy_burden (%) = (annual_energy_expenditure / annual_gross_income) × 100
```

**Affordability threshold:** 6% of gross income (DOE standard).

**Source data:** DOE LEAD `energy_burden` field (pre-calculated at the tract level as a
weighted average across all households in the tract). The 6% threshold is applied in script 03
to identify burdened households and calculate HEAG.

### 4.2 Home Energy Affordability Gap (HEAG)

**Formula (per household):**
```
heag_per_household = annual_energy_expenditure − (annual_gross_income × 0.06)
```
Set to 0 for households with `energy_burden < 6%` (no gap).

**Territory total:**
```
heag_total = sum(heag_per_household × household_count)
```
across all census tracts in the service territory where `energy_burden ≥ 6%`.

**Unit:** Dollars. Reported as per-household annual gap and as a total territory gap.

### 4.3 Household Pulse Survey Weighting

All Pulse Survey estimates are computed as weighted proportions:
```r
pct_unable_to_pay <- sum(person_weight[energy == 1]) / sum(person_weight) × 100
```
Restricted to the target state (`state_abbrev`) and the survey years with available data.

### 4.4 Weighted Average Residential Rate

**Formula:**
```
avg_rate_cents_per_kwh = (total_residential_revenue_$) / (total_residential_sales_MWh × 1000) × 100
```
Computed from EIA Form 861 `rev_res` (thousands of dollars) and `sales_res` (MWh).

**Cumulative rate change:**
```
pct_change = ((rate_final_year − rate_base_year) / rate_base_year) × 100
```

### 4.5 Disconnection Rate

**Formula:**
```
disconnection_rate (%) = (annual_disconnections / residential_customers) × 100
```
`annual_disconnections` = count of residential service terminations for non-payment in
valid months of the calendar year (excludes moratorium and incomplete-reporting months).
`residential_customers` = EIA Form 861 residential customer count for the same year.

No annualization is applied to partial years — observed totals are reported. Partial-year
flags are attached to outputs and marked in plots with open point symbols.

### 4.6 Indexed Metrics (Script 07)

All indexed metrics use a common `base_year` (set in `R/01_setup_and_data_prep.R`, = 2020).

**Formula:**
```
indexed_value_year_Y = (raw_value_year_Y / raw_value_base_year) × 100
```

An index of 100 represents the base-year level. An index of 125 = 25% growth above base.

### 4.7 Profit Margin

```
profit_margin (%) = (net_income / total_revenues) × 100
```
From 10-K data. Computed annually.

### 4.8 Dividend Yield

```
dividend_yield (%) = (annual_dividends_per_share / avg_annual_stock_price) × 100
```
`annual_dividends_per_share` from Yahoo Finance dividend history. `avg_annual_stock_price`
= mean of daily adjusted closing prices for the calendar year.

### 4.9 FPL Tier Assignment (Pulse Survey)

The Pulse Survey reports income in categorical brackets (e.g., "$25,000–$34,999"). Script 02a
assigns each respondent to one of four FPL tiers by:

1. Mapping each income bracket to its midpoint dollar value
2. Looking up the HHS Federal Poverty Level threshold for the respondent's household size
   (using `THHLD_NUMPER` and HHS FPL tables for 2023 and 2024)
3. Computing `income_midpoint / fpl_threshold` as the FPL ratio
4. Assigning to tier: 0–100%, 100–150%, 150–200%, or 200%+ FPL

HHS thresholds are hardcoded in `02a_energy_insecurity_demographics.R` for the relevant years.

### 4.10 Bill Impact Calculation

**Typical customer annual bill:**
```
annual_bill_$ = (total_residential_revenue / residential_customers)
```
Derived directly from EIA 861 data per utility per year. No consumption assumption required.

**Benchmark (1,000 kWh/month) bill:**
```
benchmark_monthly_bill_$ = avg_rate_cents_per_kwh × 1000 / 100 × 12
```
Reported alongside the actual average for comparison with external bill-impact reporting.
See `methodology_notes.md` §4 for reconciliation with Georgia Watch reported figures.

### 4.11 Counterfactual Rate Analysis

**Customer excess vs. muni/coop blended rate:**
```
annual_excess_per_customer_$ = (ga_power_rate − blended_peer_rate) × avg_kwh_per_customer / 100
cumulative_excess_$ = sum(annual_excess_per_customer × residential_customers) across years
```
`blended_peer_rate` = weighted average of cooperative and municipal utility rates in Georgia
(from EIA 861, filtered to GA, ownership type ≠ IOU). Weights = residential kWh sold.

### 4.12 Reconnection Ratio

```
reconnection_ratio = total_valid_reconnections / total_valid_disconnections
```
Computed annually for years with non-zero disconnections. Values near or above 1.0 suggest
most disconnected customers are eventually reconnected in the same year. Computed in script 05.

### 4.13 Dividend Payout Ratio

```
payout_ratio (%) = (dividends_paid / net_income) × 100
```
From 10-K data. Measures what share of profits is distributed to shareholders.
Requires Section B data (`data/10k_*.csv`).

### 4.14 Market Capitalization

```
market_cap_$B = (avg_adjusted_close_price × shares_outstanding_millions) / 1000
```
Uses adjusted close (not unadjusted) because market cap should reflect the current
effective share price post-split. Annual average of daily adjusted closing prices.

### 4.15 Customer vs. Shareholder Comparison

**Cumulative customer excess** (vs. 2020 rates):
```
annual_customer_excess_$B = annual_excess_per_customer × residential_customers / 1e9
cumulative_excess_$B = cumulative sum across 2021–report_year
```

**Dividend-to-excess ratio:**
```
ratio = cumulative_dividend_payouts_$B / cumulative_customer_excess_$B
```
Interpretive framing: for every $1 households paid above 2020 rates, Southern Company paid
$X in dividends. Computed in script 07.

---

## 5. Spatial Methods

### 5.1 Service Territory Crosswalk

The GIS service territory shapefile is used to identify census tracts within Georgia Power's
service territory. Tracts are included if their **centroid falls within the service territory
polygon** (point-in-polygon join using `sf::st_join()`).

This is centroid assignment, not area-weighted areal interpolation. Tracts that straddle the
territory boundary are included if their centroid is inside, excluded if outside. The result
is the `territory_geoids` character vector used to filter LEAD, ACS, and GIS data in all
downstream scripts.

**Georgia Power-specific context:** Georgia has significant multi-utility service area
complexity. The GIS crosswalk (`use_territory_filter = TRUE` in script 01) is essential
here — without it, results would include households served by cooperatives and municipal
utilities, overstating Georgia Power's burden figures.

**Shapefile version:** HFLID ORNL electric retail service territories shapefile (2023 vintage).
Verify the current service territory against the utility's most recent EIA Form 861 county
service area filing before updating to a newer shapefile version.

### 5.2 County-Based Crosswalk (fallback)

When GIS precision is not required or the shapefile is unavailable, census tracts can be
assigned to the utility using county service areas from EIA Form 861. All tracts in counties
where the utility serves the majority of customers are included. This introduces geographic
imprecision at county borders and is not used in this report (GIS crosswalk is preferred).

### 5.3 Choropleth Mapping (script 03d)

Script `03d_burden_maps.R` produces a side-by-side choropleth map comparing estimated 2024
energy burden by census tract for (1) all households and (2) households at 0–150% FPL.

**Aggregation:** LEAD data (projected to 2024) is aggregated to the census tract level as a
weighted mean energy burden (`weighted.mean(est_burden_2024, units)`), weighted by household
count. Two separate aggregations are computed: one across all FPL tiers, one restricted to
the 0–100% and 100–150% FPL tiers.

**Classification scheme:** Seven bins, with the 6% affordability threshold as the green/red
inflection point:

| Bin | Color | Interpretation |
|-----|-------|----------------|
| 0–3% | Dark green `#1B4D3E` | Well under threshold |
| 3–6% | Medium green `#40916C` | Near threshold |
| 6–9% | Amber `#F2994A` | Above threshold |
| 9–12% | Light red `#EB5757` | Significantly above |
| 12–15% | Medium red `#D32F2F` | Severely burdened |
| 15–20% | Dark red `#B71C1C` | Very severely burdened |
| 20%+ | Deep red `#7F0000` | Extreme burden |
| Non-Georgia Power | Light grey `#F5F5F5` | Outside service territory |

Tracts with no LEAD data (or not in service territory) are labeled "Non-Georgia Power."

**Map design:** Georgia state outline is drawn as a grey background layer for geographic
context. The map is cropped to the bounding box of territory tracts (`st_bbox(territory_tracts)`)
to remove excess whitespace from the full state extent. Five major cities are annotated with
dot + label. Savannah's label is pre-shifted west to prevent right-edge clipping.

**Layout:** `patchwork` side-by-side composition; shared legend positioned right;
6.5" × 3" at 350 dpi. CRS is inherited from `tracts_sf` (set by tigris in script 01).

**Design intent:** The low-income panel (right) should show a dramatic "redshift" relative
to the all-households panel (left), visually communicating that energy unaffordability is
concentrated among lower-income households in specific geographic pockets.

---

## 6. Demographic Analysis Methodology

### 6.1 FPL Tier Construction (Pulse Survey, script 02a)

The Household Pulse Survey reports income in categorical brackets (not continuous values).
Script 02a assigns each respondent to an FPL tier as follows:

1. Each income bracket is mapped to a midpoint dollar value (e.g., "$25,000–$34,999" → $30,000)
2. HHS Federal Poverty Level thresholds for the relevant survey years are hardcoded by
   household size (using `THHLD_NUMPER` as the size variable)
3. The respondent's income midpoint is divided by their household-size-specific FPL threshold
   to produce an FPL ratio
4. FPL ratio is mapped to tier:
   - 0–100% FPL: income midpoint < 100% of FPL threshold
   - 100–150% FPL: 100–150%
   - 150–200% FPL: 150–200%
   - 200%+ FPL: above 200%

**Limitation:** Using an income bracket midpoint introduces measurement error, especially
for respondents near a bracket boundary. The 200%+ tier includes all higher-income respondents
without an upper bound.

### 6.2 Racial Disparity Analysis (DOE LEAD, script 03b)

**Method:** Ecological inference — census tracts are classified by aggregate racial composition,
not individual households.

**Classification:** Census tracts are classified as "Majority BIPOC" if non-white, non-Hispanic
residents constitute **50% or more** of occupied housing units (from ACS 5-year estimates).
All other tracts are classified as "Majority white."

**ACS data used:** Race composition is derived from the ACS table used in script 03b
(BIPOC share computed from total units vs. white-NH units). The 50% threshold is applied
per tract.

**Energy burden calculation:** The DOE LEAD `energy_burden` field (and derived projected
burden) is aggregated within each tract type as a weighted mean, weighted by household count.

**Required footnote:** Wherever racial burden statistics appear in the report or its outputs,
the following disclosure must be included:

> *These figures describe households in majority-BIPOC or majority-white census tracts —
> not individual Black, white, or other-race households. Because individuals within a
> majority-BIPOC tract include people of all races, and vice versa, these statistics
> should not be interpreted as direct comparisons between Black and white households.
> Report language should reference "majority-BIPOC census tracts" rather than "Black
> households." See `errata.md` item I1 for recommended footnote text.*

### 6.3 Disability / Ability Facet (Pulse Survey, script 02a)

**Variables used:** `SEEING` (difficulty seeing, even with glasses) and `MOBILITY`
(difficulty walking or climbing stairs).

**Coding:** Both variables use a 4-point scale:
- 1 = No difficulty
- 2 = Some difficulty
- 3 = A lot of difficulty
- -88 / -99 = Missing / NA

**Inclusive threshold:** Respondents reporting "Some difficulty" (2) **or** "A lot of
difficulty" (3) are counted as part of the disability subpopulation. This inclusive
threshold is used because:
- The Census question's "serious difficulty" framing already filters out minor impairment
- Restricting to "A lot of difficulty" would reduce sample sizes and potentially undercount
  people facing accessibility-related energy barriers
- Disability researchers commonly operationalize self-reported difficulty items inclusively

**Alternative (strict threshold):** Restricting to "A lot of difficulty" produces higher
insecurity rates but at lower sample size. This is available as a sensitivity check.

### 6.4 Subgroup Non-Exclusivity

Pulse Survey subgroups (FPL tier, race, tenure, children presence, ability) are computed
**independently** — not jointly controlled. A respondent may appear in multiple subgroup
analyses. This design answers "are people in this subgroup more likely to face hardship?"
not "what share of low-income BIPOC renters with children also have disabilities?"

For the racial subgroup, only Black and white (non-Hispanic) respondents are compared.
Other racial/ethnic groups are excluded from the binary race comparison (but included in
the overall statewide average used as a reference line) due to sample size constraints.

---

## 7. Financial Analysis Methodology

### 7.1 Total Shareholder Return (TSR) Decomposition

Script 06 computes annual TSR as a two-component decomposition: capital gain from
**unadjusted** closing prices plus dividend yield from **raw** dividend payments.

**Capital gain:**
```
capital_gain (%) = (unadjusted_close_Dec31 − unadjusted_close_Jan1) / unadjusted_close_Jan1 × 100
```

**Dividend yield:**
```
dividend_yield (%) = annual_dividends_per_share / unadjusted_close_Jan1 × 100
```

**Annual TSR:**
```
tsr (%) = capital_gain + dividend_yield
```

**Why unadjusted close, not adjusted:** Yahoo Finance's adjusted close retroactively reduces
historical prices to account for dividend payments and stock splits. A capital gain computed
from adjusted prices already includes the dividend component. Adding raw dividend yield on top
**double-counts the dividend** — producing a ~40 percentage point overstatement of cumulative
TSR over 2020–2024 for Southern Company. See `methodology_notes.md` §5 for the full
reconciliation including specific example values.

### 7.2 Cumulative TSR

Cumulative TSR is computed by **geometrically chaining** annual TSR values:

```
cumulative_tsr = ((1 + tsr_yr1/100) × (1 + tsr_yr2/100) × ... × (1 + tsr_yrN/100) − 1) × 100
```

This correctly compounds returns year-over-year. The base year (2020) has a cumulative
TSR of 0%.

### 7.3 10-K Financial Extraction

10-K financials are manually extracted from the Southern Company annual report filed with
SEC EDGAR. Key extraction points:

- **Total revenues:** Consolidated Statements of Income
- **Net income attributable to Southern Company:** Consolidated Statements of Income
- **Operating income:** Consolidated Statements of Income
- **Capital expenditures:** Consolidated Statements of Cash Flows
- **Long-term debt:** Consolidated Balance Sheets
- **Dividends paid per share:** Notes to Financial Statements (Dividend section) or
  the Summary Financial Data table

Southern Company consolidates Georgia Power's results. The 10-K reports Southern Company
as a whole — not Georgia Power alone. The `10k_southern_company_*.csv` file should reflect
Southern Company consolidated figures unless the brief explicitly intends Georgia Power
subsidiary-only financials (available in Georgia Power's separate 10-K filing).

### 7.4 DEF 14A Executive Compensation

The DEF 14A (proxy statement) Summary Compensation Table reports total compensation for
named executive officers (NEOs). "Total compensation" as defined by SEC rules includes:

- Base salary
- Annual bonus / non-equity incentive plan compensation
- Stock awards (grant date fair value)
- Option awards (grant date fair value)
- Change in pension value and nonqualified deferred compensation earnings
- All other compensation (perquisites, 401(k) match, etc.)

The grant-date fair value of stock and option awards is included even if unvested at year-end
and never ultimately paid out. This is the standard SEC-mandated reporting convention — it
reflects the cost to shareholders, not the executive's realized income.

---

## 8. Comparative Analysis & Indexing (Script 07)

### 8.1 Base Year Selection

The base year is 2020, set in `R/01_setup_and_data_prep.R`. This year was chosen because:
- It is the first full year of the report period
- It predates both the COVID-19 disconnection moratorium (which suppressed 2020 disconnection
  figures) and the Plant Vogtle nuclear surcharge acceleration
- It provides a clean pre-intervention baseline for measuring rate, hardship, and financial
  changes over the subsequent period

### 8.2 Indexed Metrics

The following metrics are indexed to base year = 100 in script 07:

**Hardship metrics:**
- Residential rate (cents/kWh, EIA 861)
- Annual disconnection rate (EJL / EIA 861)
- Energy insecurity rate (Pulse Survey; where available)

**Financial metrics:**
- Residential revenue ($, EIA 861)
- Net income ($B, 10-K; if collected)
- CEO total compensation (DEF 14A; if collected)
- Dividends per share ($, Yahoo Finance)
- Total dividend payout ($B, Yahoo Finance × shares outstanding)
- Total shareholder return (cumulative, base = 0 in 2020)
- Market capitalization ($B)

All metrics use the `base_year` object from script 01. For metrics where the base-year value
is 0 (TSR), cumulative values are used rather than an index.

### 8.3 Dual-Panel Visualization

The indexed comparison chart is a dual-panel line chart:
- **Left panel:** Hardship metrics (rates, disconnections, insecurity)
- **Right panel:** Financial metrics (revenue, income, dividends, TSR)

Both panels share the same y-axis scale (indexed to 100). The divergence between the two
panels — hardship rising while financial performance rises faster, or hardship rising while
financial metrics hold steady — is the report's core visual claim.

### 8.4 Summary Table (script 07 output)

`lopu_summary_table.csv` provides the narrative-ready summary with one row per metric:
`category`, `metric`, `base_year_value`, `latest_year_value`, `pct_change`, `note`.
This table is the primary source for headline statistics cited in the report text.

---

## 9. Data Limitations & Caveats

### DOE LEAD baseline

LEAD is a 2022 snapshot. It does not capture rate increases, income changes, or demographic
shifts after 2022. All burden and HEAG figures should be reported as "2022 baseline estimates."
If a forward projection is applied (see §10.1), disclose the methodology and limitations.

### Household Pulse Survey geographic precision

The Pulse Survey cannot be disaggregated below the state level. Energy insecurity percentages
reflect Georgia as a whole, not Georgia Power's service territory specifically. Georgia Power
serves roughly two-thirds of Georgia's residential electricity customers; the state estimate
is a reasonable proxy but should be noted as such.

**Georgia-specific coverage gap:** Cleaned Pulse Survey data for Georgia covers **2023–2024
only** (not 2020–2024). Wave-to-date mapping is not available — script 02 falls back to
mid-year survey dates by `survey_year`. This limits the time-trend analysis for energy
insecurity relative to other pipeline metrics.

### Ecological inference in racial burden analysis

Racial burden disparities in script 03b are based on census tract-level analysis. Census
tracts are classified as "majority-BIPOC" or "majority-white" — energy burden statistics
are then computed for households within those tract types. **This is an ecological measure,
not a household-level survey.** A required footnote disclosure is specified in §6.2 above.

### Manual SEC data extraction

10-K and DEF 14A data are extracted manually from PDF filings. Transcription errors are
possible. Each financial figure should be cross-checked against at least one other section
of the filing before use. DEF 14A data has not yet been collected for this report — the
executive compensation section of script 06 is currently inactive.

### Yahoo Finance stock data

Yahoo Finance is a secondary source — not the primary disclosure source for dividends or
share counts. Use for price and yield approximations. For reported dividends, verify against
the 10-K "dividends paid" line item.

### ACS 5-year estimate overlap

ACS 2022 and 2024 5-year estimates are not fully independent — both include survey years
2020–2021. The income growth factor derived from these estimates captures partial-period
income change and may not accurately represent true 2-year income growth for all tracts.

### EJL disconnection data quality

The following EJL data quality flags are applied in script 01:

| Period | Flag | Treatment |
|--------|------|-----------|
| 2020 Jan–Jun | `moratorium_na` | Excluded from annual rate |
| 2024 Oct–Dec | `incomplete_reporting` | Excluded from annual rate |
| All other months | `valid` | Included in analysis |

2020 is a partial year (6 valid months, July–December). 2024 is a partial year (9 valid
months, January–September). No annualization is applied — observed counts are reported.

### EJL denominator

EIA Form 861 residential customer counts are used as the annual disconnection rate denominator
(not EJL's `total_connections` column). EJL's `total_connections` for Georgia Power has a
2024 discontinuity (values drop from ~2.6M to ~2.4M) that is not reflected in EIA data
and appears to be a reporting artifact.

### EIA rate vs. actual customer bills

EIA 861's average rate metric captures the blended per-kWh rate and does not separately
account for tiered seasonal pricing, fixed charges, surcharges (Plant Vogtle nuclear,
fuel cost recovery), or riders. The +25.1% cumulative rate increase (2020–2024) reflects
the structural trajectory of Georgia Power's pricing. On-the-ground bill impacts — including
all components — are higher than the blended rate suggests. See `methodology_notes.md` §4
for full reconciliation with Georgia Watch reporting.

### Pending data — program enrollment gap

Program enrollment data from GA PSC has not been collected. The enrollment gap section of
script 05 (`program_enrollment_summary.csv`) is inactive for this report.

### Southern Company vs. Georgia Power financials

The 10-K data collected for script 06 reflects **Southern Company consolidated** figures,
not Georgia Power subsidiary-only financials. Southern Company owns multiple utilities
(Georgia Power, Alabama Power, Mississippi Power, etc.). Revenue and net income figures
therefore represent the parent company, not Georgia Power's residential service territory alone.

### Service territory boundaries

The HFLID ORNL service territory shapefile may not reflect recent territory changes due to
utility mergers, divestitures, or boundary adjustments. The 2023 vintage is used for this
report. Verify against the most recent EIA Form 861 county service area filing if replicating
with updated data.

---

## 10. Experimental Methods

### 10.1 Energy Burden Projections

**Status:** Applied in production (script 03 and 03d for this report). Not yet validated
across multiple utilities. Note limitations in any report text citing projected figures.

**Purpose:** Adjust the 2022 DOE LEAD energy burden baseline forward to 2024 to estimate
current burden levels rather than reporting 2022 values as-is.

**Income projection:** Per-tract income growth factor = ACS median household income 2024
/ ACS median household income 2022. Applied as a multiplier to LEAD's average income.
Where ACS data is missing, growth factor defaults to 1 (no change).

**Electricity cost projection:** EIA electricity rate multiplier = Georgia Power 2024 rate
/ Georgia Power 2022 rate (from EIA 861). Applied as a multiplier to LEAD's per-unit
electricity cost.

**Gas and other fuel:** Held at 2022 LEAD baseline. No analogous projection source available.

**Key limitations:**
- Gas costs not projected — held at 2022 levels
- Assumes uniform rate change across all tracts (same statewide multiplier)
- ACS median income differs from LEAD's income definition
- ACS 5-year estimates overlap (not fully independent)
- Linear ratio extrapolation does not account for structural income changes

See `methodology_notes.md` §1 for full formulas and the specific parameter values applied
in this report.

### 10.2 DOE LEAD vs. EIA Cost Discrepancy ("EIA Broadcasting")

**Status:** Documented but not applied in production for this report. Optional calibration
step for reports where absolute cost accuracy is needed.

**Problem:** Naively summing raw DOE LEAD per-unit electricity costs across Georgia Power's
service territory yields approximately 10x less than the residential revenue Georgia Power
reports to EIA 861 (~$450M LEAD-implied vs. ~$4.5B EIA-reported).

**Cause:** DOE LEAD reports average cost per housing unit; EIA counts billing accounts.
Coverage and unit definitions differ.

**Resolution:** Distribute EIA's verified total residential revenue proportionally across
census tracts using LEAD's spatial distribution as allocation weights. This preserves
LEAD's relative spatial pattern while anchoring totals to EIA's verified figures.

**Key assumption:** LEAD's relative spatial distribution of electricity spending is accurate
even though LEAD's absolute totals are not.

**When to apply:** Only when absolute cost accuracy is required for financial comparisons.
For energy burden percentage calculations (cost/income), raw LEAD averages are sufficient.

See `methodology_notes.md` §2 for step-by-step implementation code.

# LOPU Series Methodology

*This is a per-report copy of the series-level methodology, included for self-containment.*
*Canonical source: `lights_out_profits_up/methodology.md`.*
*When spinning up a new report, replace this file with the current version of the canonical.*
*Per-report amendments (e.g., utility-specific data caveats) may be added at the bottom of this file.*

---

## 1. Purpose of the LOPU Analytical Framework

The Lights Out, Profits Up series aims to quantify — using publicly available, standardized
data sources — the simultaneous trends of worsening residential energy hardship and improving
investor-owned utility financial performance within a single service territory.

The framework is designed to:
- Measure energy insecurity, energy burden, and affordability gaps using federal datasets
- Track rate trends relative to peer utilities (cooperatives, municipal utilities)
- Document disconnection rates and affordability program reach shortfalls
- Measure IOU revenue, profit, executive compensation, and shareholder returns over the same period
- Index all metrics to a common base year for direct growth-rate comparison

The central analytical product is the **indexed comparison chart** (script 07): a dual-panel
visualization showing how hardship-side and financial-side metrics have moved relative to a
shared base year. The divergence between these two sets of trends is the core narrative.

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
| Key limitation | 2022 baseline only — does not reflect rate increases after 2022. Energy burden projections require additional methodology (see Section 7). |

LEAD data is filtered to the utility's service territory using either the GIS service territory
crosswalk (preferred when spatial accuracy is important) or a county-based crosswalk derived
from the utility's EIA Form 861 county service area data.

### 2.2 Household Pulse Survey

| Attribute | Value |
|-----------|-------|
| Publisher | U.S. Census Bureau |
| Geographic level | State (not utility territory) |
| What we extract | Energy insecurity indicators: unable to pay bill (`ENERGY`), unsafe temperature (`TEMPHELP`), foregone necessities (`FORGO`) |
| Relative path | `../../../Cleaned_Data/us_census/household_pulse_survey/` |
| Weight variable | `person_weight` |
| Coverage | 2020–present; multiple survey phases with varying question wording |
| Key limitation | State-level precision only. Cannot be disaggregated to utility territory. Question wording changed across phases — see script 02 crosswalk for harmonization. |

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
| Key limitation | Revenue and sales figures reflect total utility billing, not a sample. Rate = revenue / sales. |

### 2.4 SEC EDGAR — Form 10-K

| Attribute | Value |
|-----------|-------|
| Publisher | U.S. Securities and Exchange Commission |
| What we extract | Total revenues, net income, operating income, capital expenditures, total long-term debt, dividends paid per share |
| Path | `data/` (report-specific; manually extracted) |
| Coverage | Publicly traded IOUs; annual |
| Key limitation | Manually extracted from PDF filings — transcription errors are possible. Use the SEC EDGAR CIK lookup to locate the correct parent company filing. Subsidiaries may file separately or be consolidated. |

Collection instructions: `eep-pipeline-core/collectors/iou_financials_collector.md`

### 2.5 SEC EDGAR — DEF 14A (Proxy Statement)

| Attribute | Value |
|-----------|-------|
| Publisher | U.S. Securities and Exchange Commission |
| What we extract | CEO total compensation, other named executive officer (NEO) compensation from the Summary Compensation Table |
| Path | `data/` (report-specific; manually extracted) |
| Coverage | Publicly traded IOUs; annual (filed before annual shareholder meeting) |
| Key limitation | Manually extracted. "Total compensation" includes base salary, bonuses, stock awards, option awards, pension value changes, and other compensation — components vary by year and executive. |

### 2.6 Yahoo Finance via tidyquant

| Attribute | Value |
|-----------|-------|
| Source | Yahoo Finance (accessed via `tidyquant::tq_get()`) |
| What we extract | Daily closing price, adjusted closing price, volume |
| Path | `../../../Data/financial_markets/iou_stock/[TICKER]/` |
| Coverage | All publicly traded tickers; daily |
| Key limitation | Yahoo Finance data is point-in-time. Historical data may have gaps or adjustments. Verify against SEC filings for reported dividends. |

### 2.7 EJL Disconnection Dashboard

| Attribute | Value |
|-----------|-------|
| Publisher | Energy Justice Lab, Indiana University |
| What we extract | Annual residential disconnections by utility |
| Path | `../../../Data/ejl_disconnection_dashboard/` |
| Coverage | Varies by state — not all utilities or states report to EJL |
| Key limitation | Coverage is incomplete. When EJL does not cover the target utility, use state PUC data (stored in `data/`). |

### 2.8 GIS Service Territories (HFLID ORNL)

| Attribute | Value |
|-----------|-------|
| Publisher | Oak Ridge National Laboratory — Homeland Infrastructure Foundation-Level Data |
| What we extract | Service territory polygon for the target utility (filtered by `HFLID` or utility name) |
| Path | `../../../Data/gis/hflid_ornl/electric-retail-service-territories/` |
| Coverage | National; all electric retail service territories |
| Use case | Spatial crosswalk to filter census-tract data (DOE LEAD, ACS) to the utility's territory |
| Key limitation | Boundaries may not perfectly match the utility's actual service territory; use as an approximation. |

---

## 3. Key Metrics & Calculations

### 3.1 Energy Burden

**Formula:**
```
energy_burden (%) = (annual_energy_expenditure / annual_gross_income) × 100
```

**Affordability threshold:** 6% of gross income (DOE standard).

**Source data:** DOE LEAD `energy_burden` field (pre-calculated at the tract level as a
weighted average across all households in the tract). The 6% threshold is applied in script 03
to identify burdened households and calculate HEAG.

### 3.2 Home Energy Affordability Gap (HEAG)

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

### 3.3 Household Pulse Survey Weighting

All Pulse Survey estimates are computed as weighted proportions:
```r
pct_unable_to_pay <- sum(person_weight[energy == 1]) / sum(person_weight) × 100
```
Restricted to the target state and the report's year range. See script 02 for the exact
phase and question variable crosswalk used, as question wording varies across phases.

### 3.4 Weighted Average Residential Rate

**Formula:**
```
avg_rate_cents_per_kwh = (total_residential_revenue_$) / (total_residential_sales_MWh × 1000) × 100
```
Computed from EIA Form 861 `rev_res` (thousands of dollars) and `sales_res` (MWh).

**Cumulative rate change:**
```
pct_change = ((rate_final_year − rate_base_year) / rate_base_year) × 100
```

**Annual bill impact:**
```
bill_impact_$ = avg_residential_consumption_kWh × (rate_final_year − rate_base_year) / 100
```
where `avg_residential_consumption_kWh` is sourced from EIA state-level averages
(EIA Electric Power Monthly or state-specific EIA 861 averages).

### 3.5 Disconnection Rate

**Formula:**
```
disconnection_rate (%) = (annual_disconnections / residential_customers) × 100
```
`annual_disconnections` is the count of residential service terminations for non-payment
in a given calendar year. `residential_customers` is from EIA Form 861 for the same year.

### 3.6 Indexed Metrics (Script 07)

All indexed metrics use a common `base_year` (set in `R/01_setup_and_data_prep.R`).

**Formula:**
```
indexed_value_year_Y = (raw_value_year_Y / raw_value_base_year) × 100
```

An index of 100 represents the base-year level. An index of 125 = 25% growth above the base.

**Hardship metrics indexed:** energy insecurity rate (Pulse), energy burden (LEAD baseline),
disconnection rate.

**Financial metrics indexed:** residential revenue (EIA), net income (10-K), CEO compensation
(DEF 14A), stock price (Yahoo Finance).

The divergence between hardship and financial index trajectories is the central analytical claim.

### 3.7 Profit Margin

```
profit_margin (%) = (net_income / total_revenues) × 100
```
From 10-K data. Computed annually.

### 3.8 Dividend Yield

```
dividend_yield (%) = (annual_dividends_per_share / avg_annual_stock_price) × 100
```
`annual_dividends_per_share` from 10-K or DEF 14A. `avg_annual_stock_price` computed as the
mean of the annual daily adjusted closing prices from tidyquant.

---

## 4. Spatial Methods

### 4.1 Service Territory Crosswalk

When geographic precision is required (e.g., to calculate a territory-specific HEAG rather
than a county-approximate one), the GIS service territory shapefile is used to spatially join
census tracts to the utility's boundaries.

Tracts are included if their centroid falls within the service territory polygon
(point-in-polygon join using `sf::st_join()`). Partial overlaps are handled by centroid
assignment (not area-weighted, which would require areal interpolation).

### 4.2 County-Based Crosswalk (fallback)

When GIS precision is not required or the shapefile is unavailable, census tracts are assigned
to the utility using the utility's county service area from EIA Form 861. All tracts in counties
where the utility serves the majority of customers are included. This introduces geographic
imprecision at county borders.

---

## 5. AI Insight Synthesis

After scripts 01–07 have been run and outputs generated, a structured narrative document can
be produced using the `/lopu-insights` Claude Code slash command.

**How it works:**
1. Open Claude Code inside the report repo directory
2. Run `/lopu-insights`
3. Claude Code reads all output CSVs in `outputs/` and key plots in `plots/`
4. Claude Code reads `templates/insights_template.md` for the required section structure
5. Claude Code writes `outputs/[dd-mm-yyyy]-lopu-narrative-insights.md`

**What the command reads:** The 10 priority CSV outputs listed in the command prompt, plus
the script 07 indexed comparison chart and the script 04 rate trend chart.

**Human review expectations:**
- All statistics cited in the output must be traceable to the source CSVs
- Sections where data is missing are flagged, not fabricated
- The output is a first draft — review all statistics against source files before publication
- Charts referenced in the narrative should be visually inspected against the CSV data

**Advantages over an API-from-R approach:**
- No API key configuration required
- Claude Code reads CSVs and PNGs in the same session (multimodal)
- User can request revisions interactively after the initial draft
- The command travels with the repo — any team member with Claude Code can run it

---

## 6. Data Limitations & Caveats

### DOE LEAD baseline
LEAD is a 2022 snapshot. It does not capture rate increases, income changes, or demographic
shifts after 2022. All burden and HEAG figures should be reported as "2022 baseline estimates."
If a forward projection is applied (see Section 7.1), disclose the methodology and limitations.

### Household Pulse Survey geographic precision
The Pulse Survey cannot be disaggregated below the state level. Energy insecurity percentages
reflect the state as a whole, not the utility's service territory specifically. In states where
the target IOU serves a majority of residential customers, the state estimate is a reasonable
proxy. In states with significant multi-utility service areas, note this limitation.

### Manual SEC data extraction
10-K and DEF 14A data are extracted manually from PDF filings. Transcription errors are possible.
Each financial figure should be cross-checked against at least one other section of the filing
(e.g., the MD&A or the financial statement notes) before use.

### Yahoo Finance stock data
Yahoo Finance data is a secondary source — it is not the primary disclosure source for
dividends or share counts. Use it for price and yield approximations. For reported dividends,
verify against the 10-K "dividends paid" line item.

### EJL disconnection coverage
Not all utilities are covered by the EJL Disconnection Dashboard. Coverage gaps should be
documented in `data/README.md` with the alternative source used.

### Service territory boundaries
The HFLID ORNL service territory shapefile is periodically updated and may not reflect recent
territory changes due to utility mergers, divestitures, or boundary adjustments. Verify the
current service territory against the utility's most recent EIA Form 861 county service area filing.

### Ecological inference in racial burden analysis
Racial burden disparities in this report are based on census tract-level analysis (script 03b).
Census tracts are classified as "majority-BIPOC" or "majority-white" using ACS race/ethnicity data;
energy burden statistics are then computed for households within those tract types.

This is an **ecological measure**, not a household-level survey. The reported percentages describe
the share of households in majority-BIPOC or majority-white *tracts* that face high energy burdens —
not the share of Black, white, or other individual-race households. Because individuals within a
majority-BIPOC tract include people of all races, and vice versa, these figures should not be
interpreted as direct comparisons between Black and white households.

Report language should reference "majority-BIPOC census tracts" and "majority-white census tracts"
rather than "Black households" or "white households." A footnote disclosing the ecological inference
limitation is required wherever these statistics appear. See `errata.md` item I1 for the recommended
footnote text.

---

## 7. Experimental Methods

### 7.1 Energy Burden Projections

**Status:** Experimental — developed in the GA Power report. Not yet validated across
multiple utilities. Apply with caution.

**Purpose:** Adjust the 2022 DOE LEAD energy burden baseline forward to a target year
(e.g., 2025) to estimate current burden levels rather than reporting 2022 values as-is.

**Income projection:** Uses ACS 5-year estimates of tract-level median household income for
two years to compute a per-tract compound annual growth rate (CAGR), then projects forward.

**Electricity cost projection:** Applies the percentage change in the target utility's
residential rate (from EIA 861, between the LEAD baseline year and the target year) as a
multiplier to LEAD's electricity cost. Gas and other fuel costs are held at the 2022 baseline.

**Key limitations:**
- Gas costs are not projected — held at 2022 levels
- Assumes uniform rate change across all tracts
- ACS median income differs from LEAD's income definition
- Linear CAGR extrapolation does not account for structural income changes

See `methodology_notes.md` for the full formulas and implementation code.

### 7.2 DOE LEAD vs. EIA Cost Discrepancy ("EIA Broadcasting")

**Status:** Experimental — developed in the GA Power report.

**Problem:** Naively summing raw DOE LEAD per-unit electricity costs across a utility's
service territory yields approximately 10x less than the residential revenue the utility
reports to EIA Form 861 (example: ~$450M LEAD-implied vs. ~$4.5B EIA-reported for GA Power).

**Cause:** DOE LEAD reports average cost per housing unit; EIA counts billing accounts.
Coverage and unit definitions differ.

**Approach:** Rather than using LEAD's absolute cost figures, distribute EIA's verified total
residential revenue proportionally across census tracts using LEAD's spatial distribution
as the allocation weights. This preserves LEAD's relative spatial pattern while anchoring
totals to EIA's verified figures.

**Key assumption:** LEAD's relative spatial distribution of electricity spending is accurate
even though LEAD's absolute totals are not. If LEAD systematically underrepresents certain
tract types, the calibrated estimates will inherit that bias.

**When to apply:** Only when absolute cost accuracy is needed for the report's financial
comparisons (e.g., total territory-level expenditure). For energy burden percentage
calculations (cost / income), raw LEAD averages are usually sufficient.

See `methodology_notes.md` for the full step-by-step implementation.

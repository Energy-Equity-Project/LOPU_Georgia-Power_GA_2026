# LOPU Methodology Notes

Methodological approaches developed during the GA Power (LOPU-Georgia-Power_GA_2026) report.
Section 1 is now applied in production (script 03). Section 2 remains experimental.

Source files in GA Power archive:
- `Archive/energy_affordability/energy_burden_projections.R`
- `Archive/energy_affordability/energy_projections_v2.R`

---

## 1. Energy Burden Projections

**Purpose:** Project the 2022 DOE LEAD baseline energy burden forward to a target year
(e.g., 2025) to estimate current burden levels rather than reporting 2022 values as-is.

### Income projection

Uses ACS 5-year estimates of tract-level median household income (variable B19013_001)
for two years: the LEAD baseline year (2022) and the most recent available ACS year.

Per-tract compound annual growth rate (CAGR):

```r
# Example: 2022 baseline, 2024 most-recent ACS → 2-year CAGR
annual_growth_rate <- sqrt(income_2024 / income_2022)
```

Project forward to target year:

```r
est_income_target <- lead_income * (annual_growth_rate ^ years_forward)
# e.g., for 2025 (3 years from 2022): lead_income * (annual_growth_rate ^ 3)
```

Fallback: where ACS data is missing (NA), use the original LEAD income unchanged.

```r
est_income_target <- case_when(
  is.na(est_income_target) ~ lead_income,
  TRUE                     ~ est_income_target
)
```

### Electricity cost projection

Compute the percent change in the target utility's residential rate between the LEAD
baseline year and the target year using EIA 861 data. Apply as a multiplier to the LEAD
per-unit electricity cost:

```r
rate_multiplier    <- 1 + (eia_rate_pct_change / 100)
est_elec_cost_target <- lead_avg_electricity_cost * rate_multiplier
```

Gas and other fuel costs are left at the LEAD 2022 baseline — no analogous projection
source is available for those fuels.

### Projected HEAG

Recalculate the Home Energy Affordability Gap using projected income and projected
electricity cost (gas/fuel at baseline), applying the same 6% threshold:

```r
total_energy_cost_projected <- est_elec_cost_target + avg_gas_cost + avg_other_fuel_cost
affordable_cost_projected   <- est_income_target * 0.06
heag_projected              <- total_energy_cost_projected - affordable_cost_projected
```

### Parameters applied in GA Power 2026 report

| Parameter | Value |
|-----------|-------|
| Electricity rate multiplier (rate_2024 / rate_2022) | 1.0205 (15.18 → 15.49 cents/kWh) |
| Gas/other fuel costs | Held at 2022 LEAD baseline |
| ACS income variable | B19013_001 (median household income) |
| ACS years compared | 2022 and 2024 (5-year ACS) |
| Tracts with valid ACS data | 2796 GA tracts; fallback (growth_factor=1) applied where income_2022 ≤ 0 or NA |
| Target projection year | 2024 (same as ACS comparison year — simple ratio, no CAGR exponentiation) |

**Key finding:** From 2022 to 2024, Georgia Power's residential electricity rate rose ~2%,
while median household incomes rose ~7.9% at the state median — meaning the 2024 projected
burden is *lower* than the 2022 LEAD baseline. This reflects the specific 2022–2024 sub-period,
not the full 2020–2024 trend. The large cumulative rate increase (+25.1%) occurred primarily
earlier in the report period.

### Limitations

- No gas or other fuel price projection — those costs are held at 2022 levels.
- Assumes a uniform rate change across all tracts in the service territory.
- ACS median household income differs from LEAD's income definition and is not an
  exact substitute.
- The 2020-2024 ACS 5-year estimates overlap substantially — income_2024 is not fully
  independent of income_2022.
- **Status:** applied in script 03 for GA Power 2026 report. Not yet validated across
  multiple utilities. Note the limitations in any report text.

---

## 2. DOE LEAD vs EIA Cost Discrepancy and EIA Broadcasting

### The problem

Naively summing raw DOE LEAD per-unit electricity costs across a utility's service
territory yields approximately **10x less** than the residential revenue the utility
reports to EIA Form 861.

Example from GA Power (2024):
- LEAD-implied total residential electricity expenditure: ~$450 million
- EIA 861 reported residential revenue: ~$4.5 billion
- LEAD-implied unit count: ~1.78 million housing units
- EIA 861 reported customer count: ~2.45 million billing accounts

### Why the discrepancy exists

DOE LEAD reports the **average cost per housing unit** (total electricity expenditure
divided by number of housing units with electricity). EIA counts **billing accounts**
(customers). LEAD's housing unit definition and geographic coverage differ from EIA's
customer-based accounting, so absolute totals are not directly comparable.

### EIA broadcasting resolution

Rather than using LEAD's absolute cost figures, distribute EIA's verified total
residential revenue proportionally across census tracts using LEAD's spatial distribution
as the allocation weights.

Step-by-step:

1. Compute each tract's share of total LEAD electricity expenditure and of total
   LEAD unit count within the utility territory:

```r
lead_territory <- lead_territory %>%
  mutate(
    prop_elep_expenditure = elep_units  / sum(elep_units,  na.rm = TRUE),
    prop_elep_units       = elep_units_1 / sum(elep_units_1, na.rm = TRUE)
  )
```

   *(In raw LEAD: `elep_units` = total electricity expenditure for the tract;
   `elep_units_1` = number of housing units with electricity.)*

2. Distribute EIA's verified totals proportionally:

```r
lead_territory <- lead_territory %>%
  mutate(
    eia_est_expenditure = prop_elep_expenditure * eia_total_revenue,
    eia_est_units       = prop_elep_units       * eia_total_customers
  )
```

3. Derive the calibrated per-unit cost:

```r
lead_territory <- lead_territory %>%
  mutate(eia_calibrated_elec_cost = eia_est_expenditure / eia_est_units)
```

The resulting `eia_calibrated_elec_cost` is anchored to EIA's verified totals while
preserving LEAD's spatial distribution pattern.

### Key assumption

This approach assumes LEAD's **relative** spatial distribution of electricity spending
is accurate even though LEAD's **absolute** totals are not. If LEAD systematically
underrepresents certain tract types (e.g., high-income tracts), the calibrated estimates
will inherit that bias.

### Status

Experimental approach from GA Power analysis. Consider as an optional calibration step
in script 03 if absolute cost accuracy is important for the report's financial
comparisons. For burden percentage calculations (energy cost / income), the raw LEAD
averages are usually sufficient.

---

## 3. Disconnection Data — EJL Disconnection Dashboard

### Source

EJL Disconnection Dashboard (Energy Justice Lab, Indiana University), cleaned by
`eep-pipeline-core/processors/ejl_disconnection_processor.R`. Loaded in script 01
from `Cleaned_Data/ejl_disconnection_dashboard/`.

### Coverage for Georgia Power

| Year | Months in EJL | Valid Disconnection Months | Notes |
|------|--------------|--------------------------|-------|
| 2020 | Apr–Dec (9) | Jul–Dec (6) | Apr–Jun have NA disconnections (COVID moratorium) |
| 2021 | Jan–Dec (12) | 12 | Full year |
| 2022 | Jan–Dec (12) | 12 | Full year |
| 2023 | Jan–Dec (12) | 12 | Full year |
| 2024 | Jan–Dec (12) | 9 | Oct–Dec have near-zero values (incomplete reporting) |
| 2025 | Jan–Aug (8) | 8 | Outside report_year_range; used as supplemental only |

### Data quality flags

Three quality flags are applied in script 01 to each monthly row:

- `"moratorium_na"` — rows where `total_disconnections` is NA (2020 Jan–Jun); rows
  excluded from annual rate calculation
- `"incomplete_reporting"` — 2024 rows where disconnections < 200 (Oct–Dec); excluded
  from annual rate calculation
- `"valid"` — all other rows; included in analysis

### Annual rate calculation

Annual disconnection rate = sum of valid-month disconnections / EIA 861 residential
customers for that year. No annualization applied — raw observed totals are reported.
Partial-year flags (`partial_year = TRUE`) are attached to 2020 and 2024 in the output
CSV and used in plots to distinguish filled (full year) from open (partial year) points.

### Denominator

EIA Form 861 residential customer counts are used as the denominator (not EJL's
`total_connections` column). Reason: EJL's `total_connections` has a discontinuity in
2024 for Georgia Power (values drop from ~2.6M to ~2.4M) that is not reflected in
EIA data and appears to be a reporting artifact. EIA 861 is the authoritative source
for residential customer counts.

### Reconnection ratio

Annual reconnection ratio = total valid-month reconnections / total valid-month
disconnections. Values near or above 1.0 suggest most disconnected customers are
eventually reconnected. Computed in script 05 for years with non-zero disconnections.

---

## 4. EIA Average Rate vs. Actual Customer Bills

### Context

A Georgia Watch article (Drew Kann/AJC, Aug 13, 2025) reports that a Georgia Power
customer using 1,000 kWh per month now pays $43 more than in 2022, with average monthly
bills at $171 and summer bills averaging $266. Our EIA 861 analysis shows only a +2.0%
rate increase over 2022–2024 (15.18 → 15.49 cents/kWh). This section explains why the
two figures differ and why both are valid.

**Source:** "Feel like your Georgia Power bill is high this summer? Here's why?"
Georgia Watch, Aug 13, 2025.
https://georgiawatch.org/feel-like-your-georgia-power-bill-is-high-this-summer-heres-why/

### What EIA 861's average rate captures

EIA Form 861 reports total residential revenue and total residential sales (kWh) per
utility per year. The "average rate" is simply:

```
avg_rate = total_residential_revenue / total_residential_kwh_sold
```

This is a **blended annual average** that flattens all seasonal, tiered, and time-of-use
pricing into a single number. It does not separately account for:

- **Tiered seasonal pricing** — Georgia Power charges different rates in peak (Jun–Sep)
  vs. off-peak (Oct–May) months, and uses inclining block tiers during peak months
- **Fuel cost recovery** — pass-through charges for fuel and purchased power costs
- **Plant Vogtle nuclear construction surcharge** — Georgia Power's share of the
  way-over-budget Plant Vogtle Units 3 & 4 nuclear expansion
- **Environmental compliance cost recovery rider**
- **Demand-side management rider**
- **Fixed customer charge** (monthly base charge regardless of usage)

All of these appear on a customer's actual bill but are aggregated into a single revenue
figure in EIA 861.

### Georgia Power's current rate structure (as of 2025)

From the Georgia Watch article:

| Season | Tier | Rate |
|--------|------|------|
| Off-peak (Oct–May) | All usage | 8.1 ¢/kWh |
| Peak (Jun–Sep) | First 650 kWh | 8.6 ¢/kWh |
| Peak (Jun–Sep) | 651–1,000 kWh | 14.3 ¢/kWh |
| Peak (Jun–Sep) | Above 1,000 kWh | 14.8 ¢/kWh |

A customer using 1,000 kWh in a summer month pays an effective rate significantly higher
than EIA's blended annual average. The inclining block structure means higher-usage
customers are hit disproportionately harder during peak months.

### Reconciling the numbers

| Metric | EIA 861 (Our Analysis) | Georgia Watch Article |
|--------|----------------------|----------------------|
| Time period | 2020–2024 | 2022–2025 |
| Rate metric | Blended avg (¢/kWh) | Actual monthly bill ($) |
| Usage basis | Actual avg (~990 kWh/mo) | 1,000 kWh/mo benchmark |
| 2022→2024 rate change | +2.0% | — |
| 2020→2024 rate change | +25.1% | — |
| Monthly bill (2024) | ~$153 (EIA avg customer) | $171 (as of 2025) |
| Monthly increase since 2022 | +$3.11 (at EIA blended rate) | +$43 |

The ~$40/month gap between EIA's implied increase ($3.11) and the reported increase ($43)
reflects:

1. **Tiered pricing not captured by EIA's blended rate** — the EIA average flattens
   peak-season inclining block rates into a single annual figure
2. **January 2025 rate increase** — EIA 861 data for 2025 is not yet available (filed
   ~Oct 2026); three consecutive January increases (2023, 2024, 2025) are reflected in
   the article but our data only captures through 2024
3. **Riders and surcharges** — Plant Vogtle nuclear surcharge, fuel cost recovery, and
   other riders appear on bills but are bundled into EIA's revenue numerator without
   separate itemization
4. **Fixed charges** — monthly base charges that affect dollar-denominated bills but
   are absorbed into EIA's per-kWh average

### Why both numbers are valid

The EIA 861 rate trend captures the **structural trajectory** of Georgia Power's pricing
over a 5-year period. The +25.1% cumulative increase (2020–2024) — far outpacing
cooperatives (+9.9%) and municipal utilities (+10.7%) — demonstrates the acceleration in
rate growth and the disproportionate burden on IOU customers.

The Georgia Watch reporting captures the **on-the-ground bill impact** including all
components that households actually pay. The $43/month increase and $171 average bill
reflect what customers experience — which is, if anything, worse than what per-kWh rate
statistics alone suggest.

### Recommended narrative framing

> Georgia Power's average residential electricity rate rose 25.1% between 2020 and
> 2024 — from 12.39 to 15.49 cents per kilowatt-hour — outpacing cooperatives (+9.9%)
> and municipal utilities (+10.7%) in the same state. But EIA Form 861's blended rate
> metric captures only part of the cost burden households actually face. Georgia Power's
> tiered seasonal pricing, Plant Vogtle nuclear construction surcharges, fuel cost
> adjustments, and fixed charges all add to the bottom line. When these components are
> included, the impact is even steeper: a Georgia Power customer using 1,000 kWh per
> month now pays $43 more than in 2022, with average monthly bills reaching $171 — and
> summer bills averaging $266 (Georgia Watch, 2025).

### Output files

- `eia_benchmark_1000kwh.csv` — EIA blended rate applied to a 1,000 kWh/month benchmark
  customer, with change-from-2022 column for direct comparison
- `eia_vs_reported_bill_comparison.csv` — side-by-side summary of EIA analysis vs.
  Georgia Watch reported figures

---

## 5. Total Shareholder Return — Unadjusted Close Methodology

### Context

Script 06 (Section A) computes total shareholder return (TSR) for Southern Company
using a **two-component decomposition**: capital gain from unadjusted close prices +
dividend yield from raw dividend payments. This replaces the Archive approach
(`Archive/southern_co_financials.R`, `Archive/company_financials.R`) which used
Yahoo Finance's **adjusted close** prices for the capital gain component.

### Why adjusted close overstates TSR when combined with raw dividends

Yahoo Finance's adjusted close retroactively reduces historical prices to account for
dividend payments and stock splits. When you compute a return from adjusted close
prices, that return already includes the value of all dividends paid during the period.
Adding raw dividend yield on top **double-counts the dividend component**.

Example for SO in 2020:
- Unadjusted close: $62.62 (Jan 2) → $61.43 (Dec 31) = **−1.9% capital gain**
- Adjusted close: $49.67 (Jan 2) → $50.84 (Dec 31) = **+2.4% capital gain**
- Raw annual dividend: $2.54 / $62.62 start price = **+4.1% dividend yield**

Archive approach: +2.4% + 4.1% = **+6.5% TSR** (overstated — dividend counted twice)
Script 06 approach: −1.9% + 4.1% = **+2.2% TSR** (clean decomposition)

### Cumulative impact

Over 2020–2024, the methodological difference compounds significantly:

| Approach | Cumulative TSR (2020–2024) |
|----------|----------------------------|
| Archive (adjusted + raw dividends) | +102.5% |
| Script 06 (unadjusted + raw dividends) | +62.5% |

The Archive figure is ~40 percentage points higher than the correct decomposition.

### When each approach is valid

- **Adjusted close alone** (no separate dividend component): valid for computing total
  return when you don't need to decompose into capital gain vs. dividend yield
- **Unadjusted close + raw dividends** (script 06 approach): valid for TSR decomposition
  — produces a clean stacked bar chart where components don't overlap
- **Adjusted close + raw dividends** (Archive approach): **never valid** — double-counts

### Design decision

Script 06 uses unadjusted close for capital gain and start-of-year unadjusted price as
the denominator for dividend yield (standard TSR convention). This allows the stacked
bar visualization to clearly show how much of a shareholder's return came from price
appreciation vs. dividend income.

Market cap and dividend yield (in `iou_stock_annual_summary.csv`) still use the
**adjusted** price. Adjusted close is appropriate there because market cap should reflect
the current effective share price (post-split), and the annual dividend yield denominator
convention varies — we use the adjusted average for consistency with market cap.

### S&P 500 benchmark comparison (not yet implemented)

`Archive/company_financials.R` includes a cumulative return comparison of SO vs. the
S&P 500 index. This is a useful contextual metric (did SO outperform or underperform
the broad market?) but requires locally collected S&P 500 data. When S&P 500 data is
available at `Data/financial_markets/iou_stock/GSPC/`, a benchmark comparison could be
added to script 06 Section A as step A13.

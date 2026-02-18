# LOPU Methodology Notes

Experimental approaches developed during the GA Power (LOPU-Georgia-Power_GA_2026) report.
Neither is production-ready enough to add as executable code to the template scripts yet,
but both are documented here so future report authors can understand and optionally apply them.

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

### Limitations

- No gas or other fuel price projection — those costs are held at 2022 levels.
- Assumes a uniform rate change across all tracts in the service territory.
- ACS median household income differs from LEAD's income definition and is not an
  exact substitute.
- Projection is a simple linear extrapolation of the historical CAGR — it does not
  account for structural changes in income distribution.
- **Status:** developed in GA Power analysis; not yet validated across multiple
  utilities. Apply with caution and note the limitations in any report text.

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

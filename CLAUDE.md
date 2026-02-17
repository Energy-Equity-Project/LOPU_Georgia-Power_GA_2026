# LOPU — Georgia Power — GA — 2026

## Purpose

First report in the Lights Out, Profits Up series. Examines the tension between
residential energy hardship in Georgia Power's service territory and the financial
performance of its parent company, Southern Company (NYSE: SO). Covers rate trends,
energy burden, energy insecurity, and disconnections — juxtaposed against revenue,
profits, dividends, and executive compensation (2020–2024).

## Type

External — Research/Analysis

## Status

Active (migrated to LOPU template structure February 2026)

---

## Georgia Power-Specific Notes

- **EIA utility ID**: 7140 (Georgia Power Company)
- **Parent company**: Southern Company (ticker: SO, CIK: 0000092122)
- **State FIPS**: 13
- **Year range**: 2020–2024 (base year: 2020)
- **Spatial crosswalk required**: Georgia has many electric cooperatives and
  municipal utilities. DOE LEAD and rate analysis must be filtered to GA Power's
  IOU service territory using the GIS shapefile crosswalk in script 01.
- **DOE LEAD note**: Original analysis found a ~10x discrepancy between LEAD
  costs and EIA rates, resolved by recognizing LEAD reports per-unit averages
  (not per-account). See `Archive/energy_affordability/energy_burdens.R` for
  the original approach.
- **Data reads from Cleaned_Data**: Unlike the `_LOPU_template`, this report
  reads from `Cleaned_Data/` for EIA 861, DOE LEAD, and Pulse Survey. The
  template should be updated separately to match this pattern.

---

## Script Map

| Script | Purpose | Key inputs | Key outputs |
|--------|---------|-----------|-------------|
| `R/01_setup_and_data_prep.R` | Config + data loading | Cleaned_Data/ paths | Named objects in session |
| `R/02_energy_insecurity.R` | Pulse Survey insecurity analysis | `pulse` from 01 | `outputs/`, `plots/` |
| `R/03_affordability_and_burden.R` | DOE LEAD energy burden + HEAG | `lead_territory` from 01 | `outputs/`, `plots/` |
| `R/04_rate_trends.R` | EIA 861 rate trends | `target_eia_sales` from 01 | `outputs/`, `plots/` |
| `R/05_disconnections_and_programs.R` | Disconnections + enrollment gap | `data/disconnections_*` | `outputs/`, `plots/` |
| `R/06_iou_financial_performance.R` | Revenue, profit, dividends, CEO comp | `data/10k_*`, `data/def14a_*` | `outputs/`, `plots/` |
| `R/07_comparative_analysis.R` | Hardship vs. financial performance | All `outputs/` CSVs | `outputs/`, `plots/` |

For methodology reference, see `Archive/` which preserves the original topic-based
scripts used before the template migration.

---

## Data Dependencies

All shared data is referenced via relative paths from the repo root (3 levels deep
from workspace root):

| Data | Relative Path | Notes |
|------|--------------|-------|
| EIA Form 861 (cleaned) | `../../../Cleaned_Data/eia/861/` | `[date]-eia-861-sales.csv` |
| DOE LEAD (cleaned) | `../../../Cleaned_Data/doe/lead/` | `ga-census_tract-lead-2022.csv` |
| Household Pulse Survey (cleaned) | `../../../Cleaned_Data/us_census/household_pulse_survey/` | `[date]-pulse-energy-puf-harmonized.csv` |
| GIS Service Territories | `../../../Data/gis/hflid_ornl/electric-retail-service-territories/` | For spatial crosswalk |
| SEC EDGAR | `../../../Data/sec/edgar/0000092122/` | Manual collection |
| IOU Stock Data | `../../../Data/financial_markets/iou_stock/SO/` | Via tidyquant/Yahoo Finance |
| EJL Disconnection Dashboard | `../../../Data/ejl_disconnection_dashboard/` | Preferred disconnections source |

## Report-Specific Data (in `data/`)

| File | Source | Status |
|------|--------|--------|
| `10k_southern_company_2020-2024.csv` | SEC EDGAR 10-K | To collect |
| `def14a_southern_company_2020-2024.csv` | SEC EDGAR DEF 14A | To collect |
| `disconnections_georgia_power_2020-2024.csv` | GA PSC or EJL Dashboard | To collect |
| `program_enrollment_georgia_power.csv` | GA PSC filing | To collect |

## Outputs

- `outputs/` — date-prefixed CSVs of analysis results (gitignored)
- `plots/` — publication-ready charts (PNG, 350 dpi, 7.5" × 5") (gitignored)
- `Archive/` — original pre-migration scripts and data for methodology reference

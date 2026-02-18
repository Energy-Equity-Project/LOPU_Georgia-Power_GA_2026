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

## Report Configuration

| Field | Value |
|-------|-------|
| `utility_name` | Georgia Power |
| `parent_company` | Southern Company |
| `eia_utility_id` | 7140 |
| `ticker` | SO |
| `cik` | 0000092122 |
| `state_abbrev` | GA |
| `state_name` | Georgia |
| `state_fips` | 13 |
| `report_year_range` | 2020:2024 |
| `base_year` | 2020 |

---

## Data Collection Status

*Update this table as data files are collected. Check off each item before running scripts.*
*Files in `data/` are report-specific; all other paths are shared.*

| Dataset | File | Status | Source | Date Collected |
|---------|------|--------|--------|----------------|
| 10-K financials | `data/10k_southern_company_2020-2024.csv` | ⬜ Pending | SEC EDGAR | — |
| DEF 14A exec comp | `data/def14a_southern_company_2020-2024.csv` | ⬜ Pending | SEC EDGAR | — |
| Disconnections | `data/disconnections_georgia_power_2020-2024.csv` | ⬜ Pending | GA PSC or EJL Dashboard | — |
| Program enrollment | `data/program_enrollment_georgia_power.csv` | ⬜ Pending | GA PSC filing | — |
| Stock data | `../../../Data/financial_markets/iou_stock/SO/` | ⬜ Pending | `iou_stock_collector.R` | — |
| EIA 861 (cleaned) | `../../../Cleaned_Data/eia/861/` | ⬜ Verify | Shared pipeline | — |
| DOE LEAD (cleaned) | `../../../Cleaned_Data/doe/lead/` | ⬜ Verify | Shared pipeline | — |
| Household Pulse | `../../../Cleaned_Data/us_census/household_pulse_survey/` | ⬜ Verify | Shared pipeline | — |

---

## Pipeline Run Status

*Update this table after each script run. Record the date and note the key output file.*

| Script | Status | Last Run | Key Outputs |
|--------|--------|----------|-------------|
| `01_setup_and_data_prep.R` | ⬜ Not run | — | Session objects |
| `02_energy_insecurity.R` | ⬜ Not run | — | `*-pulse-summary-statistics.csv` |
| `03_affordability_and_burden.R` | ⬜ Not run | — | `*-lead-heag-total.csv`, `*-lead-burden-by-fpl.csv` |
| `04_rate_trends.R` | ⬜ Not run | — | `*-eia-target-utility-rate-trend.csv` |
| `05_disconnections_and_programs.R` | ⬜ Not run | — | `*-disconnection-rate-annual.csv` |
| `06_iou_financial_performance.R` | ⬜ Not run | — | `*-iou-financials-annual.csv`, `*-iou-ceo-compensation-trend.csv` |
| `07_comparative_analysis.R` | ⬜ Not run | — | `*-lopu-summary-table.csv`, `*-lopu-ratio-summary.csv` |
| `/lopu-insights` (slash command) | ⬜ Not run | — | `*-lopu-narrative-insights.md` |

---

## Key Outputs

*After running scripts, populate this table with the actual output file paths and headline stats.*

| Output | File | Headline Stat |
|--------|------|---------------|
| Summary table (indexed) | — | — |
| Energy insecurity rate | — | — |
| HEAG total | — | — |
| Cumulative rate change | — | — |
| Disconnection rate (latest) | — | — |
| Net income change | — | — |
| CEO comp change | — | — |
| Narrative insights | — | — |

---

## Pipeline Overview

The LOPU pipeline has 8 steps. Scripts 01–07 are R scripts run in order. Step 08 is a
Claude Code slash command run after the R scripts complete.

| Step | Script / Command | Purpose |
|------|-----------------|---------|
| 00 | `00_visual_styling.R` | Shared ggplot2 theme (sourced by other scripts) |
| 01 | `01_setup_and_data_prep.R` | Config + shared data loading |
| 02 | `02_energy_insecurity.R` | Pulse Survey energy insecurity analysis |
| 03 | `03_affordability_and_burden.R` | DOE LEAD energy burden + HEAG |
| 04 | `04_rate_trends.R` | EIA 861 rate trends + peer comparison |
| 05 | `05_disconnections_and_programs.R` | Disconnections + affordability program gap |
| 06 | `06_iou_financial_performance.R` | Revenue, profit, exec comp, stock |
| 07 | `07_comparative_analysis.R` | Indexed hardship vs. financial comparison |
| 08 | `/lopu-insights` | AI-generated narrative insights Markdown |

Script 01 must run first (loads shared data into session). Scripts 02–06 are largely independent
of each other but all depend on 01. Script 07 depends on outputs from 02–06. The `/lopu-insights`
slash command depends on all outputs from 01–07.

---

## Georgia Power-Specific Notes

- **Spatial crosswalk required**: Georgia has many electric cooperatives and
  municipal utilities. DOE LEAD and rate analysis must be filtered to GA Power's
  IOU service territory using the GIS shapefile crosswalk in script 01
  (`use_territory_filter <- TRUE`).
- **DOE LEAD note**: Original analysis found a ~10x discrepancy between LEAD
  costs and EIA rates, resolved by recognizing LEAD reports per-unit averages
  (not per-account). See `Archive/energy_affordability/energy_burdens.R` for
  the original approach, and `methodology_notes.md` for the full documentation.
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

## Key Files

- `R/01_setup_and_data_prep.R` — single customization point; source all config and data loading here
- `R/07_comparative_analysis.R` — the headline output; must run last
- `.claude/commands/lopu-insights.md` — slash command for AI narrative synthesis (run after scripts 01–07)
- `templates/insights_template.md` — required structure for the narrative output
- `glossary.md` — per-report copy of key term definitions
- `methodology.md` — per-report copy of the formal methods document

## Outputs

- `outputs/` — date-prefixed CSVs of analysis results + AI narrative Markdown (gitignored)
- `plots/` — publication-ready charts (PNG, 350 dpi, 7.5" × 5") (gitignored)
- `Archive/` — original pre-migration scripts and data for methodology reference

## Reference Documents

- `glossary.md` — definitions of all key terms (per-report copy; canonical at series level)
- `methodology.md` — formal data sources, metrics, and calculations (per-report copy; canonical at series level)
- `methodology_notes.md` — experimental methodologies (energy burden projections, EIA broadcasting) developed in this report

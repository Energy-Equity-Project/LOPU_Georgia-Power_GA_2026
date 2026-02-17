# Report-Specific Data

This folder contains data files specific to this report that cannot be stored in the
shared `Data/` directory — either because they require manual extraction from regulatory
filings or because they are report-specific inputs not yet worth promoting to a shared
pipeline.

**All shared data** (EIA 861, DOE LEAD, Pulse Survey, GIS, stock data) is referenced
from `../../../Data/` and `../../../Cleaned_Data/` via relative paths in
`R/01_setup_and_data_prep.R`.

---

## Files to Collect

| File | Source | Status | Notes |
|------|--------|--------|-------|
| `10k_southern_company_2020-2024.csv` | SEC EDGAR 10-K | To collect | Follow `eep-pipeline-core/collectors/iou_financials_collector.md` |
| `def14a_southern_company_2020-2024.csv` | SEC EDGAR DEF 14A | To collect | Summary Compensation Table; one row per executive per year |
| `disconnections_georgia_power_2020-2024.csv` | EJL Dashboard or GA PSC | To collect | Prefer EJL if coverage is complete; otherwise file GA PSC data request |
| `program_enrollment_georgia_power.csv` | GA PSC filing or utility | To collect | Annual enrollment in CARE, SVC, or equivalent affordability programs |

---

## Previously Collected Data (in Archive)

The original analysis used stock price data fetched via `tidyquant`. Those files are
preserved in `Archive/data/raw/`:

- `Archive/data/raw/southern_company_stock_prices.csv`
- `Archive/data/raw/southern_company_dividends.csv`
- `Archive/data/raw/southern_company_current_quote.csv`

Stock data for the updated analysis should be regenerated via `iou_stock_collector.R`
in `eep-pipeline-core`, or placed in the shared `../../../Data/financial_markets/iou_stock/SO/`
location if not already there.

---

## Why Not Shared Data?

Data stays in this folder (rather than `../../../Data/`) when:
1. It is manually extracted and utility-specific (e.g., exec comp tables)
2. It was provided by a partner under a data sharing agreement
3. It is state-specific regulatory data not yet worth promoting to a shared pipeline
4. Promoting it to a shared pipeline is planned but not yet complete

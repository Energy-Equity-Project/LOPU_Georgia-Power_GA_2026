# [UTILITY_NAME] — Lights Out, Profits Up: [YEAR_RANGE] Analysis

*Prepared by the Energy Equity Project | [DATE]*

---

## Executive Summary

<!-- 3–5 sentences. State the core contrast: hardship vs. profit. Lead with the
     single most striking headline statistic — ideally the indexed comparison from
     script 07 (e.g., "While energy insecurity rose X%, [utility] net income grew Y%").
     Include the HEAG total or disconnection rate as a supporting data point.
     End with a one-sentence call for policy action. -->

---

## Section 1: Energy Insecurity

<!-- Key findings from the Household Pulse Survey (script 02 outputs).
     Required elements:
     - % of households unable to pay an energy bill in the past 12 months (state-level)
     - % keeping home at unsafe temperature
     - % forgoing food, medicine, or other necessities to pay energy bills
     - Trend direction over the report period (rising / flat / declining)
     - Any available breakdowns by tenure (renter vs. owner) or race/ethnicity
     If data is unavailable for a sub-item, flag it explicitly. -->

---

## Section 2: Energy Burden & Affordability Gap

<!-- DOE LEAD findings (script 03 outputs).
     Required elements:
     - Median energy burden for households at 0–80% FPL (lowest-income tier)
     - Median energy burden for the full service territory (for context)
     - Total Home Energy Affordability Gap (HEAG) for the service territory in dollars
     - Per-household annual gap for the lowest-income tier
     - Number of households above the 6% burden threshold
     If burden projection methodology was applied (experimental), note it and cite limitations. -->

---

## Section 3: Rate Trends

<!-- EIA Form 861 findings (script 04 outputs).
     Required elements:
     - [Utility]'s cumulative % residential rate increase over the full report period
     - Annual average rate in base year vs. most recent year (cents per kWh)
     - Estimated annual bill impact in dollars (based on average usage)
     - Comparison to state investor-owned utility peers, cooperatives, and municipal utilities:
       which sector saw the largest and smallest increases?
     - State ranking or context if available -->

---

## Section 4: Disconnections & Program Gaps

<!-- Disconnection and affordability program findings (script 05 outputs).
     Required elements:
     - Annual disconnection rate in most recent year (disconnections / residential customers)
     - Trend direction over the report period
     - If program enrollment data is available:
       - Number of eligible households vs. enrolled households
       - Enrollment gap (eligible but not enrolled)
       - Gap as % of eligible population
     If disconnection or program data is unavailable, flag with a data note. -->

---

## Section 5: Utility Financial Performance

<!-- IOU financial performance findings (script 06 outputs).
     Required elements:
     - Total residential revenue: base year vs. most recent year, % change
     - Net income: base year vs. most recent year, % change
     - Profit margin trend (net income / revenue)
     - CEO total compensation: base year vs. most recent year, % change
     - Dividend yield trend (if available)
     - Market capitalization change (if available)
     Do not state the utility is "doing well" — let the numbers speak. -->

---

## Section 6: The Contrast — Lights Out, Profits Up

<!-- This is the core narrative section. Draw from script 07's indexed comparison outputs.
     Required elements:
     - State the base year and what "indexed to 100" means
     - Report the indexed end values for hardship metrics:
       e.g., "Energy insecurity index: [value] in [year] (base: 100 in [base_year])"
     - Report the indexed end values for financial metrics:
       e.g., "Net income index: [value] in [year]"
     - Synthesize the divergence: at what point did the lines diverge?
       Which direction did each set of metrics move?
     - Reference the dual-panel chart from plots/ if it was visible
     - Conclude with a statement of what this divergence means for residential customers -->

---

## Data Sources & Notes

<!-- List all data sources used in this report with collection dates and caveats.
     Include one row per source. -->

| Data Source | Coverage | Path / File | Date Collected | Key Caveats |
|-------------|----------|-------------|----------------|-------------|
| DOE LEAD | Census tract, 2022 | `../../../Cleaned_Data/doe/lead/` | — | 2022 baseline; not real-time |
| Household Pulse Survey | State level | `../../../Cleaned_Data/us_census/household_pulse_survey/` | — | State-level precision only; not utility-territory |
| EIA Form 861 | Utility level | `../../../Cleaned_Data/eia/861/` | — | Reported annually; lags ~1 year |
| SEC EDGAR 10-K | Company level | `data/` | [date] | Manually extracted; transcription risk |
| SEC DEF 14A | Company level | `data/` | [date] | Manually extracted |
| EJL / State PUC | Utility level | `data/` | [date] | Coverage varies by utility and state |
| Yahoo Finance / tidyquant | Company level | `../../../Data/financial_markets/iou_stock/` | — | Point-in-time; may have gaps |

<!-- Add additional caveats specific to this report below: -->

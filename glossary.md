# LOPU Series Glossary

*This is a per-report copy of the series-level glossary, included for self-containment.*
*Canonical source: `lights_out_profits_up/glossary.md`.*
*When spinning up a new report, replace this file with the current version of the canonical.*
*Per-report amendments (e.g., state-specific program names) may be added below the standard definitions.*

---

## Energy Hardship & Affordability

**Energy burden**
The percentage of a household's annual gross income spent on home energy costs (electricity,
gas, and other fuels). Calculated as: (annual energy expenditure) / (annual gross income) × 100.
The standard affordability threshold used in this series is **6%** — households spending more
than 6% of income on energy are considered cost-burdened. Source methodology: DOE LEAD.

**Home Energy Affordability Gap (HEAG)**
For households with an energy burden above 6%, the HEAG is the dollar difference between what
a household actually spends on energy and what 6% of their income would cover. It measures
the structural affordability shortfall — how much more households pay than they can afford.
Formula: HEAG = annual energy expenditure − (annual gross income × 0.06). Reported at the
household level (per-household annual gap) and territory level (sum across all burdened households).

**Federal Poverty Level (FPL)**
The federal income threshold used to determine eligibility for many assistance programs.
In LOPU reports, households are segmented into four income tiers relative to FPL:
- **0–80% FPL** — very low income; highest energy burdens
- **80–120% FPL** — low income
- **120–200% FPL** — moderate income
- **200%+ FPL** — above the low-income threshold

**Energy insecurity**
A household's inability to meet its energy needs, measured here using three Household Pulse
Survey indicators: (1) inability to pay an energy bill in the past 12 months; (2) keeping the
home at an unsafe temperature to reduce costs; (3) forgoing food, medicine, or other necessities
to pay energy bills.

**Enrollment gap**
The difference between the number of households estimated to be eligible for an affordability
program and the number actually enrolled. Measures the program's reach shortfall.
Formula: enrollment gap = estimated eligible households − enrolled households.

---

## Data Sources

**DOE LEAD (Low-Income Energy Affordability Data)**
A dataset published by the U.S. Department of Energy providing census-tract-level estimates
of annual energy expenditure, energy burden, and income for residential households. The 2022
version is the baseline used in this series. LEAD is derived from American Community Survey
microdata and energy expenditure models — it is not directly measured at the household level.
Key variables: `avg_electricity_cost`, `avg_gas_cost`, `energy_burden`, `household_count`.

**Household Pulse Survey**
A rapid-response survey conducted by the U.S. Census Bureau to measure economic and social
impacts on households. Used in this series for energy insecurity indicators. Data are
representative at the state level (not utility-territory level). Responses are weighted using
`person_weight` to produce population estimates. Survey phases vary in coverage years —
consult script 02 for the phases and question crosswalk used.

**EIA Form 861 (Annual Electric Power Industry Report)**
An annual survey filed by all U.S. electric utilities reporting data on electricity sales,
revenue, customer counts, and purchased power. Used in this series for residential rate trends,
customer counts, and utility revenue. Data lag approximately one year (e.g., 2024 data available
mid-2025). Cleaned version path: `../../../Cleaned_Data/eia/861/`.

**SEC EDGAR**
The SEC's Electronic Data Gathering, Analysis, and Retrieval system. Source for annual and
quarterly filings by publicly traded companies.

**Form 10-K**
An annual financial report filed with the SEC. Source for total revenue, net income, operating
income, capital expenditures, long-term debt, and dividends paid.

**DEF 14A (proxy statement)**
An SEC filing submitted before shareholder meetings. The Summary Compensation Table in the
DEF 14A discloses total compensation for the CEO and other named executive officers. Source
for CEO and executive compensation data in this series.

**EJL Disconnection Dashboard**
The Energy Justice Lab (Indiana University) aggregates state-reported utility disconnection
data. Preferred source for disconnection data when it covers the target utility. Path:
`../../../Data/ejl_disconnection_dashboard/`.

**GIS service territories (HFLID ORNL)**
Electric retail service territory boundaries from Oak Ridge National Laboratory's Homeland
Infrastructure Foundation-Level Data (HFLID). Used as an optional spatial crosswalk to
filter census-tract data to the utility's service territory. Path:
`../../../Data/gis/hflid_ornl/electric-retail-service-territories/`.

---

## Financial & Market Terms

**Investor-Owned Utility (IOU)**
A for-profit electric (or gas) utility with private shareholders. Contrasted with:
- **Electric cooperative** — customer-owned, not-for-profit
- **Municipal utility** — government-owned, operated for the public benefit
IOUs are subject to state public utility commission rate regulation but have shareholders
to whom they owe a return on investment.

**Revenue (residential)**
Total billed revenue from residential customers for electricity service. Reported to EIA
Form 861 and in 10-K filings. Expressed in dollars.

**Net income**
Total revenue minus all expenses (operating costs, depreciation, interest, taxes). Reported
in the 10-K income statement. Represents accounting profit.

**Profit margin**
Net income as a percentage of total revenue. Formula: (net income / total revenue) × 100.

**Dividend yield**
Annual dividends per share divided by the average annual stock price, expressed as a
percentage. Measures the cash return to shareholders from dividends alone.

**Market capitalization**
Total shares outstanding multiplied by the stock price. Represents the market's total
valuation of the company at a point in time.

---

## Analytical Methods

**Indexed metric**
A value normalized so that its base-year value equals 100. Used in script 07 to compare
growth rates across metrics with different units (e.g., energy burden % vs. net income $).
Formula: indexed value in year Y = (raw value in year Y / raw value in base year) × 100.
An indexed value of 125 means the metric has grown 25% above its base-year level.

**Weighted average residential rate**
The average price per kilowatt-hour paid by residential customers, calculated as:
(total residential revenue) / (total residential kilowatt-hours sold). Derived from
EIA Form 861 data. Expressed in cents per kWh.

**Cumulative rate change**
The total percentage change in the weighted average residential rate from the first year
to the last year of the report period. Calculated as:
((rate in final year − rate in base year) / rate in base year) × 100.

**Annual bill impact**
The estimated change in a typical household's annual electricity bill from the base year
to the most recent year. Calculated using the average residential consumption (kWh) for
the state or territory multiplied by the change in the weighted average rate.

**Disconnection rate**
Annual residential service disconnections (for non-payment) as a percentage of total
residential customers. Formula: (disconnections in year Y) / (residential customers in year Y) × 100.

**Energy burden projection**
An experimental methodology (see `methodology_notes.md`) that adjusts the 2022 DOE LEAD
baseline forward to a target year using ACS income growth rates and EIA rate change data.
Not yet standardized — use with caution and disclose limitations clearly.

**EIA broadcasting**
An experimental calibration approach (see `methodology_notes.md`) that rescales DOE LEAD
electricity expenditure estimates to match EIA Form 861 reported residential revenue, using
LEAD's spatial distribution as the allocation weights. Resolves the ~10x discrepancy between
raw LEAD totals and EIA verified totals.

---

## Equity & Policy Context

**Energy justice**
The equitable distribution of energy benefits and burdens across communities, with particular
attention to low-income households and communities of color. In this series, energy justice
encompasses both the distribution of energy affordability (who pays more relative to income)
and the distribution of program benefits (who receives assistance).

**BIPOC**
Black, Indigenous, and People of Color. Used when describing racial and ethnic disparities
in energy burden, insecurity, and service quality.

**Public utility commission (PUC) / Public service commission (PSC)**
The state regulatory body that oversees investor-owned utility rates, service quality, and
program requirements. Rate changes require commission approval via a rate case process.

**Rate case**
A formal regulatory proceeding in which a utility requests permission from the PUC/PSC to
change its rates. The utility must justify the requested increase with cost-of-service data.

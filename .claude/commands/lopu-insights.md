You are helping synthesize analytical outputs from a **Lights Out, Profits Up (LOPU)** report into a structured narrative Markdown document. Follow these steps exactly.

---

## Step 1: Read Report Configuration

Read `CLAUDE.md` in the current directory and extract the **Report Configuration** section to identify:
- `utility_name`
- `parent_company`
- `report_year_range` (e.g., 2019–2024)
- `base_year`
- `state_abbrev`
- `state_name`

If CLAUDE.md does not have a Report Configuration section, read `R/01_setup_and_data_prep.R` and find the `# CUSTOMIZE` block to extract the same fields.

---

## Step 2: Inventory Available Outputs

List all files in `outputs/` and `plots/`. Use this inventory to understand what data is available. Not every report will have every file — handle missing files gracefully by flagging those sections rather than skipping them silently.

---

## Step 3: Read Output CSVs

Read the following CSVs from `outputs/`, matching by filename pattern (files are date-prefixed as `dd-mm-yyyy-*`). Read each file that exists:

| Priority | Pattern | Script | Content |
|----------|---------|--------|---------|
| Critical | `*-lopu-summary-table.csv` | 07 | Headline hardship vs. financial indexed comparison |
| Critical | `*-lopu-ratio-summary.csv` | 07 | Percent changes by metric |
| High | `*-lead-heag-total.csv` | 03 | Total HEAG for service territory |
| High | `*-lead-burden-by-fpl.csv` | 03 | Energy burden by FPL income tier |
| High | `*-pulse-summary-statistics.csv` | 02 | Headline energy insecurity percentages |
| High | `*-eia-target-utility-rate-trend.csv` | 04 | Rate trend over report period |
| High | `*-eia-state-rate-change-summary.csv` | 04 | Peer comparison (IOU vs. coop vs. muni) |
| Medium | `*-disconnection-rate-annual.csv` | 05 | Annual disconnection rate trend |
| Medium | `*-iou-financials-annual.csv` | 06 | Revenue, net income, profit margin |
| Medium | `*-iou-ceo-compensation-trend.csv` | 06 | CEO compensation trend |

Read every file that is present. For each missing file, note it — do not fabricate data.

---

## Step 4: View Key Plots

Read the following plot files visually to confirm the narrative direction:
- `plots/*-lopu-indexed-comparison*.png` (script 07 headline dual-panel chart)
- `plots/*-rate-trend*.png` (script 04 rate trend chart)

If you can see the charts, briefly note what the visual direction shows (rising vs. flat, divergence point, etc.).

---

## Step 5: Read the Output Template

Read `templates/insights_template.md` for the required section structure and placeholder guidance.

---

## Step 6: Write the Narrative Document

Using everything you have read, write a structured narrative Markdown document. Save it to:

```
outputs/[dd-mm-yyyy]-lopu-narrative-insights.md
```

Use today's date in `dd-mm-yyyy` format (e.g., `18-02-2026`).

### Constraints — follow these strictly:

1. **No hallucinated statistics.** Every number you cite must come from a CSV or plot you actually read. If a statistic is unavailable, say so explicitly.
2. **Flag missing data.** For any section where the underlying data file was not found, include a note: `> **Data note:** [filename pattern] was not found in outputs/. This section requires manual completion.`
3. **Plain language.** Write for a general audience — advocates, journalists, policymakers. Avoid jargon where possible; define terms on first use.
4. **Lead with the contrast.** The core narrative is: hardship rising while profits climb. Lead each section with the most striking finding. The executive summary should open with the single most powerful contrast statistic.
5. **Cite the source CSV** for each statistic in a parenthetical: `(source: [filename])`.
6. **Follow the template structure exactly.** Do not add, remove, or reorder sections.
7. **Round appropriately.** Percentages to one decimal place; dollar figures to the nearest dollar or thousand depending on magnitude; indexed values to one decimal place.
8. **Tense:** Write in present tense for findings ("rates have increased by X%"), past tense for events ("in 2022, the utility reported...").

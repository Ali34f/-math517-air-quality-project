# London air quality: roadside vs urban background NO₂

MATH517 group coursework. We answer **Option 1** of the brief:

> How do NO₂ concentrations differ between roadside and urban-background sites, and how do these differences vary across the day and week?

## Repository contents

| File / folder | Purpose |
|---|---|
| `no2_analysis.R` | Full analysis: cleaning, figures, probability, test, model |
| `LAQN_data_2019_2025.Rproj` | RStudio project (sets the working directory) |
| `outputs/` | All figures and result files produced by the script |

## How to reproduce

1. Install R (we used 4.6.1) and these packages:
   ```r
   install.packages(c("readr", "dplyr", "tidyr", "lubridate", "ggplot2", "scales", "lme4", "emmeans"))
   ```
2. Copy `measurements.csv` and `sites.csv` from the DLE coursework package (version dated 29–30 Oct 2026) into this folder.
   They are not on GitHub because `measurements.csv` (271 MB) exceeds GitHub's file-size limit.
3. Open `LAQN_data_2019_2025.Rproj` in RStudio and run `no2_analysis.R` from top to bottom.
   All files in `outputs/` are recreated.

## Data

- Source: London Air Quality Network (LAQN), Imperial College London, fixed extract supplied on the DLE.
- 58 sites (38 roadside, 20 urban background), hourly NO₂ and PM2.5, 2019–2025. Only NO₂ is analysed.
- The `unit` and `data_quality_status` columns are empty for every row; concentrations are assumed to be µg/m³.
- The extract contains no data for the last day of each month (84 days in total).

## Key analysis decisions

| Decision | Choice |
|---|---|
| Pollutant and period | NO₂, 2019–2025 |
| Time zone | Timestamps converted from UTC to London local time |
| Data capture rule | Site-years with < 75% valid hours removed |
| Invalid values | Missing and negative values removed |
| Averaging | Per site first, then across sites, so each site counts equally |
| Day type | Weekday = Mon–Fri, Weekend = Sat–Sun (bank holidays not separated) |
| Time bands | Night 00–05, Morning peak 06–09, Daytime 10–15, Evening peak 16–19, Late evening 20–23 |
| Probability threshold | Hour above 40 µg/m³ (UK annual-mean objective, used as a benchmark only) |
| Statistical test | Welch two-sample t-test on one mean per site |
| Model | Linear mixed model of site × year × band × day-type means, random intercept per site |

## Outputs

| File | Contents |
|---|---|
| `fig_coverage.png` | Data capture by site and year |
| `fig_hourly.png` | Mean NO₂ by hour, weekday vs weekend (lead figure) |
| `fig_difference.png` | Roadside excess over urban background by hour |
| `fig_heatmap.png` | Mean NO₂ by hour and day of week |
| `fig_distribution.png` | Site-year mean NO₂ by site type |
| `fig_trend.png` | Annual trend at sites with complete records |
| `fig_model_check.png` | Model residual checks |
| `descriptive_stats.csv` | Summary statistics by site type |
| `probability_exceed.csv` | Probability an hour exceeds 40 µg/m³ |
| `t_test.txt` | Welch t-test result |
| `model_summary.txt`, `emmeans_contrasts.txt` | Mixed model and roadside-minus-background estimates |
| `session_info.txt` | R and package versions used |
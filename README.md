# HK Property Affordability Tracker

A data pipeline and SQL analysis that tracks Hong Kong private residential
prices against official household income data, to measure housing
affordability over time using an internationally recognized methodology.

## What it does

- Pulls official government data (Rating and Valuation Department price
  statistics + Census and Statistics Department income statistics) on a
  recurring basis
- Cleans and loads it into a MySQL database via an idempotent R pipeline
  (safe to re-run or schedule on cron)
- Computes Hong Kong's housing affordability using the **Median Multiple**
  standard (median home price ÷ gross annual median household income) —
  the same methodology used by the World Bank, UN, OECD, IMF, and the
  Demographia International Housing Affordability Survey
- Extends the analysis to the district level, weighting income by
  population to compare affordability across Hong Kong's three main
  regions (Hong Kong Island, Kowloon, New Territories)

## Key finding

Affordability improved from **2021 (Median Multiple 22.2×) to 2025
(15.9×)**, but Hong Kong remained in Demographia's "severely unaffordable"
band (≥5.1×) throughout the period — consistent with Demographia's own
published range for Hong Kong (14–23× across recent years).

Breaking the analysis down by region reveals a more interesting result:
**Kowloon, not Hong Kong Island, has the worst affordability ratio every
year from 2021 to 2025** (26.1× in 2021, still 19.25× in 2025), even though
Hong Kong Island has the higher absolute home prices. This is because
Kowloon's population-weighted household income is pulled down by
lower-income districts (e.g. Kwun Tong, Sham Shui Po) more than its home
prices are discounted relative to Hong Kong Island. Looking at price alone
would give the wrong answer about where the affordability problem is worst.

## Tech stack

- **R** — data acquisition and cleaning pipeline (`httr`, `readr`, `dplyr`,
  `tidyr`, `stringr`, `RMariaDB`)
- **MySQL** — data warehouse (5 tables: price index, average price by
  region, sales volume, income reference at territory and district level)
- **SQL** — all analysis logic: affordability index, watch-zone alerting on
  price momentum, region comparison, population-weighted regional income
- **Cron** — monthly scheduled re-runs (matches the government data
  provider's own monthly publication cycle)

## Project structure

```
hk-property-tracker/
├── pipeline/
│   └── fetch_rvd.R              # Downloads, cleans, and upserts source data into MySQL
├── sql/
│   ├── 01_schema.sql             # Table definitions
│   ├── 02_validate.sql           # Data health checks
│   ├── 03_affordability.sql      # Territory-wide Median Multiple affordability index
│   ├── 04_alerts.sql             # Price-momentum watch-zone alerting
│   ├── 05_region_comparison.sql  # Region-level price trend and ranking
│   └── 06_plan_b_region_income.sql  # District-level income weighted into regional affordability
├── .env.example
└── README.md
```

## Setup

1. MySQL 8.0+ running locally. Copy `.env.example` to `.env` and fill in
   your credentials.
2. Apply the schema: `mysql -u root -p < sql/01_schema.sql`
3. Install R dependencies:
   ```r
   install.packages(c("httr", "readr", "dplyr", "tidyr", "stringr", "RMariaDB"))
   ```
4. Run the pipeline: `Rscript pipeline/fetch_rvd.R`
5. Run the analysis queries in `sql/03_affordability.sql` through
   `sql/06_plan_b_region_income.sql`.

## Methodology notes

- **Median Multiple** thresholds follow Demographia's published bands:
  Affordable ≤3.0, Moderately Unaffordable 3.1–4.0, Seriously Unaffordable
  4.1–5.0, Severely Unaffordable ≥5.1.
- Converting the government's per-square-metre price figure into a
  whole-dwelling price requires an assumed unit size; this project uses
  40 sqm (~430 sqft) as an illustrative small-flat benchmark. This is a
  stated project assumption, not an official published figure.
- District-level income is mapped to Hong Kong's three RVD price regions
  using the official district-to-region mapping, weighted by 2021 census
  population. This is a standard approximation (weighted average of
  district medians), not an official regional median income figure.

## Status

Core pipeline, schema, and all analysis SQL (affordability index,
watch-zone alerting, region comparison, district-weighted regional
affordability) are complete and verified against real government data.
A visualization layer is planned as a next step.

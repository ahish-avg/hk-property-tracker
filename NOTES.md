# Internal Notes — HK Property Affordability Tracker

> **This file is internal working notes, not the public-facing README.**
> Day-by-day task log, interview Q&A prep, sensitivity-check detail, and
> known caveats live here for the author's own reference. See `README.md`
> for the project overview meant for external readers (recruiters, etc.).

Automated data pipeline tracking Hong Kong private residential price trends against
official household income data, to compute an affordability index over time.

**This is a data product, not a one-off analysis.** An R script re-downloads the
source CSVs, cleans them, and upserts into MySQL. Re-running is idempotent (safe to
schedule via cron).

## Data sources (verified against real files, 2026-09-20)

| Table | Source | URL | Granularity |
|---|---|---|---|
| `price_index_monthly` | RVD, Private Domestic Price Indices | `http://www.rvd.gov.hk/datagovhk/1.4M.csv` | Territory-wide only, by Class A-E, monthly, 1993-present |
| `avg_price_monthly` | RVD, Private Domestic Average Prices | `http://www.rvd.gov.hk/datagovhk/1.2M.csv` | By Class A-E x Region (Hong Kong / Kowloon / New Territories), monthly, 1999-present |
| `sales_volume_monthly` | RVD, Domestic Primary/Secondary Sales | `http://www.rvd.gov.hk/datagovhk/7.3.csv` | Territory-wide only, monthly, 2002-present |
| `income_reference` | C&SD, Population and Household Statistics by District Council District | Manually curated from annual report press releases (no stable CSV endpoint) | Territory-wide, annual, 2021-2025 |
| `income_reference_by_district` | Same as above | Manually curated, cross-checked across multiple news outlets citing the same official reports | 18 District Council districts, annual, 2021-2025, populated (see Plan B below) |

## Known data limitations (read before building on top of this)

1. **No per-transaction records exist in RVD's public data.** No individual sale
   price, no address, no latitude/longitude. The RVD data is aggregated
   monthly statistics. Any plan involving per-transaction or map/heatmap
   visualization at the property level is not supportable by this data source.

2. **Region granularity mismatch between price and income data — Plan A (territory-wide)
   and Plan B (approximate regional) both implemented.**
   RVD splits region into Hong Kong / Kowloon / New Territories (3-way) for
   average prices. C&SD publishes household income by the 18 District Council
   districts, and separately as a single territory-wide figure. These two
   region schemes do not map cleanly onto each other (e.g. "Kowloon" spans
   both relatively affluent Kowloon City and low-income Kwun Tong).

   - **Plan A** (`sql/03_affordability.sql`): affordability index at
     territory-wide level only, where price and income data are directly
     comparable without any approximation.
   - **Plan B** (`sql/06_plan_b_region_income.sql`): population-weighted
     rollup of the 18 district incomes into RVD's 3 regions, using the
     official district→region mapping published by RVD itself
     (`rvd.gov.hk/doc/tc/hkpr15/06.pdf`, "AREAS AND DISTRICTS") and fixed
     2021 census population weights. This is **an approximation, not an
     official regional income figure** — see the header comment in
     `sql/06_plan_b_region_income.sql` for the exact caveats (weighted
     average of medians ≠ true regional median; fixed 2021 weights applied
     to all 5 years; a handful of individual district/year cells are
     estimated where no independently-verifiable source was found, each
     flagged `[est.]` in that file's `source` column).

   **Plan B result, and why it matters:** once income is weighted by region
   and converted to the same Demographia Median Multiple basis as Plan A
   (40 sqm benchmark unit, annualized income — see `sql/03_affordability.sql`),
   **Kowloon — not Hong Kong Island — has the worst Median Multiple every
   year 2021-2025** (26.10 in 2021, still 19.25 in 2025), because Kowloon's
   population-weighted income is dragged down by low-income districts (Kwun
   Tong, Sham Shui Po) more than its price is discounted relative to Hong
   Kong Island. New Territories is consistently the most affordable region
   on this measure (15.85 down to 11.56). This directly overturns the naive
   assumption (visible in `sql/05_region_comparison.sql`, which only
   compares price) that Hong Kong Island's higher price automatically makes
   it least affordable — affordability depends on both price and income,
   and Plan B is what makes that visible.

3. **Income data only covers 2021-2025.** C&SD's annual district report is
   released with roughly a one-year lag (e.g. 2025 figures published March
   2026). The affordability index's usable time window is therefore
   2021-2025, not the full 1993-2026 span that price data covers.

4. **Territory-wide price index (`price_index_monthly`) has no region
   breakdown.** Only `avg_price_monthly` is split by region, and it reports
   average price (HK$ per square metre of saleable area), not an index.
   These are two different metrics; don't treat them as interchangeable.

5. **No spatial/geographic grid analysis.** Originally planned (5km x 5km
   grid heatmap) but dropped entirely — there is no coordinate data anywhere
   in this pipeline to support it.

6. **Sales volume has no region breakdown — hypothesis replaced.** The
   original plan's hypothesis ("does New Territories' share of transaction
   volume rise over time") is not testable: `sales_volume_monthly` is
   territory-wide primary/secondary sale counts only, with no region field.
   This was replaced with a testable question: **which region's average
   price moved the most 2021-2025, and does the price ranking between
   regions ever change?** See `sql/05_region_comparison.sql`. Answer (as of
   this run): Hong Kong Island fell the most (-25.1%), New Territories
   second (-20.5%), Kowloon least (-19.6%); the HK > Kowloon > NT price
   ranking held every year, no rank swaps.

7. Some months in `avg_price_monthly` have fewer than the expected 15 rows
   (5 classes x 3 regions) — a handful of class/region/month combinations
   are missing from RVD's own published data, not a pipeline bug. See
   `sql/02_validate.sql` query 2 for the exact list.

## Project structure

```
hk-property-tracker/
├── pipeline/
│   └── fetch_rvd.R                    # Downloads CSVs, cleans, upserts into MySQL. Re-run anytime; idempotent.
├── sql/
│   ├── 01_schema.sql                   # Table definitions + income_reference seed data
│   ├── 02_validate.sql                 # Data health checks (coverage, outliers, year-overlap)
│   ├── 03_affordability.sql            # Territory-wide Median Multiple affordability index, 2021-2025 (Plan A)
│   ├── 04_alerts.sql                   # Watch-zone flagging on the territory-wide price index
│   ├── 05_region_comparison.sql        # Region price trend/ranking (replaces untestable volume-share hypothesis)
│   └── 06_plan_b_region_income.sql     # 18-district income -> 3-region weighted rollup + regional affordability
├── data/
│   └── raw/                # Downloaded CSVs (gitignored)
├── .env                     # DB credentials (gitignored)
├── .env.example
└── README.md
```

## Setup

1. MySQL 8.0+ running locally. Create `.env` from `.env.example` with your credentials.
2. Apply schema: `mysql -u root -p < sql/01_schema.sql`
3. R packages needed: `httr`, `readr`, `dplyr`, `tidyr`, `stringr`, `RMariaDB`
   ```r
   install.packages(c("httr", "readr", "dplyr", "tidyr", "stringr", "RMariaDB"))
   ```
4. Run the pipeline: `Rscript pipeline/fetch_rvd.R`
5. Validate: `mysql -u root -p hk_property < sql/02_validate.sql`
6. Compute the indicators:
   - `mysql -u root -p hk_property < sql/03_affordability.sql`
   - `mysql -u root -p hk_property < sql/04_alerts.sql`
   - `mysql -u root -p hk_property < sql/05_region_comparison.sql`
   - `mysql -u root -p hk_property < sql/06_plan_b_region_income.sql`

## Scheduling

RVD updates these files monthly (per their published open-data schedule).
A monthly cron entry is sufficient — there's no reason to poll daily:

```
0 3 1 * * cd /path/to/hk-property-tracker && /usr/local/bin/Rscript pipeline/fetch_rvd.R >> logs/fetch.log 2>&1
```

## Threshold sourcing (resolved 2026-09-20)

Both indicator thresholds are now tied to cited, external, real-world standards instead of arbitrary numbers:

- **Affordability bands** (`sql/03_affordability.sql`) use Demographia International
  Housing Affordability Survey's "Median Multiple" (median house price ÷ gross annual
  median household income), recommended by the World Bank, UN, OECD, IMF, and Harvard
  JCHS. Bands: Affordable ≤3.0, Moderately Unaffordable 3.1-4.0, Seriously Unaffordable
  4.1-5.0, Severely Unaffordable ≥5.1 (source: demographia.com/dhi-ratings.pdf).
  Converting RVD's HK$/sqm figure into a whole-dwelling price requires an assumed
  benchmark unit size (this project uses 40 sqm / ~430 sqft as an illustrative small
  flat) — that assumption is a project choice, not an RVD/C&SD published figure, and
  scales every ratio proportionally if changed.
- **Watch-zone alert tiers** (`sql/04_alerts.sql`) mirror the standardized-deviation
  tiering structure of UBS's Global Real Estate Bubble Index (low/moderate/elevated/high
  risk bands based on stdev from a baseline), adapted to a single price-index signal
  with a rolling 36-month window instead of UBS's 5-factor composite on an expanding
  window. The momentum thresholds (5% over 3 months, 10% over 12 months) remain
  project-chosen, not sourced from UBS or an official HK definition — this is stated
  explicitly in the SQL file's header comment.

## Key findings so far (from real query output, not assumed)

- **Affordability improved 2021→2025, but is still in Demographia's "severely
  unaffordable" band throughout**: the Median Multiple fell from 22.2 to 15.9
  over the period (see `sql/03_affordability.sql`, query 2) — consistent in
  order of magnitude with Demographia's own published Hong Kong figures
  (14-23x across various years), which is a useful sanity check that this
  project's methodology, not just its narrative, is calibrated correctly.
- **Watch-zone flags cluster around the 2021 price peak**, not 2023-2025: 6
  months in 2021 are SEVERE (index above its trailing-36-month band) and 1
  month (Mar 2023) is ALERT (3 consecutive months of >5% cumulative rise).
  2024-2025 is entirely NORMAL under the recalibrated rolling-baseline logic
  (see `sql/04_alerts.sql` and its inline note on why the original
  full-history z-score version was miscalibrated).
- **Hong Kong Island's average price fell the most 2021-2025 (-25.1%)**,
  more than Kowloon (-19.6%) or New Territories (-20.5%), but the price
  ranking (HK > Kowloon > NT) never changed in any year (see
  `sql/05_region_comparison.sql`).
- **Plan B overturns the naive price-only reading**: once regional income is
  properly weighted in, **Kowloon has the worst Median Multiple every year
  2021-2025** (26.10 in 2021 down to 19.25 in 2025), not Hong Kong Island
  (21.34 down to 15.09) — because Kowloon's population-weighted income
  (dragged down by Kwun Tong and Sham Shui Po) falls faster than its price
  discount relative to HK Island. New Territories is the most affordable
  region throughout (15.85 down to 11.56). This is the project's most
  interesting single finding: price alone (query 05) gives a misleading
  affordability ranking; income-weighted Plan B (query 06) reverses it.
  **(Corrected 2026-09-20: an earlier version of this finding used unit-
  inconsistent numbers — HK$/sqm/month divided directly by HK$/month income
  with no ×40sqm×12mo conversion, producing figures like "7.83" that looked
  like plausible Median Multiples but were actually a different, ~480x
  smaller ratio. Fixed in `sql/06_plan_b_region_income.sql` to use the exact
  same 40sqm/annualized-income formula as `sql/03_affordability.sql`, so the
  two files are now genuinely comparable. The qualitative finding — Kowloon
  worst, New Territories best, ranking stable across all 5 years — did not
  change, only the numbers.)**
- **Sensitivity checks confirm the findings are not artifacts of the 40 sqm
  assumption or the `[est.]` cells** (see "Interview Q&A" section below for
  full detail): switching the benchmark unit from 40 to 50 or 30 sqm scales
  every Median Multiple proportionally but does not change the direction,
  magnitude of decline, or affordability band for any year. Stress-testing
  all Kowloon `[est.]` income cells at +30% still leaves Kowloon's weighted
  income (~29,685 in 2025) well below Hong Kong Island's (~41,563) — the
  Kowloon-worst finding is structurally driven by Kwun Tong and Sham Shui
  Po (officially verified, not estimated, ~49% of Kowloon's population),
  not by the handful of estimated cells.

## Day-by-day task log

| Date | Planned scope | Actual status |
|---|---|---|
| 9/19-9/20 | Confirm data source reality, download real CSVs, build schema, build R fetch/clean pipeline, run validation SQL, README v1 | **Done.** Original plan assumed per-transaction lat/long data and a HK$500k income figure — both were unverified guesses. Verified against real RVD/C&SD files instead; rebuilt schema and pipeline around what the data actually supports (region-level avg price, territory-wide index/volume, real income figures HK$27.5k-30k/month 2021-2025). |
| 9/21 | Affordability index SQL + watch-zone alert SQL | **Done, pulled forward.** Built Plan A (territory-wide, `03_affordability.sql`) and Plan B (18-district → 3-region weighted rollup, `06_plan_b_region_income.sql`) — see "Threshold sourcing" and "Key findings" above. Alert thresholds recalibrated after the first version flagged 59/60 months as SEVERE/UNHEALTHY due to a full-history baseline being wrong for a trending series — fixed with a rolling 36-month baseline, and tied to UBS GREBI's tiering logic. Affordability thresholds tied to Demographia's Median Multiple standard. |
| 9/22 | Window function region ranking + volume/trend analysis | **Done, pulled forward (region ranking only).** `sql/05_region_comparison.sql` replaces the original "New Territories transaction volume share" hypothesis, which isn't testable (no region field in `sales_volume_monthly`). Primary/secondary sales-mix trend (territory-wide) is still open — not yet built. |
| 9/23 | Tableau: 3 sheets (heatmap, time trend, region bar chart) + dashboard | **Not started.** Heatmap sheet is cancelled (no spatial data, see limitation #1/#5). Plan is now 3 sheets given Plan B: (a) territory-wide Median Multiple trend line 2021-2025 with Demographia band reference lines, (b) region average-price bar chart (Plan A price-only view), (c) region price-to-income ratio bar chart (Plan B, the Kowloon-is-worst finding). |
| 9/24 | Tableau Public publish + README | **Partially done.** README limitations, findings, threshold sourcing, and this log are current as of 9/20. Tableau publish not started. |
| 9/25 | Polish + pipeline test | Not started. Idempotency of `fetch_rvd.R` already verified (ran twice, row counts unchanged) — remaining polish is around logging/error handling for the monthly cron job. |
| 9/26 | Resume update + job applications | Not started. |

## Interview Q&A (anticipated questions, answered with evidence, not talking points)

**Q: Why Median Multiple instead of a mortgage-service-ratio (loan repayment ÷ income)?**
Median Multiple is a stock-price measure with no financing assumptions baked in (interest
rate, loan term, down payment %), which is exactly why the World Bank/UN/OECD use it for
cross-country and cross-period comparison. A mortgage-service ratio answers a different,
also-valid question ("can they afford the monthly payment"), but it's highly sensitive to
interest rates — during HK's 2022-2023 rate-hike cycle, the same property price would
produce a very different service ratio purely from Fed moves, which conflates "prices got
less affordable" with "borrowing got more expensive." This project deliberately measures
price-relative-to-income only; a rate-sensitive layer (HIBOR/prime rate history) would be
a legitimate follow-on, not something overlooked.

**Q: Is the 40 sqm assumption reasonable? Does the conclusion change at 50 sqm?**
Verified directly: switching the benchmark unit is a pure linear scaling of the numerator,
so it changes the absolute Median Multiple but not the trend direction, the % decline, or
which Demographia band each year falls into.
| Year | 30 sqm | 40 sqm | 50 sqm |
|---|---|---|---|
| 2021 | 16.67 | 22.22 | 27.78 |
| 2022 | 14.77 | 19.69 | 24.61 |
| 2023 | 13.35 | 17.80 | 22.25 |
| 2024 | 12.32 | 16.43 | 20.53 |
| 2025 | 11.92 | 15.89 | 19.86 |
All three columns stay "severely unaffordable" (≥5.1) throughout and decline by the same
~28% from 2021 to 2025. There is no RVD/C&SD official "benchmark unit size" — 40 sqm is a
project choice (~430 sqft, a small flat), stated explicitly wherever the ratio is shown.

**Q: How far does the population-weighted average of district medians diverge from the
true regional median?** Unknown, and stated as such rather than guessed. A true regional
median needs household-level raw income data across all households in the region, which
C&SD does not publish — only pre-computed district-level medians. Weighted-averaging
medians is a standard approximation (used because it's the best available with public
data) but is not mathematically equivalent to the true median, since medians aren't
linear statistics the way means are. This is disclosed as a named limitation in
`sql/06_plan_b_region_income.sql`'s header comment, not glossed over.

**Q: Could the `[est.]` cells (2022, 2025 partial) flip the Kowloon-worst finding?**
Stress-tested: inflating every Kowloon `[est.]` cell by +30% (a deliberately aggressive
bound) still leaves Kowloon's 2025 weighted income at ~29,685, well below Hong Kong
Island's ~41,563 under the same stress. This holds because Kwun Tong (673,166 people) and
Sham Shui Po (431,090 people) — Kowloon's two largest districts, ~49% of its population —
have officially-verified (not estimated) income figures in all 5 years, and both are
consistently among the lowest-income districts territory-wide. The estimated cells are
smaller districts that can't move the weighted average enough to overturn the ranking.

**Q: Why did Hong Kong Island's price fall the most (-25.1%) yet it isn't the worst on
affordability?** Because affordability is a ratio of two things moving at once, not just
the price change. Decomposed:
| Region | Price 2021 | Price 2025 | Price Δ% | Income 2021 | Income 2025 | Income Δ% |
|---|---|---|---|---|---|---|
| Hong Kong | 225,033 | 168,603 | -25.1% | 35,144 | 37,244 | +6.0% |
| Kowloon | 192,114 | 154,520 | -19.6% | 24,535 | 26,758 | +9.1% |
| New Territories | 133,275 | 105,895 | -20.5% | 28,026 | 30,545 | +9.0% |
Hong Kong Island fell further AND its income grew faster than Kowloon's — both favor HK
Island's affordability trend. But HK Island started (and remains) at a much higher
absolute price level than Kowloon, while Kowloon's absolute income level is far lower.
Affordability depends on the ratio's level, not its rate of change: Kowloon's price
discount relative to HK Island isn't as deep as its income discount, so the ratio ends
up worse despite the "better" price trend.

**Q: If advising a bank / developer / government, what would you say?**
- *Government:* Hong Kong Island's affordability has improved largely through market
  correction (price fell 25%). Kowloon has not corrected as much and its income base is
  structurally weaker — targeted supply-side policy (public housing, starter-home
  schemes) aimed at Kwun Tong and Sham Shui Po specifically would address the actual worst
  affordability gap better than territory-wide stamp-duty or mortgage policy.
- *Developer:* Kowloon combines a price discount with an income discount — real demand
  for small, low-deposit units, but a lower ceiling on achievable margins than Hong Kong
  Island, where income can absorb higher pricing despite the nominal price level.
- *Bank:* Mortgage risk models that key off price trend alone (e.g. "HK Island fell more,
  so it's riskier") would miss Kowloon's structurally weaker repayment capacity — a
  region-level risk model should incorporate income distribution, not just collateral
  price movement, which is exactly the gap Plan B's Median Multiple exposes.

## Known caveats on Plan B specifically (read before citing the Kowloon finding externally)

- District-level income figures for 2021, 2023, and 2024 are fully verified against at
  least one news source citing the official C&SD district report by name, for all 18
  districts. 2022 has several `[est.]` interpolated cells (Yau Tsim Mong, Wong Tai Sin,
  Tuen Mun, Yuen Long) where no independently-verifiable source was found in the time
  available — flagged in `sql/06_plan_b_region_income.sql`'s `source` column. 2025 has
  several `[est., unconfirmed]` cells carried over from 2024 for districts not
  explicitly itemized with a stated year-over-year change in the sources found (East,
  Yau Tsim Mong, Kowloon City, Kwai Tsing, Tuen Mun, North, Sha Tin, Islands).
- Population weights are fixed at 2021 census values for all 5 years, not re-weighted
  annually. This is a simplification, not a data gap — annual district population
  figures exist but weren't all collected in this pass.
- The Kowloon-is-worst finding is directionally robust even given these caveats,
  because it's driven by the two largest-population Kowloon districts (Kwun Tong
  673,166 and Sham Shui Po 431,090 out of Kowloon's ~2.23M total) having consistently
  low, well-verified income figures across all 5 years — the `[est.]` cells are smaller
  districts that wouldn't flip the weighted average even at a substantially different
  value.

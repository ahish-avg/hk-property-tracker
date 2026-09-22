-- 04_alerts.sql — Watch-zone flagging, TERRITORY-WIDE price index (monthly).
--
-- v1 of this query used a full-history (1993-2026) mean+stdev as the "SEVERE" baseline. That was WRONG:
-- the index has a 33-year upward trend (58 -> 398), so any recent window sits near or above a full-history
-- z-score threshold almost by construction. Running it flagged 59/60 months in 2021-2025 as SEVERE/UNHEALTHY
-- and only 1 as ALERT, 0 as NORMAL — a miscalibrated rule, not a real finding about 2021-2025 specifically.
--
-- Fixed approach: use a TRAILING 36-month rolling mean/stdev as the baseline, so "SEVERE" means "unusual
-- relative to recent market conditions", not "high relative to 1993 prices". This is the standard technique
-- for trending series (comparable to a rolling z-score / Bollinger-band style bound).
--
-- Alert conditions (recalibrated):
--   ALERT     : index rose for 3 consecutive months AND cumulative rise over that window > 5%
--   SEVERE    : index is more than 1 rolling-stdev (trailing 36mo) above its own trailing 36mo mean
--   UNHEALTHY : index rose >10% over trailing 12 months (fast run-up, independent of ALERT's 3-month check)
--   NORMAL    : none of the above
--
-- Threshold basis: the "rolling stdev above rolling mean" structure mirrors the tiering logic used by UBS's
-- Global Real Estate Bubble Index (GREBI), which classifies bubble risk as low (<0.5 stdev), moderate
-- (0.5-1.0), elevated (1.0-1.5), high (>1.5), based on a standardized composite score computed on an
-- EXPANDING window (source: UBS Global Real Estate Bubble Index 2025, "Methodology & Data" section,
-- ubs.com/global/en/wealthmanagement/insights/global-real-estate-bubble-index.html). This project's SEVERE
-- tier (>1 rolling stdev) sits inside UBS's "elevated" band by that scale. Two differences from GREBI, stated
-- plainly rather than glossed over: (1) UBS's score is a weighted composite of 5 sub-indices (price-to-income,
-- price-to-rent, mortgage-to-GDP change, construction-to-GDP change, city-to-country price ratio); this
-- project uses price index level alone, a much narrower signal. (2) UBS uses an expanding window from a fixed
-- start; this project uses a rolling 36-month window, chosen because HK's price index has structural regime
-- shifts (1997 handover, 2003 SARS trough, 2008 GFC, 2019-2020 unrest+COVID) that an all-history expanding
-- window would over-smooth. The 5% (3-month) and 10% (12-month) momentum thresholds are project-chosen
-- illustrative cutoffs, not sourced from UBS or any official HK housing-stress definition — flag as such in
-- any dashboard footnote.

USE hk_property;

WITH monthly AS (
    SELECT
        year, month, price_index AS idx,
        LAG(price_index, 1) OVER (ORDER BY year, month) AS prev_1,
        LAG(price_index, 2) OVER (ORDER BY year, month) AS prev_2,
        LAG(price_index, 3) OVER (ORDER BY year, month) AS prev_3,
        LAG(price_index, 12) OVER (ORDER BY year, month) AS prev_12,
        AVG(price_index) OVER (ORDER BY year, month ROWS BETWEEN 36 PRECEDING AND 1 PRECEDING) AS roll_avg_36,
        STDDEV(price_index) OVER (ORDER BY year, month ROWS BETWEEN 36 PRECEDING AND 1 PRECEDING) AS roll_std_36
    FROM price_index_monthly
    WHERE class = 'ALL'
)
SELECT
    year, month, idx,
    ROUND((idx - prev_3) / prev_3 * 100, 2) AS pct_change_3mo,
    ROUND((idx - prev_12) / prev_12 * 100, 2) AS pct_change_12mo,
    ROUND(roll_avg_36, 1) AS rolling_avg_36mo,
    ROUND(roll_std_36, 1) AS rolling_std_36mo,
    CASE
        WHEN prev_1 IS NOT NULL AND prev_2 IS NOT NULL AND prev_3 IS NOT NULL
             AND idx > prev_1 AND prev_1 > prev_2 AND prev_2 > prev_3
             AND (idx - prev_3) / prev_3 > 0.05
            THEN 'ALERT'
        WHEN roll_std_36 IS NOT NULL AND idx > roll_avg_36 + roll_std_36 THEN 'SEVERE'
        WHEN prev_12 IS NOT NULL AND (idx - prev_12) / prev_12 > 0.10 THEN 'UNHEALTHY'
        ELSE 'NORMAL'
    END AS status
FROM monthly
WHERE year BETWEEN 2021 AND 2025
ORDER BY year, month;

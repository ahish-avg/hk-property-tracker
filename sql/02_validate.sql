-- 02_validate.sql — sanity checks on loaded data (part of 9/20 cleaning task)
-- Not the affordability index itself (that's 9/21). These are health checks only.

USE hk_property;

-- 1. Coverage check: does each series have a continuous monthly run, or are there gaps?
--    (Territory-wide price index, 'ALL' class)
SELECT
    year,
    COUNT(*) AS months_present
FROM price_index_monthly
WHERE class = 'ALL'
GROUP BY year
ORDER BY year;

-- 2. Coverage check: avg_price_monthly by region x class — should be 5 classes x 3 regions = 15 rows/month
SELECT
    year, month,
    COUNT(*) AS rows_present
FROM avg_price_monthly
GROUP BY year, month
HAVING rows_present <> 15
ORDER BY year, month;

-- 3. Outlier scan: price_index should not be negative, zero, or implausibly discontinuous month-to-month
WITH idx AS (
    SELECT
        year, month, class, price_index,
        LAG(price_index) OVER (PARTITION BY class ORDER BY year, month) AS prev_index
    FROM price_index_monthly
    WHERE class = 'ALL'
)
SELECT
    year, month, class, price_index, prev_index,
    ROUND((price_index - prev_index) / prev_index * 100, 2) AS mom_pct_change
FROM idx
WHERE prev_index IS NOT NULL
  AND ABS((price_index - prev_index) / prev_index) > 0.15  -- flag >15% month-on-month swing for manual review
ORDER BY year, month;

-- 4. Outlier scan: avg_price_hkd sanity range (HK$ per sq. metre saleable, should be in a plausible band)
SELECT region, class, MIN(avg_price_hkd) AS min_price, MAX(avg_price_hkd) AS max_price, AVG(avg_price_hkd) AS avg_price
FROM avg_price_monthly
GROUP BY region, class
ORDER BY region, class;

-- 5. income_reference vs RVD data year alignment: which years actually have BOTH price and income data?
--    This is the "time window is only 2021-2025" check the memo calls out.
SELECT DISTINCT p.year
FROM price_index_monthly p
INNER JOIN income_reference i ON p.year = i.year
ORDER BY p.year;

-- 6. Remark flag audit: how many rows are marked provisional ('P') vs revised ('Z')?
SELECT remark, COUNT(*) AS n
FROM price_index_monthly
GROUP BY remark;

SELECT remark, COUNT(*) AS n
FROM avg_price_monthly
GROUP BY remark;

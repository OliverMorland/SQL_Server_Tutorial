# Bonus Exercises — SQL Server

*Six additional moderate exercises using the `nass_training` database.*

These assume you have completed Parts 1–4 of the main tutorial and have the `nass_training` database loaded with all seed data. Each exercise builds on what you've already learned — joins, CTEs, aggregation, and window functions — and asks you to combine them in ways that reflect real analytical work.

Try every challenge before reading the solution. That's still the rule.

---

## Exercise 1 — Year-over-year change with LAG()

The `harvests` table holds both 2023 and 2024 corn rows for four operations. `LAG()` reaches into the *previous* row in a window and pulls a value from it. That's exactly what you need to compute a year-over-year change without a self-join.

```sql
-- For each operation, show corn production in both survey years
-- alongside the change from the prior year
SELECT o.operation_name,
       h.survey_year,
       h.production                                           AS corn_production,
       LAG(h.production) OVER (
           PARTITION BY h.operation_id
           ORDER BY     h.survey_year
       )                                                      AS prior_year_production
FROM   harvests    h
JOIN   operations  o  ON o.operation_id  = h.operation_id
JOIN   commodities cm ON cm.commodity_id = h.commodity_id
WHERE  cm.commodity_name = 'Corn'
ORDER  BY o.operation_name, h.survey_year;
GO
```

`LAG()` returns `NULL` for the first row in each partition — there's no year before 2023. That `NULL` is correct; it's honest. Replacing it with a zero would be a lie.

### Challenge 1

> Extend the query above to add a fourth column, `yoy_change`, showing the 2024 production minus the 2023 production. For operations that only appear in 2024, `yoy_change` should be `NULL`. Show only the 2024 rows so each operation appears once.

<details><summary>Solution (try it first)</summary>

```sql
WITH corn_by_year AS (
    SELECT o.operation_name,
           h.survey_year,
           h.production                                           AS corn_production,
           LAG(h.production) OVER (
               PARTITION BY h.operation_id
               ORDER BY     h.survey_year
           )                                                      AS prior_year_production
    FROM   harvests    h
    JOIN   operations  o  ON o.operation_id  = h.operation_id
    JOIN   commodities cm ON cm.commodity_id = h.commodity_id
    WHERE  cm.commodity_name = 'Corn'
)
SELECT operation_name,
       corn_production,
       prior_year_production,
       corn_production - prior_year_production AS yoy_change
FROM   corn_by_year
WHERE  survey_year = 2024
ORDER  BY yoy_change DESC;
GO
```

Filtering to `survey_year = 2024` *after* the window runs is the key move. If you filtered inside the CTE, `LAG()` would have nothing to look back at and you'd get all NULLs. Do the windowing first; filter the output after.
</details>

---

## Exercise 2 — Anti-join: operations with no 2024 grain harvests

Not every question is "give me rows that match." Some of the most useful queries are "give me rows that *don't* match." The reliable pattern for this is a `LEFT JOIN … WHERE … IS NULL`, sometimes called an anti-join. It's cleaner and faster than `NOT IN` when NULLs might be involved.

```sql
-- Operations that reported NO harvest of any kind in 2024
SELECT o.operation_name,
       o.total_acres
FROM   operations o
LEFT   JOIN harvests h ON h.operation_id = o.operation_id
                      AND h.survey_year  = 2024
WHERE  h.harvest_id IS NULL
ORDER  BY o.operation_name;
GO
```

The join condition includes the year filter — that's intentional. If you put `AND h.survey_year = 2024` in the `WHERE` clause instead, SQL Server evaluates it after the join and silently turns your outer join into an inner join. Year conditions that scope a `LEFT JOIN` belong in the `ON` clause.

### Challenge 2

> Find every operation that planted crops in 2024 but recorded **no grain harvests** (i.e., no harvest where `commodity_group = 'Grains'`) that year. Show the operation name and total farm acreage.

<details><summary>Solution (try it first)</summary>

```sql
SELECT o.operation_name,
       o.total_acres
FROM   operations o
LEFT   JOIN (
    SELECT DISTINCT h.operation_id
    FROM   harvests    h
    JOIN   commodities cm ON cm.commodity_id = h.commodity_id
    WHERE  cm.commodity_group = 'Grains'
    AND    h.survey_year      = 2024
) grains ON grains.operation_id = o.operation_id
WHERE  grains.operation_id IS NULL
ORDER  BY o.total_acres DESC;
GO
```

The subquery in the `FROM` clause collects every operation that *does* have a 2024 grain harvest. The outer `LEFT JOIN … IS NULL` inverts that to find the ones that don't. Sandhill Cattle Co should appear — it reports only Cattle, which is Livestock, not Grains.
</details>

---

## Exercise 3 — Harvest efficiency by commodity

`acres_harvested / acres_planted` is the crop's *completion rate* — what fraction of what was put in the ground was actually brought in. A rate below 90% is worth a second look. Computing it correctly requires the same safe-division discipline from the main tutorial: `NULLIF` the denominator.

### Challenge 3

> For **2024**, compute each commodity's average harvest completion rate as a percentage (one decimal), and label it with a `CASE` expression:
> - `90% or above` → `'On Track'`
> - `80% to below 90%` → `'Watch'`
> - `Below 80%` → `'Poor'`
>
> Show commodity name, completion rate, and label, ordered by completion rate descending.

<details><summary>Solution (try it first)</summary>

```sql
WITH completion AS (
    SELECT cm.commodity_name,
           ROUND(
               100.0 * SUM(h.acres_harvested)
                     / NULLIF(SUM(h.acres_planted), 0),
               1
           ) AS completion_pct
    FROM   harvests    h
    JOIN   commodities cm ON cm.commodity_id = h.commodity_id
    WHERE  h.survey_year = 2024
    GROUP  BY cm.commodity_name
)
SELECT commodity_name,
       completion_pct,
       CASE
           WHEN completion_pct >= 90 THEN 'On Track'
           WHEN completion_pct >= 80 THEN 'Watch'
           ELSE                           'Poor'
       END AS efficiency_label
FROM   completion
ORDER  BY completion_pct DESC;
GO
```

The CTE computes the aggregated ratio first; the outer `SELECT` applies the `CASE` to the finished number. Keeping the `CASE` out of the aggregation layer makes both halves easier to read and change independently.
</details>

---

## Exercise 4 — Chaining two CTEs

A single `WITH` block can hold multiple CTEs separated by commas. The second CTE can reference the first. This is how you build a query in legible steps rather than nesting one subquery inside another inside another.

```sql
-- Two CTEs: the first computes a value per row, the second summarizes it
WITH op_yield AS (
    SELECT o.operation_name,
           cm.commodity_name,
           ROUND(
               SUM(h.production) / NULLIF(SUM(h.acres_harvested), 0),
               1
           ) AS yield_per_acre
    FROM   harvests    h
    JOIN   operations  o  ON o.operation_id  = h.operation_id
    JOIN   commodities cm ON cm.commodity_id = h.commodity_id
    WHERE  cm.commodity_group = 'Grains'
    AND    h.survey_year      = 2024
    GROUP  BY o.operation_name, cm.commodity_name
),
avg_yield AS (
    SELECT commodity_name,
           AVG(yield_per_acre) AS avg_yield
    FROM   op_yield
    GROUP  BY commodity_name
)
SELECT oy.operation_name,
       oy.commodity_name,
       oy.yield_per_acre,
       ay.avg_yield,
       ROUND(oy.yield_per_acre - ay.avg_yield, 1) AS vs_average
FROM   op_yield  oy
JOIN   avg_yield ay ON ay.commodity_name = oy.commodity_name
ORDER  BY oy.commodity_name, vs_average DESC;
GO
```

### Challenge 4

> Using **two chained CTEs**, identify which states' total 2024 corn production is **above the national average for corn-producing states**. First CTE: state totals. Second CTE: the average of those totals. Final `SELECT`: states and their total, filtered to those above average, highest first.

<details><summary>Solution (try it first)</summary>

```sql
WITH state_corn AS (
    SELECT s.state_name,
           SUM(h.production) AS total_corn
    FROM   harvests    h
    JOIN   operations  o  ON o.operation_id  = h.operation_id
    JOIN   counties    c  ON c.county_id     = o.county_id
    JOIN   states      s  ON s.state_code    = c.state_code
    JOIN   commodities cm ON cm.commodity_id = h.commodity_id
    WHERE  cm.commodity_name = 'Corn'
    AND    h.survey_year     = 2024
    GROUP  BY s.state_name
),
national_avg AS (
    SELECT AVG(total_corn) AS avg_corn
    FROM   state_corn
)
SELECT sc.state_name,
       sc.total_corn
FROM   state_corn  sc
CROSS  JOIN national_avg na
WHERE  sc.total_corn > na.avg_corn
ORDER  BY sc.total_corn DESC;
GO
```

`CROSS JOIN` on a single-row CTE is the clean way to bring a scalar into every row without a subquery in the `WHERE` clause. The second CTE produces exactly one row, so the cross join multiplies each state row by one — no fan-out. Iowa and Nebraska should appear.
</details>

---

## Exercise 5 — Conditional aggregation (pivot-style columns)

Sometimes you need one row per entity with separate columns for different categories — a "pivot." SQL Server has a `PIVOT` operator, but conditional aggregation with `CASE` inside `SUM()` is more portable, more readable, and easier to extend:

```sql
SUM(CASE WHEN condition THEN value ELSE 0 END) AS column_name
```

The `ELSE 0` matters. A `NULL` propagates through `SUM` differently than a `0` — for totals, you want zero; for averages, you might want `NULL`. Know which you need.

### Challenge 5

> Produce a **2024 state summary table** with one row per state and three numeric columns: `corn_production`, `soybean_production`, and `winter_wheat_production`. States with no harvest of a given commodity should show `0`. Order by state name.

<details><summary>Solution (try it first)</summary>

```sql
SELECT s.state_name,
       SUM(CASE WHEN cm.commodity_name = 'Corn'
                THEN h.production ELSE 0 END)         AS corn_production,
       SUM(CASE WHEN cm.commodity_name = 'Soybeans'
                THEN h.production ELSE 0 END)         AS soybean_production,
       SUM(CASE WHEN cm.commodity_name = 'Winter Wheat'
                THEN h.production ELSE 0 END)         AS winter_wheat_production
FROM   states      s
LEFT   JOIN counties    c  ON c.state_code    = s.state_code
LEFT   JOIN operations  o  ON o.county_id     = c.county_id
LEFT   JOIN harvests    h  ON h.operation_id  = o.operation_id
                          AND h.survey_year   = 2024
LEFT   JOIN commodities cm ON cm.commodity_id = h.commodity_id
GROUP  BY s.state_name
ORDER  BY s.state_name;
GO
```

All the joins are `LEFT JOIN` so that states with no matching harvests still appear as a row — they'll just have all zeros. If you used `INNER JOIN`, Kansas (which has only Winter Wheat in the data) would disappear from the corn and soybean columns entirely. `LEFT JOIN` keeps the row; `CASE … ELSE 0` fills in the zeros.
</details>

---

## Exercise 6 — Running total with SUM() OVER and ROW_NUMBER()

A running total shows how a cumulative value builds across an ordered set of rows. It's a common ask in reporting: "show me each farm's contribution to the state corn total, in order from largest to smallest." The tool is `SUM() OVER (PARTITION BY … ORDER BY …)` — the same window function family you met in Level 4, but with an `ORDER BY` inside the `OVER` clause to make the sum cumulative rather than complete.

```sql
-- Running total of corn production, cumulating from largest to smallest farm
WITH op_corn AS (
    SELECT s.state_name,
           o.operation_name,
           SUM(h.production) AS corn_production
    FROM   harvests    h
    JOIN   operations  o  ON o.operation_id  = h.operation_id
    JOIN   counties    c  ON c.county_id     = o.county_id
    JOIN   states      s  ON s.state_code    = c.state_code
    JOIN   commodities cm ON cm.commodity_id = h.commodity_id
    WHERE  cm.commodity_name = 'Corn'
    AND    h.survey_year     = 2024
    GROUP  BY s.state_name, o.operation_name
)
SELECT state_name,
       operation_name,
       corn_production,
       SUM(corn_production) OVER (
           PARTITION BY state_name
           ORDER BY     corn_production DESC
       ) AS running_state_total
FROM   op_corn
ORDER  BY state_name, corn_production DESC;
GO
```

### Challenge 6

> Extend the running total query above to add two more columns:
> - `state_total` — the full state corn production (the same number on every row for a given state).
> - `cumulative_pct` — the running total expressed as a percentage of the state total, one decimal. This tells you: "after counting the top N farms, what share of the state's corn production have we accounted for?"
>
> Order by state, then by corn production descending.

<details><summary>Solution (try it first)</summary>

```sql
WITH op_corn AS (
    SELECT s.state_name,
           o.operation_name,
           SUM(h.production) AS corn_production
    FROM   harvests    h
    JOIN   operations  o  ON o.operation_id  = h.operation_id
    JOIN   counties    c  ON c.county_id     = o.county_id
    JOIN   states      s  ON s.state_code    = c.state_code
    JOIN   commodities cm ON cm.commodity_id = h.commodity_id
    WHERE  cm.commodity_name = 'Corn'
    AND    h.survey_year     = 2024
    GROUP  BY s.state_name, o.operation_name
),
windowed AS (
    SELECT state_name,
           operation_name,
           corn_production,
           SUM(corn_production) OVER (
               PARTITION BY state_name
               ORDER BY     corn_production DESC
           )                                                        AS running_state_total,
           SUM(corn_production) OVER (PARTITION BY state_name)      AS state_total
    FROM   op_corn
)
SELECT state_name,
       operation_name,
       corn_production,
       running_state_total,
       state_total,
       ROUND(
           100.0 * running_state_total
                 / NULLIF(state_total, 0),
           1
       ) AS cumulative_pct
FROM   windowed
ORDER  BY state_name, corn_production DESC;
GO
```

Two windows over the same partition: one ordered (for the running total) and one unordered (for the complete state total). SQL Server computes both in a single pass. Notice that `NULLIF` on `state_total` — it can never actually be zero given the data, but the habit of guarding every denominator is more valuable than knowing it's safe this time.
</details>

---

*These six exercises cover the patterns you'll reach for most often in analytical work: temporal comparison, set exclusion, ratio labelling, multi-step derivation, pivoting, and cumulative distribution. The syntax changes; the discipline doesn't.*

# Automating the Farmwork: A Guide to SQL Stored Procedures

*A hands-on tutorial for the USDA NASS agricultural dataset — same discipline, new tool.*

---

## A word before we start

Every Monday morning, somewhere in an agency, an analyst opens SSMS, pastes last week's harvest query, changes a year, and runs it. Then they do it again next Monday. And the Monday after that. That is not a workflow — it is busywork with a human in the middle where a database object should be.

A **stored procedure** is a named, compiled unit of SQL that lives inside the database. You define it once with `CREATE PROCEDURE`, call it with `EXEC`, and from then on the database owns the parsing and optimization. The logic lives in one place. Change it once; every caller gets the fix. The caller passes parameters, not queries — so no caller can accidentally break the SQL by mistyping a keyword. When you're querying millions of NASS survey records, the execution plan cache alone is worth the price of admission.

Think of it as you would a well-named function in any other language — except this function runs on the server, right next to the data. You have written functions before. This is that.

---

## Creating your first procedure

Start simple. A procedure is a wrapper around work you already know how to express.

```sql
USE nass_training;
GO

CREATE PROCEDURE usp_list_commodities
AS
BEGIN
    SELECT commodity_name,
           commodity_group
    FROM   commodities
    ORDER  BY commodity_group, commodity_name;
END;
GO
```

The `usp_` prefix stands for *user stored procedure*. It distinguishes procedures you write from the system procedures SQL Server ships with (which use `sp_`). Some shops use `proc_` or nothing at all — the point is that you pick a convention and hold to it. Name the procedure the way you'd name a function: a verb phrase that says what it does.

Call it:

```sql
EXEC usp_list_commodities;
GO
```

That is the whole loop. Define once. Call as needed.

> **Sybase note:** In Sybase ASE the body uses `AS` and terminates at `GO`. The `BEGIN`/`END` block is optional — ASE infers the boundary from the `GO`. Everything else in this tutorial is character-for-character the same in both engines unless I say otherwise.

---

## Adding parameters

A procedure without parameters is just a saved query. Parameters are where procedures earn their keep — they let the caller vary the inputs while the logic stays fixed.

```sql
CREATE PROCEDURE usp_operations_by_state
    @state_code CHAR(2)
AS
BEGIN
    SELECT o.operation_name,
           c.county_name,
           o.total_acres
    FROM   operations o
    JOIN   counties   c ON c.county_id  = o.county_id
    JOIN   states     s ON s.state_code = c.state_code
    WHERE  s.state_code = @state_code
    ORDER  BY o.total_acres DESC;
END;
GO
```

Call it with Iowa's code:

```sql
EXEC usp_operations_by_state @state_code = 'IA';
GO
```

Always name your parameters in the call. Positional arguments work, but named arguments are self-documenting — a reader does not need to open the procedure definition to know what `'IA'` means. A call is code too; treat it like one.

---

## Default parameter values

Parameters can carry defaults, which let callers omit them when the default is appropriate:

```sql
CREATE PROCEDURE usp_harvest_summary
    @survey_year    INT          = 2024,
    @commodity_name VARCHAR(40)  = 'Corn'
AS
BEGIN
    SELECT s.state_name,
           SUM(h.production)       AS total_production,
           SUM(h.acres_harvested)  AS total_harvested,
           ROUND(
               SUM(h.production) / NULLIF(SUM(h.acres_harvested), 0),
               1
           )                        AS yield_per_acre
    FROM   harvests    h
    JOIN   operations  o  ON o.operation_id  = h.operation_id
    JOIN   counties    c  ON c.county_id     = o.county_id
    JOIN   states      s  ON s.state_code    = c.state_code
    JOIN   commodities cm ON cm.commodity_id = h.commodity_id
    WHERE  cm.commodity_name = @commodity_name
    AND    h.survey_year     = @survey_year
    GROUP  BY s.state_name
    ORDER  BY total_production DESC;
END;
GO
```

Now the caller picks how much they need to say:

```sql
-- Use both defaults (2024 corn):
EXEC usp_harvest_summary;
GO

-- Override just the year:
EXEC usp_harvest_summary @survey_year = 2023;
GO

-- Override both:
EXEC usp_harvest_summary @survey_year = 2024, @commodity_name = 'Soybeans';
GO
```

Notice `NULLIF` is still there on the denominator. The defensive patterns you learned in the main tutorial do not retire just because the code moved into a procedure. Bring them with you wherever you go.

---

### Challenge 1

> Create a stored procedure called `usp_top_operations` that accepts two parameters: `@commodity_name VARCHAR(40)` and `@survey_year INT`. The procedure should return the **top 5 operations** by total production for that commodity and year, showing: operation name, state name, and total production — highest first.

<details><summary>Solution (try it first)</summary>

```sql
CREATE PROCEDURE usp_top_operations
    @commodity_name VARCHAR(40),
    @survey_year    INT
AS
BEGIN
    SELECT TOP 5
           o.operation_name,
           s.state_name,
           SUM(h.production) AS total_production
    FROM   harvests    h
    JOIN   operations  o  ON o.operation_id  = h.operation_id
    JOIN   counties    c  ON c.county_id     = o.county_id
    JOIN   states      s  ON s.state_code    = c.state_code
    JOIN   commodities cm ON cm.commodity_id = h.commodity_id
    WHERE  cm.commodity_name = @commodity_name
    AND    h.survey_year     = @survey_year
    GROUP  BY o.operation_name, s.state_name
    ORDER  BY total_production DESC;
END;
GO

-- Test it:
EXEC usp_top_operations @commodity_name = 'Corn', @survey_year = 2024;
GO
```

`TOP 5` inside the procedure is intentional — the procedure *is* the policy. If you find yourself wanting to make the row count configurable, add a third parameter: `@top_n INT = 5`. A default of 5 means existing callers change nothing; new callers can override it. That is how you extend a procedure without breaking its contract.

</details>

---

## Output parameters

Sometimes you do not want a result set — you want a single scalar the caller can use in further logic. An output parameter delivers that.

```sql
CREATE PROCEDURE usp_total_production
    @commodity_name  VARCHAR(40),
    @survey_year     INT,
    @total           NUMERIC(18,1) OUTPUT
AS
BEGIN
    SELECT @total = SUM(h.production)
    FROM   harvests    h
    JOIN   commodities cm ON cm.commodity_id = h.commodity_id
    WHERE  cm.commodity_name = @commodity_name
    AND    h.survey_year     = @survey_year;
END;
GO
```

The caller declares a variable, passes it, and reads the result:

```sql
DECLARE @corn_total NUMERIC(18,1);

EXEC usp_total_production
    @commodity_name = 'Corn',
    @survey_year    = 2024,
    @total          = @corn_total OUTPUT;

SELECT @corn_total AS total_corn_2024;
GO
```

Declare, pass with `OUTPUT`, read. The pattern is always the same. Output parameters are most useful when the caller is another procedure or a script that needs to branch on the result. If you just need a human to see a number, a regular result set is cleaner.

---

## Variables and conditional logic

Procedures are a real execution environment. You can declare variables, compute intermediate values, and branch on conditions:

```sql
CREATE PROCEDURE usp_classify_state_production
    @state_code     CHAR(2),
    @commodity_name VARCHAR(40),
    @survey_year    INT
AS
BEGIN
    DECLARE @total_production NUMERIC(18,1);

    SELECT @total_production = SUM(h.production)
    FROM   harvests    h
    JOIN   operations  o  ON o.operation_id  = h.operation_id
    JOIN   counties    c  ON c.county_id     = o.county_id
    JOIN   states      s  ON s.state_code    = c.state_code
    JOIN   commodities cm ON cm.commodity_id = h.commodity_id
    WHERE  s.state_code      = @state_code
    AND    cm.commodity_name = @commodity_name
    AND    h.survey_year     = @survey_year;

    SELECT @total_production AS total_production,
           CASE
               WHEN @total_production >= 500000 THEN 'High'
               WHEN @total_production >= 200000 THEN 'Medium'
               WHEN @total_production IS NOT NULL THEN 'Low'
               ELSE 'No data'
           END                AS production_tier;
END;
GO

EXEC usp_classify_state_production
    @state_code     = 'IL',
    @commodity_name = 'Corn',
    @survey_year    = 2024;
GO
```

The `NULL` guard in the `CASE` is load-bearing: if a state has no harvests for that commodity and year, `SUM` returns `NULL`, not zero. Test for `NULL` explicitly or you will silently drop states that simply had no activity — which is different from states that had low activity. The difference matters in agricultural reporting.

---

### Challenge 2

> Create a stored procedure called `usp_year_over_year_change` that accepts `@commodity_name VARCHAR(40)`. For every state that has production data in **both** 2023 and 2024, return: state name, 2023 total production, 2024 total production, and the numeric change (2024 minus 2023) — ordered by the change, largest gain first. Use CTEs inside the procedure body to keep the logic readable.

<details><summary>Solution (try it first)</summary>

```sql
CREATE PROCEDURE usp_year_over_year_change
    @commodity_name VARCHAR(40)
AS
BEGIN
    WITH prod_2023 AS (
        SELECT s.state_name,
               SUM(h.production) AS production
        FROM   harvests    h
        JOIN   operations  o  ON o.operation_id  = h.operation_id
        JOIN   counties    c  ON c.county_id     = o.county_id
        JOIN   states      s  ON s.state_code    = c.state_code
        JOIN   commodities cm ON cm.commodity_id = h.commodity_id
        WHERE  cm.commodity_name = @commodity_name
        AND    h.survey_year     = 2023
        GROUP  BY s.state_name
    ),
    prod_2024 AS (
        SELECT s.state_name,
               SUM(h.production) AS production
        FROM   harvests    h
        JOIN   operations  o  ON o.operation_id  = h.operation_id
        JOIN   counties    c  ON c.county_id     = o.county_id
        JOIN   states      s  ON s.state_code    = c.state_code
        JOIN   commodities cm ON cm.commodity_id = h.commodity_id
        WHERE  cm.commodity_name = @commodity_name
        AND    h.survey_year     = 2024
        GROUP  BY s.state_name
    )
    SELECT p23.state_name,
           p23.production              AS production_2023,
           p24.production              AS production_2024,
           p24.production - p23.production AS change
    FROM   prod_2023 p23
    JOIN   prod_2024 p24 ON p24.state_name = p23.state_name
    ORDER  BY change DESC;
END;
GO

-- Test it:
EXEC usp_year_over_year_change @commodity_name = 'Corn';
GO
```

Two CTEs, one `INNER JOIN` between them. The `JOIN` is intentional: a state that appears in only one year is excluded from the change calculation, because you cannot compute a difference from a single data point. If you want to include those states with a `NULL` for the missing year, swap the `JOIN` for a `FULL OUTER JOIN` and wrap the arithmetic in `COALESCE`. That change is one word and one function call — but it is a meaningful analytical choice, not a typo fix. Know why you wrote the join type you wrote.

CTEs work identically inside a procedure as they do in a standalone query. This is one of the things that makes SQL composable: the tools you know stay the tools you use, wherever you apply them.

</details>

---

## Closing: what stored procedures buy you

The syntax is the easy part. What matters is the habit: every piece of logic that a caller would otherwise copy-and-paste is a candidate for a procedure. Duplicate logic is a liability. The moment a business rule changes — a new commodity group, a revised yield formula — you want to change it in one place, not hunt through a dozen scripts hoping you found them all.

Write procedures the way you write any other code: name them for what they do, keep each one focused on one job, and guard against the bad data you know will eventually arrive. A stored procedure is not a magic box — it is just code that lives closer to the data. Treat it with the same discipline.

# From the Soil Up: A Craftsman's Guide to Sybase and SQL Server

*A hands-on tutorial for handling USDA NASS agricultural data — written in the spirit of software craftsmanship.*

---

## A word before we start

Listen. You already write Python, and you wrote Unity before that, so you know how to think. Good. That means I am not going to insult you by explaining what a loop is. What I *am* going to do is harder and more important: I'm going to ask you to treat SQL the way a craftsman treats any tool — with respect, with discipline, and with the understanding that **code is read far more often than it is written.**

A query you fire off today against the National Agricultural Statistics Service's data will be read next year by some tired analyst at 4:45 on a Friday, trying to figure out why the corn numbers for Iowa look wrong. That analyst might be you. Write for that person. Name things so they reveal intent. Format so the structure is obvious at a glance. Understand every line before you run it — *especially* before you run anything that changes data.

We will work through two dialects: **Sybase (SAP ASE)** first, then **Microsoft SQL Server**. Here is a secret that makes this whole journey easier: they are siblings. In the late 1980s, Microsoft licensed Sybase's source code; SQL Server *was* Sybase for years before they diverged. Both speak a language called **Transact-SQL (T-SQL)**. So when you learn one, you mostly learn the other — and I'll point out the handful of places where the family resemblance breaks down.

Each dialect has four levels — *extremely easy*, *easy*, *moderate*, *challenging* — and each level ends with a challenge. Try every challenge before you read the solution. A challenge you peek at is a workout you watched someone else do.

You are an experienced developer, so there's no Python here. Everything runs in VSCode.

---

## Part 0 — Setting up your workshop

A professional sets up the shop before picking up the chisel. This part has no SQL. Do it once.

### What you need

- **VSCode** (you have it).
- **Docker Desktop** — we'll run both database engines as containers so we never pollute your machine.

### SQL Server — the easy one

Microsoft ships first-class tooling, so start your local server with one command:

Run this in a **PowerShell** terminal inside VSCode (Terminal → New Terminal — PowerShell is the Windows default). PowerShell continues a long line with a backtick `` ` ``, not the Unix backslash:

```powershell
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=Harvest!2025" `
  -p 1433:1433 --name nass-sqlserver `
  -d mcr.microsoft.com/mssql/server:2022-latest
```

If you'd rather not think about line-continuation characters at all, put it on one line — this works in PowerShell *and* in the old Command Prompt (cmd.exe):

```powershell
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=Harvest!2025" -p 1433:1433 --name nass-sqlserver -d mcr.microsoft.com/mssql/server:2022-latest
```

> Docker Desktop on Windows must be running before you fire that command — and Docker on Windows needs the WSL 2 backend (Docker Desktop will prompt you to install it the first time if it isn't already there). The SQL Server image is x64, which is exactly what your Windows PC is, so there's nothing to emulate.

Now the client. In VSCode, install the extension **SQL Server (mssql)** by Microsoft. Then:

1. Open the SQL Server panel in the sidebar → **Add Connection**.
2. Server: `localhost,1433` — User: `sa` — Password: `Harvest!2025` — Trust server certificate: yes.
3. Open any `.sql` file, make sure the connection is selected in the status bar, and run with **Ctrl+Shift+E** or right-click → *Execute Query*.

That's it. SQL Server is ready.

### Sybase (SAP ASE) — the honest truth

I'm going to be straight with you, because a craftsman doesn't hide the rough parts of the job. Sybase is *harder* to stand up locally than SQL Server. SAP does not put a friendly public image on Docker Hub. The realistic path is:

1. Register (free) for the **SAP ASE Developer Edition** installer at SAP's developer center.
2. Build a container from one of the community Dockerfiles (search GitHub for `sap-ase-developer-docker` or `sybase-ase-docker`); you drop the downloaded installer next to the Dockerfile and build. ASE listens on port **5000**.
3. To talk to it from VSCode, install the **DBCode** extension, which supports *SAP ASE (Sybase)* as a connection type directly. Alternatively, `docker exec` into the container and use the bundled `isql` command-line tool right inside VSCode's integrated terminal. Run the first line in your Windows **PowerShell** terminal; that drops you *inside* the container's Linux shell, where the remaining two lines are Linux commands (don't run those in PowerShell):

```powershell
# Run this line in PowerShell on Windows — it opens a shell inside the Linux container:
docker exec -it my-sybase /bin/bash
```

```bash
# You are now inside the container (a Linux prompt). These are Linux commands:
source /opt/sybase/SYBASE.sh
isql -U sa -P <your-password> -S <server-name>
```

With `isql`, you type SQL, then `GO` on its own line to execute a batch. (You'll see `GO` throughout this tutorial — it's the batch terminator both engines' command-line tools understand.)

### The pragmatic move (read this twice)

Because Sybase and SQL Server share the T-SQL core, **every query in the Sybase section of this tutorial also runs on SQL Server**, with only two or three tiny differences I'll flag explicitly. So if you can't get ASE running today, do not sit idle waiting on a download. Run the Sybase exercises against your SQL Server container, keep a note of the dialect differences, and move on. That is exactly what a professional does when the environment fights back: you find the path that keeps you productive, and you write down what you learned. Don't let a missing container stop you from learning the language.

---

## Part 1 — Building the farm: our schema

Every example below uses one small world modeled on how NASS actually thinks about agriculture: **states** contain **counties**, counties contain **operations** (NASS-speak for farms), and each operation reports **harvests** of various **commodities** for a given survey year.

Run this once in each engine. I'll give you the Sybase version in full; the SQL Server version is identical except for one word, which I'll show you.

### Create the database (Sybase)

```sql
CREATE DATABASE nass_training
GO
USE nass_training
GO
```

> If ASE complains about devices or size, it's telling you the default data device is small. For a learning database you can size it explicitly, e.g. `CREATE DATABASE nass_training ON default = 50` (megabytes), or simply create your tables inside an existing database. Know your environment — that complaint is information, not an obstacle.

### Create the tables (Sybase)

Notice the names. Not `tbl1`, not `t_cnty`. Names that say what they are. This is not decoration — it's the cheapest, highest-return discipline in our entire craft.

```sql
CREATE TABLE states (
    state_code  char(2)      NOT NULL,
    state_name  varchar(40)  NOT NULL,
    PRIMARY KEY (state_code)
)
GO

CREATE TABLE counties (
    county_id    int          IDENTITY,
    county_name  varchar(60)  NOT NULL,
    state_code   char(2)      NOT NULL,
    PRIMARY KEY (county_id),
    FOREIGN KEY (state_code) REFERENCES states (state_code)
)
GO

CREATE TABLE commodities (
    commodity_id     int          IDENTITY,
    commodity_name   varchar(40)  NOT NULL,
    commodity_group  varchar(40)  NOT NULL,
    PRIMARY KEY (commodity_id)
)
GO

CREATE TABLE operations (
    operation_id    int          IDENTITY,
    operation_name  varchar(80)  NOT NULL,
    county_id       int          NOT NULL,
    total_acres     int          NOT NULL,
    PRIMARY KEY (operation_id),
    FOREIGN KEY (county_id) REFERENCES counties (county_id)
)
GO

CREATE TABLE harvests (
    harvest_id       int           IDENTITY,
    operation_id     int           NOT NULL,
    commodity_id     int           NOT NULL,
    survey_year      int           NOT NULL,
    acres_planted    numeric(10,1) NOT NULL,
    acres_harvested  numeric(10,1) NOT NULL,
    production       numeric(14,1) NOT NULL,   -- bushels for grain, head for livestock, tons for hay
    PRIMARY KEY (harvest_id),
    FOREIGN KEY (operation_id) REFERENCES operations (operation_id),
    FOREIGN KEY (commodity_id) REFERENCES commodities (commodity_id)
)
GO
```

### The one difference for SQL Server

In SQL Server, an auto-incrementing column wants a seed and step: write `IDENTITY(1,1)` instead of bare `IDENTITY`. Everything else is character-for-character the same. So for SQL Server:

```sql
CREATE DATABASE nass_training;
GO
USE nass_training;
GO
-- ...then paste the same five CREATE TABLE statements,
-- changing every `IDENTITY` to `IDENTITY(1,1)`.
```

That's the first family difference. Note how small it is. Don't Repeat Yourself applies across dialects too — reuse the DDL, change the one token.

### Seed the data (identical in both engines)

The `INSERT` statements below are *exactly the same* in Sybase and SQL Server. Run them once in each database.

```sql
INSERT INTO states (state_code, state_name) VALUES ('IA', 'Iowa')
INSERT INTO states (state_code, state_name) VALUES ('IL', 'Illinois')
INSERT INTO states (state_code, state_name) VALUES ('NE', 'Nebraska')
INSERT INTO states (state_code, state_name) VALUES ('KS', 'Kansas')
INSERT INTO states (state_code, state_name) VALUES ('MN', 'Minnesota')
GO

INSERT INTO counties (county_name, state_code) VALUES ('Story', 'IA')
INSERT INTO counties (county_name, state_code) VALUES ('Polk', 'IA')
INSERT INTO counties (county_name, state_code) VALUES ('McLean', 'IL')
INSERT INTO counties (county_name, state_code) VALUES ('Champaign', 'IL')
INSERT INTO counties (county_name, state_code) VALUES ('Lancaster', 'NE')
INSERT INTO counties (county_name, state_code) VALUES ('Hall', 'NE')
INSERT INTO counties (county_name, state_code) VALUES ('Sedgwick', 'KS')
INSERT INTO counties (county_name, state_code) VALUES ('Blue Earth', 'MN')
GO

INSERT INTO commodities (commodity_name, commodity_group) VALUES ('Corn', 'Grains')
INSERT INTO commodities (commodity_name, commodity_group) VALUES ('Soybeans', 'Oilseeds')
INSERT INTO commodities (commodity_name, commodity_group) VALUES ('Winter Wheat', 'Grains')
INSERT INTO commodities (commodity_name, commodity_group) VALUES ('Cattle', 'Livestock')
INSERT INTO commodities (commodity_name, commodity_group) VALUES ('Hay', 'Forage')
GO

INSERT INTO operations (operation_name, county_id, total_acres) VALUES ('Tallgrass Family Farm', 1, 3200)
INSERT INTO operations (operation_name, county_id, total_acres) VALUES ('Cyclone Acres', 1, 1500)
INSERT INTO operations (operation_name, county_id, total_acres) VALUES ('Prairie Gold Co-op', 2, 5400)
INSERT INTO operations (operation_name, county_id, total_acres) VALUES ('Heartland Grain LLC', 3, 4100)
INSERT INTO operations (operation_name, county_id, total_acres) VALUES ('Illini Fields', 4, 2600)
INSERT INTO operations (operation_name, county_id, total_acres) VALUES ('Platte Valley Farms', 5, 3800)
INSERT INTO operations (operation_name, county_id, total_acres) VALUES ('Sandhill Cattle Co', 6, 6000)
INSERT INTO operations (operation_name, county_id, total_acres) VALUES ('Sunflower State Acres', 7, 2200)
INSERT INTO operations (operation_name, county_id, total_acres) VALUES ('North Star Farms', 8, 2900)
GO

-- 2024 survey year
INSERT INTO harvests (operation_id, commodity_id, survey_year, acres_planted, acres_harvested, production) VALUES (1, 1, 2024, 1800, 1780, 320400)
INSERT INTO harvests (operation_id, commodity_id, survey_year, acres_planted, acres_harvested, production) VALUES (1, 2, 2024, 1200, 1190, 65450)
INSERT INTO harvests (operation_id, commodity_id, survey_year, acres_planted, acres_harvested, production) VALUES (3, 1, 2024, 900, 895, 156625)
INSERT INTO harvests (operation_id, commodity_id, survey_year, acres_planted, acres_harvested, production) VALUES (4, 1, 2024, 3000, 2980, 566200)
INSERT INTO harvests (operation_id, commodity_id, survey_year, acres_planted, acres_harvested, production) VALUES (4, 2, 2024, 1000, 995, 54725)
INSERT INTO harvests (operation_id, commodity_id, survey_year, acres_planted, acres_harvested, production) VALUES (5, 1, 2024, 1500, 1490, 274160)
INSERT INTO harvests (operation_id, commodity_id, survey_year, acres_planted, acres_harvested, production) VALUES (5, 3, 2024, 900, 880, 44000)
INSERT INTO harvests (operation_id, commodity_id, survey_year, acres_planted, acres_harvested, production) VALUES (6, 1, 2024, 2000, 1980, 336600)
INSERT INTO harvests (operation_id, commodity_id, survey_year, acres_planted, acres_harvested, production) VALUES (6, 2, 2024, 1600, 1590, 81090)
INSERT INTO harvests (operation_id, commodity_id, survey_year, acres_planted, acres_harvested, production) VALUES (7, 4, 2024, 5500, 5500, 4200)
INSERT INTO harvests (operation_id, commodity_id, survey_year, acres_planted, acres_harvested, production) VALUES (8, 3, 2024, 1500, 1470, 66150)
INSERT INTO harvests (operation_id, commodity_id, survey_year, acres_planted, acres_harvested, production) VALUES (8, 1, 2024, 600, 595, 101150)
INSERT INTO harvests (operation_id, commodity_id, survey_year, acres_planted, acres_harvested, production) VALUES (9, 5, 2024, 800, 800, 3200)
INSERT INTO harvests (operation_id, commodity_id, survey_year, acres_planted, acres_harvested, production) VALUES (9, 1, 2024, 1500, 1485, 282150)
INSERT INTO harvests (operation_id, commodity_id, survey_year, acres_planted, acres_harvested, production) VALUES (9, 2, 2024, 1200, 1195, 65725)
GO

-- 2023 survey year (for year-over-year work later)
INSERT INTO harvests (operation_id, commodity_id, survey_year, acres_planted, acres_harvested, production) VALUES (1, 1, 2023, 1750, 1740, 296800)
INSERT INTO harvests (operation_id, commodity_id, survey_year, acres_planted, acres_harvested, production) VALUES (4, 1, 2023, 2900, 2880, 489600)
INSERT INTO harvests (operation_id, commodity_id, survey_year, acres_planted, acres_harvested, production) VALUES (6, 1, 2023, 2000, 1975, 326125)
INSERT INTO harvests (operation_id, commodity_id, survey_year, acres_planted, acres_harvested, production) VALUES (9, 1, 2023, 1450, 1440, 244800)
GO
```

A note on the data you just loaded: `production` mixes units on purpose. Corn is in bushels, Cattle is in head, Hay is in tons. The real world is messy like this, and a careless analyst who averages "production" across all commodities produces nonsense. We'll deal with that honestly in the challenges. Mixing incompatible units is a bug, not a feature — your job is to notice.

---

# SYBASE (SAP ASE)

---

## Level 1 — Extremely Easy: reading what's there

The most fundamental act in SQL is asking a table to show you its rows. In `isql`, remember to end each batch with `GO`. In the DBCode/mssql extensions, you just execute.

```sql
USE nass_training
GO

SELECT * FROM commodities
GO
```

That `SELECT *` is fine when you're poking around interactively. But hear me now: **`SELECT *` does not belong in code that lasts.** It hides intent, it breaks silently when someone adds a column, and it hauls back data nobody asked for. Name your columns. Always. Here's the professional version:

```sql
SELECT commodity_name, commodity_group
FROM   commodities
GO
```

Look at the formatting. Keywords lined up, one logical piece per line. You think that's fussy? It's the difference between a query you can scan in two seconds and one you have to decode. Pick a style and hold to it like your name depended on it — because in a shared codebase, it does.

A comment explains *why*, never *what*:

```sql
-- Pull the commodity reference list for the survey codebook
SELECT commodity_name, commodity_group
FROM   commodities
GO
```

### Challenge 1

> List the name of every **state** and its two-letter code, columns named explicitly — no `SELECT *`.

<details><summary>Solution (try it first)</summary>

```sql
SELECT state_name, state_code
FROM   states
GO
```

That's the whole job. The discipline of naming the columns even when "it's just two of them" is what builds the habit you'll need when it's twenty.
</details>

---

## Level 2 — Easy: filtering, sorting, and limiting

A table dump is rarely the answer. You want *the rows that matter, in the order that matters.*

`WHERE` filters. `ORDER BY` sorts. `DISTINCT` removes duplicates.

```sql
-- Operations bigger than 3,000 acres, biggest first
SELECT operation_name, total_acres
FROM   operations
WHERE  total_acres > 3000
ORDER  BY total_acres DESC
GO
```

Combine conditions with `AND` / `OR`, and reach for `BETWEEN`, `IN`, and `LIKE` to keep things readable:

```sql
SELECT operation_name, total_acres
FROM   operations
WHERE  total_acres BETWEEN 2500 AND 5000
ORDER  BY operation_name
GO

SELECT DISTINCT commodity_group
FROM   commodities
GO
```

**Limiting rows — a family difference.** Classic Sybase limits results with `SET ROWCOUNT`:

```sql
SET ROWCOUNT 3
SELECT operation_name, total_acres
FROM   operations
ORDER  BY total_acres DESC
GO
SET ROWCOUNT 0   -- always reset it, or it silently caps every query in your session
GO
```

That `SET ROWCOUNT 0` afterward is not optional. Leaving session state changed behind you is how you hand the next person a mystery bug. Clean up after yourself. (Modern ASE also accepts `SELECT TOP 3 ...`, which is the SQL Server way — we'll lean on that shortly.)

### Challenge 2

> Find every operation **larger than 3,000 acres**, largest first, showing only the operation name and its acreage.

<details><summary>Solution (try it first)</summary>

```sql
SELECT operation_name, total_acres
FROM   operations
WHERE  total_acres > 3000
ORDER  BY total_acres DESC
GO
```

If you got Prairie Gold Co-op (5,400) and Sandhill Cattle Co (6,000) in your results, check your sort direction — Sandhill should be on top.
</details>

---

## Level 3 — Moderate: joining tables and summarizing

Here's where SQL earns its keep. Our data is split across tables on purpose (that's normalization — no sane person stores the state name on every harvest row). To answer real questions, you stitch tables back together with `JOIN`.

Always state your join condition. A join without an `ON` clause is a *cross join* — every row times every row — and it will quietly hand you garbage. Qualify your columns and alias your tables with names that mean something:

```sql
-- Which operation sits in which county and state?
SELECT o.operation_name,
       c.county_name,
       s.state_name
FROM   operations o
JOIN   counties   c ON c.county_id   = o.county_id
JOIN   states     s ON s.state_code  = c.state_code
ORDER  BY s.state_name, c.county_name
GO
```

Note the aliases: `o`, `c`, `s`. Short, but each one obviously stands for its table. I qualify *every* column with its alias even when I don't strictly have to. Why? So the reader never has to guess which table `state_code` came from. Ambiguity is a defect.

Now aggregate. `GROUP BY` collapses rows into groups; `SUM`, `AVG`, `COUNT`, `MIN`, `MAX` summarize each group. `HAVING` filters *after* grouping (where `WHERE` filters *before*):

```sql
-- Total production per commodity, but only grains
-- (remember: mixing units across groups is nonsense)
SELECT cm.commodity_name,
       SUM(h.production) AS total_production
FROM   harvests    h
JOIN   commodities cm ON cm.commodity_id = h.commodity_id
WHERE  cm.commodity_group = 'Grains'
GROUP  BY cm.commodity_name
HAVING SUM(h.production) > 100000
ORDER  BY total_production DESC
GO
```

That `AS total_production` alias is doing real work — it names the result so the next reader knows what the number *is*. A column headed `total_production` is documentation; a column headed by an unlabeled `SUM(h.production)` is a riddle.

### Challenge 3

> For the **2024** survey year, report **total corn production per state**, highest first. Show the state name and the total.

<details><summary>Solution (try it first)</summary>

```sql
SELECT s.state_name,
       SUM(h.production) AS total_corn_production
FROM   harvests    h
JOIN   operations  o  ON o.operation_id = h.operation_id
JOIN   counties    c  ON c.county_id    = o.county_id
JOIN   states      s  ON s.state_code   = c.state_code
JOIN   commodities cm ON cm.commodity_id = h.commodity_id
WHERE  cm.commodity_name = 'Corn'
AND    h.survey_year     = 2024
GROUP  BY s.state_name
ORDER  BY total_corn_production DESC
GO
```

Four joins to walk from a harvest all the way up to its state, two filters in the `WHERE`, one `GROUP BY`. Read it top to bottom — it tells a story. That's the goal.
</details>

---

## Level 4 — Challenging: subqueries, CASE, and computing yield safely

Real NASS work is full of *derived* numbers. The headline metric in crop reporting is **yield** — production divided by harvested acres. Computing it correctly requires care, because (a) you must never divide by zero, and (b) you must never divide bushels of corn by acres and then accidentally fold in head of cattle.

Two tools for this level:

**`CASE`** — inline conditional logic:

```sql
SELECT operation_name,
       total_acres,
       CASE
           WHEN total_acres >= 4000 THEN 'Large'
           WHEN total_acres >= 2500 THEN 'Medium'
           ELSE                          'Small'
       END AS size_class
FROM   operations
ORDER  BY total_acres DESC
GO
```

**Subqueries** — a query inside a query. Here's one that finds operations producing more corn than the average corn-producing operation in 2024:

```sql
SELECT o.operation_name,
       h.production
FROM   harvests    h
JOIN   operations  o  ON o.operation_id  = h.operation_id
JOIN   commodities cm ON cm.commodity_id = h.commodity_id
WHERE  cm.commodity_name = 'Corn'
AND    h.survey_year     = 2024
AND    h.production > (SELECT AVG(h2.production)
                       FROM   harvests    h2
                       JOIN   commodities cm2 ON cm2.commodity_id = h2.commodity_id
                       WHERE  cm2.commodity_name = 'Corn'
                       AND    h2.survey_year     = 2024)
ORDER  BY h.production DESC
GO
```

And the safe-division pattern. `NULLIF(x, 0)` returns `NULL` when `x` is zero, so a divide-by-zero becomes a harmless `NULL` instead of an error. Defensive code is professional code.

### Challenge 4

> Build a **2024 grain-yield report**. For grain commodities **only** (`commodity_group = 'Grains'`), show: state name, commodity name, total production, total harvested acres, and **yield** (production per harvested acre) rounded to one decimal. Order by yield, highest first. Filtering to grains is not optional — it's what stops you from dividing cattle by acres and reporting a fiction.

<details><summary>Solution (try it first)</summary>

```sql
SELECT s.state_name,
       cm.commodity_name,
       SUM(h.production)                                          AS total_production,
       SUM(h.acres_harvested)                                     AS total_harvested,
       ROUND(SUM(h.production) / NULLIF(SUM(h.acres_harvested),0), 1) AS yield_per_acre
FROM   harvests    h
JOIN   operations  o  ON o.operation_id  = h.operation_id
JOIN   counties    c  ON c.county_id     = o.county_id
JOIN   states      s  ON s.state_code    = c.state_code
JOIN   commodities cm ON cm.commodity_id = h.commodity_id
WHERE  cm.commodity_group = 'Grains'
AND    h.survey_year      = 2024
GROUP  BY s.state_name, cm.commodity_name
ORDER  BY yield_per_acre DESC
GO
```

The `NULLIF` around the denominator is the line that separates a query that survives bad data from one that blows up in production. Put it in by reflex.
</details>

---

# MICROSOFT SQL SERVER

---

## What carries over, and what's new

You just learned T-SQL. SQL Server speaks the same language, so almost everything transfers untouched: `SELECT`, `WHERE`, `ORDER BY`, `JOIN`, `GROUP BY`, `HAVING`, `CASE`, subqueries, `NULLIF`, `ROUND`, the `+` for string concatenation, `GETDATE()`, and the `GO` batch terminator all behave the same.

The differences worth knowing:

- **Identity:** `IDENTITY(1,1)` in SQL Server vs bare `IDENTITY` in Sybase (you've already met this one).
- **Limiting rows:** SQL Server uses `TOP n` (and `TOP n PERCENT`, `TOP n WITH TIES`) rather than `SET ROWCOUNT`. Both also support modern `OFFSET … FETCH`.
- **Richer analytics:** SQL Server has had full, mature **window functions** and **common table expressions (CTEs)** for years. Sybase's window support is newer and more limited, so this is genuinely where the two part ways — and where SQL Server starts to feel powerful.

Stand up the SQL Server `nass_training` database now (Part 0 + Part 1, remembering `IDENTITY(1,1)` and the identical `INSERT`s). Then continue.

---

## Level 1 — Extremely Easy: SELECT, and meet TOP

Everything from Sybase Level 1 works here verbatim. The one new tool is `TOP`:

```sql
USE nass_training;
GO

-- Confirm which engine you're actually on — never assume
SELECT @@VERSION;
GO

-- The three largest operations
SELECT TOP 3 operation_name, total_acres
FROM   operations
ORDER  BY total_acres DESC;
GO
```

`TOP` without an `ORDER BY` is a trap: "give me 3 rows" with no defined order means the engine gives you *any* 3, and which 3 can change between runs. If you write `TOP`, write `ORDER BY`. A nondeterministic query is a defect waiting to surprise you.

### Challenge 1

> Show the **three smallest** operations by acreage — name and acres.

<details><summary>Solution (try it first)</summary>

```sql
SELECT TOP 3 operation_name, total_acres
FROM   operations
ORDER  BY total_acres ASC;
GO
```

The only change from the example is the sort direction. Small details, correctly handled, are the whole job.
</details>

---

## Level 2 — Easy: strings, dates, and null-handling

Filtering and sorting are exactly as you learned them. Let's add the everyday functions you'll lean on constantly in reporting work.

```sql
-- String functions: build a readable label
SELECT UPPER(commodity_name) + ' (' + commodity_group + ')' AS commodity_label
FROM   commodities
ORDER  BY commodity_group, commodity_name;
GO

-- Date functions: anchor a query to "last year" relative to today
SELECT YEAR(GETDATE())        AS this_year,
       DATEADD(year, -1, GETDATE()) AS one_year_ago;
GO

-- Null-handling: COALESCE returns the first non-null value
SELECT operation_name,
       COALESCE(total_acres, 0) AS acres_or_zero
FROM   operations;
GO
```

`ISNULL(x, y)` does the same single-replacement job and exists in *both* engines; `COALESCE` is the standard, more flexible form. Prefer the one your team already uses — consistency beats cleverness.

### Challenge 2

> Produce one column for every commodity that reads like `Corn (Grains)` — the name, a space, then the group in parentheses — sorted by group, then by name within each group.

<details><summary>Solution (try it first)</summary>

```sql
SELECT commodity_name + ' (' + commodity_group + ')' AS commodity_label
FROM   commodities
ORDER  BY commodity_group, commodity_name;
GO
```

Two sort keys, in priority order. The result reads like something you'd hand a human — which is the point of a label.
</details>

---

## Level 3 — Moderate: joins, grouping, and your first CTE

Joins, `GROUP BY`, and `HAVING` are identical to the Sybase section, so I won't repeat them. Instead, meet the tool that will most improve the *readability* of your SQL: the **Common Table Expression**.

A CTE is a named, temporary result you define with `WITH` and then use like a table in the query that follows. It is the SQL equivalent of extracting a well-named variable instead of burying a calculation inside a tangle of parentheses. Compare it to the nested subquery from Sybase Level 4 — same logic, but now the intermediate result has a *name*, and names are how we make code speak.

```sql
-- Per-state corn production for 2024, named once, used once
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
)
SELECT state_name, total_corn
FROM   state_corn
ORDER  BY total_corn DESC;
GO
```

One caution SQL Server will eventually teach you the hard way: the statement *before* a `WITH` must be terminated with a semicolon. Get in the habit of ending every statement with `;` and you'll never meet that error. Terminate your statements. It's good hygiene and the standard expects it.

### Challenge 3

> Using a **CTE**, list every state whose **total 2024 corn production exceeds 300,000** bushels, with the total, highest first.

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
)
SELECT state_name, total_corn
FROM   state_corn
WHERE  total_corn > 300000
ORDER  BY total_corn DESC;
GO
```

You *could* have done this by repeating the aggregate in a `HAVING` clause. The CTE version is longer but clearer — and when the logic grows, clarity is what saves you. Choose the form that the next reader will thank you for.
</details>

---

## Level 4 — Challenging: window functions

This is the summit, and it's the clearest example of SQL Server outrunning its Sybase ancestor. **Window functions** let you compute across a set of rows *related to the current row* — a rank, a running total, a share of a group total — **without collapsing your rows** the way `GROUP BY` does. You keep every detail row *and* get the summary alongside it.

The shape is `function() OVER (PARTITION BY … ORDER BY …)`. `PARTITION BY` defines the window (think "reset the calculation for each state"); `ORDER BY` orders rows within it.

```sql
-- Rank each operation's 2024 corn production within its own state,
-- and show each one's share of the state total — detail rows preserved
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
       RANK() OVER (PARTITION BY state_name ORDER BY corn_production DESC) AS state_rank,
       SUM(corn_production) OVER (PARTITION BY state_name)                 AS state_total
FROM   op_corn
ORDER  BY state_name, state_rank;
GO
```

Sit with that for a minute. The same `corn_production` value appears on every row, but `RANK()` and `SUM() OVER` give each row context about its neighbors. That's something a plain `GROUP BY` cannot do, and it's the heart of nearly every analytical report you'll write for NASS.

Useful members of the family: `ROW_NUMBER()` (a strict 1,2,3 with no ties), `RANK()` (ties share a rank, then it skips), `DENSE_RANK()` (ties share, no skip), and `LAG()` / `LEAD()` (reach into the previous or next row — perfect for year-over-year change).

### Challenge 4

> For **2024 corn**, produce **one row per operation** showing: state name, operation name, its corn production, its **rank within the state** (1 = highest), and its **percentage share** of that state's total corn production (one decimal). Order by state, then by rank.

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
)
SELECT state_name,
       operation_name,
       corn_production,
       RANK() OVER (PARTITION BY state_name ORDER BY corn_production DESC) AS state_rank,
       ROUND(
           100.0 * corn_production
                 / SUM(corn_production) OVER (PARTITION BY state_name),
           1
       ) AS pct_of_state
FROM   op_corn
ORDER  BY state_name, state_rank;
GO
```

Two windows over the same partition: one to rank, one to total for the percentage. Note the `100.0` — a literal with a decimal point forces real division instead of integer division. Forget the `.0` and you'll get a column of zeros and waste an hour. Small thing; big consequence. The craft lives in details like that.

**Stretch goal:** add a `LAG()` window partitioned by operation and ordered by `survey_year` to show each operation's 2023→2024 change in corn production. You have 2023 rows for four operations waiting for exactly this.
</details>

---

## Closing: the part that outlasts the syntax

You now have the four levels in both dialects, and you've seen that "learning Sybase then SQL Server" is mostly learning *one* language well and noting where the family split. The syntax you'll find in any reference. What I want you to carry out of here is the disciplines, because those are what make you trustworthy with NASS's data:

- **Name things so they reveal intent** — tables, columns, aliases, result columns. Naming is the cheapest documentation you will ever write.
- **Format for the reader.** Consistent keywords, one clause per line, qualified columns. You write a query once; it's read for years.
- **Never `SELECT *` in anything that lasts.** Say what you mean.
- **Guard against bad data** — `NULLIF` your denominators, never mix units across commodity groups, force decimal division when you need it.
- **Reset session state** you change (`SET ROWCOUNT 0`), terminate your statements, and clean up after yourself.
- **And the rule that matters most when you touch production data:** before you ever run an `UPDATE` or `DELETE`, run the `SELECT` with the *same* `WHERE` clause first and look at exactly which rows you're about to change. The database holding the nation's agricultural statistics is a shared resource and a public trust. Treat it like one.

Make it work, make it right, keep it clean. In that order, and never skip the last two. Now go write something an exhausted analyst will bless you for on a Friday afternoon.

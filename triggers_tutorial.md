# The Watchful Fields: A Guide to SQL Triggers

*A hands-on tutorial for the USDA NASS agricultural dataset — reacting to change, automatically.*

---

## A word before we start

A trigger is a procedure that fires itself. You do not call it — the database calls it, automatically, the moment a row is inserted, updated, or deleted on a table you've attached the trigger to. It is the closest thing SQL has to an event listener.

That power comes with a warning I will not bury in a footnote: **triggers are invisible to the caller.** An analyst who inserts a harvest record has no idea a trigger is running. If that trigger writes to another table, sends an alert, or rolls back the transaction, the caller only sees the effect — not the cause. That opacity is exactly why triggers are the right tool for some jobs and exactly the wrong tool for others. The right jobs: audit logging, enforcing constraints that `CHECK` cannot express, keeping denormalized summary tables synchronized. The wrong jobs: business logic that belongs in application code, anything so complex it needs a debugger.

Use them deliberately. Document them. And when something mysterious happens to your data, check the triggers first.

---

## Before you begin: add an audit table

The most common legitimate use of a trigger is audit logging — recording who changed what and when. Add this table to `nass_training` before running any of the examples below. It has no relationship to the survey data; it just watches it.

```sql
USE nass_training;
GO

CREATE TABLE harvest_audit (
    audit_id      INT           IDENTITY(1,1)  PRIMARY KEY,
    action_type   VARCHAR(6)    NOT NULL,           -- INSERT, UPDATE, DELETE
    harvest_id    INT           NOT NULL,
    operation_id  INT,
    commodity_id  INT,
    survey_year   INT,
    production    NUMERIC(14,1),
    changed_at    DATETIME      NOT NULL  DEFAULT GETDATE(),
    changed_by    VARCHAR(128)  NOT NULL  DEFAULT SYSTEM_USER
);
GO
```

`SYSTEM_USER` is a built-in that returns the login name of whoever is running the statement. `GETDATE()` timestamps the moment the trigger fires. Both are free — no caller has to pass them in, and no caller can forget to. That is one of the real advantages of a trigger over application-level logging: you cannot opt out.

> **Sybase note:** `SYSTEM_USER` and `GETDATE()` work identically in Sybase ASE. `IDENTITY` without `(1,1)` is the ASE form; adjust as you learned in the main tutorial. Everything else below runs unchanged.

---

## Your first trigger: AFTER INSERT

A trigger on a table fires in response to a DML event (`INSERT`, `UPDATE`, or `DELETE`). `AFTER` (SQL Server's keyword; Sybase uses `FOR`, which SQL Server also accepts) means the trigger runs *after* the row has been written to the table and constraints have been checked — but while the transaction is still open, so it can still be rolled back.

```sql
CREATE TRIGGER trg_harvests_audit_insert
ON harvests
AFTER INSERT
AS
BEGIN
    INSERT INTO harvest_audit (action_type, harvest_id, operation_id,
                                commodity_id, survey_year, production)
    SELECT 'INSERT',
           i.harvest_id,
           i.operation_id,
           i.commodity_id,
           i.survey_year,
           i.production
    FROM   inserted i;
END;
GO
```

Two things to notice.

First: **the `inserted` pseudo-table.** Inside any `INSERT` or `UPDATE` trigger, the database gives you a virtual table called `inserted` that contains the rows that were just written. It has the same columns as the table the trigger is on. You do not create it, declare it, or join it to anything external — it is just there.

Second: the `FROM inserted` is a set-based operation, not a row-by-row loop. A single `INSERT` statement that writes a thousand rows fires this trigger *once*, and `inserted` holds all thousand rows. Always write your trigger logic against the full set. A trigger that assumes `inserted` holds exactly one row will silently produce wrong results — or miss rows entirely — when a bulk load arrives. Bulk loads are exactly when you need your audit trail the most.

Test it:

```sql
-- Insert a new harvest row:
INSERT INTO harvests (operation_id, commodity_id, survey_year,
                      acres_planted, acres_harvested, production)
VALUES (2, 1, 2024, 400, 395, 71100);
GO

-- Confirm the audit record appeared:
SELECT *
FROM   harvest_audit;
GO
```

The audit row is there. You wrote no code in the INSERT statement to put it there.

---

### Challenge 1

> Extend the audit coverage. Create two more triggers — `trg_harvests_audit_update` and `trg_harvests_audit_delete` — so that every change to the `harvests` table is logged in `harvest_audit`. For **UPDATE**, log the **new** values (what the row looks like after the change). For **DELETE**, log the row **as it was** before it was removed.

*Hint: for a `DELETE` trigger, the rows being removed live in a pseudo-table called `deleted`, not `inserted`.*

<details><summary>Solution (try it first)</summary>

```sql
CREATE TRIGGER trg_harvests_audit_update
ON harvests
AFTER UPDATE
AS
BEGIN
    -- `inserted` holds the post-update (new) values
    INSERT INTO harvest_audit (action_type, harvest_id, operation_id,
                                commodity_id, survey_year, production)
    SELECT 'UPDATE',
           i.harvest_id,
           i.operation_id,
           i.commodity_id,
           i.survey_year,
           i.production
    FROM   inserted i;
END;
GO

CREATE TRIGGER trg_harvests_audit_delete
ON harvests
AFTER DELETE
AS
BEGIN
    -- `deleted` holds the pre-delete (old) values
    INSERT INTO harvest_audit (action_type, harvest_id, operation_id,
                                commodity_id, survey_year, production)
    SELECT 'DELETE',
           d.harvest_id,
           d.operation_id,
           d.commodity_id,
           d.survey_year,
           d.production
    FROM   deleted d;
END;
GO
```

Now test the whole lifecycle:

```sql
-- Update the row we inserted in the example above:
UPDATE harvests
SET    production = 72000
WHERE  harvest_id = (SELECT MAX(harvest_id) FROM harvests);
GO

-- Delete it:
DELETE FROM harvests
WHERE  harvest_id = (SELECT MAX(harvest_id) FROM harvests);
GO

-- Review the full audit trail:
SELECT action_type, harvest_id, production, changed_at, changed_by
FROM   harvest_audit
ORDER  BY audit_id;
GO
```

Three rows in `harvest_audit`: one INSERT, one UPDATE, one DELETE. That is a complete history of a row's life — enough for a regulator, an auditor, or a tired analyst trying to figure out where a number came from.

For an UPDATE, `inserted` holds the new values and `deleted` holds the old ones simultaneously. If you need to log *both* — a before/after pair — join them on the primary key: `FROM inserted i JOIN deleted d ON d.harvest_id = i.harvest_id`. That pattern is how you build a full change log, not just a snapshot log.

</details>

---

## The `inserted` and `deleted` tables, fully mapped

Before going further, here is the complete picture:

| Event    | `inserted`          | `deleted`           |
|----------|---------------------|---------------------|
| INSERT   | New rows            | Empty               |
| UPDATE   | Rows after update   | Rows before update  |
| DELETE   | Empty               | Rows being removed  |

Commit this to memory. Every trigger logic mistake I have seen traces back to reaching for the wrong table.

---

## Validation triggers: enforcing rules the schema cannot

A `CHECK` constraint covers simple column-level rules: `total_acres > 0`, for example. But some rules span two columns: `acres_harvested` cannot exceed `acres_planted`, because you cannot harvest more than you plant. A `CHECK` constraint handles that if both columns are on the same table — and in this schema they are, so a `CHECK` would work here. But triggers handle the cases that `CHECK` cannot: rules that involve other tables, rules that depend on aggregated state, or rules that need to produce informative error messages.

Here is the pattern:

```sql
CREATE TRIGGER trg_harvests_validate_acres
ON harvests
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM   inserted
        WHERE  acres_harvested > acres_planted
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50001, 'acres_harvested cannot exceed acres_planted.', 1;
    END;
END;
GO
```

`ROLLBACK TRANSACTION` inside a trigger voids the entire statement that caused the trigger to fire. The row that violated the rule never lands in the table. `THROW` then surfaces an error message to the caller with a meaningful description of what went wrong. Error number 50001–2147483647 is the user-defined range; pick something above 50000 and document it.

Notice the structure: check the bad condition with `IF EXISTS`, then roll back and throw. Do not write `IF NOT EXISTS ... ELSE rollback` — the positive guard is harder to read, and in trigger code you want the exceptional path to stand out.

> **Sybase note:** `THROW` is SQL Server 2012+. In Sybase ASE, use `RAISERROR` instead:
> ```sql
> RAISERROR 50001 'acres_harvested cannot exceed acres_planted.'
> ```
> The rollback-then-raise pattern is identical in both engines; only the error-raising syntax differs.

Test it:

```sql
-- This should be rejected:
INSERT INTO harvests (operation_id, commodity_id, survey_year,
                      acres_planted, acres_harvested, production)
VALUES (1, 1, 2024, 500, 600, 108000);
GO
-- Expected: Msg 50001, 'acres_harvested cannot exceed acres_planted.'

-- This should succeed:
INSERT INTO harvests (operation_id, commodity_id, survey_year,
                      acres_planted, acres_harvested, production)
VALUES (1, 1, 2024, 500, 490, 88200);
GO
```

---

### Challenge 2

> The `harvests` table records production as a raw number, but the unit depends on the commodity — bushels for grain, head for livestock, tons for hay. A well-known data quality rule at NASS is that livestock production should never appear alongside a grain `commodity_group` in the same harvest row, and vice versa. Create a trigger called `trg_harvests_validate_commodity_group` that fires on `INSERT` and `UPDATE` to `harvests`. The trigger should reject any row where the commodity's group is `'Livestock'` but the `production` value exceeds 100,000, or where the group is `'Grains'` but production is less than 1 (a zero or negative grain harvest is suspicious). Roll back and throw an informative error for each case.
>
> *This is a simplified rule invented for the exercise. Real NASS validation is more nuanced — but the shape of the problem is real.*

<details><summary>Solution (try it first)</summary>

```sql
CREATE TRIGGER trg_harvests_validate_commodity_group
ON harvests
AFTER INSERT, UPDATE
AS
BEGIN
    -- Livestock with suspiciously high head count
    IF EXISTS (
        SELECT 1
        FROM   inserted i
        JOIN   commodities cm ON cm.commodity_id = i.commodity_id
        WHERE  cm.commodity_group = 'Livestock'
        AND    i.production       > 100000
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50002,
              'Livestock production exceeds 100,000 head — verify units before inserting.',
              1;
    END;

    -- Grain with zero or negative production
    IF EXISTS (
        SELECT 1
        FROM   inserted i
        JOIN   commodities cm ON cm.commodity_id = i.commodity_id
        WHERE  cm.commodity_group = 'Grains'
        AND    i.production       < 1
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50003,
              'Grain production is zero or negative — this row requires review.',
              1;
    END;
END;
GO
```

Test both paths:

```sql
-- Should fail — 500,000 head of cattle is not plausible:
INSERT INTO harvests (operation_id, commodity_id, survey_year,
                      acres_planted, acres_harvested, production)
VALUES (7, 4, 2024, 5000, 5000, 500000);
GO

-- Should fail — zero-bushel corn harvest is suspicious:
INSERT INTO harvests (operation_id, commodity_id, survey_year,
                      acres_planted, acres_harvested, production)
VALUES (1, 1, 2024, 1000, 990, 0);
GO

-- Should succeed — plausible cattle record:
INSERT INTO harvests (operation_id, commodity_id, survey_year,
                      acres_planted, acres_harvested, production)
VALUES (7, 4, 2024, 5000, 5000, 3800);
GO
```

A few things worth absorbing from this solution.

The trigger joins `inserted` to `commodities`. That join is what makes this rule impossible to express as a simple `CHECK` constraint — a `CHECK` only sees the row being written, not the `commodity_group` sitting in another table. The trigger can reach across tables; a `CHECK` cannot.

The two `IF EXISTS` blocks are independent checks, not nested. Each one rolls back and throws its own message. If you nested them, the first failure would prevent the second check from ever running, which means you might surface one error when two rules were violated. Independent blocks produce cleaner diagnostics.

And the error messages name the problem in terms a domain expert understands: "500,000 head of cattle" and "zero-bushel corn." Not "constraint violation at row 14." Error messages are documentation the user reads at the worst possible moment — write them for that moment.

</details>

---

## Managing triggers: viewing, disabling, dropping

Triggers are objects in the database. You can inspect, disable, and remove them.

```sql
-- See all triggers on the harvests table:
SELECT name,
       type_desc,
       is_disabled
FROM   sys.triggers
WHERE  parent_id = OBJECT_ID('harvests');
GO

-- Disable a trigger temporarily (useful during bulk loads):
DISABLE TRIGGER trg_harvests_audit_insert ON harvests;
GO

-- Re-enable it:
ENABLE TRIGGER trg_harvests_audit_insert ON harvests;
GO

-- Remove a trigger permanently:
DROP TRIGGER trg_harvests_validate_acres;
GO
```

The `DISABLE` / `ENABLE` pair is important to know. When you need to load a hundred thousand historical harvest rows, firing an audit trigger on each one will fill your audit table with noise and slow the load. Disable the trigger, run the bulk load, re-enable it. Document that you did it. The audit trail will have a gap — that gap should be visible, not invisible.

A trigger you cannot disable is a trigger that will cost you someday. Design accordingly.

---

## Closing: what triggers are for

A trigger is not a place to hide business logic. It is a place to enforce guarantees the schema cannot express and to observe changes that callers cannot be trusted to log themselves. Audit trails belong here. Cross-table constraints belong here. Updating a pre-aggregated summary table when the source data changes belongs here.

Application logic, workflow routing, notifications — those belong in the application. The temptation to sneak them into a trigger is real, because triggers are powerful and the database is always running. Resist it. The analyst who gets a mysterious rollback at 4:45 on a Friday because a trigger they did not know existed enforced a rule they did not know applied — that analyst will not thank you.

Write triggers narrowly. Document them prominently. And when something unexpected happens to your data, look at the triggers first.

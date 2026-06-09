USE nass_training;
GO

-- CREATE TRIGGER trg_harvests_audit_insert
-- ON harvests
-- AFTER INSERT
-- AS
-- BEGIN
--     INSERT INTO harvest_audit (action_type, harvest_id, operation_id,
--                                 commodity_id, survey_year, production)
--     SELECT 'INSERT',
--            i.harvest_id,
--            i.operation_id,
--            i.commodity_id,
--            i.survey_year,
--            i.production
--     FROM   inserted i;
-- END;
-- GO

-- Insert a new harvest row:
-- INSERT INTO harvests (operation_id, commodity_id, survey_year,
--                       acres_planted, acres_harvested, production)
-- VALUES (2, 1, 2024, 400, 395, 71100);
-- GO

-- -- Confirm the audit record appeared:
-- SELECT *
-- FROM   harvest_audit;
-- GO

-- CREATE TRIGGER trg_harvests_audit_update
-- ON harvests
-- AFTER UPDATE
-- AS
-- BEGIN
--     INSERT INTO harvest_audit (action_type, 
--     harvest_id, 
--     operation_id,
--     commodity_id,
--     survey_year,
--     production)
--     SELECT 'UPDATE',
--            i.harvest_id,
--            i.operation_id,
--            i.commodity_id,
--            i.survey_year,
--            i.production
--     FROM   inserted i;
-- END;
-- GO

-- CREATE TRIGGER trg_harvests_audit_delete
-- ON harvests
-- AFTER DELETE
-- AS
-- BEGIN
--     INSERT INTO harvest_audit (action_type,
--     harvest_id,
--     operation_id,
--     commodity_id,
--     survey_year,
--     production)
--     SELECT 'DELETE',
--               d.harvest_id,
--               d.operation_id,
--               d.commodity_id,
--               d.survey_year,
--               d.production
--     FROM   deleted d;
-- END;
-- GO

-- SELECT h.harvest_id, o.operation_name, h.production FROM harvests h
-- JOIN operations o ON h.operation_id = o.operation_id

-- DROP TRIGGER IF EXISTS trg_harvests_validate_commodity_group;
-- GO

-- CREATE TRIGGER trg_harvests_validate_commodity_group
-- ON harvests
-- AFTER INSERT, UPDATE
-- AS
-- BEGIN
--     -- Livestock with suspiciously high head count
--     IF EXISTS (
--         SELECT 1
--         FROM   inserted i
--         JOIN   commodities cm ON cm.commodity_id = i.commodity_id
--         WHERE  cm.commodity_group = 'Livestock'
--         AND    i.production       > 100000
--     )
--     BEGIN
--         ROLLBACK TRANSACTION;
--         THROW 50002,
--               'Livestock production exceeds 100,000 head — verify units before inserting.',
--               1;
--     END;

--     -- Grain with zero or negative production
--     IF EXISTS (
--         SELECT 1
--         FROM   inserted i
--         JOIN   commodities cm ON cm.commodity_id = i.commodity_id
--         WHERE  cm.commodity_group = 'Grains'
--         AND    i.production       < 1
--     )
--     BEGIN
--         ROLLBACK TRANSACTION;
--         THROW 50003,
--               'Grain production is zero or negative — this row requires review.',
--               1;
--     END;
-- END;
-- GO


-- INSERT INTO harvests (operation_id,
-- commodity_id,
-- survey_year,
-- acres_planted,
-- acres_harvested,
-- production)
-- VALUES (4, 4, 2024, 1000, 1000, 1000000000);
-- GO

-- SELECT commodity_id, commodity_name, commodity_group FROM commodities;

-- SELECT h.harvest_id, h.production, c.commodity_id, c.commodity_group
-- FROM harvests h
-- JOIN commodities c ON h.commodity_id = c.commodity_id

-- See all triggers on the harvests table:
SELECT name,
       type_desc,
       is_disabled
FROM   sys.triggers
WHERE  parent_id = OBJECT_ID('harvests');
GO

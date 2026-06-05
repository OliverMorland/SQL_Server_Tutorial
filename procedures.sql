USE nass_training;
GO

-- CREATE PROCEDURE production_by_state_yoy_change
-- @commodity_name VARCHAR(50) = 'Corn'
-- AS
-- BEGIN
-- WITH state_production AS (
-- SELECT
-- s.state_name,
-- c.commodity_name,
-- h.survey_year,
-- SUM(h.production) AS state_production,
-- LAG(SUM(h.production)) OVER (PARTITION BY s.state_name ORDER BY h.survey_year) AS previous_year_production
-- FROM harvests h
-- JOIN operations o ON h.operation_id = o.operation_id
-- JOIN counties co ON o.county_id = co.county_id
-- JOIN states s ON co.state_code = s.state_code
-- JOIN commodities c ON h.commodity_id = c.commodity_id
-- WHERE c.commodity_name = @commodity_name
-- GROUP BY s.state_name, c.commodity_name, h.survey_year
-- )
-- SELECT
-- state_production.state_name,
-- (state_production.state_production - state_production.previous_year_production) AS yoy_change
-- FROM state_production
-- WHERE (state_production.state_production - state_production.previous_year_production) IS NOT NULL
-- ORDER BY state_production.state_name, yoy_change DESC;
-- END;

EXEC production_by_state_yoy_change @commodity_name = 'Corn';

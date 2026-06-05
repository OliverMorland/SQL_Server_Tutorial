USE nass_training;
GO

-- CREATE PROCEDURE usp_top_operations
-- @commodity_name VARCHAR(40),
-- @survey_year INT,
-- @count INT = 5
-- AS
-- BEGIN
-- SELECT TOP (@count)
-- o.operation_name,
-- h.survey_year,
-- c.commodity_name,
-- s.state_name,
-- (SUM(h.production)) AS total_production
-- FROM operations o
-- JOIN harvests h ON h.operation_id = o.operation_id
-- JOIN commodities c ON c.commodity_id = h.commodity_id
-- JOIN counties co ON co.county_id = o.county_id
-- JOIN states s ON s.state_code = co.state_code
-- WHERE c.commodity_name = @commodity_name AND h.survey_year = @survey_year
-- GROUP BY o.operation_name, h.survey_year, c.commodity_name, s.state_name
-- ORDER BY total_production DESC
-- END;

EXEC usp_top_operations 
@commodity_name = 'Corn',
@survey_year = 2023,
@count = 1000;

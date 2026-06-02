USE nass_training
GO

SELECT s.state_name, c.commodity_name, SUM(h.production) AS total_production
FROM harvests h
JOIN commodities c ON h.commodity_id = c.commodity_id
JOIN operations o ON h.operation_id = o.operation_id
JOIN counties co ON o.county_id = co.county_id
JOIN states s ON co.state_code = s.state_code
WHERE h.survey_year = 2024 AND c.commodity_name = 'Corn'
GROUP BY s.state_name, c.commodity_name
ORDER BY total_production DESC
GO
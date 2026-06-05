USE nass_training
GO

SELECT 
s.state_name, 
c.commodity_name, 
SUM(h.production) AS total_production, 
SUM(h.acres_harvested) AS total_acres_harvested, 
ROUND((SUM(h.production) / NULLIF(SUM(h.acres_harvested),0)), 1) AS yield_per_acre
FROM harvests h 
JOIN commodities c ON h.commodity_id = c.commodity_id
JOIN operations o ON h.operation_id = o.operation_id
JOIN counties co ON o.county_id = co.county_id
JOIN states s ON co.state_code = s.state_code
WHERE c.commodity_group = 'Grains'
GROUP BY s.state_name, c.commodity_name
ORDER BY yield_per_acre DESC
GO
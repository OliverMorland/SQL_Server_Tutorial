USE nass_training;
GO

SELECT @@VERSION;
GO

WITH corn_harvest AS (
    SELECT operation_name, 
    state_name,
    SUM (h.production) AS total_operation_production
    FROM operations o
    JOIN counties c ON o.county_id = c.county_id
    JOIN states s ON c.state_code = s.state_code
    JOIN harvests h ON o.operation_id = h.operation_id
    JOIN commodities com ON h.commodity_id = com.commodity_id
    WHERE com.commodity_name = 'Corn'
    GROUP BY o.operation_name, s.state_name
)
SELECT 
operation_name, 
state_name, 
total_operation_production,
SUM (total_operation_production) OVER (PARTITION BY state_name) AS total_state_production,
(total_operation_production * 100.0) / NULLIF(SUM (total_operation_production) OVER (PARTITION BY state_name), 0) AS percent_of_state_production,
RANK() OVER (PARTITION BY state_name ORDER BY total_operation_production DESC) AS rank_within_state
FROM corn_harvest
ORDER BY state_name, rank_within_state
GO
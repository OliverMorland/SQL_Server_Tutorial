USE nass_training
GO

-- Operations that reported NO harvest of any kind in 2024
SELECT o.operation_name, c.commodity_group
FROM operations o
LEFT JOIN harvests h ON o.operation_id = h.operation_id
LEFT JOIN commodities c ON h.commodity_id = c.commodity_id
WHERE h.survey_year = 2024
GO

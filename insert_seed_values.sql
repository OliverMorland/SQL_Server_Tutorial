INSERT INTO states (state_code, state_name) VALUES ('IA', 'Iowa')
INSERT into states (state_code, state_name) VALUES ('IL', 'Illinois')
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
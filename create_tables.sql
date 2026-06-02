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
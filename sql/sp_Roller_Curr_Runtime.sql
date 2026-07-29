/*
    Active roller runtime + limit for component monitoring dashboard.

    Returns END_YN = 'N' rows with RUNTIME_LIMIT_HOUR from TB_ROLLER_TRACKER.
    Optional @RollerId filters to one roller; @OnlyActive kept for compatibility.

    EXEC dbo.sp_Roller_Curr_Runtime
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Roller_Curr_Runtime
    @RollerId   VARCHAR(30) = NULL,
    @OnlyActive BIT         = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        COMPANY,
        FACTORY,
        ROLLER_ID,
        ROLLER_SEQ,
        BIN_LOCATION_CD,
        REPLACE_DT,
        RUNTIME_SEC,
        RUNTIME_LIMIT_HOUR,
        END_YN
    FROM dbo.TB_ROLLER_TRACKER
    WHERE (@OnlyActive = 0 OR END_YN = 'N')
      AND (@RollerId IS NULL OR ROLLER_ID = @RollerId)
    ORDER BY BIN_LOCATION_CD, ROLLER_SEQ;
END;
GO

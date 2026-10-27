/*
    Limit-change history for a roller (newest first).

    EXEC dbo.sp_Roller_LimitHistory_Select @RollerId = 'ST0009_0001'
    EXEC dbo.sp_Roller_LimitHistory_Select @BinLocation = 'ST0009_0001'
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Roller_LimitHistory_Select
    @RollerId     VARCHAR(30)  = NULL,
    @BinLocation  VARCHAR(50)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF ( @RollerId IS NULL OR LTRIM(RTRIM(@RollerId)) = '' )
       AND ( @BinLocation IS NULL OR LTRIM(RTRIM(@BinLocation)) = '' )
    BEGIN
        RAISERROR(N'RollerId or BinLocation is required.', 16, 1);
        RETURN;
    END;

    SELECT
        h.HIST_ID,
        h.ROLLER_ID,
        h.BIN_LOCATION_CD,
        h.OLD_LIMIT_HOUR,
        h.NEW_LIMIT_HOUR,
        h.CHANGED_DT,
        h.CHANGED_BY
    FROM dbo.TB_ROLLER_LIMIT_HISTORY h
    WHERE (
            @RollerId IS NOT NULL
            AND LTRIM(RTRIM(@RollerId)) <> ''
            AND h.ROLLER_ID = @RollerId
          )
       OR (
            (@RollerId IS NULL OR LTRIM(RTRIM(@RollerId)) = '')
            AND h.BIN_LOCATION_CD = @BinLocation
          )
    ORDER BY h.CHANGED_DT DESC, h.HIST_ID DESC;
END;
GO

/*
    Batch update active roller runtime limits; log each change.

    EXEC dbo.sp_Roller_Runtime_Limit_BatchUpdate
        @RollerIds = 'ST0009_0001,ST0009_0002',
        @RuntimeLimit = 4000
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Roller_Runtime_Limit_BatchUpdate
    @RollerIds     NVARCHAR(MAX),
    @RuntimeLimit  DECIMAL(10, 2),
    @ChangedBy     NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @RuntimeLimit IS NULL OR @RuntimeLimit <= 0
    BEGIN
        RAISERROR(N'RuntimeLimit must be greater than zero.', 16, 1);
        RETURN;
    END;

    ;WITH IdList AS (
        SELECT LTRIM(RTRIM(value)) AS ROLLER_ID
        FROM STRING_SPLIT(@RollerIds, ',')
        WHERE LTRIM(RTRIM(value)) <> ''
    ),
    Targets AS (
        SELECT
            t.ROLLER_ID,
            t.BIN_LOCATION_CD,
            t.RUNTIME_LIMIT_HOUR AS OLD_LIMIT_HOUR
        FROM dbo.TB_ROLLER_TRACKER AS t
        INNER JOIN IdList AS i ON i.ROLLER_ID = t.ROLLER_ID
        WHERE t.END_YN = 'N'
          AND (
              t.RUNTIME_LIMIT_HOUR IS NULL
              OR CAST(t.RUNTIME_LIMIT_HOUR AS DECIMAL(10, 2)) <> @RuntimeLimit
          )
    )
    INSERT INTO dbo.TB_ROLLER_LIMIT_HISTORY (
        ROLLER_ID, BIN_LOCATION_CD, OLD_LIMIT_HOUR, NEW_LIMIT_HOUR, CHANGED_DT, CHANGED_BY
    )
    SELECT
        ROLLER_ID,
        BIN_LOCATION_CD,
        OLD_LIMIT_HOUR,
        @RuntimeLimit,
        SYSUTCDATETIME(),
        NULLIF(LTRIM(RTRIM(@ChangedBy)), N'')
    FROM Targets;

    ;WITH IdList AS (
        SELECT LTRIM(RTRIM(value)) AS ROLLER_ID
        FROM STRING_SPLIT(@RollerIds, ',')
        WHERE LTRIM(RTRIM(value)) <> ''
    )
    UPDATE t
       SET t.RUNTIME_LIMIT_HOUR = @RuntimeLimit
    FROM dbo.TB_ROLLER_TRACKER AS t
    INNER JOIN IdList AS i ON i.ROLLER_ID = t.ROLLER_ID
    WHERE t.END_YN = 'N';
END;
GO

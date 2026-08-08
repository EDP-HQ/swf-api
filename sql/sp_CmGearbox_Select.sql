/*
    List gearbox assets in a process/line pool.
    EXEC dbo.sp_CmGearbox_Select @ProcessCd='STRANDING', @LineCd='BUNCHER', @Status='SPARE'
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CmGearbox_Select
    @ProcessCd VARCHAR(20),
    @LineCd    VARCHAR(20) = NULL,
    @Status    VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @ProcessCd = UPPER(NULLIF(LTRIM(RTRIM(@ProcessCd)), ''));
    SET @LineCd = UPPER(NULLIF(LTRIM(RTRIM(@LineCd)), ''));
    SET @Status = UPPER(NULLIF(LTRIM(RTRIM(@Status)), ''));

    IF @ProcessCd IS NULL
    BEGIN
        RAISERROR(N'ProcessCd is required.', 16, 1);
        RETURN;
    END;

    IF @ProcessCd = 'STRANDING' AND (@LineCd IS NULL OR @LineCd NOT IN ('BUNCHER', 'TUBULAR'))
    BEGIN
        RAISERROR(N'STRANDING requires LineCd BUNCHER or TUBULAR.', 16, 1);
        RETURN;
    END;

    IF @ProcessCd <> 'STRANDING'
        SET @LineCd = NULL;

    SELECT
        a.COMPANY,
        a.FACTORY,
        a.GEARBOX_ID,
        a.PROCESS_CD,
        a.LINE_CD,
        a.STATUS,
        a.CURRENT_MACHINE_NM,
        a.CURRENT_PART_ID,
        a.LIFETIME_RUNTIME_SEC,
        a.CREATED_DT,
        a.LAST_CHG_DT,
        InstallRuntimeSec = ISNULL(t.RUNTIME_SEC, 0),
        RuntimeLimitHour = t.RUNTIME_LIMIT_HOUR
    FROM dbo.TB_CM_GEARBOX_ASSET a
    LEFT JOIN dbo.TB_COMPONENTS_TRACKER t
        ON t.PART_ID = a.CURRENT_PART_ID
       AND t.[USE] = 'Y'
    WHERE a.PROCESS_CD = @ProcessCd
      AND (
            (@LineCd IS NULL AND a.LINE_CD IS NULL)
            OR a.LINE_CD = @LineCd
          )
      AND (@Status IS NULL OR a.STATUS = @Status)
    ORDER BY a.GEARBOX_ID;
END;
GO

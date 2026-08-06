/*
    Roller bin list for a process / stranding line — no hardcoded ST0009–ST0015 list.

    EXEC dbo.sp_RollerTracker_SelectRoller @ProcessCd='STRANDING', @LineCd='BUNCHER'
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_RollerTracker_SelectRoller
    @ProcessCd VARCHAR(20) = 'STRANDING',
    @LineCd    VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @ProcessCd = UPPER(NULLIF(LTRIM(RTRIM(@ProcessCd)), ''));
    SET @LineCd = UPPER(NULLIF(LTRIM(RTRIM(@LineCd)), ''));

    DECLARE @ProcessId VARCHAR(10) = dbo.fn_Cm_ProcessIdFromCd(@ProcessCd);
    IF @ProcessId IS NULL
    BEGIN
        RAISERROR(N'ProcessCd must be INLINE, DRAWING, STRANDING, CLOSING or REWINDER.', 16, 1);
        RETURN;
    END;

    IF @ProcessCd = 'STRANDING' AND @LineCd IS NOT NULL AND @LineCd NOT IN ('BUNCHER', 'TUBULAR')
    BEGIN
        RAISERROR(N'STRANDING LineCd must be BUNCHER or TUBULAR.', 16, 1);
        RETURN;
    END;

    ;WITH b AS (
        SELECT
            BIN_LOCATION_CD,
            BIN_LOCATION_DESC,
            MACHINE_CD = LEFT(BIN_LOCATION_CD, CHARINDEX('_', BIN_LOCATION_CD + '_') - 1),
            MACHINE_NAME = dbo.fn_Cm_MachineNameFromBinDesc(BIN_LOCATION_DESC),
            IS_BUNCHER = CASE
                WHEN UPPER(LTRIM(BIN_LOCATION_DESC)) LIKE N'BUN %' THEN 1
                ELSE 0 END
        FROM dbo.TB_CD_BIN_LOCATION
        WHERE PROCESS_ID = @ProcessId
          AND BIN_LOCATION_TP = N'Pay-off'
    )
    SELECT
        b.BIN_LOCATION_CD,
        b.BIN_LOCATION_DESC,
        b.MACHINE_CD,
        b.MACHINE_NAME
    FROM b
    WHERE (
            @ProcessCd <> 'STRANDING'
            OR @LineCd IS NULL
            OR (@LineCd = 'BUNCHER' AND b.IS_BUNCHER = 1)
            OR (@LineCd = 'TUBULAR' AND b.IS_BUNCHER = 0)
          )
    ORDER BY b.MACHINE_CD, b.BIN_LOCATION_CD;
END;
GO

/*
    Active (working) roller bins for a process / line.

    EXEC dbo.sp_RollerTracker_ActiveRoller @ProcessCd='STRANDING', @LineCd='BUNCHER'
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_RollerTracker_ActiveRoller
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

    ;WITH bins AS (
        SELECT
            BIN_LOCATION_CD,
            IS_BUNCHER = CASE
                WHEN UPPER(LTRIM(BIN_LOCATION_DESC)) LIKE N'BUN %' THEN 1
                ELSE 0 END
        FROM dbo.TB_CD_BIN_LOCATION
        WHERE PROCESS_ID = @ProcessId
          AND BIN_LOCATION_TP = N'Pay-off'
    )
    SELECT DISTINCT TOP (2000) p.BIN_LOCATION_CD
    FROM dbo.TB_WO_STRANDING_PROVIDE_OPEN p
    INNER JOIN bins b ON b.BIN_LOCATION_CD = p.BIN_LOCATION_CD
    WHERE p.PROVIDE_DT > DATEADD(YEAR, -2, GETDATE())
      AND (
            @ProcessCd <> 'STRANDING'
            OR @LineCd IS NULL
            OR (@LineCd = 'BUNCHER' AND b.IS_BUNCHER = 1)
            OR (@LineCd = 'TUBULAR' AND b.IS_BUNCHER = 0)
          )
    ORDER BY p.BIN_LOCATION_CD;
END;
GO

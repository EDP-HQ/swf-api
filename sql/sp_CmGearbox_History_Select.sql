/*
    Mount history for one gearbox (or all in pool).
    EXEC dbo.sp_CmGearbox_History_Select @GearboxId='GB01'
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CmGearbox_History_Select
    @ProcessCd VARCHAR(20) = 'STRANDING',
    @LineCd    VARCHAR(20) = 'BUNCHER',
    @GearboxId VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @ProcessCd = UPPER(NULLIF(LTRIM(RTRIM(@ProcessCd)), ''));
    SET @LineCd = UPPER(NULLIF(LTRIM(RTRIM(@LineCd)), ''));
    SET @GearboxId = UPPER(NULLIF(LTRIM(RTRIM(@GearboxId)), ''));

    IF @ProcessCd IS NULL SET @ProcessCd = 'STRANDING';
    IF @ProcessCd = 'STRANDING' AND (@LineCd IS NULL OR @LineCd NOT IN ('BUNCHER', 'TUBULAR'))
    BEGIN
        RAISERROR(N'STRANDING requires LineCd BUNCHER or TUBULAR.', 16, 1);
        RETURN;
    END;
    IF @ProcessCd <> 'STRANDING' SET @LineCd = NULL;

    SELECT
        h.HIST_ID,
        h.GEARBOX_ID,
        a.GEARBOX_NM,
        h.MACHINE_NM,
        h.PART_ID,
        h.PROCESS_CD,
        h.LINE_CD,
        h.MOUNT_DT,
        h.DISMOUNT_DT,
        h.RUNTIME_SEC,
        h.REASON
    FROM dbo.TB_CM_GEARBOX_HISTORY h
    LEFT JOIN dbo.TB_CM_GEARBOX_ASSET a
        ON a.GEARBOX_ID = h.GEARBOX_ID
       AND a.COMPANY = h.COMPANY
       AND a.FACTORY = h.FACTORY
    WHERE h.PROCESS_CD = @ProcessCd
      AND ((@LineCd IS NULL AND h.LINE_CD IS NULL) OR h.LINE_CD = @LineCd)
      AND (@GearboxId IS NULL OR h.GEARBOX_ID = @GearboxId)
    ORDER BY h.GEARBOX_ID, h.MOUNT_DT DESC;
END;
GO

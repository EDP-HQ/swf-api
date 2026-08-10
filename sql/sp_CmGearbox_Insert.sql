/*
    Add a gearbox asset to a process/line pool (default SPARE).

    EXEC dbo.sp_CmGearbox_Insert
        @GearboxId='GB11', @GearboxNm=N'Gearbox 11',
        @ProcessCd='STRANDING', @LineCd='BUNCHER'
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CmGearbox_Insert
    @Company     VARCHAR(10)    = 'KSB',
    @Factory     VARCHAR(20)    = 'F002',
    @GearboxId   VARCHAR(20),
    @GearboxNm   NVARCHAR(100)  = NULL,
    @ProcessCd   VARCHAR(20)    = 'STRANDING',
    @LineCd      VARCHAR(20)    = 'BUNCHER',
    @Status      VARCHAR(10)    = 'SPARE'
AS
BEGIN
    SET NOCOUNT ON;

    SET @Company = NULLIF(LTRIM(RTRIM(@Company)), '');
    SET @Factory = NULLIF(LTRIM(RTRIM(@Factory)), '');
    SET @GearboxId = UPPER(NULLIF(LTRIM(RTRIM(@GearboxId)), ''));
    SET @GearboxNm = NULLIF(LTRIM(RTRIM(@GearboxNm)), N'');
    SET @ProcessCd = UPPER(NULLIF(LTRIM(RTRIM(@ProcessCd)), ''));
    SET @LineCd = UPPER(NULLIF(LTRIM(RTRIM(@LineCd)), ''));
    SET @Status = UPPER(NULLIF(LTRIM(RTRIM(@Status)), ''));

    IF @Company IS NULL OR @Factory IS NULL OR @GearboxId IS NULL
    BEGIN
        RAISERROR(N'Company, Factory and GearboxId are required.', 16, 1);
        RETURN;
    END;

    IF @ProcessCd IS NULL SET @ProcessCd = 'STRANDING';
    IF @ProcessCd = 'STRANDING' AND (@LineCd IS NULL OR @LineCd NOT IN ('BUNCHER', 'TUBULAR'))
    BEGIN
        RAISERROR(N'STRANDING requires LineCd BUNCHER or TUBULAR.', 16, 1);
        RETURN;
    END;
    IF @ProcessCd <> 'STRANDING' SET @LineCd = NULL;

    IF @Status IS NULL OR @Status NOT IN ('SPARE', 'REPAIR')
        SET @Status = 'SPARE';

    IF @GearboxNm IS NULL
        SET @GearboxNm = @GearboxId;

    IF EXISTS (
        SELECT 1
        FROM dbo.TB_CM_GEARBOX_ASSET
        WHERE COMPANY = @Company AND FACTORY = @Factory AND GEARBOX_ID = @GearboxId
    )
    BEGIN
        RAISERROR(N'GearboxId already exists.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.TB_CM_GEARBOX_ASSET
        (COMPANY, FACTORY, GEARBOX_ID, GEARBOX_NM, PROCESS_CD, LINE_CD, STATUS,
         CURRENT_MACHINE_NM, CURRENT_PART_ID, LIFETIME_RUNTIME_SEC, CREATED_DT, LAST_CHG_DT)
    VALUES
        (@Company, @Factory, @GearboxId, @GearboxNm, @ProcessCd, @LineCd, @Status,
         NULL, NULL, 0, GETDATE(), GETDATE());

    SELECT
        a.COMPANY,
        a.FACTORY,
        a.GEARBOX_ID,
        GearboxNm = ISNULL(NULLIF(LTRIM(RTRIM(a.GEARBOX_NM)), N''), a.GEARBOX_ID),
        a.PROCESS_CD,
        a.LINE_CD,
        a.STATUS,
        a.CURRENT_MACHINE_NM,
        a.CURRENT_PART_ID,
        a.LIFETIME_RUNTIME_SEC,
        a.CREATED_DT,
        a.LAST_CHG_DT,
        InstallRuntimeSec = CAST(0 AS BIGINT),
        RuntimeLimitHour = CAST(NULL AS DECIMAL(12, 2))
    FROM dbo.TB_CM_GEARBOX_ASSET a
    WHERE a.COMPANY = @Company AND a.FACTORY = @Factory AND a.GEARBOX_ID = @GearboxId;
END;
GO

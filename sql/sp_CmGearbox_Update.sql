/*
    Update gearbox display name (master).
    EXEC dbo.sp_CmGearbox_Update @GearboxId='GB01', @GearboxNm='GB Unit Alpha'
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CmGearbox_Update
    @Company   VARCHAR(10) = 'KSB',
    @Factory   VARCHAR(20) = 'F002',
    @GearboxId VARCHAR(20),
    @GearboxNm NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SET @Company = NULLIF(LTRIM(RTRIM(@Company)), '');
    SET @Factory = NULLIF(LTRIM(RTRIM(@Factory)), '');
    SET @GearboxId = UPPER(NULLIF(LTRIM(RTRIM(@GearboxId)), ''));
    SET @GearboxNm = NULLIF(LTRIM(RTRIM(@GearboxNm)), '');

    IF @Company IS NULL OR @Factory IS NULL OR @GearboxId IS NULL OR @GearboxNm IS NULL
    BEGIN
        RAISERROR(N'Company, Factory, GearboxId and GearboxNm are required.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.TB_CM_GEARBOX_ASSET
        WHERE COMPANY = @Company AND FACTORY = @Factory AND GEARBOX_ID = @GearboxId
    )
    BEGIN
        RAISERROR(N'Gearbox not found.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.TB_CM_GEARBOX_ASSET
    SET GEARBOX_NM = @GearboxNm,
        LAST_CHG_DT = GETDATE()
    WHERE COMPANY = @Company
      AND FACTORY = @Factory
      AND GEARBOX_ID = @GearboxId;

    SELECT
        COMPANY, FACTORY, GEARBOX_ID, GEARBOX_NM, PROCESS_CD, LINE_CD, STATUS,
        CURRENT_MACHINE_NM, CURRENT_PART_ID, LIFETIME_RUNTIME_SEC, CREATED_DT, LAST_CHG_DT
    FROM dbo.TB_CM_GEARBOX_ASSET
    WHERE COMPANY = @Company AND FACTORY = @Factory AND GEARBOX_ID = @GearboxId;
END;
GO

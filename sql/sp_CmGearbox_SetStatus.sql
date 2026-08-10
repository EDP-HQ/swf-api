/*
    Mark gearbox SPARE / REPAIR / RETIRED (not IN_USE — use Swap for that).
    EXEC dbo.sp_CmGearbox_SetStatus @GearboxId='GB08', @Status='RETIRED'
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CmGearbox_SetStatus
    @Company   VARCHAR(10) = 'KSB',
    @Factory   VARCHAR(20) = 'F002',
    @GearboxId VARCHAR(20),
    @Status    VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @Company = NULLIF(LTRIM(RTRIM(@Company)), '');
    SET @Factory = NULLIF(LTRIM(RTRIM(@Factory)), '');
    SET @GearboxId = UPPER(NULLIF(LTRIM(RTRIM(@GearboxId)), ''));
    SET @Status = UPPER(NULLIF(LTRIM(RTRIM(@Status)), ''));

    IF @Company IS NULL OR @Factory IS NULL OR @GearboxId IS NULL OR @Status IS NULL
    BEGIN
        RAISERROR(N'Company, Factory, GearboxId and Status are required.', 16, 1);
        RETURN;
    END;

    IF @Status NOT IN ('SPARE', 'REPAIR', 'RETIRED')
    BEGIN
        RAISERROR(N'Status must be SPARE, REPAIR or RETIRED (use Swap for IN_USE).', 16, 1);
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

    IF EXISTS (
        SELECT 1
        FROM dbo.TB_CM_GEARBOX_ASSET
        WHERE COMPANY = @Company AND FACTORY = @Factory AND GEARBOX_ID = @GearboxId
          AND STATUS = 'IN_USE'
    )
    BEGIN
        RAISERROR(N'Cannot change status while gearbox is IN_USE. Swap it off the machine first.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.TB_CM_GEARBOX_ASSET
    SET STATUS = @Status,
        CURRENT_MACHINE_NM = NULL,
        CURRENT_PART_ID = NULL,
        LAST_CHG_DT = GETDATE()
    WHERE COMPANY = @Company
      AND FACTORY = @Factory
      AND GEARBOX_ID = @GearboxId;

    SELECT *
    FROM dbo.TB_CM_GEARBOX_ASSET
    WHERE COMPANY = @Company AND FACTORY = @Factory AND GEARBOX_ID = @GearboxId;
END;
GO

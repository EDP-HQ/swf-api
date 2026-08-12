/*
    Remove (deactivate) an active component from a machine.
    Does not insert a replacement. Gearbox pool assets return to SPARE.

    EXEC dbo.sp_Components_Remove @PartId='FP202600001'
    EXEC dbo.sp_Components_Remove @MachineNm='BUN 500-1', @PartSeq=2
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Components_Remove
    @PartId     VARCHAR(20)   = NULL,
    @MachineNm  NVARCHAR(100) = NULL,
    @PartSeq    INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @PartId IS NULL AND (@MachineNm IS NULL OR @PartSeq IS NULL)
    BEGIN
        RAISERROR(N'Provide PartId or both MachineNm and PartSeq.', 16, 1);
        RETURN;
    END;

    DECLARE @OldPartId  VARCHAR(20);
    DECLARE @Company    VARCHAR(10);
    DECLARE @Factory    VARCHAR(20);
    DECLARE @PartType   VARCHAR(20);
    DECLARE @Machine    NVARCHAR(100);
    DECLARE @ProcessCd  VARCHAR(20);
    DECLARE @LineCd     VARCHAR(20);
    DECLARE @RuntimeSec BIGINT;
    DECLARE @Now        DATETIME = GETDATE();
    DECLARE @GearboxId  VARCHAR(20);

    SELECT TOP 1
        @OldPartId = PART_ID,
        @Company = COMPANY,
        @Factory = FACTORY,
        @PartType = PART_TYPE,
        @Machine = MACHINE_NM,
        @ProcessCd = PROCESS_CD,
        @LineCd = LINE_CD,
        @RuntimeSec = ISNULL(RUNTIME_SEC, 0)
    FROM dbo.TB_COMPONENTS_TRACKER WITH (UPDLOCK, HOLDLOCK)
    WHERE [USE] = 'Y'
      AND (
          (@PartId IS NOT NULL AND PART_ID = @PartId)
          OR (
              @PartId IS NULL
              AND MACHINE_NM = @MachineNm
              AND PART_SEQ = @PartSeq
          )
      );

    IF @OldPartId IS NULL
    BEGIN
        RAISERROR(N'Active component not found.', 16, 1);
        RETURN;
    END;

    BEGIN TRAN;

    IF UPPER(LTRIM(RTRIM(@PartType))) = 'GEARBOX'
       AND OBJECT_ID(N'dbo.TB_CM_GEARBOX_ASSET', N'U') IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM dbo.TB_CM_GEARBOX_ASSET
            WHERE PROCESS_CD = ISNULL(@ProcessCd, PROCESS_CD)
              AND ((@LineCd IS NULL AND LINE_CD IS NULL) OR LINE_CD = @LineCd)
       )
    BEGIN
        SELECT @GearboxId = a.GEARBOX_ID
        FROM dbo.TB_CM_GEARBOX_ASSET a WITH (UPDLOCK, HOLDLOCK)
        WHERE a.COMPANY = @Company
          AND a.FACTORY = @Factory
          AND (
                a.CURRENT_PART_ID = @OldPartId
                OR a.GEARBOX_ID = @OldPartId
                OR (
                    a.CURRENT_MACHINE_NM = @Machine
                    AND a.STATUS = 'IN_USE'
                    AND (@ProcessCd IS NULL OR a.PROCESS_CD = @ProcessCd)
                    AND ((@LineCd IS NULL AND a.LINE_CD IS NULL) OR a.LINE_CD = @LineCd)
                )
              );

        IF @GearboxId IS NULL
            SET @GearboxId = @OldPartId;

        UPDATE dbo.TB_CM_GEARBOX_HISTORY
        SET DISMOUNT_DT = @Now,
            RUNTIME_SEC = @RuntimeSec,
            REASON = ISNULL(REASON, 'REMOVE')
        WHERE GEARBOX_ID = @GearboxId
          AND MACHINE_NM = @Machine
          AND DISMOUNT_DT IS NULL;

        UPDATE dbo.TB_CM_GEARBOX_ASSET
        SET STATUS = 'SPARE',
            CURRENT_MACHINE_NM = NULL,
            CURRENT_PART_ID = NULL,
            LIFETIME_RUNTIME_SEC = ISNULL(LIFETIME_RUNTIME_SEC, 0) + @RuntimeSec,
            LAST_CHG_DT = @Now
        WHERE COMPANY = @Company
          AND FACTORY = @Factory
          AND GEARBOX_ID = @GearboxId;
    END;

    UPDATE dbo.TB_COMPONENTS_TRACKER
    SET [USE] = 'N',
        DISMANTLE_DT = @Now
    WHERE PART_ID = @OldPartId;

    COMMIT TRAN;

    SELECT
        COMPANY, FACTORY, PART_ID, PART_SEQ, PART_TYPE, MACHINE_NM,
        PROCESS_CD, LINE_CD,
        REPLACE_DT, DISMANTLE_DT, RUNTIME_LIMIT_HOUR, RUNTIME_SEC, [USE]
    FROM dbo.TB_COMPONENTS_TRACKER
    WHERE PART_ID = @OldPartId;
END;
GO

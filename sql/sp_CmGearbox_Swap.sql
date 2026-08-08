/*
    Swap (or first-mount) a spare gearbox onto a machine.
    Removed gearbox -> REPAIR (default). New install runtime = 0.
    Asset keeps lifetime runtime + history.

    EXEC dbo.sp_CmGearbox_Swap
        @MachineNm='BUN 500-1', @NewGearboxId='GB08',
        @ProcessCd='STRANDING', @LineCd='BUNCHER'
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CmGearbox_Swap
    @Company           VARCHAR(10)    = 'KSB',
    @Factory           VARCHAR(20)    = 'F002',
    @MachineNm         NVARCHAR(100),
    @NewGearboxId      VARCHAR(20),
    @ProcessCd         VARCHAR(20)    = 'STRANDING',
    @LineCd            VARCHAR(20)    = 'BUNCHER',
    @RuntimeLimitHour  DECIMAL(12, 2) = NULL,
    @RemovedStatus     VARCHAR(10)    = 'REPAIR'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Company = NULLIF(LTRIM(RTRIM(@Company)), '');
    SET @Factory = NULLIF(LTRIM(RTRIM(@Factory)), '');
    SET @MachineNm = NULLIF(LTRIM(RTRIM(@MachineNm)), '');
    SET @NewGearboxId = UPPER(NULLIF(LTRIM(RTRIM(@NewGearboxId)), ''));
    SET @ProcessCd = UPPER(NULLIF(LTRIM(RTRIM(@ProcessCd)), ''));
    SET @LineCd = UPPER(NULLIF(LTRIM(RTRIM(@LineCd)), ''));
    SET @RemovedStatus = UPPER(NULLIF(LTRIM(RTRIM(@RemovedStatus)), ''));

    IF @Company IS NULL OR @Factory IS NULL OR @MachineNm IS NULL OR @NewGearboxId IS NULL
    BEGIN
        RAISERROR(N'Company, Factory, MachineNm and NewGearboxId are required.', 16, 1);
        RETURN;
    END;

    IF @ProcessCd IS NULL SET @ProcessCd = 'STRANDING';
    IF @ProcessCd = 'STRANDING' AND (@LineCd IS NULL OR @LineCd NOT IN ('BUNCHER', 'TUBULAR'))
    BEGIN
        RAISERROR(N'STRANDING requires LineCd BUNCHER or TUBULAR.', 16, 1);
        RETURN;
    END;
    IF @ProcessCd <> 'STRANDING' SET @LineCd = NULL;

    IF @RemovedStatus IS NULL OR @RemovedStatus NOT IN ('REPAIR', 'SPARE')
        SET @RemovedStatus = 'REPAIR';

    DECLARE @Now DATETIME = GETDATE();
    DECLARE @ReplaceDt DATETIME = CAST(@Now AS DATE);
    DECLARE @OldPartId VARCHAR(20);
    DECLARE @OldGearboxId VARCHAR(20);
    DECLARE @OldLimit DECIMAL(12, 2);
    DECLARE @InstallRuntime BIGINT;
    DECLARE @NewPartSeq INT;
    DECLARE @Limit DECIMAL(12, 2);

    BEGIN TRAN;

    /* New asset must be SPARE in this pool */
    IF NOT EXISTS (
        SELECT 1
        FROM dbo.TB_CM_GEARBOX_ASSET WITH (UPDLOCK, HOLDLOCK)
        WHERE COMPANY = @Company
          AND FACTORY = @Factory
          AND GEARBOX_ID = @NewGearboxId
          AND PROCESS_CD = @ProcessCd
          AND ((@LineCd IS NULL AND LINE_CD IS NULL) OR LINE_CD = @LineCd)
          AND STATUS = 'SPARE'
    )
    BEGIN
        ROLLBACK TRAN;
        RAISERROR(N'New gearbox must exist in this pool with STATUS=SPARE.', 16, 1);
        RETURN;
    END;

    /* Current active gearbox on machine (if any) */
    SELECT TOP 1
        @OldPartId = t.PART_ID,
        @OldLimit = t.RUNTIME_LIMIT_HOUR,
        @InstallRuntime = ISNULL(t.RUNTIME_SEC, 0)
    FROM dbo.TB_COMPONENTS_TRACKER t WITH (UPDLOCK, HOLDLOCK)
    WHERE t.[USE] = 'Y'
      AND t.MACHINE_NM = @MachineNm
      AND UPPER(LTRIM(RTRIM(t.PART_TYPE))) = 'GEARBOX'
      AND t.PROCESS_CD = @ProcessCd
      AND ((@LineCd IS NULL AND t.LINE_CD IS NULL) OR t.LINE_CD = @LineCd);

    SET @Limit = COALESCE(@RuntimeLimitHour, @OldLimit, 7000);
    IF @Limit IS NULL OR @Limit <= 0 SET @Limit = 7000;

    IF @OldPartId IS NOT NULL
    BEGIN
        SELECT @OldGearboxId = a.GEARBOX_ID
        FROM dbo.TB_CM_GEARBOX_ASSET a WITH (UPDLOCK, HOLDLOCK)
        WHERE a.COMPANY = @Company
          AND a.FACTORY = @Factory
          AND (
                a.CURRENT_PART_ID = @OldPartId
                OR a.GEARBOX_ID = @OldPartId
                OR (
                    a.CURRENT_MACHINE_NM = @MachineNm
                    AND a.STATUS = 'IN_USE'
                    AND a.PROCESS_CD = @ProcessCd
                    AND ((@LineCd IS NULL AND a.LINE_CD IS NULL) OR a.LINE_CD = @LineCd)
                )
              );

        IF @OldGearboxId IS NULL
            SET @OldGearboxId = @OldPartId;

        /* Close open history + fold install into lifetime */
        UPDATE dbo.TB_CM_GEARBOX_HISTORY
        SET DISMOUNT_DT = @Now,
            RUNTIME_SEC = @InstallRuntime,
            REASON = ISNULL(REASON, 'SWAP')
        WHERE GEARBOX_ID = @OldGearboxId
          AND MACHINE_NM = @MachineNm
          AND DISMOUNT_DT IS NULL;

        UPDATE dbo.TB_CM_GEARBOX_ASSET
        SET STATUS = @RemovedStatus,
            CURRENT_MACHINE_NM = NULL,
            CURRENT_PART_ID = NULL,
            LIFETIME_RUNTIME_SEC = ISNULL(LIFETIME_RUNTIME_SEC, 0) + @InstallRuntime,
            LAST_CHG_DT = @Now
        WHERE COMPANY = @Company
          AND FACTORY = @Factory
          AND GEARBOX_ID = @OldGearboxId;

        UPDATE dbo.TB_COMPONENTS_TRACKER
        SET [USE] = 'N',
            DISMANTLE_DT = @Now
        WHERE PART_ID = @OldPartId;
    END;

    SELECT @NewPartSeq = ISNULL(MAX(PART_SEQ), 0) + 1
    FROM dbo.TB_COMPONENTS_TRACKER WITH (UPDLOCK, HOLDLOCK)
    WHERE [USE] = 'Y'
      AND MACHINE_NM = @MachineNm
      AND PROCESS_CD = @ProcessCd
      AND ((@LineCd IS NULL AND LINE_CD IS NULL) OR LINE_CD = @LineCd);

    /* Tracker PART_ID = gearbox asset id */
    INSERT INTO dbo.TB_COMPONENTS_TRACKER
    (
        COMPANY, FACTORY, PART_ID, PART_SEQ, PART_TYPE, MACHINE_NM,
        PROCESS_CD, LINE_CD,
        REPLACE_DT, DISMANTLE_DT, RUNTIME_LIMIT_HOUR, RUNTIME_SEC, [USE]
    )
    VALUES
    (
        @Company, @Factory, @NewGearboxId, @NewPartSeq, 'GEARBOX', @MachineNm,
        @ProcessCd, @LineCd,
        @ReplaceDt, NULL, @Limit, 0, 'Y'
    );

    UPDATE dbo.TB_CM_GEARBOX_ASSET
    SET STATUS = 'IN_USE',
        CURRENT_MACHINE_NM = @MachineNm,
        CURRENT_PART_ID = @NewGearboxId,
        LAST_CHG_DT = @Now
    WHERE COMPANY = @Company
      AND FACTORY = @Factory
      AND GEARBOX_ID = @NewGearboxId;

    INSERT INTO dbo.TB_CM_GEARBOX_HISTORY
    (
        COMPANY, FACTORY, GEARBOX_ID, MACHINE_NM, PART_ID,
        PROCESS_CD, LINE_CD, MOUNT_DT, DISMOUNT_DT, RUNTIME_SEC, REASON
    )
    VALUES
    (
        @Company, @Factory, @NewGearboxId, @MachineNm, @NewGearboxId,
        @ProcessCd, @LineCd, @Now, NULL, 0, CASE WHEN @OldPartId IS NULL THEN 'INITIAL' ELSE 'SWAP' END
    );

    COMMIT TRAN;

    SELECT
        COMPANY, FACTORY, PART_ID, PART_SEQ, PART_TYPE, MACHINE_NM,
        PROCESS_CD, LINE_CD,
        REPLACE_DT, DISMANTLE_DT, RUNTIME_LIMIT_HOUR, RUNTIME_SEC, [USE]
    FROM dbo.TB_COMPONENTS_TRACKER
    WHERE PART_ID = @NewGearboxId AND [USE] = 'Y';
END;
GO

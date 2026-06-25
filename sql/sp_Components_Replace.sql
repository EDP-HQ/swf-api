/*
    Replace an active component:
      1. Set former row [USE] = 'N' and DISMANTLE_DT = now
      2. Insert new row with RUNTIME_SEC = 0 and [USE] = 'Y'

    Identify the active row by @PartId OR (@MachineNm + @PartSeq).
    Returns the newly inserted row.
*/

USE SFC_WR_DB;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Components_Replace
    @PartId            VARCHAR(20)     = NULL,
    @MachineNm         NVARCHAR(100)   = NULL,
    @PartSeq           INT             = NULL,
    @RuntimeLimitHour  DECIMAL(12, 2)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @PartId IS NULL AND (@MachineNm IS NULL OR @PartSeq IS NULL)
    BEGIN
        RAISERROR(N'Provide PartId or both MachineNm and PartSeq.', 16, 1);
        RETURN;
    END;

    IF @PartSeq IS NOT NULL AND @PartSeq NOT IN (1, 2, 3)
    BEGIN
        RAISERROR(N'PartSeq must be 1 (gearbox), 2 (SF), or 3 (SB).', 16, 1);
        RETURN;
    END;

    DECLARE @OldPartId  VARCHAR(20);
    DECLARE @Company    VARCHAR(10);
    DECLARE @Factory    VARCHAR(20);
    DECLARE @PartType   VARCHAR(20);
    DECLARE @Machine    NVARCHAR(100);
    DECLARE @Seq        INT;
    DECLARE @Limit      DECIMAL(12, 2);
    DECLARE @Now        DATETIME = GETDATE();
    DECLARE @ReplaceDt  DATETIME = CAST(@Now AS DATE);
    DECLARE @YearPrefix VARCHAR(4) = CONVERT(VARCHAR(4), YEAR(@Now));
    DECLARE @NewPartId  VARCHAR(20);
    DECLARE @NextSeq    INT;

    SELECT TOP 1
        @OldPartId = PART_ID,
        @Company = COMPANY,
        @Factory = FACTORY,
        @PartType = PART_TYPE,
        @Machine = MACHINE_NM,
        @Seq = PART_SEQ,
        @Limit = RUNTIME_LIMIT_HOUR
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

    IF @RuntimeLimitHour IS NOT NULL AND @RuntimeLimitHour > 0
        SET @Limit = @RuntimeLimitHour;

    BEGIN TRAN;

    UPDATE dbo.TB_COMPONENTS_TRACKER
    SET
        [USE] = 'N',
        DISMANTLE_DT = @Now
    WHERE PART_ID = @OldPartId;

    SELECT @NextSeq = ISNULL(MAX(CAST(RIGHT(PART_ID, 5) AS INT)), 0) + 1
    FROM dbo.TB_COMPONENTS_TRACKER WITH (UPDLOCK, HOLDLOCK)
    WHERE PART_ID LIKE 'FP' + @YearPrefix + '%';

    SET @NewPartId = 'FP' + @YearPrefix + RIGHT('00000' + CAST(@NextSeq AS VARCHAR(5)), 5);

    INSERT INTO dbo.TB_COMPONENTS_TRACKER
    (
        COMPANY,
        FACTORY,
        PART_ID,
        PART_SEQ,
        PART_TYPE,
        MACHINE_NM,
        REPLACE_DT,
        DISMANTLE_DT,
        RUNTIME_LIMIT_HOUR,
        RUNTIME_SEC,
        [USE]
    )
    VALUES
    (
        @Company,
        @Factory,
        @NewPartId,
        @Seq,
        @PartType,
        @Machine,
        @ReplaceDt,
        NULL,
        @Limit,
        0,
        'Y'
    );

    COMMIT;

    SELECT
        COMPANY,
        FACTORY,
        PART_ID,
        PART_SEQ,
        PART_TYPE,
        MACHINE_NM,
        REPLACE_DT,
        DISMANTLE_DT,
        RUNTIME_LIMIT_HOUR,
        RUNTIME_SEC,
        [USE]
    FROM dbo.TB_COMPONENTS_TRACKER
    WHERE PART_ID = @NewPartId;
END;
GO

/*
    Replace an active component; copies PROCESS_CD / LINE_CD onto the new row.
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

    DECLARE @OldPartId  VARCHAR(20);
    DECLARE @Company    VARCHAR(10);
    DECLARE @Factory    VARCHAR(20);
    DECLARE @PartType   VARCHAR(20);
    DECLARE @Machine    NVARCHAR(100);
    DECLARE @ProcessCd  VARCHAR(20);
    DECLARE @LineCd     VARCHAR(20);
    DECLARE @Limit      DECIMAL(12, 2);
    DECLARE @Now        DATETIME = GETDATE();
    DECLARE @ReplaceDt  DATETIME = CAST(@Now AS DATE);
    DECLARE @YearPrefix VARCHAR(4) = CONVERT(VARCHAR(4), YEAR(@Now));
    DECLARE @NewPartId  VARCHAR(20);
    DECLARE @NextSeq    INT;
    DECLARE @NewPartSeq INT;

    SELECT TOP 1
        @OldPartId = PART_ID,
        @Company = COMPANY,
        @Factory = FACTORY,
        @PartType = PART_TYPE,
        @Machine = MACHINE_NM,
        @ProcessCd = PROCESS_CD,
        @LineCd = LINE_CD,
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

    IF @ProcessCd IS NULL SET @ProcessCd = 'STRANDING';
    IF @ProcessCd = 'STRANDING' AND @LineCd IS NULL SET @LineCd = 'BUNCHER';

    IF UPPER(LTRIM(RTRIM(@PartType))) = 'GEARBOX'
       AND EXISTS (
            SELECT 1
            FROM dbo.TB_CM_GEARBOX_ASSET
            WHERE PROCESS_CD = @ProcessCd
              AND ((@LineCd IS NULL AND LINE_CD IS NULL) OR LINE_CD = @LineCd)
       )
    BEGIN
        RAISERROR(N'Gearbox uses the pool swap API (sp_CmGearbox_Swap), not Components_Replace.', 16, 1);
        RETURN;
    END;

    IF @RuntimeLimitHour IS NOT NULL AND @RuntimeLimitHour > 0
        SET @Limit = @RuntimeLimitHour;

    SELECT @NewPartSeq = ISNULL(MAX(PART_SEQ), 0) + 1
    FROM dbo.TB_COMPONENTS_TRACKER WITH (UPDLOCK, HOLDLOCK)
    WHERE [USE] = 'Y'
      AND MACHINE_NM = @Machine
      AND PROCESS_CD = @ProcessCd
      AND ((@LineCd IS NULL AND LINE_CD IS NULL) OR LINE_CD = @LineCd);

    BEGIN TRAN;

    UPDATE dbo.TB_COMPONENTS_TRACKER
    SET [USE] = 'N', DISMANTLE_DT = @Now
    WHERE PART_ID = @OldPartId;

    SELECT @NextSeq = ISNULL(MAX(CAST(RIGHT(PART_ID, 5) AS INT)), 0) + 1
    FROM dbo.TB_COMPONENTS_TRACKER WITH (UPDLOCK, HOLDLOCK)
    WHERE PART_ID LIKE 'FP' + @YearPrefix + '%';

    SET @NewPartId = 'FP' + @YearPrefix + RIGHT('00000' + CAST(@NextSeq AS VARCHAR(5)), 5);

    INSERT INTO dbo.TB_COMPONENTS_TRACKER
    (
        COMPANY, FACTORY, PART_ID, PART_SEQ, PART_TYPE, MACHINE_NM,
        PROCESS_CD, LINE_CD,
        REPLACE_DT, DISMANTLE_DT, RUNTIME_LIMIT_HOUR, RUNTIME_SEC, [USE]
    )
    VALUES
    (
        @Company, @Factory, @NewPartId, @NewPartSeq, @PartType, @Machine,
        @ProcessCd, @LineCd,
        @ReplaceDt, NULL, @Limit, 0, 'Y'
    );

    COMMIT;

    SELECT
        COMPANY, FACTORY, PART_ID, PART_SEQ, PART_TYPE, MACHINE_NM,
        PROCESS_CD, LINE_CD,
        REPLACE_DT, DISMANTLE_DT, RUNTIME_LIMIT_HOUR, RUNTIME_SEC, [USE]
    FROM dbo.TB_COMPONENTS_TRACKER
    WHERE PART_ID = @NewPartId;
END;
GO

/*
    Register a new active component on a machine (scoped by process / line).
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Components_Insert
    @Company           VARCHAR(10),
    @Factory           VARCHAR(20),
    @MachineNm         NVARCHAR(100),
    @PartType          VARCHAR(20),
    @RuntimeLimitHour  DECIMAL(12, 2),
    @ProcessCd         VARCHAR(20) = 'STRANDING',
    @LineCd            VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Company = NULLIF(LTRIM(RTRIM(@Company)), '');
    SET @Factory = NULLIF(LTRIM(RTRIM(@Factory)), '');
    SET @MachineNm = NULLIF(LTRIM(RTRIM(@MachineNm)), '');
    SET @PartType = NULLIF(LTRIM(RTRIM(@PartType)), '');
    SET @ProcessCd = UPPER(NULLIF(LTRIM(RTRIM(@ProcessCd)), ''));
    SET @LineCd = UPPER(NULLIF(LTRIM(RTRIM(@LineCd)), ''));

    IF @Company IS NULL OR @Factory IS NULL OR @MachineNm IS NULL OR @PartType IS NULL
    BEGIN
        RAISERROR(N'Company, Factory, MachineNm and PartType are required.', 16, 1);
        RETURN;
    END;

    IF @RuntimeLimitHour IS NULL OR @RuntimeLimitHour <= 0
    BEGIN
        RAISERROR(N'RuntimeLimitHour must be greater than zero.', 16, 1);
        RETURN;
    END;

    IF @ProcessCd IS NULL OR dbo.fn_Cm_ProcessIdFromCd(@ProcessCd) IS NULL
    BEGIN
        RAISERROR(N'ProcessCd must be INLINE, DRAWING, STRANDING, CLOSING or REWINDER.', 16, 1);
        RETURN;
    END;

    IF @ProcessCd = 'STRANDING'
    BEGIN
        IF @LineCd IS NULL OR @LineCd NOT IN ('BUNCHER', 'TUBULAR')
        BEGIN
            RAISERROR(N'STRANDING requires LineCd BUNCHER or TUBULAR.', 16, 1);
            RETURN;
        END;
    END
    ELSE
        SET @LineCd = NULL;

    IF EXISTS (
        SELECT 1
        FROM dbo.TB_COMPONENTS_TRACKER WITH (UPDLOCK, HOLDLOCK)
        WHERE [USE] = 'Y'
          AND MACHINE_NM = @MachineNm
          AND PROCESS_CD = @ProcessCd
          AND ((@LineCd IS NULL AND LINE_CD IS NULL) OR LINE_CD = @LineCd)
          AND UPPER(LTRIM(RTRIM(PART_TYPE))) = UPPER(@PartType)
    )
    BEGIN
        RAISERROR(N'An active component with this part type already exists on this machine.', 16, 1);
        RETURN;
    END;

    DECLARE @PartSeq      INT;
    DECLARE @Now          DATETIME = GETDATE();
    DECLARE @ReplaceDt    DATETIME = CAST(@Now AS DATE);
    DECLARE @YearPrefix   VARCHAR(4) = CONVERT(VARCHAR(4), YEAR(@Now));
    DECLARE @NextIdSeq    INT;
    DECLARE @NewPartId    VARCHAR(20);

    SELECT @PartSeq = ISNULL(MAX(PART_SEQ), 0) + 1
    FROM dbo.TB_COMPONENTS_TRACKER WITH (UPDLOCK, HOLDLOCK)
    WHERE [USE] = 'Y'
      AND MACHINE_NM = @MachineNm
      AND PROCESS_CD = @ProcessCd
      AND ((@LineCd IS NULL AND LINE_CD IS NULL) OR LINE_CD = @LineCd);

    SELECT @NextIdSeq = ISNULL(MAX(CAST(RIGHT(PART_ID, 5) AS INT)), 0) + 1
    FROM dbo.TB_COMPONENTS_TRACKER WITH (UPDLOCK, HOLDLOCK)
    WHERE PART_ID LIKE 'FP' + @YearPrefix + '%';

    SET @NewPartId = 'FP' + @YearPrefix + RIGHT('00000' + CAST(@NextIdSeq AS VARCHAR(5)), 5);

    INSERT INTO dbo.TB_COMPONENTS_TRACKER
    (
        COMPANY, FACTORY, PART_ID, PART_SEQ, PART_TYPE, MACHINE_NM,
        PROCESS_CD, LINE_CD,
        REPLACE_DT, DISMANTLE_DT, RUNTIME_LIMIT_HOUR, RUNTIME_SEC, [USE]
    )
    VALUES
    (
        @Company, @Factory, @NewPartId, @PartSeq, @PartType, @MachineNm,
        @ProcessCd, @LineCd,
        @ReplaceDt, NULL, @RuntimeLimitHour, 0, 'Y'
    );

    SELECT
        COMPANY, FACTORY, PART_ID, PART_SEQ, PART_TYPE, MACHINE_NM,
        PROCESS_CD, LINE_CD,
        REPLACE_DT, DISMANTLE_DT, RUNTIME_LIMIT_HOUR, RUNTIME_SEC, [USE]
    FROM dbo.TB_COMPONENTS_TRACKER
    WHERE PART_ID = @NewPartId;
END;
GO

/*
    Register a machine under a process (and optional Stranding line).

    EXEC dbo.sp_CmMachine_Insert
        @Company = 'KSB', @Factory = 'F002',
        @ProcessCd = 'STRANDING', @LineCd = 'TUBULAR',
        @MachineNm = 'TUB 1250-1',
        @MachineCd = NULL
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CmMachine_Insert
    @Company   VARCHAR(10),
    @Factory   VARCHAR(20),
    @ProcessCd VARCHAR(20),
    @LineCd    VARCHAR(20) = NULL,
    @MachineNm NVARCHAR(100),
    @MachineCd NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Company = NULLIF(LTRIM(RTRIM(@Company)), '');
    SET @Factory = NULLIF(LTRIM(RTRIM(@Factory)), '');
    SET @ProcessCd = UPPER(NULLIF(LTRIM(RTRIM(@ProcessCd)), ''));
    SET @LineCd = UPPER(NULLIF(LTRIM(RTRIM(@LineCd)), ''));
    SET @MachineNm = NULLIF(LTRIM(RTRIM(@MachineNm)), '');
    SET @MachineCd = NULLIF(LTRIM(RTRIM(@MachineCd)), '');

    IF @Company IS NULL OR @Factory IS NULL OR @ProcessCd IS NULL OR @MachineNm IS NULL
    BEGIN
        RAISERROR(N'Company, Factory, ProcessCd and MachineNm are required.', 16, 1);
        RETURN;
    END;

    IF @ProcessCd NOT IN ('INLINE', 'DRAWING', 'STRANDING', 'CLOSING', 'REWINDER')
    BEGIN
        RAISERROR(N'ProcessCd must be INLINE, DRAWING, STRANDING, CLOSING or REWINDER.', 16, 1);
        RETURN;
    END;

    DECLARE @NormCd NVARCHAR(50) = NULL;
    IF @ProcessCd = 'INLINE'
    BEGIN
        SET @NormCd = dbo.fn_Cm_NormalizeInlineMachineCd(@MachineCd);
        IF @NormCd IS NULL
        BEGIN
            RAISERROR(N'INLINE requires machine code INnnnn or LInnnn (e.g. IN0012).', 16, 1);
            RETURN;
        END;
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
        FROM dbo.TB_CM_MACHINE
        WHERE COMPANY = @Company
          AND FACTORY = @Factory
          AND PROCESS_CD = @ProcessCd
          AND MACHINE_NM = @MachineNm
          AND USE_YN = 'Y'
    )
    BEGIN
        RAISERROR(N'This machine is already registered for the process.', 16, 1);
        RETURN;
    END;

    IF @NormCd IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM dbo.TB_CM_MACHINE
            WHERE COMPANY = @Company
              AND FACTORY = @Factory
              AND PROCESS_CD = @ProcessCd
              AND MACHINE_CD = @NormCd
              AND MACHINE_NM <> @MachineNm
              AND USE_YN = 'Y'
       )
    BEGIN
        RAISERROR(N'That machine code is already used on another INLINE card.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM dbo.TB_CM_MACHINE
        WHERE COMPANY = @Company
          AND FACTORY = @Factory
          AND PROCESS_CD = @ProcessCd
          AND MACHINE_NM = @MachineNm
          AND USE_YN = 'N'
    )
    BEGIN
        UPDATE dbo.TB_CM_MACHINE
        SET USE_YN = 'Y',
            LINE_CD = @LineCd,
            MACHINE_CD = @NormCd,
            LAST_CHG_DT = GETDATE()
        WHERE COMPANY = @Company
          AND FACTORY = @Factory
          AND PROCESS_CD = @ProcessCd
          AND MACHINE_NM = @MachineNm;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.TB_CM_MACHINE
            (COMPANY, FACTORY, PROCESS_CD, LINE_CD, MACHINE_NM, MACHINE_CD, USE_YN, CREATED_DT)
        VALUES
            (@Company, @Factory, @ProcessCd, @LineCd, @MachineNm, @NormCd, 'Y', GETDATE());
    END;

    SELECT
        COMPANY,
        FACTORY,
        PROCESS_CD,
        LINE_CD,
        MACHINE_NM,
        MACHINE_CD,
        USE_YN,
        CREATED_DT,
        LAST_CHG_DT
    FROM dbo.TB_CM_MACHINE
    WHERE COMPANY = @Company
      AND FACTORY = @Factory
      AND PROCESS_CD = @ProcessCd
      AND MACHINE_NM = @MachineNm;
END;
GO

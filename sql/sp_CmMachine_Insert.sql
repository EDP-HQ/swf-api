/*
    Register a machine under a process (and optional Stranding line).

    EXEC dbo.sp_CmMachine_Insert
        @Company = 'KSB', @Factory = 'F002',
        @ProcessCd = 'STRANDING', @LineCd = 'TUBULAR',
        @MachineNm = 'TUB 1250-1',
        @MachineCd = NULL,
        @LineYn = 'N'

    INLINE shared line card: @LineYn = 'Y' (no machine code; one per process).
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
    @MachineCd NVARCHAR(50) = NULL,
    @LineYn    CHAR(1)      = 'N'
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
    SET @LineYn = UPPER(NULLIF(LTRIM(RTRIM(@LineYn)), ''));
    IF @LineYn IS NULL SET @LineYn = 'N';

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

    IF @LineYn NOT IN ('Y', 'N')
    BEGIN
        RAISERROR(N'LineYn must be Y or N.', 16, 1);
        RETURN;
    END;

    IF @LineYn = 'Y' AND @ProcessCd <> 'INLINE'
    BEGIN
        RAISERROR(N'Shared line card is only for INLINE.', 16, 1);
        RETURN;
    END;

    IF @LineYn = 'Y'
        SET @MachineCd = NULL;

    IF @ProcessCd = 'INLINE' AND @LineYn = 'N' AND @MachineCd IS NULL
    BEGIN
        RAISERROR(N'INLINE requires a machine code.', 16, 1);
        RETURN;
    END;

    IF @ProcessCd <> 'INLINE'
        SET @MachineCd = NULL;

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

    IF @LineYn = 'Y'
       AND EXISTS (
            SELECT 1
            FROM dbo.TB_CM_MACHINE
            WHERE COMPANY = @Company
              AND FACTORY = @Factory
              AND PROCESS_CD = @ProcessCd
              AND LINE_YN = 'Y'
              AND USE_YN = 'Y'
              AND MACHINE_NM <> @MachineNm
       )
    BEGIN
        RAISERROR(N'A shared line card is already registered for INLINE.', 16, 1);
        RETURN;
    END;

    IF @MachineCd IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM dbo.TB_CM_MACHINE
            WHERE COMPANY = @Company
              AND FACTORY = @Factory
              AND PROCESS_CD = @ProcessCd
              AND MACHINE_CD = @MachineCd
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
            MACHINE_CD = @MachineCd,
            LINE_YN = @LineYn,
            LAST_CHG_DT = GETDATE()
        WHERE COMPANY = @Company
          AND FACTORY = @Factory
          AND PROCESS_CD = @ProcessCd
          AND MACHINE_NM = @MachineNm;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.TB_CM_MACHINE
            (COMPANY, FACTORY, PROCESS_CD, LINE_CD, MACHINE_NM, MACHINE_CD, LINE_YN, USE_YN, CREATED_DT)
        VALUES
            (@Company, @Factory, @ProcessCd, @LineCd, @MachineNm, @MachineCd, @LineYn, 'Y', GETDATE());
    END;

    SELECT
        COMPANY,
        FACTORY,
        PROCESS_CD,
        LINE_CD,
        MACHINE_NM,
        MACHINE_CD,
        LINE_YN,
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

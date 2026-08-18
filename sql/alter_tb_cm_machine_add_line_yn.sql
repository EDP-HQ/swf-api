/*
    Shared INLINE line card: LINE_YN = 'Y' — no takeup code.
    Run/Stop is OR of other INLINE machines (app + runtime worker).
*/

USE SFC_WR_DB;
GO

IF COL_LENGTH(N'dbo.TB_CM_MACHINE', N'LINE_YN') IS NULL
BEGIN
    ALTER TABLE dbo.TB_CM_MACHINE
        ADD LINE_YN CHAR(1) NOT NULL CONSTRAINT DF_TB_CM_MACHINE_LINE DEFAULT ('N');
END;
GO

IF COL_LENGTH(N'dbo.TB_CM_MACHINE', N'LINE_YN') IS NOT NULL
   AND NOT EXISTS (
        SELECT 1
        FROM sys.check_constraints
        WHERE name = N'CK_TB_CM_MACHINE_LINE'
          AND parent_object_id = OBJECT_ID(N'dbo.TB_CM_MACHINE')
   )
BEGIN
    ALTER TABLE dbo.TB_CM_MACHINE
        ADD CONSTRAINT CK_TB_CM_MACHINE_LINE CHECK (LINE_YN IN ('Y', 'N'));
END;
GO

-- One shared INLINE line card. Users do not add this from the board.
IF COL_LENGTH(N'dbo.TB_CM_MACHINE', N'LINE_YN') IS NOT NULL
   AND NOT EXISTS (
        SELECT 1
        FROM dbo.TB_CM_MACHINE
        WHERE PROCESS_CD = N'INLINE'
          AND ISNULL(LINE_YN, N'N') = N'Y'
   )
BEGIN
    DECLARE @LineCompany VARCHAR(10);
    DECLARE @LineFactory VARCHAR(20);

    SELECT TOP 1
        @LineCompany = COMPANY,
        @LineFactory = FACTORY
    FROM dbo.TB_CM_MACHINE
    WHERE PROCESS_CD = N'INLINE'
    ORDER BY CREATED_DT;

    IF @LineCompany IS NULL SET @LineCompany = 'KSB';
    IF @LineFactory IS NULL SET @LineFactory = 'F002';

    IF EXISTS (
        SELECT 1
        FROM dbo.TB_CM_MACHINE
        WHERE COMPANY = @LineCompany
          AND FACTORY = @LineFactory
          AND PROCESS_CD = N'INLINE'
          AND MACHINE_NM = N'INLINE LINE'
    )
        UPDATE dbo.TB_CM_MACHINE
        SET LINE_YN = N'Y',
            MACHINE_CD = NULL,
            USE_YN = N'Y',
            LAST_CHG_DT = GETDATE()
        WHERE COMPANY = @LineCompany
          AND FACTORY = @LineFactory
          AND PROCESS_CD = N'INLINE'
          AND MACHINE_NM = N'INLINE LINE';
    ELSE
        INSERT INTO dbo.TB_CM_MACHINE
            (COMPANY, FACTORY, PROCESS_CD, LINE_CD, MACHINE_NM, MACHINE_CD, LINE_YN, USE_YN, CREATED_DT)
        VALUES
            (@LineCompany, @LineFactory, N'INLINE', NULL, N'INLINE LINE', NULL, N'Y', N'Y', GETDATE());
END;
GO

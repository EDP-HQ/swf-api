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

IF NOT EXISTS (
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

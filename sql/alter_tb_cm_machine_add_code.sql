/*
    User-entered plant/takeup machine code for INLINE registry cards.
    Drawing/Closing/etc. keep name-matching; INLINE uses this code (IN####).
*/

USE SFC_WR_DB;
GO

IF COL_LENGTH(N'dbo.TB_CM_MACHINE', N'MACHINE_CD') IS NULL
BEGIN
    ALTER TABLE dbo.TB_CM_MACHINE
        ADD MACHINE_CD NVARCHAR(50) NULL;
END;
GO

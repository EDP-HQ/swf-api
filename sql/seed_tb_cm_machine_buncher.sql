/*
    Seed Stranding / Buncher machines currently used by component monitoring.
*/

USE SFC_WR_DB;
GO

SET NOCOUNT ON;

DECLARE @Company VARCHAR(10) = 'KSB';
DECLARE @Factory VARCHAR(20) = 'F002';

IF OBJECT_ID(N'dbo.TB_CM_MACHINE', N'U') IS NULL
BEGIN
    RAISERROR(N'TB_CM_MACHINE missing — run create_tb_cm_machine.sql first.', 16, 1);
    RETURN;
END;

;WITH m AS (
    SELECT v.MACHINE_NM
    FROM (VALUES
        (N'BUN 500-1'),
        (N'BUN 400-1'),
        (N'BUN 500-2'),
        (N'BUN 500-3'),
        (N'BUN 630'),
        (N'BUN 300-1'),
        (N'BUN 300-2')
    ) AS v(MACHINE_NM)
)
INSERT INTO dbo.TB_CM_MACHINE (COMPANY, FACTORY, PROCESS_CD, LINE_CD, MACHINE_NM, USE_YN, CREATED_DT)
SELECT @Company, @Factory, 'STRANDING', 'BUNCHER', m.MACHINE_NM, 'Y', GETDATE()
FROM m
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.TB_CM_MACHINE t
    WHERE t.COMPANY = @Company
      AND t.FACTORY = @Factory
      AND t.PROCESS_CD = 'STRANDING'
      AND t.MACHINE_NM = m.MACHINE_NM
);

DECLARE @Cnt INT =
(
    SELECT COUNT(*)
    FROM dbo.TB_CM_MACHINE
    WHERE PROCESS_CD = 'STRANDING'
      AND LINE_CD = 'BUNCHER'
      AND USE_YN = 'Y'
);
PRINT CONCAT('Buncher seed done. Active STRANDING/BUNCHER count: ', @Cnt);
GO

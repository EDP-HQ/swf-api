/*
    Seed dbo.TB_COMPONENTS_TRACKER — 3 rows per machine:
      PART_SEQ 1 / GEARBOX — 8000 h
      PART_SEQ 2 / SF      — 6000 h (Skipper front)
      PART_SEQ 3 / SB      — 6000 h (Skipper back)

    Run after: create_machine_fixed_part.sql
    Safe to re-run (skips rows that already exist).
*/

USE SFC_WR_DB;
GO

SET NOCOUNT ON;

DECLARE @Company    VARCHAR(10)  = 'KSB';
DECLARE @Factory    VARCHAR(20)  = 'F002';
DECLARE @ReplaceDt  DATETIME     = CAST(GETDATE() AS DATE);
DECLARE @YearPrefix VARCHAR(4)   = CONVERT(VARCHAR(4), YEAR(GETDATE()));

IF OBJECT_ID(N'dbo.TB_COMPONENTS_TRACKER', N'U') IS NULL
BEGIN
    RAISERROR(N'dbo.TB_COMPONENTS_TRACKER does not exist. Run create_machine_fixed_part.sql first.', 16, 1);
    RETURN;
END;

IF OBJECT_ID(N'tempdb..#machines') IS NOT NULL
    DROP TABLE #machines;

CREATE TABLE #machines
(
    MACHINE_NM NVARCHAR(100) NOT NULL PRIMARY KEY
);

/* Load machines from roller on/off SP (adjust #onoff columns if your SP returns more fields) */
BEGIN TRY
    IF OBJECT_ID(N'tempdb..#onoff') IS NOT NULL
        DROP TABLE #onoff;

    CREATE TABLE #onoff
    (
        MachineName NVARCHAR(200) NULL,
        MACHINE_NO  NVARCHAR(50)  NULL,
        RUN_DN_TYPE VARCHAR(10)   NULL
    );

    INSERT #onoff
    EXEC dbo.sp_Roller_Run_ONOFF;

    INSERT INTO #machines (MACHINE_NM)
    SELECT DISTINCT LTRIM(RTRIM(o.MachineName))
    FROM #onoff AS o
    WHERE o.MachineName IS NOT NULL
      AND LTRIM(RTRIM(o.MachineName)) <> '';
END TRY
BEGIN CATCH
    PRINT N'Note: sp_Roller_Run_ONOFF not used — ' + ERROR_MESSAGE();
END CATCH;

/* Fallback machine list (same as parts-board dashboard) */
INSERT INTO #machines (MACHINE_NM)
SELECT v.MACHINE_NM
FROM (VALUES
    (N'BUN 300-1'),
    (N'BUN 300-2'),
    (N'BUN 400-1'),
    (N'BUN 500-1'),
    (N'BUN 500-2'),
    (N'BUN 500-3'),
    (N'BUN 630')
) AS v(MACHINE_NM)
WHERE NOT EXISTS (
    SELECT 1
    FROM #machines AS m
    WHERE m.MACHINE_NM = v.MACHINE_NM
);

;WITH parts AS (
    SELECT *
    FROM (VALUES
        (1, N'GEARBOX', 8000.00),
        (2, N'SF',      6000.00),
        (3, N'SB',      6000.00)
    ) AS p(PART_SEQ, PART_TYPE, RUNTIME_LIMIT_HOUR)
),
numbered AS (
    SELECT
        m.MACHINE_NM,
        p.PART_SEQ,
        p.PART_TYPE,
        p.RUNTIME_LIMIT_HOUR,
        ROW_NUMBER() OVER (ORDER BY m.MACHINE_NM, p.PART_SEQ) AS rn
    FROM #machines AS m
    CROSS JOIN parts AS p
)
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
SELECT
    @Company,
    @Factory,
    'FP' + @YearPrefix + RIGHT('00000' + CAST(n.rn AS VARCHAR(5)), 5),
    n.PART_SEQ,
    n.PART_TYPE,
    n.MACHINE_NM,
    @ReplaceDt,
    NULL,
    n.RUNTIME_LIMIT_HOUR,
    0,
    'Y'
FROM numbered AS n
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.TB_COMPONENTS_TRACKER AS t
    WHERE t.MACHINE_NM = n.MACHINE_NM
      AND t.PART_SEQ = n.PART_SEQ
      AND t.[USE] = 'Y'
);

PRINT CONCAT(N'Inserted ', @@ROWCOUNT, N' component row(s).');

SELECT
    t.MACHINE_NM,
    t.PART_SEQ,
    t.PART_TYPE,
    t.PART_ID,
    t.RUNTIME_LIMIT_HOUR,
    t.RUNTIME_SEC,
    t.REPLACE_DT,
    t.[USE]
FROM dbo.TB_COMPONENTS_TRACKER AS t
ORDER BY t.MACHINE_NM, t.PART_SEQ;
GO

/*
    Seed Buncher gearbox pool (10) and migrate existing active tracker rows.
    GB01-GB07 <- current machines; GB08-GB10 <- SPARE.
*/

USE SFC_WR_DB;
GO

SET NOCOUNT ON;

DECLARE @Company VARCHAR(10) = 'KSB';
DECLARE @Factory VARCHAR(20) = 'F002';
DECLARE @ProcessCd VARCHAR(20) = 'STRANDING';
DECLARE @LineCd VARCHAR(20) = 'BUNCHER';

IF OBJECT_ID(N'dbo.TB_CM_GEARBOX_ASSET', N'U') IS NULL
BEGIN
    RAISERROR(N'TB_CM_GEARBOX_ASSET missing — run create_tb_cm_gearbox.sql first.', 16, 1);
    RETURN;
END;

;WITH ids AS (
    SELECT v.GEARBOX_ID
    FROM (VALUES
        ('GB01'),('GB02'),('GB03'),('GB04'),('GB05'),
        ('GB06'),('GB07'),('GB08'),('GB09'),('GB10')
    ) AS v(GEARBOX_ID)
)
INSERT INTO dbo.TB_CM_GEARBOX_ASSET
    (COMPANY, FACTORY, GEARBOX_ID, PROCESS_CD, LINE_CD, STATUS, LIFETIME_RUNTIME_SEC, CREATED_DT)
SELECT @Company, @Factory, i.GEARBOX_ID, @ProcessCd, @LineCd, 'SPARE', 0, GETDATE()
FROM ids i
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.TB_CM_GEARBOX_ASSET a
    WHERE a.COMPANY = @Company
      AND a.FACTORY = @Factory
      AND a.GEARBOX_ID = i.GEARBOX_ID
);

;WITH activeGb AS (
    SELECT
        t.PART_ID,
        t.MACHINE_NM,
        t.RUNTIME_SEC,
        t.REPLACE_DT,
        rn = ROW_NUMBER() OVER (ORDER BY t.MACHINE_NM)
    FROM dbo.TB_COMPONENTS_TRACKER t
    WHERE t.[USE] = 'Y'
      AND UPPER(LTRIM(RTRIM(t.PART_TYPE))) = 'GEARBOX'
      AND t.PROCESS_CD = @ProcessCd
      AND t.LINE_CD = @LineCd
),
map AS (
    SELECT
        PART_ID AS OldPartId,
        MACHINE_NM,
        RUNTIME_SEC,
        REPLACE_DT,
        GearboxId = 'GB' + RIGHT('0' + CAST(rn AS VARCHAR(2)), 2)
    FROM activeGb
    WHERE rn <= 7
)
UPDATE a
SET
    a.STATUS = 'IN_USE',
    a.CURRENT_MACHINE_NM = m.MACHINE_NM,
    a.CURRENT_PART_ID = m.OldPartId,
    a.LIFETIME_RUNTIME_SEC = CASE
        WHEN ISNULL(a.LIFETIME_RUNTIME_SEC, 0) > 0 THEN a.LIFETIME_RUNTIME_SEC
        ELSE ISNULL(m.RUNTIME_SEC, 0)
    END,
    a.LAST_CHG_DT = GETDATE()
FROM dbo.TB_CM_GEARBOX_ASSET a
INNER JOIN map m ON m.GearboxId = a.GEARBOX_ID
WHERE a.COMPANY = @Company
  AND a.FACTORY = @Factory
  AND a.PROCESS_CD = @ProcessCd
  AND a.LINE_CD = @LineCd
  AND a.STATUS = 'SPARE';

;WITH activeGb AS (
    SELECT
        t.PART_ID,
        t.MACHINE_NM,
        t.RUNTIME_SEC,
        t.REPLACE_DT,
        rn = ROW_NUMBER() OVER (ORDER BY t.MACHINE_NM)
    FROM dbo.TB_COMPONENTS_TRACKER t
    WHERE t.[USE] = 'Y'
      AND UPPER(LTRIM(RTRIM(t.PART_TYPE))) = 'GEARBOX'
      AND t.PROCESS_CD = @ProcessCd
      AND t.LINE_CD = @LineCd
),
map AS (
    SELECT
        PART_ID AS OldPartId,
        MACHINE_NM,
        RUNTIME_SEC,
        REPLACE_DT,
        GearboxId = 'GB' + RIGHT('0' + CAST(rn AS VARCHAR(2)), 2)
    FROM activeGb
    WHERE rn <= 7
)
INSERT INTO dbo.TB_CM_GEARBOX_HISTORY
    (COMPANY, FACTORY, GEARBOX_ID, MACHINE_NM, PART_ID, PROCESS_CD, LINE_CD,
     MOUNT_DT, DISMOUNT_DT, RUNTIME_SEC, REASON)
SELECT
    @Company, @Factory, m.GearboxId, m.MACHINE_NM, m.OldPartId, @ProcessCd, @LineCd,
    ISNULL(m.REPLACE_DT, GETDATE()), NULL, ISNULL(m.RUNTIME_SEC, 0), 'MIGRATE'
FROM map m
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.TB_CM_GEARBOX_HISTORY h
    WHERE h.GEARBOX_ID = m.GearboxId
      AND h.DISMOUNT_DT IS NULL
);

DECLARE @InUse INT = (
    SELECT COUNT(*) FROM dbo.TB_CM_GEARBOX_ASSET
    WHERE PROCESS_CD = @ProcessCd AND LINE_CD = @LineCd AND STATUS = 'IN_USE'
);
DECLARE @Spare INT = (
    SELECT COUNT(*) FROM dbo.TB_CM_GEARBOX_ASSET
    WHERE PROCESS_CD = @ProcessCd AND LINE_CD = @LineCd AND STATUS = 'SPARE'
);

PRINT CONCAT('Buncher gearbox pool: IN_USE=', @InUse, ' SPARE=', @Spare);
GO

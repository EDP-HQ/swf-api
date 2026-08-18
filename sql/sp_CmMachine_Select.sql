/*
    Component-monitoring machine registry, with plant Run/Stop when the
    display name matches TB_CD_MACHINE (SWF prefix + trailing (T)/(P)/… stripped).

    EXEC dbo.sp_CmMachine_Select @ProcessCd='CLOSING', @UseYn='Y'
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CmMachine_Select
    @ProcessCd     VARCHAR(20) = NULL,
    @LineCd        VARCHAR(20) = NULL,
    @UseYn         CHAR(1)     = 'Y',
    @IncludeHidden BIT         = 0
AS
BEGIN
    SET NOCOUNT ON;

    SET @ProcessCd = UPPER(NULLIF(LTRIM(RTRIM(@ProcessCd)), ''));
    SET @LineCd = UPPER(NULLIF(LTRIM(RTRIM(@LineCd)), ''));
    SET @UseYn = NULLIF(LTRIM(RTRIM(@UseYn)), '');

    IF @ProcessCd = 'STRANDING' AND @LineCd IS NULL
    BEGIN
        SELECT TOP 0
            COMPANY, FACTORY, PROCESS_CD, LINE_CD, MACHINE_NM, USE_YN,
            CREATED_DT, LAST_CHG_DT,
            CAST(NULL AS NVARCHAR(50)) AS MACHINE_NO,
            CAST(NULL AS NVARCHAR(10)) AS RUN_DN_TYPE,
            CAST(NULL AS DATETIME) AS RUN_START_TIME,
            CAST(NULL AS NVARCHAR(50)) AS MACHINE_CD
        FROM dbo.TB_CM_MACHINE;
        RETURN;
    END;

    ;WITH plant AS (
        SELECT
            m.MACHINE_CD,
            m.MACHINE_DESC,
            m.MACHINE_DESC_SHORT,
            PlantName = LTRIM(RTRIM(
                CASE
                    WHEN UPPER(LEFT(LTRIM(m.MACHINE_DESC), 4)) = N'SWF '
                        THEN SUBSTRING(LTRIM(m.MACHINE_DESC), 5, 400)
                    ELSE m.MACHINE_DESC
                END
            )),
            -- Closing/Tubular: SWF 12X12C(T) → 12X12C ; SWF 8X6F-3 (cmp no) → 8X6F-3
            PlantNameCore = LTRIM(RTRIM(
                CASE
                    WHEN CHARINDEX(N'(',
                            CASE
                                WHEN UPPER(LEFT(LTRIM(m.MACHINE_DESC), 4)) = N'SWF '
                                    THEN SUBSTRING(LTRIM(m.MACHINE_DESC), 5, 400)
                                ELSE m.MACHINE_DESC
                            END
                         ) > 0
                    THEN LEFT(
                            CASE
                                WHEN UPPER(LEFT(LTRIM(m.MACHINE_DESC), 4)) = N'SWF '
                                    THEN SUBSTRING(LTRIM(m.MACHINE_DESC), 5, 400)
                                ELSE m.MACHINE_DESC
                            END,
                            CHARINDEX(N'(',
                                CASE
                                    WHEN UPPER(LEFT(LTRIM(m.MACHINE_DESC), 4)) = N'SWF '
                                        THEN SUBSTRING(LTRIM(m.MACHINE_DESC), 5, 400)
                                    ELSE m.MACHINE_DESC
                                END
                            ) - 1
                         )
                    ELSE CASE
                            WHEN UPPER(LEFT(LTRIM(m.MACHINE_DESC), 4)) = N'SWF '
                                THEN SUBSTRING(LTRIM(m.MACHINE_DESC), 5, 400)
                            ELSE m.MACHINE_DESC
                         END
                END
            ))
        FROM dbo.TB_CD_MACHINE m
        WHERE ISNULL(m.USE_YN, N'Y') = N'Y'
    )
    SELECT
        cm.COMPANY,
        cm.FACTORY,
        cm.PROCESS_CD,
        cm.LINE_CD,
        cm.MACHINE_NM,
        cm.USE_YN,
        cm.CREATED_DT,
        cm.LAST_CHG_DT,
        CASE
            WHEN cm.PROCESS_CD = N'INLINE'
                THEN dbo.fn_Cm_NormalizeInlineMachineCd(cm.MACHINE_CD)
            ELSE cd.MACHINE_CD
        END AS MACHINE_NO,
        CASE
            WHEN cm.PROCESS_CD = N'INLINE' THEN N'00'
            ELSE ISNULL(rd.RUN_DN_TYPE, N'00')
        END AS RUN_DN_TYPE,
        CASE
            WHEN cm.PROCESS_CD = N'INLINE' THEN CAST(NULL AS DATETIME)
            ELSE rd.START_TIME
        END AS RUN_START_TIME,
        cm.MACHINE_CD
    FROM dbo.TB_CM_MACHINE cm
    OUTER APPLY (
        SELECT TOP 1 p.MACHINE_CD
        FROM plant p
        WHERE p.PlantName = cm.MACHINE_NM
           OR p.PlantNameCore = cm.MACHINE_NM
           OR p.MACHINE_DESC = cm.MACHINE_NM
           OR p.MACHINE_DESC_SHORT = cm.MACHINE_NM
           OR p.PlantNameCore = LTRIM(RTRIM(
                CASE
                    WHEN CHARINDEX(N'(', cm.MACHINE_NM) > 0
                        THEN LEFT(cm.MACHINE_NM, CHARINDEX(N'(', cm.MACHINE_NM) - 1)
                    ELSE cm.MACHINE_NM
                END
              ))
    ) cd
    OUTER APPLY (
        SELECT TOP 1
            r.RUN_DN_TYPE,
            r.START_TIME
        FROM dbo.TB_RUN_DOWN_COLLECTION r
        WHERE cm.PROCESS_CD <> N'INLINE'
          AND cd.MACHINE_CD IS NOT NULL
          AND r.MACHINE_NO = cd.MACHINE_CD
        ORDER BY r.START_TIME DESC
    ) rd
    WHERE (@IncludeHidden = 1 OR @UseYn IS NULL OR cm.USE_YN = @UseYn)
      AND (@ProcessCd IS NULL OR cm.PROCESS_CD = @ProcessCd)
      AND (
            @ProcessCd IS NULL
            OR @ProcessCd <> 'STRANDING'
            OR cm.LINE_CD = @LineCd
          )
      AND (
            @ProcessCd IS NULL
            OR @ProcessCd = 'STRANDING'
            OR cm.LINE_CD IS NULL
          )
    ORDER BY cm.PROCESS_CD, cm.LINE_CD, cm.MACHINE_NM;
END;
GO

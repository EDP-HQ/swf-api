/*
    Buncher machine Run/Stop for roller + component monitoring.

    Reads local TB_RUN_DOWN_COLLECTION (already fed from plant) — does NOT call
    linked server SEAHQ_01_SEC.sp_ON_OFF_MACHINE (that path hangs on MSDTC/RPC).

    MachineName = MACHINE_DESC with leading "SWF " and trailing "(…)" stripped
    so it matches TB_CM_MACHINE / board names (e.g. BUN 500-1).
    RUN_DN_TYPE = '01' → Run, otherwise Stop.

    EXEC dbo.sp_Roller_Run_ONOFF
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Roller_Run_ONOFF
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH cd AS (
        SELECT
            m.MACHINE_CD,
            m.MACHINE_DESC,
            m.MACHINE_DESC_SHORT,
            m.PROCESS_ID,
            RawName = LTRIM(RTRIM(
                CASE
                    WHEN UPPER(LEFT(LTRIM(m.MACHINE_DESC), 4)) = N'SWF '
                        THEN SUBSTRING(LTRIM(m.MACHINE_DESC), 5, 400)
                    ELSE m.MACHINE_DESC
                END
            ))
        FROM dbo.TB_CD_MACHINE m
        WHERE ISNULL(m.USE_YN, N'Y') = N'Y'
          AND m.PROCESS_ID = N'ST'
          AND m.MACHINE_DESC LIKE N'%BUN%'
    ),
    named AS (
        SELECT
            MACHINE_CD,
            MACHINE_DESC,
            MACHINE_DESC_SHORT,
            PROCESS_ID,
            RawName,
            MachineName = LTRIM(RTRIM(
                CASE
                    WHEN CHARINDEX(N'(', RawName) > 0
                        THEN LEFT(RawName, CHARINDEX(N'(', RawName) - 1)
                    ELSE RawName
                END
            ))
        FROM cd
    ),
    mx AS (
        SELECT
            r.MACHINE_NO,
            MAX(r.START_TIME) AS START_TIME
        FROM dbo.TB_RUN_DOWN_COLLECTION r
        WHERE EXISTS (
            SELECT 1 FROM named n WHERE n.MACHINE_CD = r.MACHINE_NO
        )
        GROUP BY r.MACHINE_NO
    )
    SELECT
        CAST(NULL AS BIGINT) AS RUNDN_ID,
        n.MACHINE_CD AS MACHINE_NO,
        n.MachineName,
        ISNULL(r.RUN_DN_TYPE, N'00') AS RUN_DN_TYPE,
        mx.START_TIME,
        r.END_TIME,
        n.MACHINE_DESC,
        n.MACHINE_DESC_SHORT,
        n.PROCESS_ID,
        n.RawName AS MACHINE_NAME_FULL
    FROM named n
    LEFT JOIN mx
        ON mx.MACHINE_NO = n.MACHINE_CD
    LEFT JOIN dbo.TB_RUN_DOWN_COLLECTION r
        ON r.MACHINE_NO = mx.MACHINE_NO
       AND r.START_TIME = mx.START_TIME
    ORDER BY n.MachineName;
END;
GO

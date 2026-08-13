/*
    Plant Run/Stop for component monitoring (Drawing, Closing, Rewinder, …).

    Latest row per machine from TB_RUN_DOWN_COLLECTION, joined to TB_CD_MACHINE.
    MachineName is MACHINE_DESC with a leading "SWF " stripped so it matches
    TB_CM_MACHINE.MACHINE_NM (e.g. SWF 12X13HSP → 12X13HSP).
    RUN_DN_TYPE = '01' → Run, otherwise Stop.

    EXEC dbo.sp_Components_Run_ONOFF @ProcessCd = 'DRAWING'
    EXEC dbo.sp_Components_Run_ONOFF  -- all processes
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Components_Run_ONOFF
    @ProcessCd VARCHAR(20) = NULL,
    @LineCd    VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Proc VARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(@ProcessCd, N''))));
    DECLARE @ProcessId NVARCHAR(10) = CASE @Proc
        WHEN N'DRAWING'   THEN N'DW'
        WHEN N'INLINE'    THEN N'IL'
        WHEN N'STRANDING' THEN N'ST'
        WHEN N'CLOSING'   THEN N'CL'
        WHEN N'REWINDER'  THEN N'RE'
        WHEN N''          THEN NULL
        ELSE NULL
    END;

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
          AND (@ProcessId IS NULL OR m.PROCESS_ID = @ProcessId)
    ),
    named AS (
        SELECT
            MACHINE_CD,
            MACHINE_DESC,
            MACHINE_DESC_SHORT,
            PROCESS_ID,
            -- Prefer core name so registry "12X12C" matches plant "12X12C(T)"
            MachineName = LTRIM(RTRIM(
                CASE
                    WHEN CHARINDEX(N'(', RawName) > 0
                        THEN LEFT(RawName, CHARINDEX(N'(', RawName) - 1)
                    ELSE RawName
                END
            )),
            RawName
        FROM cd
    ),
    latest AS (
        SELECT
            r.MACHINE_NO,
            r.RUN_DN_TYPE,
            r.START_TIME,
            r.END_TIME,
            rn = ROW_NUMBER() OVER (PARTITION BY r.MACHINE_NO ORDER BY r.START_TIME DESC)
        FROM dbo.TB_RUN_DOWN_COLLECTION r
        INNER JOIN named n ON n.MACHINE_CD = r.MACHINE_NO
    )
    SELECT
        CAST(NULL AS BIGINT) AS RUNDN_ID,
        n.MACHINE_CD AS MACHINE_NO,
        n.MachineName,
        ISNULL(l.RUN_DN_TYPE, N'00') AS RUN_DN_TYPE,
        l.START_TIME,
        l.END_TIME,
        n.MACHINE_DESC,
        n.MACHINE_DESC_SHORT,
        n.PROCESS_ID,
        n.RawName AS MACHINE_NAME_FULL
    FROM named n
    LEFT JOIN latest l
        ON l.MACHINE_NO = n.MACHINE_CD
       AND l.rn = 1
    ORDER BY n.MachineName;
END;
GO

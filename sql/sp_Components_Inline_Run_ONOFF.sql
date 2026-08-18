/*
    INLINE Run/Stop from takeup linked DB, keyed by user-entered MACHINE_CD (IN####).

    Use OPENQUERY — do not INSERT EXEC (MSDTC blocks distributed tx on SEAHQ01).

    EXEC dbo.sp_Components_Inline_Run_ONOFF
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Components_Inline_Run_ONOFF
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT
            CAST(NULL AS BIGINT) AS RUNDN_ID,
            t.MACHINE AS MACHINE_NO,
            ISNULL(
                LTRIM(RTRIM(
                    CASE
                        WHEN UPPER(LEFT(LTRIM(p.MACHINE_DESC), 4)) = N'SWF '
                            THEN SUBSTRING(LTRIM(p.MACHINE_DESC), 5, 400)
                        ELSE p.MACHINE_DESC
                    END
                )),
                t.MACHINE
            ) AS MachineName,
            CASE WHEN ISNULL(t.TAKEUP_RUN, 0) = 1 THEN N'01' ELSE N'00' END AS RUN_DN_TYPE,
            t.TIME_STAMP AS START_TIME,
            CAST(NULL AS DATETIME) AS END_TIME,
            p.MACHINE_DESC,
            p.MACHINE_DESC_SHORT,
            p.MACHINE_CD AS PLANT_MACHINE_CD
        FROM OPENQUERY(
            SEAHQ01,
            N'SET FMTONLY OFF; EXEC [KSB_INTAKEUPdb_01].[dbo].[Up_GetLatestTakeupRun_ByMachine]'
        ) t
        LEFT JOIN dbo.TB_CD_MACHINE p
            ON p.PROCESS_ID = N'IL'
           AND (
                p.MACHINE_CD = N'LI' + RIGHT(t.MACHINE, 4)
                OR p.MACHINE_CD = t.MACHINE
              )
        ORDER BY t.MACHINE;
    END TRY
    BEGIN CATCH
        SELECT
            CAST(NULL AS BIGINT) AS RUNDN_ID,
            CAST(NULL AS NVARCHAR(50)) AS MACHINE_NO,
            CAST(NULL AS NVARCHAR(200)) AS MachineName,
            CAST(N'00' AS NVARCHAR(10)) AS RUN_DN_TYPE,
            CAST(NULL AS DATETIME) AS START_TIME,
            CAST(NULL AS DATETIME) AS END_TIME,
            CAST(NULL AS NVARCHAR(200)) AS MACHINE_DESC,
            CAST(NULL AS NVARCHAR(100)) AS MACHINE_DESC_SHORT,
            CAST(NULL AS NVARCHAR(50)) AS PLANT_MACHINE_CD
        WHERE 1 = 0;
    END CATCH;
END;
GO

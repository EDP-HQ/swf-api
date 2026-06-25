/*
    Returns active component rows from dbo.TB_COMPONENTS_TRACKER
    for Parts Monitoring (gearbox, skipper SF / SB).

    [USE] = 'Y' → active, 'N' → ended/replaced.
    Optional filters — pass NULL to return all active rows.
*/

USE SFC_WR_DB;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Components_Select
    @Company   VARCHAR(10)  = NULL,
    @Factory   VARCHAR(20)  = NULL,
    @MachineNm NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
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
    FROM dbo.TB_COMPONENTS_TRACKER
    WHERE [USE] = 'Y'
      AND (@Company IS NULL OR COMPANY = @Company)
      AND (@Factory IS NULL OR FACTORY = @Factory)
      AND (@MachineNm IS NULL OR MACHINE_NM = @MachineNm)
    ORDER BY MACHINE_NM, PART_SEQ;
END;
GO

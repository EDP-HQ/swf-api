/*
    Replace history for a component slot on a machine (all rows for MACHINE_NM + PART_TYPE).

    Identify by @PartId (derives machine + type) OR @MachineNm + @PartType.
    Ordered newest first (REPLACE_DT desc, PART_SEQ desc).
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Components_History
    @PartId     VARCHAR(20)     = NULL,
    @MachineNm  NVARCHAR(100)   = NULL,
    @PartType   VARCHAR(20)     = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @PartId IS NOT NULL
    BEGIN
        SELECT
            @MachineNm = MACHINE_NM,
            @PartType = PART_TYPE
        FROM dbo.TB_COMPONENTS_TRACKER
        WHERE PART_ID = @PartId;
    END;

    SET @PartType = NULLIF(LTRIM(RTRIM(@PartType)), '');

    IF @MachineNm IS NULL OR LTRIM(RTRIM(@MachineNm)) = ''
    BEGIN
        RAISERROR(N'MachineNm is required.', 16, 1);
        RETURN;
    END;

    IF @PartType IS NULL
    BEGIN
        RAISERROR(N'PartType is required.', 16, 1);
        RETURN;
    END;

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
    WHERE MACHINE_NM = @MachineNm
      AND UPPER(LTRIM(RTRIM(PART_TYPE))) = UPPER(@PartType)
    ORDER BY REPLACE_DT DESC, PART_SEQ DESC, PART_ID DESC;
END;
GO

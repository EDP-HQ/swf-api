/*
    Active components, optionally scoped by process / line / machine.

    EXEC dbo.sp_Components_Select @ProcessCd='STRANDING', @LineCd='BUNCHER'
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Components_Select
    @Company   VARCHAR(10)   = NULL,
    @Factory   VARCHAR(20)   = NULL,
    @MachineNm NVARCHAR(100) = NULL,
    @ProcessCd VARCHAR(20)   = NULL,
    @LineCd    VARCHAR(20)   = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @Company = NULLIF(LTRIM(RTRIM(@Company)), '');
    SET @Factory = NULLIF(LTRIM(RTRIM(@Factory)), '');
    SET @MachineNm = NULLIF(LTRIM(RTRIM(@MachineNm)), '');
    SET @ProcessCd = UPPER(NULLIF(LTRIM(RTRIM(@ProcessCd)), ''));
    SET @LineCd = UPPER(NULLIF(LTRIM(RTRIM(@LineCd)), ''));

    -- Stranding without line must not return Buncher+Tubular together
    IF @ProcessCd = 'STRANDING' AND @LineCd IS NULL
    BEGIN
        SELECT TOP 0
            COMPANY, FACTORY, PART_ID, PART_SEQ, PART_TYPE, MACHINE_NM,
            PROCESS_CD, LINE_CD, REPLACE_DT, DISMANTLE_DT, RUNTIME_LIMIT_HOUR, RUNTIME_SEC, [USE]
        FROM dbo.TB_COMPONENTS_TRACKER;
        RETURN;
    END;

    SELECT
        COMPANY,
        FACTORY,
        PART_ID,
        PART_SEQ,
        PART_TYPE,
        MACHINE_NM,
        PROCESS_CD,
        LINE_CD,
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
      AND (@ProcessCd IS NULL OR PROCESS_CD = @ProcessCd)
      AND (
            @ProcessCd IS NULL
            OR @ProcessCd <> 'STRANDING'
            OR LINE_CD = @LineCd
          )
      AND (
            @ProcessCd = 'STRANDING'
            OR LINE_CD IS NULL
          )
    ORDER BY MACHINE_NM, PART_SEQ;
END;
GO

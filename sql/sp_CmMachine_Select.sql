/*
    List registered component-monitoring machines.
    Optional filters: @ProcessCd, @LineCd, @UseYn (default 'Y').

    EXEC dbo.sp_CmMachine_Select @ProcessCd = 'STRANDING', @LineCd = 'BUNCHER'
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CmMachine_Select
    @ProcessCd VARCHAR(20) = NULL,
    @LineCd    VARCHAR(20) = NULL,
    @UseYn     CHAR(1)     = 'Y'
AS
BEGIN
    SET NOCOUNT ON;

    SET @ProcessCd = NULLIF(LTRIM(RTRIM(@ProcessCd)), '');
    SET @LineCd = NULLIF(LTRIM(RTRIM(@LineCd)), '');
    SET @UseYn = NULLIF(LTRIM(RTRIM(@UseYn)), '');

    SELECT
        COMPANY,
        FACTORY,
        PROCESS_CD,
        LINE_CD,
        MACHINE_NM,
        USE_YN,
        CREATED_DT,
        LAST_CHG_DT
    FROM dbo.TB_CM_MACHINE
    WHERE (@UseYn IS NULL OR USE_YN = @UseYn)
      AND (@ProcessCd IS NULL OR PROCESS_CD = @ProcessCd)
      AND (
            @LineCd IS NULL
            OR LINE_CD = @LineCd
            OR (@LineCd = '' AND LINE_CD IS NULL)
          )
    ORDER BY PROCESS_CD, LINE_CD, MACHINE_NM;
END;
GO

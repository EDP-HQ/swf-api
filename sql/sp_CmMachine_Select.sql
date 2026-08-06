/*
    List registered machines. For STRANDING, @LineCd is required.
    Non-STRANDING processes only return rows with LINE_CD NULL.
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
    @UseYn     CHAR(1)     = 'Y',
    @IncludeHidden BIT     = 0
AS
BEGIN
    SET NOCOUNT ON;

    SET @ProcessCd = UPPER(NULLIF(LTRIM(RTRIM(@ProcessCd)), ''));
    SET @LineCd = UPPER(NULLIF(LTRIM(RTRIM(@LineCd)), ''));
    SET @UseYn = NULLIF(LTRIM(RTRIM(@UseYn)), '');

    IF @ProcessCd = 'STRANDING' AND @LineCd IS NULL
    BEGIN
        SELECT TOP 0
            COMPANY, FACTORY, PROCESS_CD, LINE_CD, MACHINE_NM, USE_YN, CREATED_DT, LAST_CHG_DT
        FROM dbo.TB_CM_MACHINE;
        RETURN;
    END;

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
    WHERE (@IncludeHidden = 1 OR @UseYn IS NULL OR USE_YN = @UseYn)
      AND (@ProcessCd IS NULL OR PROCESS_CD = @ProcessCd)
      AND (
            @ProcessCd <> 'STRANDING'
            OR LINE_CD = @LineCd
          )
      AND (
            @ProcessCd = 'STRANDING'
            OR LINE_CD IS NULL
          )
    ORDER BY PROCESS_CD, LINE_CD, MACHINE_NM;
END;
GO

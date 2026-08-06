/*
    Active roller runtime + limit, scoped by process / line via bin master.

    EXEC dbo.sp_Roller_Curr_Runtime @ProcessCd='STRANDING', @LineCd='BUNCHER'
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Roller_Curr_Runtime
    @RollerId   VARCHAR(30)  = NULL,
    @OnlyActive BIT          = 1,
    @ProcessCd  VARCHAR(20)  = NULL,
    @LineCd     VARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @RollerId = NULLIF(LTRIM(RTRIM(@RollerId)), '');
    SET @ProcessCd = UPPER(NULLIF(LTRIM(RTRIM(@ProcessCd)), ''));
    SET @LineCd = UPPER(NULLIF(LTRIM(RTRIM(@LineCd)), ''));

    DECLARE @ProcessId VARCHAR(10) = dbo.fn_Cm_ProcessIdFromCd(@ProcessCd);

    ;WITH bins AS (
        SELECT
            BIN_LOCATION_CD,
            IS_BUNCHER = CASE
                WHEN UPPER(LTRIM(BIN_LOCATION_DESC)) LIKE N'BUN %' THEN 1
                ELSE 0 END
        FROM dbo.TB_CD_BIN_LOCATION
        WHERE (@ProcessId IS NULL OR PROCESS_ID = @ProcessId)
          AND BIN_LOCATION_TP = N'Pay-off'
    )
    SELECT
        t.COMPANY,
        t.FACTORY,
        t.ROLLER_ID,
        t.ROLLER_SEQ,
        t.BIN_LOCATION_CD,
        t.REPLACE_DT,
        t.RUNTIME_SEC,
        t.RUNTIME_LIMIT_HOUR,
        t.END_YN
    FROM dbo.TB_ROLLER_TRACKER t
    LEFT JOIN bins b ON b.BIN_LOCATION_CD = t.BIN_LOCATION_CD
    WHERE (@OnlyActive = 0 OR t.END_YN = N'N')
      AND (@RollerId IS NULL OR t.ROLLER_ID = @RollerId)
      AND (
            @ProcessCd IS NULL
            OR (
                b.BIN_LOCATION_CD IS NOT NULL
                AND (
                    @ProcessCd <> 'STRANDING'
                    OR @LineCd IS NULL
                    OR (@LineCd = 'BUNCHER' AND b.IS_BUNCHER = 1)
                    OR (@LineCd = 'TUBULAR' AND b.IS_BUNCHER = 0)
                )
            )
          )
    ORDER BY t.BIN_LOCATION_CD, t.ROLLER_SEQ;
END;
GO

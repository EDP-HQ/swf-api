/****************************************************************************
    Name    : sp_Bobbin_Inventory_ForScrap_Select
    Purpose : List TB_INVENTORY rows for a scanned bobbin barcode before PDA scrap.
              Barcode → LC_CD resolution matches USP_SFC_PDA_SCRAP_I10 (read-only).
              Does not modify inventory or call scrap.

    EXEC sp_Bobbin_Inventory_ForScrap_Select 'KSB','F002','PB40_0005','ENG'
****************************************************************************/
CREATE OR ALTER PROCEDURE [dbo].[sp_Bobbin_Inventory_ForScrap_Select]
(
    @COMPANY    NVARCHAR(20),
    @FACTORY    NVARCHAR(20),
    @LC_CD      NVARCHAR(20),
    @LANG       VARCHAR(5) = 'ENG'
)
AS
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

BEGIN
    DECLARE @LookupCd   NVARCHAR(20) = LTRIM(RTRIM(@LC_CD)),
            @ResolvedLc NVARCHAR(20) = LTRIM(RTRIM(@LC_CD));

    IF @LookupCd = ''
    BEGIN
        RETURN;
    END

    IF EXISTS (
        SELECT 1
        FROM TB_CD_LC
        WHERE LC_BARCODE_ID = @LookupCd
          AND TEMP_LC_YN = 'Y'
    )
    BEGIN
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM TB_CD_LC WHERE LC_BARCODE_ID = @LookupCd)
    BEGIN
        SELECT @ResolvedLc = LC_CD
        FROM TB_CD_LC
        WHERE LC_BARCODE_ID = @LookupCd;
    END

    SELECT
        B.PL_NO,
        B.LC_CD,
        B.MATERIAL_CD,
        B.MATERIAL_DESC,
        B.BIN_LOCATION_CD,
        B.STORAGE_LOCATION_CD,
        B.BALANCE_WT,
        B.BALANCE_LENGTH,
        B.PROD_DT,
        B.INVENTORY_STATUS,
        B.WO_PROCESS_ID
    FROM TB_INVENTORY B
    WHERE B.COMPANY = @COMPANY
      AND B.FACTORY = @FACTORY
      AND (
            B.LC_CD = @ResolvedLc
         OR B.LC_CD = @LookupCd
         OR B.PL_NO = @LookupCd
      )
    ORDER BY B.PROD_DT DESC, B.PL_NO;
END
GO

/*
    Map UI PROCESS_CD → TB_CD_BIN_LOCATION.PROCESS_ID
    and Stranding LINE_CD → Buncher (BUN*) vs Tubular (other ST pay-off).
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION dbo.fn_Cm_ProcessIdFromCd(@ProcessCd VARCHAR(20))
RETURNS VARCHAR(10)
AS
BEGIN
    DECLARE @p VARCHAR(20) = UPPER(NULLIF(LTRIM(RTRIM(@ProcessCd)), ''));
    RETURN CASE @p
        WHEN 'INLINE' THEN 'IL'
        WHEN 'DRAWING' THEN 'DW'
        WHEN 'STRANDING' THEN 'ST'
        WHEN 'CLOSING' THEN 'CL'
        WHEN 'REWINDER' THEN 'RE'
        ELSE NULL
    END;
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_Cm_MachineNameFromBinDesc(@BinDesc NVARCHAR(200))
RETURNS NVARCHAR(100)
AS
BEGIN
    DECLARE @d NVARCHAR(200) = LTRIM(RTRIM(ISNULL(@BinDesc, N'')));
    DECLARE @i INT;

    SET @i = CHARINDEX(N' (', @d);
    IF @i > 1
        RETURN LTRIM(RTRIM(LEFT(@d, @i - 1)));

    SET @i = CHARINDEX(N' PAY-OFF', UPPER(@d));
    IF @i > 1
        RETURN LTRIM(RTRIM(LEFT(@d, @i - 1)));

    SET @i = CHARINDEX(N' TAKE-UP', UPPER(@d));
    IF @i > 1
        RETURN LTRIM(RTRIM(LEFT(@d, @i - 1)));

    RETURN @d;
END;
GO

-- INLINE: LI0001 or IN0001 → IN0001 (takeup key). Invalid → NULL.
CREATE OR ALTER FUNCTION dbo.fn_Cm_NormalizeInlineMachineCd(@MachineCd NVARCHAR(50))
RETURNS NVARCHAR(50)
AS
BEGIN
    DECLARE @v NVARCHAR(50) = UPPER(LTRIM(RTRIM(ISNULL(@MachineCd, N''))));
    IF @v LIKE N'LI[0-9][0-9][0-9][0-9]' RETURN N'IN' + RIGHT(@v, 4);
    IF @v LIKE N'IN[0-9][0-9][0-9][0-9]' RETURN @v;
    RETURN NULL;
END;
GO

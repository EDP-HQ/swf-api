/*
    Hide / unhide a registered machine (USE_YN = N / Y).
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CmMachine_SetVisible
    @Company    VARCHAR(10),
    @Factory    VARCHAR(20),
    @ProcessCd  VARCHAR(20),
    @LineCd     VARCHAR(20) = NULL,
    @MachineNm  NVARCHAR(100),
    @VisibleYn  CHAR(1)       -- 'Y' = show, 'N' = hide
AS
BEGIN
    SET NOCOUNT ON;

    SET @Company = NULLIF(LTRIM(RTRIM(@Company)), '');
    SET @Factory = NULLIF(LTRIM(RTRIM(@Factory)), '');
    SET @ProcessCd = UPPER(NULLIF(LTRIM(RTRIM(@ProcessCd)), ''));
    SET @LineCd = UPPER(NULLIF(LTRIM(RTRIM(@LineCd)), ''));
    SET @MachineNm = NULLIF(LTRIM(RTRIM(@MachineNm)), '');
    SET @VisibleYn = UPPER(NULLIF(LTRIM(RTRIM(@VisibleYn)), ''));

    IF @Company IS NULL OR @Factory IS NULL OR @ProcessCd IS NULL OR @MachineNm IS NULL
    BEGIN
        RAISERROR(N'Company, Factory, ProcessCd and MachineNm are required.', 16, 1);
        RETURN;
    END;

    IF @VisibleYn NOT IN ('Y', 'N')
    BEGIN
        RAISERROR(N'VisibleYn must be Y or N.', 16, 1);
        RETURN;
    END;

    IF @ProcessCd = 'STRANDING' AND (@LineCd IS NULL OR @LineCd NOT IN ('BUNCHER', 'TUBULAR'))
    BEGIN
        RAISERROR(N'STRANDING requires LineCd BUNCHER or TUBULAR.', 16, 1);
        RETURN;
    END;

    IF @ProcessCd <> 'STRANDING'
        SET @LineCd = NULL;

    UPDATE dbo.TB_CM_MACHINE
    SET USE_YN = @VisibleYn,
        LAST_CHG_DT = GETDATE()
    WHERE COMPANY = @Company
      AND FACTORY = @Factory
      AND PROCESS_CD = @ProcessCd
      AND MACHINE_NM = @MachineNm
      AND (
            (@LineCd IS NULL AND LINE_CD IS NULL)
            OR LINE_CD = @LineCd
          );

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR(N'Machine not found in registry for this process/line.', 16, 1);
        RETURN;
    END;

    SELECT COMPANY, FACTORY, PROCESS_CD, LINE_CD, MACHINE_NM, USE_YN, CREATED_DT, LAST_CHG_DT
    FROM dbo.TB_CM_MACHINE
    WHERE COMPANY = @Company
      AND FACTORY = @Factory
      AND PROCESS_CD = @ProcessCd
      AND MACHINE_NM = @MachineNm
      AND (
            (@LineCd IS NULL AND LINE_CD IS NULL)
            OR LINE_CD = @LineCd
          );
END;
GO

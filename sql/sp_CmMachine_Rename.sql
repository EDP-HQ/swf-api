/*
    Rename a registered machine. Updates registry + component + gearbox name refs.

    EXEC dbo.sp_CmMachine_Rename
        @Company = 'KSB', @Factory = 'F002',
        @ProcessCd = 'DRAWING', @LineCd = NULL,
        @OldMachineNm = '8X8+6X7HSP',
        @NewMachineNm = '8X8 HSP',
        @MachineCd = NULL
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CmMachine_Rename
    @Company       VARCHAR(10),
    @Factory       VARCHAR(20),
    @ProcessCd     VARCHAR(20),
    @LineCd        VARCHAR(20)    = NULL,
    @OldMachineNm  NVARCHAR(100),
    @NewMachineNm  NVARCHAR(100),
    @MachineCd     NVARCHAR(50)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Company = NULLIF(LTRIM(RTRIM(@Company)), '');
    SET @Factory = NULLIF(LTRIM(RTRIM(@Factory)), '');
    SET @ProcessCd = UPPER(NULLIF(LTRIM(RTRIM(@ProcessCd)), ''));
    SET @LineCd = UPPER(NULLIF(LTRIM(RTRIM(@LineCd)), ''));
    SET @OldMachineNm = NULLIF(LTRIM(RTRIM(@OldMachineNm)), '');
    SET @NewMachineNm = NULLIF(LTRIM(RTRIM(@NewMachineNm)), '');
    SET @MachineCd = NULLIF(LTRIM(RTRIM(@MachineCd)), '');

    IF @Company IS NULL OR @Factory IS NULL OR @ProcessCd IS NULL
       OR @OldMachineNm IS NULL OR @NewMachineNm IS NULL
    BEGIN
        RAISERROR(N'Company, Factory, ProcessCd, OldMachineNm and NewMachineNm are required.', 16, 1);
        RETURN;
    END;

    IF @ProcessCd = 'STRANDING'
    BEGIN
        IF @LineCd IS NULL OR @LineCd NOT IN ('BUNCHER', 'TUBULAR')
        BEGIN
            RAISERROR(N'STRANDING requires LineCd BUNCHER or TUBULAR.', 16, 1);
            RETURN;
        END;
    END
    ELSE
        SET @LineCd = NULL;

    DECLARE @NormCd NVARCHAR(50) = NULL;
    DECLARE @HasCode BIT = 0;
    IF @ProcessCd = 'INLINE'
    BEGIN
        SET @HasCode = 1;
        SET @NormCd = dbo.fn_Cm_NormalizeInlineMachineCd(@MachineCd);
        IF @MachineCd IS NOT NULL AND @NormCd IS NULL
        BEGIN
            RAISERROR(N'INLINE machine code must be INnnnn or LInnnn (e.g. IN0012).', 16, 1);
            RETURN;
        END;
    END;

    DECLARE @NameChanged BIT = CASE WHEN @OldMachineNm = @NewMachineNm THEN 0 ELSE 1 END;

    IF @NameChanged = 0 AND @HasCode = 0
    BEGIN
        RAISERROR(N'New name is the same as the current name.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.TB_CM_MACHINE
        WHERE COMPANY = @Company
          AND FACTORY = @Factory
          AND PROCESS_CD = @ProcessCd
          AND MACHINE_NM = @OldMachineNm
          AND (
                (@LineCd IS NULL AND LINE_CD IS NULL)
                OR LINE_CD = @LineCd
              )
    )
    BEGIN
        RAISERROR(N'Machine not found in registry for this process/line.', 16, 1);
        RETURN;
    END;

    IF @NameChanged = 1
       AND EXISTS (
        SELECT 1
        FROM dbo.TB_CM_MACHINE
        WHERE COMPANY = @Company
          AND FACTORY = @Factory
          AND PROCESS_CD = @ProcessCd
          AND MACHINE_NM = @NewMachineNm
    )
    BEGIN
        RAISERROR(N'That machine name is already registered for this process.', 16, 1);
        RETURN;
    END;

    IF @NormCd IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM dbo.TB_CM_MACHINE
            WHERE COMPANY = @Company
              AND FACTORY = @Factory
              AND PROCESS_CD = @ProcessCd
              AND MACHINE_CD = @NormCd
              AND MACHINE_NM <> @OldMachineNm
              AND USE_YN = 'Y'
       )
    BEGIN
        RAISERROR(N'That machine code is already used on another INLINE card.', 16, 1);
        RETURN;
    END;

    BEGIN TRAN;

    UPDATE dbo.TB_CM_MACHINE
    SET MACHINE_NM = @NewMachineNm,
        MACHINE_CD = CASE WHEN @HasCode = 1 THEN @NormCd ELSE MACHINE_CD END,
        LAST_CHG_DT = GETDATE()
    WHERE COMPANY = @Company
      AND FACTORY = @Factory
      AND PROCESS_CD = @ProcessCd
      AND MACHINE_NM = @OldMachineNm
      AND (
            (@LineCd IS NULL AND LINE_CD IS NULL)
            OR LINE_CD = @LineCd
          );

    IF @NameChanged = 1
    BEGIN
        UPDATE dbo.TB_COMPONENTS_TRACKER
        SET MACHINE_NM = @NewMachineNm
        WHERE MACHINE_NM = @OldMachineNm
          AND ISNULL(PROCESS_CD, N'') = ISNULL(@ProcessCd, N'')
          AND (
                @LineCd IS NULL
                OR ISNULL(LINE_CD, N'') = @LineCd
              );

        IF OBJECT_ID(N'dbo.TB_CM_GEARBOX_ASSET', N'U') IS NOT NULL
        BEGIN
            UPDATE dbo.TB_CM_GEARBOX_ASSET
            SET CURRENT_MACHINE_NM = @NewMachineNm,
                LAST_CHG_DT = GETDATE()
            WHERE CURRENT_MACHINE_NM = @OldMachineNm
              AND ISNULL(PROCESS_CD, N'') = ISNULL(@ProcessCd, N'')
              AND (
                    @LineCd IS NULL
                    OR ISNULL(LINE_CD, N'') = @LineCd
                  );
        END;

        IF OBJECT_ID(N'dbo.TB_CM_GEARBOX_HISTORY', N'U') IS NOT NULL
        BEGIN
            UPDATE dbo.TB_CM_GEARBOX_HISTORY
            SET MACHINE_NM = @NewMachineNm
            WHERE MACHINE_NM = @OldMachineNm
              AND ISNULL(PROCESS_CD, N'') = ISNULL(@ProcessCd, N'')
              AND (
                    @LineCd IS NULL
                    OR ISNULL(LINE_CD, N'') = @LineCd
                  );
        END;
    END;

    COMMIT TRAN;

    SELECT
        COMPANY, FACTORY, PROCESS_CD, LINE_CD, MACHINE_NM, MACHINE_CD, USE_YN, CREATED_DT, LAST_CHG_DT
    FROM dbo.TB_CM_MACHINE
    WHERE COMPANY = @Company
      AND FACTORY = @Factory
      AND PROCESS_CD = @ProcessCd
      AND MACHINE_NM = @NewMachineNm;
END;
GO

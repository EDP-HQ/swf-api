/*
    Persist accumulated roller runtime when a roller stops working
    (machine STOP or roller no longer active).

    Updates RUNTIME_SEC on the active row (END_YN = 'N').
    Identify row by @RollerId OR @BinLocationCd.

    Read runtime via existing sp_Roller_Curr_Runtime (no separate retrieve SP).
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Roller_UpdateRuntime
    @RollerId       VARCHAR(30)  = NULL,
    @BinLocationCd  NVARCHAR(50) = NULL,
    @RuntimeSec     BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    IF @RuntimeSec IS NULL OR @RuntimeSec < 0
    BEGIN
        RAISERROR(N'RuntimeSec must be zero or greater.', 16, 1);
        RETURN;
    END;

    IF @RollerId IS NULL AND @BinLocationCd IS NULL
    BEGIN
        RAISERROR(N'Provide RollerId or BinLocationCd.', 16, 1);
        RETURN;
    END;

    DECLARE @TargetRollerId VARCHAR(30);

    SELECT TOP 1 @TargetRollerId = ROLLER_ID
    FROM dbo.TB_ROLLER_TRACKER WITH (UPDLOCK, ROWLOCK)
    WHERE END_YN = 'N'
      AND (
          (@RollerId IS NOT NULL AND ROLLER_ID = @RollerId)
          OR (@BinLocationCd IS NOT NULL AND BIN_LOCATION_CD = @BinLocationCd)
      );

    IF @TargetRollerId IS NULL
    BEGIN
        RAISERROR(N'Active roller not found.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.TB_ROLLER_TRACKER
    SET RUNTIME_SEC = @RuntimeSec
    WHERE ROLLER_ID = @TargetRollerId;

    SELECT
        COMPANY,
        ROLLER_ID,
        ROLLER_SEQ,
        BIN_LOCATION_CD,
        REPLACE_DT,
        RUNTIME_SEC
    FROM dbo.TB_ROLLER_TRACKER
    WHERE ROLLER_ID = @TargetRollerId;
END;
GO

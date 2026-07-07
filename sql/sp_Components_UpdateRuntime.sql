/*
    Persist accumulated component runtime when a machine stops.

    Updates RUNTIME_SEC on the active row ([USE] = 'Y').
    Identify row by @PartId OR (@MachineNm + @PartSeq).

    Returns the updated row.
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Components_UpdateRuntime
    @PartId     VARCHAR(20)     = NULL,
    @MachineNm  NVARCHAR(100)   = NULL,
    @PartSeq    INT             = NULL,
    @RuntimeSec BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    IF @RuntimeSec IS NULL OR @RuntimeSec < 0
    BEGIN
        RAISERROR(N'RuntimeSec must be zero or greater.', 16, 1);
        RETURN;
    END;

    IF @PartId IS NULL AND (@MachineNm IS NULL OR @PartSeq IS NULL)
    BEGIN
        RAISERROR(N'Provide PartId or both MachineNm and PartSeq.', 16, 1);
        RETURN;
    END;

    DECLARE @TargetPartId VARCHAR(20);

    SELECT TOP 1 @TargetPartId = PART_ID
    FROM dbo.TB_COMPONENTS_TRACKER WITH (UPDLOCK, ROWLOCK)
    WHERE [USE] = 'Y'
      AND (
          (@PartId IS NOT NULL AND PART_ID = @PartId)
          OR (
              @PartId IS NULL
              AND MACHINE_NM = @MachineNm
              AND PART_SEQ = @PartSeq
          )
      );

    IF @TargetPartId IS NULL
    BEGIN
        RAISERROR(N'Active component not found.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.TB_COMPONENTS_TRACKER
    SET RUNTIME_SEC = @RuntimeSec
    WHERE PART_ID = @TargetPartId;

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
    WHERE PART_ID = @TargetPartId;
END;
GO

/*
    Update runtime limit (hours) on the active component row ([USE] = 'Y').
    Identify row by @PartId OR (@MachineNm + @PartSeq).

    Returns the updated row.
*/

USE SFC_WR_DB;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Components_UpdateRuntimeLimit
    @PartId            VARCHAR(20)     = NULL,
    @MachineNm         NVARCHAR(100)   = NULL,
    @PartSeq           INT             = NULL,
    @RuntimeLimitHour  DECIMAL(12, 2)
AS
BEGIN
    SET NOCOUNT ON;

    IF @RuntimeLimitHour IS NULL OR @RuntimeLimitHour <= 0
    BEGIN
        RAISERROR(N'RuntimeLimitHour must be greater than zero.', 16, 1);
        RETURN;
    END;

    IF @PartId IS NULL AND (@MachineNm IS NULL OR @PartSeq IS NULL)
    BEGIN
        RAISERROR(N'Provide PartId or both MachineNm and PartSeq.', 16, 1);
        RETURN;
    END;

    IF @PartSeq IS NOT NULL AND @PartSeq NOT IN (1, 2, 3)
    BEGIN
        RAISERROR(N'PartSeq must be 1 (gearbox), 2 (SF), or 3 (SB).', 16, 1);
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
    SET RUNTIME_LIMIT_HOUR = @RuntimeLimitHour
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

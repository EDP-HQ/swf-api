/*
    Update runtime limit (hours) on the active component row ([USE] = 'Y').
    Logs old → new limit into TB_COMPONENTS_LIMIT_HISTORY when the value changes.

    Identify row by @PartId OR (@MachineNm + @PartSeq).
    Returns the updated row.
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Components_UpdateRuntimeLimit
    @PartId            VARCHAR(20)     = NULL,
    @MachineNm         NVARCHAR(100)   = NULL,
    @PartSeq           INT             = NULL,
    @RuntimeLimitHour  DECIMAL(12, 2),
    @ChangedBy         NVARCHAR(100)   = NULL
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

    DECLARE
        @TargetPartId VARCHAR(20),
        @OldLimit DECIMAL(12, 2),
        @Machine NVARCHAR(100),
        @PartType NVARCHAR(100),
        @Seq INT;

    SELECT TOP 1
        @TargetPartId = PART_ID,
        @OldLimit = RUNTIME_LIMIT_HOUR,
        @Machine = MACHINE_NM,
        @PartType = PART_TYPE,
        @Seq = PART_SEQ
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

    IF @OldLimit IS NULL OR @OldLimit <> @RuntimeLimitHour
    BEGIN
        INSERT INTO dbo.TB_COMPONENTS_LIMIT_HISTORY (
            PART_ID, MACHINE_NM, PART_TYPE, PART_SEQ,
            OLD_LIMIT_HOUR, NEW_LIMIT_HOUR, CHANGED_DT, CHANGED_BY
        )
        VALUES (
            @TargetPartId, @Machine, @PartType, @Seq,
            @OldLimit, @RuntimeLimitHour, SYSUTCDATETIME(), NULLIF(LTRIM(RTRIM(@ChangedBy)), N'')
        );
    END;

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

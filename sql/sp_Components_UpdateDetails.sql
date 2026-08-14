/*
    Update PART_DETAILS on an active component.

    EXEC dbo.sp_Components_UpdateDetails @PartId='FP202600001', @PartDetails='SKF 6205'
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Components_UpdateDetails
    @PartId       VARCHAR(20)     = NULL,
    @MachineNm    NVARCHAR(100)   = NULL,
    @PartSeq      INT             = NULL,
    @PartDetails  NVARCHAR(500)   = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @PartId IS NULL AND (@MachineNm IS NULL OR @PartSeq IS NULL)
    BEGIN
        RAISERROR(N'Provide PartId or both MachineNm and PartSeq.', 16, 1);
        RETURN;
    END;

    SET @PartDetails = NULLIF(LTRIM(RTRIM(@PartDetails)), '');

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
    SET PART_DETAILS = @PartDetails
    WHERE PART_ID = @TargetPartId;

    SELECT
        COMPANY, FACTORY, PART_ID, PART_SEQ, PART_TYPE, MACHINE_NM,
        PROCESS_CD, LINE_CD,
        REPLACE_DT, DISMANTLE_DT, RUNTIME_LIMIT_HOUR, RUNTIME_SEC, [USE],
        PART_DETAILS
    FROM dbo.TB_COMPONENTS_TRACKER
    WHERE PART_ID = @TargetPartId;
END;
GO

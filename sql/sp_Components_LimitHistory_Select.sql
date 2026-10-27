/*
    Limit-change history for a component (newest first).

    EXEC dbo.sp_Components_LimitHistory_Select @PartId = 'FP202600001'
    EXEC dbo.sp_Components_LimitHistory_Select @MachineNm = 'BUN 500-1', @PartType = 'GEARBOX'
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Components_LimitHistory_Select
    @PartId     VARCHAR(20)     = NULL,
    @MachineNm  NVARCHAR(100)   = NULL,
    @PartType   NVARCHAR(100)   = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @PartId IS NULL OR LTRIM(RTRIM(@PartId)) = ''
    BEGIN
        IF @MachineNm IS NULL OR LTRIM(RTRIM(@MachineNm)) = ''
        BEGIN
            RAISERROR(N'PartId or MachineNm is required.', 16, 1);
            RETURN;
        END;
    END;

    SELECT
        h.HIST_ID,
        h.PART_ID,
        h.MACHINE_NM,
        h.PART_TYPE,
        h.PART_SEQ,
        h.OLD_LIMIT_HOUR,
        h.NEW_LIMIT_HOUR,
        h.CHANGED_DT,
        h.CHANGED_BY
    FROM dbo.TB_COMPONENTS_LIMIT_HISTORY h
    WHERE (
            @PartId IS NOT NULL
            AND LTRIM(RTRIM(@PartId)) <> ''
            AND h.PART_ID = @PartId
          )
       OR (
            (@PartId IS NULL OR LTRIM(RTRIM(@PartId)) = '')
            AND h.MACHINE_NM = @MachineNm
            AND (
                @PartType IS NULL
                OR LTRIM(RTRIM(@PartType)) = ''
                OR UPPER(LTRIM(RTRIM(h.PART_TYPE))) = UPPER(LTRIM(RTRIM(@PartType)))
            )
          )
    ORDER BY h.CHANGED_DT DESC, h.HIST_ID DESC;
END;
GO

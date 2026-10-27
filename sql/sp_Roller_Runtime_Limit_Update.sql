/*
    Update active roller runtime limit and log history when value changes.

    EXEC dbo.sp_Roller_Runtime_Limit_Update @RollerId = 'ST0009_0001', @RuntimeLimit = 4000
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Roller_Runtime_Limit_Update
    @RollerId      VARCHAR(30),
    @RuntimeLimit  DECIMAL(18, 2),
    @ChangedBy     NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @RollerId IS NULL OR LTRIM(RTRIM(@RollerId)) = ''
    BEGIN
        RAISERROR(N'RollerId is required.', 16, 1);
        RETURN;
    END;

    IF @RuntimeLimit IS NULL OR @RuntimeLimit <= 0
    BEGIN
        RAISERROR(N'RuntimeLimit must be greater than zero.', 16, 1);
        RETURN;
    END;

    DECLARE
        @OldLimit DECIMAL(12, 2),
        @Bin VARCHAR(50);

    SELECT TOP 1
        @OldLimit = RUNTIME_LIMIT_HOUR,
        @Bin = BIN_LOCATION_CD
    FROM dbo.TB_ROLLER_TRACKER WITH (UPDLOCK, ROWLOCK)
    WHERE ROLLER_ID = @RollerId
      AND END_YN = 'N';

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR(N'Active roller not found.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.TB_ROLLER_TRACKER
    SET RUNTIME_LIMIT_HOUR = @RuntimeLimit
    WHERE ROLLER_ID = @RollerId
      AND END_YN = 'N';

    IF @OldLimit IS NULL OR CAST(@OldLimit AS DECIMAL(18, 2)) <> @RuntimeLimit
    BEGIN
        INSERT INTO dbo.TB_ROLLER_LIMIT_HISTORY (
            ROLLER_ID, BIN_LOCATION_CD, OLD_LIMIT_HOUR, NEW_LIMIT_HOUR, CHANGED_DT, CHANGED_BY
        )
        VALUES (
            @RollerId, @Bin, @OldLimit, @RuntimeLimit, SYSUTCDATETIME(),
            NULLIF(LTRIM(RTRIM(@ChangedBy)), N'')
        );
    END;
END;
GO

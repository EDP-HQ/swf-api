/*

    Register a new active component on a machine.



    PART_SEQ is auto-assigned: MAX(PART_SEQ) among active rows on the machine + 1,

    or 1 when this is the first active component on the machine.



    Fails if an active row with the same PART_TYPE already exists on the machine.

*/



USE SFC_WR_DB;

GO



SET ANSI_NULLS ON;

GO

SET QUOTED_IDENTIFIER ON;

GO



CREATE OR ALTER PROCEDURE dbo.sp_Components_Insert

    @Company           VARCHAR(10),

    @Factory           VARCHAR(20),

    @MachineNm         NVARCHAR(100),

    @PartType          VARCHAR(20),

    @RuntimeLimitHour  DECIMAL(12, 2)

AS

BEGIN

    SET NOCOUNT ON;

    SET XACT_ABORT ON;



    IF @Company IS NULL OR LTRIM(RTRIM(@Company)) = ''

    BEGIN

        RAISERROR(N'Company is required.', 16, 1);

        RETURN;

    END;



    IF @Factory IS NULL OR LTRIM(RTRIM(@Factory)) = ''

    BEGIN

        RAISERROR(N'Factory is required.', 16, 1);

        RETURN;

    END;



    IF @MachineNm IS NULL OR LTRIM(RTRIM(@MachineNm)) = ''

    BEGIN

        RAISERROR(N'MachineNm is required.', 16, 1);

        RETURN;

    END;



    IF @RuntimeLimitHour IS NULL OR @RuntimeLimitHour <= 0

    BEGIN

        RAISERROR(N'RuntimeLimitHour must be greater than zero.', 16, 1);

        RETURN;

    END;



    SET @PartType = NULLIF(LTRIM(RTRIM(@PartType)), '');



    IF @PartType IS NULL

    BEGIN

        RAISERROR(N'PartType is required.', 16, 1);

        RETURN;

    END;



    IF EXISTS (

        SELECT 1

        FROM dbo.TB_COMPONENTS_TRACKER WITH (UPDLOCK, HOLDLOCK)

        WHERE [USE] = 'Y'

          AND MACHINE_NM = @MachineNm

          AND UPPER(LTRIM(RTRIM(PART_TYPE))) = UPPER(@PartType)

    )

    BEGIN

        RAISERROR(N'An active component with this part type already exists on this machine.', 16, 1);

        RETURN;

    END;



    DECLARE @PartSeq      INT;

    DECLARE @Now          DATETIME = GETDATE();

    DECLARE @ReplaceDt    DATETIME = CAST(@Now AS DATE);

    DECLARE @YearPrefix   VARCHAR(4) = CONVERT(VARCHAR(4), YEAR(@Now));

    DECLARE @NextIdSeq    INT;

    DECLARE @NewPartId    VARCHAR(20);



    SELECT @PartSeq = ISNULL(MAX(PART_SEQ), 0) + 1

    FROM dbo.TB_COMPONENTS_TRACKER WITH (UPDLOCK, HOLDLOCK)

    WHERE [USE] = 'Y'

      AND MACHINE_NM = @MachineNm;



    SELECT @NextIdSeq = ISNULL(MAX(CAST(RIGHT(PART_ID, 5) AS INT)), 0) + 1

    FROM dbo.TB_COMPONENTS_TRACKER WITH (UPDLOCK, HOLDLOCK)

    WHERE PART_ID LIKE 'FP' + @YearPrefix + '%';



    SET @NewPartId = 'FP' + @YearPrefix + RIGHT('00000' + CAST(@NextIdSeq AS VARCHAR(5)), 5);



    INSERT INTO dbo.TB_COMPONENTS_TRACKER

    (

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

    )

    VALUES

    (

        @Company,

        @Factory,

        @NewPartId,

        @PartSeq,

        @PartType,

        @MachineNm,

        @ReplaceDt,

        NULL,

        @RuntimeLimitHour,

        0,

        'Y'

    );



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

    WHERE PART_ID = @NewPartId;

END;

GO



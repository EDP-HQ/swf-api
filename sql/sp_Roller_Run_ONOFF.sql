/*
    Buncher Run/Stop from linked HQ SP. Do not wrap in INSERT EXEC —
    linked server requires MSDTC which is disabled here.

    EXEC dbo.sp_Roller_Run_ONOFF
*/

USE SFC_WR_DB;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Roller_Run_ONOFF
AS
BEGIN
    SET NOCOUNT ON;

    EXEC [SEAHQ_01_SEC].[SEAHQ_01_SEC].[dbo].[sp_ON_OFF_MACHINE];
END;
GO

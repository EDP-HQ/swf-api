/***********************************************************************************************
    sp_MaterialVerification_M2B_Select
    Material → bin location verification (KBAS010 Suggestion Bin.lo / TB_CD_MATERIAL.BIN_LOCATION_CD).

    Does NOT replace USP_SFC_KBAS090_PRINT_R10_M — used only by the new M2B dashboard.

    FLAG2 (wrong item):
      - Empty bin → Y
      - Stock on bin but no material assigned to this bin on TB_CD_MATERIAL → N
      - More than one distinct inventory MATERIAL_CD → N
      - Inventory MATERIAL_CD (or NC replace match) not in allowed set for this bin → N
      - Otherwise → Y

    BIN_LOCATION_TARGET column: expected grade text from material master (MATERIAL_DESC_ADVARIS).

    exec dbo.sp_MaterialVerification_M2B_Select @LANG = 'EN';
***********************************************************************************************/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_MaterialVerification_M2B_Select]
(
    @LANG VARCHAR(5) = 'EN'
)
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    ;WITH AllowedMaterials AS (
        SELECT
            m.BIN_LOCATION_CD,
            LTRIM(RTRIM(m.MATERIAL_CD)) AS ALLOWED_MATERIAL_CD
        FROM dbo.TB_CD_MATERIAL AS m WITH (NOLOCK)
        WHERE ISNULL(m.USE_YN, 'N') = 'Y'
          AND m.BIN_LOCATION_CD IS NOT NULL
          AND LTRIM(RTRIM(m.BIN_LOCATION_CD)) <> ''
          AND m.MATERIAL_CD IS NOT NULL
          AND LTRIM(RTRIM(m.MATERIAL_CD)) <> ''

        UNION

        SELECT
            m.BIN_LOCATION_CD,
            LTRIM(RTRIM(m.NC_REPLACE_MATERIAL_CD)) AS ALLOWED_MATERIAL_CD
        FROM dbo.TB_CD_MATERIAL AS m WITH (NOLOCK)
        WHERE ISNULL(m.USE_YN, 'N') = 'Y'
          AND m.BIN_LOCATION_CD IS NOT NULL
          AND LTRIM(RTRIM(m.BIN_LOCATION_CD)) <> ''
          AND m.NC_REPLACE_MATERIAL_CD IS NOT NULL
          AND LTRIM(RTRIM(m.NC_REPLACE_MATERIAL_CD)) <> ''
    ),
    ExpectByBin AS (
        SELECT
            m.BIN_LOCATION_CD,
            COUNT(DISTINCT m.MATERIAL_CD) AS SUGGESTION_MATERIAL_CNT,
            MIN(m.MATERIAL_CD) AS PRIMARY_MATERIAL_CD,
            MIN(m.MATERIAL_DESC_ADVARIS) AS MATERIAL_TARGET
        FROM dbo.TB_CD_MATERIAL AS m WITH (NOLOCK)
        WHERE ISNULL(m.USE_YN, 'N') = 'Y'
          AND m.BIN_LOCATION_CD IS NOT NULL
          AND LTRIM(RTRIM(m.BIN_LOCATION_CD)) <> ''
        GROUP BY m.BIN_LOCATION_CD
    ),
    BinUnion AS (
        SELECT
            dbo.FN_COMMON_SEL('CDNAME', 'MES025', A.STORE_TP, @LANG) AS CDNAME,
            A.BIN_LOCATION_CD AS BIN_LOC,
            A.STORE_TP,
            A.BIN_LOCATION_DESC
        FROM dbo.TB_CD_BIN_LOCATION AS A WITH (NOLOCK)
        WHERE A.STORE_TP IN ('05', '03', '07')

        UNION ALL

        SELECT
            dbo.FN_COMMON_SEL('CDNAME', 'MES025', A.STORE_TP, @LANG) AS CDNAME,
            A.BIN_LOCATION_CD AS BIN_LOC,
            A.STORE_TP,
            A.BIN_LOCATION_DESC
        FROM dbo.TB_CD_BIN_LOCATION AS A WITH (NOLOCK)
        WHERE A.STORE_TP = '06'
          AND TRY_CAST(RIGHT(A.BIN_LOCATION_CD, 4) AS INT) <= 128
          AND A.BIN_LOCATION_CD <> 'WM0001_0001'
    ),
    Detail AS (
        SELECT
            U.CDNAME,
            U.BIN_LOC,
            U.BIN_LOCATION_DESC,
            CASE WHEN B.PL_NO IS NULL THEN 0 ELSE 1 END AS CNT,
            B.MATERIAL_CD AS INV_MATERIAL_CD,
            am.ALLOWED_MATERIAL_CD AS ALLOWED_MATCH
        FROM BinUnion AS U
        LEFT JOIN dbo.TB_INVENTORY AS B WITH (NOLOCK)
            ON U.BIN_LOC = B.BIN_LOCATION_CD
        LEFT JOIN AllowedMaterials AS am
            ON am.BIN_LOCATION_CD = U.BIN_LOC
           AND am.ALLOWED_MATERIAL_CD = LTRIM(RTRIM(B.MATERIAL_CD))
    ),
    InvAgg AS (
        SELECT
            D.CDNAME,
            D.BIN_LOC,
            MAX(D.BIN_LOCATION_DESC) AS BIN_LOCATION_DESC,
            SUM(D.CNT) AS TOTAL_CNT,
            COUNT(DISTINCT CASE WHEN D.CNT > 0 THEN D.INV_MATERIAL_CD END) AS INV_MATERIAL_DISTINCT_CNT,
            MAX(CASE WHEN D.CNT > 0 THEN D.INV_MATERIAL_CD END) AS INV_MATERIAL_CD_SAMPLE,
            SUM(
                CASE
                    WHEN D.CNT > 0 AND (D.INV_MATERIAL_CD IS NULL OR D.ALLOWED_MATCH IS NULL) THEN 1
                    ELSE 0
                END
            ) AS INVALID_LOT_CNT
        FROM Detail AS D
        GROUP BY D.CDNAME, D.BIN_LOC
    )
    SELECT
        A.CDNAME,
        A.BIN_LOC,
        A.BIN_LOC AS BIN_LOC_FULL,
        ISNULL(E.MATERIAL_TARGET, N'') AS BIN_LOCATION_TARGET,
        A.TOTAL_CNT,
        ISNULL(E.SUGGESTION_MATERIAL_CNT, 0) AS SUGGESTION_MATERIAL_CNT,
        E.PRIMARY_MATERIAL_CD AS EXPECTED_MATERIAL_CD,
        A.INV_MATERIAL_CD_SAMPLE AS ACTUAL_MATERIAL_CD,
        'Y' AS FLAG1,
        CASE
            WHEN A.TOTAL_CNT = 0 THEN 'Y'
            WHEN ISNULL(E.SUGGESTION_MATERIAL_CNT, 0) = 0 THEN 'N'
            WHEN A.INV_MATERIAL_DISTINCT_CNT > 1 THEN 'N'
            WHEN A.INVALID_LOT_CNT > 0 THEN 'N'
            ELSE 'Y'
        END AS FLAG2,
        'M2B' AS VERIFICATION_RULE
    FROM InvAgg AS A
    LEFT JOIN ExpectByBin AS E
        ON E.BIN_LOCATION_CD = A.BIN_LOC
    ORDER BY
        CASE WHEN A.CDNAME = 'RW-B' THEN '0' ELSE A.CDNAME END DESC,
        A.BIN_LOC;
END;
GO

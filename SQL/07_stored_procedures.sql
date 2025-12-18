/* ============================================================
   File: 07_stored_procedures.sql
   Purpose: Analytical stored procedures for reporting + Power BI
   Project: Public Sector Expenditure Data Warehouse
   Platform: Microsoft SQL Server (T-SQL)

   Important (GitHub / Public Repo):
   - This file defines stored procedures only.
   - It does NOT enable xp_cmdshell or export files.
   - Optional export commands (BCP) should live in a separate local script
     such as: /sql/99_optional_exports_local.sql (DO NOT commit with paths).
   ============================================================ */

USE PublicSpendDW;
GO

/* ============================================================
   1) sp_Top3Suppliers
      - Result set 1: Top 3 suppliers by total spend (entire period)
      - Result set 2: Monthly totals for those top 3 suppliers
   ============================================================ */
DROP PROCEDURE IF EXISTS dbo.sp_Top3Suppliers;
GO

CREATE PROCEDURE dbo.sp_Top3Suppliers
AS
BEGIN
    SET NOCOUNT ON;

    /* A CTE scope is a single statement; use a temp table for reuse */
    IF OBJECT_ID('tempdb..#Top3') IS NOT NULL
        DROP TABLE #Top3;

    ;WITH SupplierTotals AS (
        SELECT
            F.SupplierID,
            SUM(F.Amount) AS TotalSpent
        FROM dbo.FactInvoice AS F
        GROUP BY F.SupplierID
    )
    SELECT TOP (3)
        SupplierID,
        TotalSpent
    INTO #Top3
    FROM SupplierTotals
    ORDER BY TotalSpent DESC;

    -- Result Set 1: Overall Top 3 suppliers
    SELECT
        S.SupplierName,
        T.TotalSpent
    FROM #Top3 AS T
    INNER JOIN dbo.DimSupplier AS S
        ON S.SupplierID = T.SupplierID
    ORDER BY T.TotalSpent DESC;

    -- Result Set 2: Monthly spend for same Top 3 suppliers
    SELECT
        D.[Year],
        D.[Month],
        S.SupplierName,
        SUM(F.Amount) AS MonthlyTotal
    FROM dbo.FactInvoice AS F
    INNER JOIN dbo.DimDate     AS D ON D.DateID     = F.DateID
    INNER JOIN dbo.DimSupplier AS S ON S.SupplierID = F.SupplierID
    INNER JOIN #Top3           AS T ON T.SupplierID = F.SupplierID
    GROUP BY D.[Year], D.[Month], S.SupplierName
    ORDER BY D.[Year], D.[Month], MonthlyTotal DESC;
END;
GO

/* ============================================================
   2) sp_ExpenseTypeAboveAvg2Month
      - Uses last date in dataset to compute a rolling 2-month window
      - Aggregates spend per ExpenseType within window
      - Returns only expense types above the average (JSON output)
   ============================================================ */
DROP PROCEDURE IF EXISTS dbo.sp_ExpenseTypeAboveAvg2Month;
GO

CREATE PROCEDURE dbo.sp_ExpenseTypeAboveAvg2Month
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MaxDate   date,
            @StartDate date;

    SELECT @MaxDate = MAX(D.FullDate)
    FROM dbo.FactInvoice AS F
    INNER JOIN dbo.DimDate AS D
        ON D.DateID = F.DateID;

    SET @StartDate = DATEADD(MONTH, -2, @MaxDate);

    ;WITH TwoMonthTotals AS (
        SELECT
            ET.ExpenseType,
            SUM(F.Amount) AS TwoMonthTotal
        FROM dbo.FactInvoice AS F
        INNER JOIN dbo.DimExpenseType AS ET ON ET.ExpenseTypeID = F.ExpenseTypeID
        INNER JOIN dbo.DimDate        AS D  ON D.DateID        = F.DateID
        WHERE D.FullDate >  @StartDate
          AND D.FullDate <= @MaxDate
        GROUP BY ET.ExpenseType
    ),
    WithAverage AS (
        SELECT
            ExpenseType,
            TwoMonthTotal,
            AVG(TwoMonthTotal) OVER () AS AvgTwoMonth
        FROM TwoMonthTotals
    )
    SELECT
        ExpenseType,
        TwoMonthTotal,
        AvgTwoMonth
    FROM WithAverage
    WHERE TwoMonthTotal > AvgTwoMonth
    ORDER BY TwoMonthTotal DESC
    FOR JSON PATH, ROOT('ExpenseTypesAboveAverage');
END;
GO

/* ============================================================
   3) sp_MonthlyExpenseAreaRanking
      - Top 10 expense areas per month
      - Rank movement compared to previous month for the same area
   ============================================================ */
DROP PROCEDURE IF EXISTS dbo.sp_MonthlyExpenseAreaRanking;
GO

CREATE PROCEDURE dbo.sp_MonthlyExpenseAreaRanking
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Base AS (
        SELECT
            EA.ExpenseArea,
            D.[Year],
            D.[Month],
            SUM(F.Amount) AS TotalSpent
        FROM dbo.FactInvoice AS F
        INNER JOIN dbo.DimExpenseArea AS EA ON EA.ExpenseAreaID = F.ExpenseAreaID
        INNER JOIN dbo.DimDate        AS D  ON D.DateID        = F.DateID
        GROUP BY EA.ExpenseArea, D.[Year], D.[Month]
    ),
    Ranked AS (
        SELECT
            ExpenseArea,
            [Year],
            [Month],
            TotalSpent,
            RANK() OVER (
                PARTITION BY [Year], [Month]
                ORDER BY TotalSpent DESC
            ) AS RankNow
        FROM Base
    ),
    Prev AS (
        SELECT
            ExpenseArea,
            [Year],
            [Month],
            TotalSpent,
            RankNow,
            LAG(RankNow) OVER (
                PARTITION BY ExpenseArea
                ORDER BY [Year], [Month]
            ) AS PrevRank
        FROM Ranked
    )
    SELECT
        ExpenseArea,
        [Year],
        [Month],
        TotalSpent,
        RankNow,
        PrevRank,
        CASE
            WHEN PrevRank IS NULL THEN NULL
            ELSE PrevRank - RankNow     -- +ve = moved up, -ve = moved down
        END AS Movement
    FROM Prev
    WHERE RankNow <= 10
    ORDER BY [Year], [Month], RankNow;
END;
GO

/* ============================================================
   4) sp_SupplierTimeHierarchyAnalysis
      - Supplier totals by Year/Quarter/Month
      - YTD running total per supplier/year
      - Quarter total across all suppliers
      - Supplier monthly share of the quarter (%)
   ============================================================ */
DROP PROCEDURE IF EXISTS dbo.sp_SupplierTimeHierarchyAnalysis;
GO

CREATE PROCEDURE dbo.sp_SupplierTimeHierarchyAnalysis
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Base AS (
        SELECT
            S.SupplierName,
            D.[Year],
            DATEPART(QUARTER, D.FullDate) AS [Quarter],
            MONTH(D.FullDate)             AS [Month],
            SUM(F.Amount) AS MonthlyTotal
        FROM dbo.FactInvoice AS F
        INNER JOIN dbo.DimSupplier AS S ON S.SupplierID = F.SupplierID
        INNER JOIN dbo.DimDate     AS D ON D.DateID     = F.DateID
        GROUP BY
            S.SupplierName,
            D.[Year],
            DATEPART(QUARTER, D.FullDate),
            MONTH(D.FullDate)
    ),
    Enriched AS (
        SELECT
            SupplierName,
            [Year],
            [Quarter],
            [Month],
            MonthlyTotal,

            SUM(MonthlyTotal) OVER (
                PARTITION BY SupplierName, [Year]
                ORDER BY [Quarter], [Month]
                ROWS UNBOUNDED PRECEDING
            ) AS SupplierYearToDate,

            SUM(MonthlyTotal) OVER (
                PARTITION BY [Year], [Quarter]
            ) AS QuarterTotalAllSuppliers,

            100.0 * MonthlyTotal /
            NULLIF(SUM(MonthlyTotal) OVER (PARTITION BY [Year], [Quarter]), 0)
            AS MonthlyShareOfQuarterPercent
        FROM Base
    )
    SELECT
        SupplierName,
        [Year],
        [Quarter],
        [Month],
        DATENAME(MONTH, DATEFROMPARTS([Year], [Month], 1)) + ' ' + CAST([Year] AS varchar(4)) AS MonthLabel,
        MonthlyTotal,
        SupplierYearToDate,
        QuarterTotalAllSuppliers,
        MonthlyShareOfQuarterPercent
    FROM Enriched
    ORDER BY [Year], [Quarter], [Month], SupplierName;
END;
GO
/* ============================================================
   End of stored procedures
   ============================================================ */
/* ============================================================
   File: 08_views_for_powerbi.sql
   Purpose: Create SQL views for Power BI consumption
   Project: Public Sector Expenditure Data Warehouse
   Platform: Microsoft SQL Server (T-SQL)

   Rationale:
   - Power BI cannot directly consume stored procedure result sets.
   - These views replicate the logic of analytical stored procedures
     and act as stable, queryable data sources for the dashboard.
   ============================================================ */

USE PublicSpendDW;
GO

/* ============================================================
   1) Top 3 Suppliers – Overall
      (Equivalent to sp_Top3Suppliers – result set 1)
   ============================================================ */
DROP VIEW IF EXISTS dbo.vw_Top3Suppliers;
GO

CREATE VIEW dbo.vw_Top3Suppliers
AS
WITH SupplierTotals AS (
    SELECT
        F.SupplierID,
        SUM(F.Amount) AS TotalSpent
    FROM dbo.FactInvoice AS F
    GROUP BY F.SupplierID
)
SELECT TOP (3)
    S.SupplierName,
    ST.TotalSpent
FROM SupplierTotals AS ST
INNER JOIN dbo.DimSupplier AS S
    ON S.SupplierID = ST.SupplierID
ORDER BY ST.TotalSpent DESC;
GO

/* ============================================================
   2) Top 3 Suppliers – Monthly Breakdown
      (Equivalent to sp_Top3Suppliers – result set 2)
   ============================================================ */
DROP VIEW IF EXISTS dbo.vw_Top3Suppliers_Monthly;
GO

CREATE VIEW dbo.vw_Top3Suppliers_Monthly
AS
WITH SupplierTotals AS (
    SELECT
        F.SupplierID,
        SUM(F.Amount) AS TotalSpent
    FROM dbo.FactInvoice AS F
    GROUP BY F.SupplierID
),
Top3 AS (
    SELECT TOP (3)
        SupplierID
    FROM SupplierTotals
    ORDER BY TotalSpent DESC
)
SELECT
    D.[Year],
    D.[Month],
    S.SupplierName,
    SUM(F.Amount) AS MonthlyTotal
FROM dbo.FactInvoice AS F
INNER JOIN dbo.DimDate     AS D ON D.DateID     = F.DateID
INNER JOIN dbo.DimSupplier AS S ON S.SupplierID = F.SupplierID
INNER JOIN Top3            AS T ON T.SupplierID = F.SupplierID
GROUP BY
    D.[Year],
    D.[Month],
    S.SupplierName;
GO

/* ============================================================
   3) Expense Types Above Average Spend (Last 2 Months)
      (Equivalent to sp_ExpenseTypeAboveAvg2Month)
   ============================================================ */
DROP VIEW IF EXISTS dbo.vw_ExpenseTypeAboveAvg2Month;
GO

CREATE VIEW dbo.vw_ExpenseTypeAboveAvg2Month
AS
WITH MaxDateCTE AS (
    SELECT MAX(D.FullDate) AS MaxDate
    FROM dbo.FactInvoice AS F
    INNER JOIN dbo.DimDate AS D
        ON D.DateID = F.DateID
),
TwoMonthTotals AS (
    SELECT
        ET.ExpenseType,
        SUM(F.Amount) AS TwoMonthTotal
    FROM dbo.FactInvoice AS F
    INNER JOIN dbo.DimExpenseType AS ET ON ET.ExpenseTypeID = F.ExpenseTypeID
    INNER JOIN dbo.DimDate        AS D  ON D.DateID        = F.DateID
    CROSS JOIN MaxDateCTE
    WHERE D.FullDate >  DATEADD(MONTH, -2, MaxDate)
      AND D.FullDate <= MaxDate
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
WHERE TwoMonthTotal > AvgTwoMonth;
GO

/* ============================================================
   4) Monthly Top-10 Expense Area Ranking
      (Equivalent to sp_MonthlyExpenseAreaRanking)

   Note for Power BI:
   - A SortKey is included to preserve ordering
     (Year → Month → Rank) inside Table visuals.
   ============================================================ */
DROP VIEW IF EXISTS dbo.vw_MonthlyExpenseAreaRanking;
GO

CREATE VIEW dbo.vw_MonthlyExpenseAreaRanking
AS
WITH Base AS (
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
        ELSE PrevRank - RankNow
    END AS Movement,
    ([Year] * 10000) + ([Month] * 100) + RankNow AS SortKey
FROM Prev
WHERE RankNow <= 10;
GO

/* ============================================================
   5) Supplier Time Hierarchy Analysis
      (Equivalent to sp_SupplierTimeHierarchyAnalysis)
   ============================================================ */
DROP VIEW IF EXISTS dbo.vw_SupplierTimeHierarchyAnalysis;
GO

CREATE VIEW dbo.vw_SupplierTimeHierarchyAnalysis
AS
WITH Base AS (
    SELECT
        S.SupplierName,
        D.[Year],
        DATEPART(QUARTER, D.FullDate) AS [Quarter],
        MONTH(D.FullDate)             AS [Month],
        (D.[Year] * 100 + MONTH(D.FullDate)) AS YearMonthKey,
        SUM(F.Amount) AS MonthlyTotal
    FROM dbo.FactInvoice AS F
    INNER JOIN dbo.DimSupplier AS S ON S.SupplierID = F.SupplierID
    INNER JOIN dbo.DimDate     AS D ON D.DateID     = F.DateID
    GROUP BY
        S.SupplierName,
        D.[Year],
        DATEPART(QUARTER, D.FullDate),
        MONTH(D.FullDate),
        (D.[Year] * 100 + MONTH(D.FullDate))
),
Enriched AS (
    SELECT
        SupplierName,
        [Year],
        [Quarter],
        [Month],
        YearMonthKey,
        MonthlyTotal,

        SUM(MonthlyTotal) OVER (
            PARTITION BY SupplierName, [Year]
            ORDER BY YearMonthKey
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
    DATENAME(MONTH, DATEFROMPARTS([Year], [Month], 1)) 
        + ' ' + CAST([Year] AS varchar(4)) AS MonthLabel,
    MonthlyTotal,
    SupplierYearToDate,
    QuarterTotalAllSuppliers,
    MonthlyShareOfQuarterPercent
FROM Enriched;
GO
/* ============================================================
   End of views for Power BI
   ============================================================ */
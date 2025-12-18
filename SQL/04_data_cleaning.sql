/* ============================================================
   File: 04_data_cleaning.sql
   Purpose: Create cleaned dataset (Invoice_Clean) from raw staging data
   Project: Public Sector Expenditure Data Warehouse
   Platform: Microsoft SQL Server (T-SQL)

   Cleaning rules:
   - DateOfPayment: parsed using TRY_CONVERT with style 103 (dd/mm/yyyy)
     to avoid regional date misinterpretation.
   - Amount: TRY_CAST to DECIMAL(18,2)
   - Duplicate removal: keep 1 row per (TransactionNumber, Supplier, Amount, DateOfPayment)
   ============================================================ */

USE PublicSpendDW;
GO

/* ===== 1) Drop & rebuild Invoice_Clean ===== */
IF OBJECT_ID('dbo.Invoice_Clean', 'U') IS NOT NULL
    DROP TABLE dbo.Invoice_Clean;
GO

SELECT
    Department,
    Entity,

    -- Source uses UK-style dates (dd/mm/yyyy). Style 103 enforces correct parsing.
    TRY_CONVERT(date, DateOfPayment, 103) AS DateOfPayment,

    ExpenseType,
    ExpenseArea,
    Supplier,
    TransactionNumber,
    TRY_CAST(Amount AS DECIMAL(18,2)) AS Amount,
    Description,
    SupplierPostCode,
    SupplierType,
    ContractNumber,
    ProjectCode,
    ExpenditureType
INTO dbo.Invoice_Clean
FROM dbo.Invoice_Staging;
GO

/* ===== 2) Data quality checks ===== */
SELECT COUNT(*) AS CleanRowCount
FROM dbo.Invoice_Clean;
GO

-- Rows where date failed to parse
SELECT COUNT(*) AS InvalidDateCount
FROM dbo.Invoice_Clean
WHERE DateOfPayment IS NULL;
GO

-- Rows where amount failed to parse
SELECT COUNT(*) AS InvalidAmountCount
FROM dbo.Invoice_Clean
WHERE Amount IS NULL;
GO

/* ===== 3) Duplicate detection (audit) ===== */
SELECT
    TransactionNumber,
    Supplier,
    Amount,
    DateOfPayment,
    COUNT(*) AS DuplicateCount
FROM dbo.Invoice_Clean
GROUP BY TransactionNumber, Supplier, Amount, DateOfPayment
HAVING COUNT(*) > 1;
GO

/* ===== 4) Remove duplicates (keep 1 row per natural key group) ===== */
SELECT COUNT(*) AS RowCount_BeforeDeDup
FROM dbo.Invoice_Clean;
GO

;WITH Dedup AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY TransactionNumber, Supplier, Amount, DateOfPayment
            ORDER BY (SELECT 1)
        ) AS RN
    FROM dbo.Invoice_Clean
)
DELETE FROM Dedup
WHERE RN > 1;
GO

SELECT COUNT(*) AS RowCount_AfterDeDup
FROM dbo.Invoice_Clean;
GO

-- Quick sample (avoid SELECT * in scripts)
SELECT TOP (50)
    Department, Entity, DateOfPayment, Supplier, Amount, TransactionNumber
FROM dbo.Invoice_Clean
ORDER BY DateOfPayment DESC;
GO

/* ============================================================
   File: 02_staging_load.sql
   Purpose: Create staging table and load raw spend files (tab-delimited)
   Project: Public Sector Expenditure Data Warehouse
   Platform: Microsoft SQL Server (T-SQL)

   Notes:
   - This script loads raw data into dbo.Invoice_Staging as VARCHAR for
     maximum ingestion tolerance (dirty data expected).
   - Do NOT commit raw CSV/TXT files to GitHub. Store them locally.
   - Update the file paths below to match your environment.

   Expected input format:
   - Tab-delimited .txt (converted from CSV if required)
   - Header row present (FIRSTROW = 2)
   ============================================================ */

USE PublicSpendDW;
GO

/* ===== 1) Drop & recreate staging table ===== */
IF OBJECT_ID('dbo.Invoice_Staging', 'U') IS NOT NULL
    DROP TABLE dbo.Invoice_Staging;
GO

CREATE TABLE dbo.Invoice_Staging (
    Department        VARCHAR(MAX) NULL,
    Entity            VARCHAR(MAX) NULL,
    DateOfPayment     VARCHAR(MAX) NULL,
    ExpenseType       VARCHAR(MAX) NULL,
    ExpenseArea       VARCHAR(MAX) NULL,
    Supplier          VARCHAR(MAX) NULL,
    TransactionNumber VARCHAR(MAX) NULL,
    Amount            VARCHAR(MAX) NULL,
    Description       VARCHAR(MAX) NULL,
    SupplierPostCode  VARCHAR(MAX) NULL,
    SupplierType      VARCHAR(MAX) NULL,
    ContractNumber    VARCHAR(MAX) NULL,
    ProjectCode       VARCHAR(MAX) NULL,
    ExpenditureType   VARCHAR(MAX) NULL
);
GO

/* ===== 2) BULK INSERT raw files into staging =====
   Replace <LOCAL_PATH> with your folder path, and <FILENAME> with the actual file name, e.g.:
   C:\PublicSpendData\

   Tip:
   - If your file has Windows line endings, ROWTERMINATOR might need '\r\n'
   - If you see weird characters, add CODEPAGE = '65001' for UTF-8
==================================================== */

-- File 1
BULK INSERT dbo.Invoice_Staging
FROM '<LOCAL_PATH>\filename1.txt'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '\t',
    ROWTERMINATOR = '\n',     -- change to '\r\n' if needed
    TABLOCK
);
GO

-- File 2
BULK INSERT dbo.Invoice_Staging
FROM '<LOCAL_PATH>\filename2.txt'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '\t',
    ROWTERMINATOR = '\n',
    TABLOCK
);
GO

-- File 3
BULK INSERT dbo.Invoice_Staging
FROM '<LOCAL_PATH>\filename3.txt'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '\t',
    ROWTERMINATOR = '\n',
    TABLOCK
);
GO

-- File 4
BULK INSERT dbo.Invoice_Staging
FROM '<LOCAL_PATH>\filename4.txt'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '\t',
    ROWTERMINATOR = '\n',
    TABLOCK
);
GO

/* ===== 3) Validation checks ===== */
SELECT COUNT(*) AS StagingRowCount
FROM dbo.Invoice_Staging;
GO

-- Quick sanity sample (avoid SELECT * in professional scripts)
SELECT TOP (50)
    Department, Entity, DateOfPayment, Amount, Supplier, ExpenseType
FROM dbo.Invoice_Staging;
GO
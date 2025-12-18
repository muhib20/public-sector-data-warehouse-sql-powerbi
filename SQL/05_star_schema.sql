/* ============================================================
   File: 05_star_schema.sql
   Purpose: Create star schema dimensions (Organisation, Supplier, Expense Type,
            Expense Area, Date) for the data warehouse
   Project: Public Sector Expenditure Data Warehouse
   Platform: Microsoft SQL Server (T-SQL)

   Notes:
   - Fact table is dropped first to avoid FK dependency issues during rebuild.
   - Dimension attributes are loaded from dbo.Invoice_Clean.
   - TRIM/LTRIM/RTRIM used to reduce join mismatches caused by whitespace.
   ============================================================ */

USE PublicSpendDW;
GO

/* ===== 0) Drop dependent fact table (if exists) ===== */
IF OBJECT_ID('dbo.FactInvoice', 'U') IS NOT NULL
    DROP TABLE dbo.FactInvoice;
GO

/* ===== 1) DimOrganisation ===== */
IF OBJECT_ID('dbo.DimOrganisation', 'U') IS NOT NULL
    DROP TABLE dbo.DimOrganisation;
GO

CREATE TABLE dbo.DimOrganisation (
    OrganisationID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Department     VARCHAR(255) NULL,
    Entity         VARCHAR(255) NULL
);
GO

INSERT INTO dbo.DimOrganisation (Department, Entity)
SELECT DISTINCT
    NULLIF(LTRIM(RTRIM(Department)), ''),
    NULLIF(LTRIM(RTRIM(Entity)), '')
FROM dbo.Invoice_Clean;
GO

SELECT COUNT(*) AS DimOrganisationRowCount
FROM dbo.DimOrganisation;
GO

/* ===== 2) DimSupplier ===== */
IF OBJECT_ID('dbo.DimSupplier', 'U') IS NOT NULL
    DROP TABLE dbo.DimSupplier;
GO

CREATE TABLE dbo.DimSupplier (
    SupplierID       INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    SupplierName     VARCHAR(255) NULL,
    SupplierPostCode VARCHAR(50)  NULL,
    SupplierType     VARCHAR(255) NULL
);
GO

INSERT INTO dbo.DimSupplier (SupplierName, SupplierPostCode, SupplierType)
SELECT DISTINCT
    NULLIF(LTRIM(RTRIM(Supplier)), ''),
    NULLIF(LTRIM(RTRIM(SupplierPostCode)), ''),
    NULLIF(LTRIM(RTRIM(SupplierType)), '')
FROM dbo.Invoice_Clean;
GO

SELECT COUNT(*) AS DimSupplierRowCount
FROM dbo.DimSupplier;
GO

/* ===== 3) DimExpenseType ===== */
IF OBJECT_ID('dbo.DimExpenseType', 'U') IS NOT NULL
    DROP TABLE dbo.DimExpenseType;
GO

CREATE TABLE dbo.DimExpenseType (
    ExpenseTypeID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ExpenseType   VARCHAR(255) NULL
);
GO

INSERT INTO dbo.DimExpenseType (ExpenseType)
SELECT DISTINCT
    NULLIF(LTRIM(RTRIM(ExpenseType)), '')
FROM dbo.Invoice_Clean;
GO

SELECT COUNT(*) AS DimExpenseTypeRowCount
FROM dbo.DimExpenseType;
GO

/* ===== 4) DimExpenseArea ===== */
IF OBJECT_ID('dbo.DimExpenseArea', 'U') IS NOT NULL
    DROP TABLE dbo.DimExpenseArea;
GO

CREATE TABLE dbo.DimExpenseArea (
    ExpenseAreaID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ExpenseArea   VARCHAR(255) NULL
);
GO

INSERT INTO dbo.DimExpenseArea (ExpenseArea)
SELECT DISTINCT
    NULLIF(LTRIM(RTRIM(ExpenseArea)), '')
FROM dbo.Invoice_Clean;
GO

SELECT COUNT(*) AS DimExpenseAreaRowCount
FROM dbo.DimExpenseArea;
GO

/* ===== 5) DimDate (distinct dates from source) ===== */
IF OBJECT_ID('dbo.DimDate', 'U') IS NOT NULL
    DROP TABLE dbo.DimDate;
GO

CREATE TABLE dbo.DimDate (
    DateID     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    FullDate   DATE NOT NULL,
    [Year]     INT  NOT NULL,
    [Month]    INT  NOT NULL,
    MonthName  VARCHAR(20) NOT NULL
);
GO

INSERT INTO dbo.DimDate (FullDate, [Year], [Month], MonthName)
SELECT DISTINCT
    DateOfPayment,
    YEAR(DateOfPayment),
    MONTH(DateOfPayment),
    DATENAME(MONTH, DateOfPayment)
FROM dbo.Invoice_Clean
WHERE DateOfPayment IS NOT NULL;
GO

SELECT COUNT(*) AS DimDateRowCount
FROM dbo.DimDate;
GO

-- Quick sanity samples (avoid SELECT * dumps)
SELECT TOP (10) * FROM dbo.DimOrganisation ORDER BY OrganisationID;
SELECT TOP (10) * FROM dbo.DimSupplier     ORDER BY SupplierID;
SELECT TOP (10) * FROM dbo.DimExpenseType  ORDER BY ExpenseTypeID;
SELECT TOP (10) * FROM dbo.DimExpenseArea  ORDER BY ExpenseAreaID;
SELECT TOP (10) * FROM dbo.DimDate         ORDER BY FullDate;
GO

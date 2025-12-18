/* ============================================================
   File: 06_fact_load.sql
   Purpose: Create and load FactInvoice from Invoice_Clean using star schema keys
   Project: Public Sector Expenditure Data Warehouse
   Platform: Microsoft SQL Server (T-SQL)

   Design:
   - FactInvoice contains foreign keys to all dimensions + measures.
   - Load uses INNER JOIN to enforce referential integrity.
     (Rows that fail to match any dimension are excluded by design.)

   Validation:
   - Row counts: Invoice_Clean vs FactInvoice
   - Diagnostics to identify which dimension join caused row loss
   ============================================================ */

USE PublicSpendDW;
GO

/* ===== 1) Drop & recreate fact table ===== */
IF OBJECT_ID('dbo.FactInvoice', 'U') IS NOT NULL
    DROP TABLE dbo.FactInvoice;
GO

CREATE TABLE dbo.FactInvoice (
    FactID            INT IDENTITY(1,1) NOT NULL PRIMARY KEY,

    OrganisationID    INT NOT NULL,
    SupplierID        INT NOT NULL,
    ExpenseTypeID     INT NOT NULL,
    ExpenseAreaID     INT NOT NULL,
    DateID            INT NOT NULL,

    Amount            DECIMAL(18,2) NULL,
    TransactionNumber VARCHAR(100) NULL,
    [Description]     VARCHAR(MAX) NULL,

    CONSTRAINT FK_FactInvoice_Organisation FOREIGN KEY (OrganisationID)
        REFERENCES dbo.DimOrganisation(OrganisationID),

    CONSTRAINT FK_FactInvoice_Supplier FOREIGN KEY (SupplierID)
        REFERENCES dbo.DimSupplier(SupplierID),

    CONSTRAINT FK_FactInvoice_ExpenseType FOREIGN KEY (ExpenseTypeID)
        REFERENCES dbo.DimExpenseType(ExpenseTypeID),

    CONSTRAINT FK_FactInvoice_ExpenseArea FOREIGN KEY (ExpenseAreaID)
        REFERENCES dbo.DimExpenseArea(ExpenseAreaID),

    CONSTRAINT FK_FactInvoice_Date FOREIGN KEY (DateID)
        REFERENCES dbo.DimDate(DateID)
);
GO

/* ===== 2) Load fact table (strict matching) ===== */
INSERT INTO dbo.FactInvoice (
    OrganisationID,
    SupplierID,
    ExpenseTypeID,
    ExpenseAreaID,
    DateID,
    Amount,
    TransactionNumber,
    [Description]
)
SELECT
    o.OrganisationID,
    s.SupplierID,
    et.ExpenseTypeID,
    ea.ExpenseAreaID,
    dd.DateID,
    i.Amount,
    i.TransactionNumber,
    i.[Description]
FROM dbo.Invoice_Clean AS i
INNER JOIN dbo.DimOrganisation AS o
    ON LTRIM(RTRIM(i.Department)) = LTRIM(RTRIM(o.Department))
   AND LTRIM(RTRIM(i.Entity))     = LTRIM(RTRIM(o.Entity))

INNER JOIN dbo.DimSupplier AS s
    ON LTRIM(RTRIM(i.Supplier)) = LTRIM(RTRIM(s.SupplierName))
   AND ISNULL(LTRIM(RTRIM(i.SupplierPostCode)), '') = ISNULL(LTRIM(RTRIM(s.SupplierPostCode)), '')
   AND ISNULL(LTRIM(RTRIM(i.SupplierType)), '')     = ISNULL(LTRIM(RTRIM(s.SupplierType)), '')

INNER JOIN dbo.DimExpenseType AS et
    ON LTRIM(RTRIM(i.ExpenseType)) = LTRIM(RTRIM(et.ExpenseType))

INNER JOIN dbo.DimExpenseArea AS ea
    ON LTRIM(RTRIM(i.ExpenseArea)) = LTRIM(RTRIM(ea.ExpenseArea))

INNER JOIN dbo.DimDate AS dd
    ON i.DateOfPayment = dd.FullDate;
GO

/* ===== 3) Row-count validation ===== */
SELECT COUNT(*) AS CleanRows
FROM dbo.Invoice_Clean;

SELECT COUNT(*) AS FactRows
FROM dbo.FactInvoice;
GO

/* ===== 4) Diagnostics: identify where rows are being dropped =====
   These queries help explain fact-vs-clean differences and are valuable evidence.
=============================================================== */

-- Missing Organisation match
SELECT COUNT(*) AS NoOrganisationMatch
FROM dbo.Invoice_Clean i
LEFT JOIN dbo.DimOrganisation o
  ON LTRIM(RTRIM(i.Department)) = LTRIM(RTRIM(o.Department))
 AND LTRIM(RTRIM(i.Entity))     = LTRIM(RTRIM(o.Entity))
WHERE o.OrganisationID IS NULL;
GO

-- Missing Supplier match
SELECT COUNT(*) AS NoSupplierMatch
FROM dbo.Invoice_Clean i
LEFT JOIN dbo.DimSupplier s
  ON LTRIM(RTRIM(i.Supplier)) = LTRIM(RTRIM(s.SupplierName))
 AND ISNULL(LTRIM(RTRIM(i.SupplierPostCode)), '') = ISNULL(LTRIM(RTRIM(s.SupplierPostCode)), '')
 AND ISNULL(LTRIM(RTRIM(i.SupplierType)), '')     = ISNULL(LTRIM(RTRIM(s.SupplierType)), '')
WHERE s.SupplierID IS NULL;
GO

-- Missing ExpenseType match
SELECT COUNT(*) AS NoExpenseTypeMatch
FROM dbo.Invoice_Clean i
LEFT JOIN dbo.DimExpenseType et
  ON LTRIM(RTRIM(i.ExpenseType)) = LTRIM(RTRIM(et.ExpenseType))
WHERE et.ExpenseTypeID IS NULL;
GO

-- Missing ExpenseArea match
SELECT COUNT(*) AS NoExpenseAreaMatch
FROM dbo.Invoice_Clean i
LEFT JOIN dbo.DimExpenseArea ea
  ON LTRIM(RTRIM(i.ExpenseArea)) = LTRIM(RTRIM(ea.ExpenseArea))
WHERE ea.ExpenseAreaID IS NULL;
GO

-- Missing Date match
SELECT COUNT(*) AS NoDateMatch
FROM dbo.Invoice_Clean i
LEFT JOIN dbo.DimDate dd
  ON i.DateOfPayment = dd.FullDate
WHERE dd.DateID IS NULL;
GO

/* ===== 5) Quick sample ===== */
SELECT TOP (10)
    FactID, OrganisationID, SupplierID, ExpenseTypeID, ExpenseAreaID, DateID, Amount, TransactionNumber
FROM dbo.FactInvoice
ORDER BY FactID;
GO

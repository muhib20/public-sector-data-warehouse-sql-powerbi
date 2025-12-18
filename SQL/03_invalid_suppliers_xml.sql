/* ============================================================
   File: 03_invalid_suppliers_xml.sql
   Purpose: Load invalid supplier names from XML and remove them from staging
   Project: Public Sector Expenditure Data Warehouse
   Platform: Microsoft SQL Server (T-SQL)

   Notes:
   - This script expects an XML file containing suppliers to exclude.
   - Do NOT commit the XML file to GitHub if it's proprietary; commit only
     the schema/example (e.g., suppliers_schema.xml).
   - Some XML exports contain invalid characters such as '&' which must be
     escaped as '&amp;' before SQL Server can parse the XML.
   ============================================================ */

USE PublicSpendDW;
GO

/* ===== 1) Create / reset InvalidSuppliers ===== */
IF OBJECT_ID('dbo.InvalidSuppliers', 'U') IS NOT NULL
    DROP TABLE dbo.InvalidSuppliers;
GO

CREATE TABLE dbo.InvalidSuppliers (
    SupplierName VARCHAR(255) NOT NULL
);
GO

/* ===== 2) Load invalid suppliers from XML =====
   Replace <XML_PATH> with your local file path, e.g.:
   C:\PublicSpendData\Suppliers.xml

   If XML fails to parse:
   - Open the file and replace bare '&' with '&amp;'
================================================== */

DECLARE @XmlText NVARCHAR(MAX);
DECLARE @XmlDoc  XML;

SELECT @XmlText = BulkColumn
FROM OPENROWSET(
        BULK '<XML_PATH>\Suppliers.xml',
        SINGLE_CLOB
) AS X;

-- Try parse XML (prevents hard failure and gives a clearer error)
SET @XmlDoc = TRY_CAST(@XmlText AS XML);

IF @XmlDoc IS NULL
BEGIN
    THROW 50001, 'XML parsing failed. Ensure the XML is well-formed (e.g., replace "&" with "&amp;").', 1;
END;
GO

-- Insert supplier names from XML nodes
INSERT INTO dbo.InvalidSuppliers (SupplierName)
SELECT
    T.N.value('@SupplierName', 'VARCHAR(255)') AS SupplierName
FROM @XmlDoc.nodes('/Suppliers/Supplier') AS T(N);
GO

/* ===== 3) Validate invalid supplier load ===== */
SELECT COUNT(*) AS InvalidSupplierCount
FROM dbo.InvalidSuppliers;
GO

SELECT TOP (20) SupplierName
FROM dbo.InvalidSuppliers
ORDER BY SupplierName;
GO

/* ===== 4) Remove invalid suppliers from Invoice_Staging ===== */
SELECT COUNT(*) AS StagingRowCount_Before
FROM dbo.Invoice_Staging;
GO

DELETE S
FROM dbo.Invoice_Staging AS S
INNER JOIN dbo.InvalidSuppliers AS I
    ON LTRIM(RTRIM(S.Supplier)) = LTRIM(RTRIM(I.SupplierName));
GO

SELECT COUNT(*) AS StagingRowCount_After
FROM dbo.Invoice_Staging;
GO

/* ===== 5) Anonymise personal expense / withheld names =====
   GitHub-safe placeholder instead of any student ID / personal identifier
============================================================= */

UPDATE dbo.Invoice_Staging
SET Supplier = 'REDACTED_PERSONAL_EXPENSE'
WHERE Supplier LIKE '%Personal Expense%'
   OR Supplier LIKE '%Name Withheld%';
GO

SELECT COUNT(*) AS RedactedSupplierRows
FROM dbo.Invoice_Staging
WHERE Supplier = 'REDACTED_PERSONAL_EXPENSE';
GO

/* ============================================================
   File: 01_database_setup.sql
   Purpose: Create the data warehouse database
   Project: Public Sector Expenditure Data Warehouse
   Platform: Microsoft SQL Server (T-SQL)

   Description:
   - Drops the existing database if it exists
   - Creates a fresh database for the data warehouse
   - Intended to be executed before any ETL or schema scripts
   ============================================================ */

IF DB_ID('PublicSpendDW') IS NOT NULL
DROP DATABASE PublicSpendDW;
GO
-- Create the data warehouse database
CREATE DATABASE PublicSpendDW;
GO

-- Switch context to the newly created database
USE PublicSpendDW;
GO
-- Verify database creation
SELECT DB_NAME() AS CurrentDatabase;
GO
# Public Sector Expenditure Data Warehouse (SQL Server & Power BI)

## Overview
This project implements an end-to-end data warehousing and analytical reporting solution using SQL Server and Power BI.  
The dataset is based on UK public sector spending records and demonstrates real-world ETL challenges, dimensional modelling, analytical querying, and business intelligence dashboarding.

---

## Project Architecture

The diagram below illustrates the complete data pipeline, from raw data ingestion to analytical reporting:

![Project Architecture](https://github.com/muhib20/public-sector-data-warehouse-sql-powerbi/blob/main/Docs/architecture_diagram.png)

*Figure: End-to-end ETL and analytics architecture for public sector expenditure analysis.*

---

## Key Features
- Multi-file CSV ingestion using T-SQL `BULK INSERT`
- Robust staging and data cleansing pipeline
- XML-based invalid supplier filtering
- Star schema data warehouse design
- Advanced analytical stored procedures
- Power BI dashboard built on SQL views

---

## Technologies Used
- SQL Server (T-SQL)
- BULK INSERT / BCP
- XML processing (`OPENROWSET`)
- Window functions (`RANK`, `LAG`, `ROW_NUMBER`)
- Power BI

---

## Data Pipeline
1. Raw CSV files loaded into staging tables  
2. Data cleansing and validation (dates, amounts, duplicates)  
3. Invalid suppliers removed using XML reference data  
4. Star schema created (Fact + Dimensions)  
5. Analytical queries implemented as stored procedures  
6. Views created for Power BI consumption  

---

## Data Model (ER Diagram)

The data warehouse follows a star schema design with a central fact table linked to multiple dimensions:

![ER Diagram](https://github.com/muhib20/public-sector-data-warehouse-sql-powerbi/blob/main/Docs/er_diagram.png)

*Figure: Star schema data model used for analytical reporting.*

---

## Analytical Queries Implemented
- Top 3 suppliers overall and monthly breakdown
- Expense types above average spend (last 2 months)
- Monthly top-10 expense area ranking with rank movement
- Supplier time hierarchy analysis (Year / Quarter / Month)

---

## Power BI Dashboard

The Power BI dashboard consolidates all analytical outputs into a single, interactive page, supporting exploration through filters and slicers.

### Top 3 Suppliers – Total & Monthly Spend
![Top 3 Suppliers](https://github.com/muhib20/public-sector-data-warehouse-sql-powerbi/blob/main/Docs/sample_dashboard_top_3_suppliers.png)

### Expense Types Above Average Spend
![Expense Types Above Average](https://github.com/muhib20/public-sector-data-warehouse-sql-powerbi/blob/main/Docs/sample_dashboard_expense_types.png)

### Supplier Time Hierarchy Analysis
![Supplier Time Hierarchy](https://github.com/muhib20/public-sector-data-warehouse-sql-powerbi/blob/main/Docs/sample_dashboard_time_hierarchy.png)

### Monthly Top-10 Expense Area Ranking
![Top 10 Expense Areas](https://github.com/muhib20/public-sector-data-warehouse-sql-powerbi/blob/main/Docs/sample_dashboard_top_10_expense_area.png)

---

## Data Source

The raw dataset used in this project consists of UK public sector spend records published
by the Department for Business, Innovation & Skills (BIS). These datasets are publicly
available under the UK Government’s open data policy.

The source CSV files can be downloaded from the official UK data portal:
🔗 https://www.data.gov.uk/dataset/22a8f668-9cf5-43b6-b097-8be0303ad74d/financial-transactions-spend-data-bis

To reproduce the ETL pipeline in this repository:
1. Download the relevant CSV files from the above link.
2. Convert them to tab-delimited `.txt` if needed.
3. Place them in a local folder before running the staging load SQL scripts.

---

## Notes on Public Repository
- Raw CSV files and full XML reference data are not included to avoid data duplication and licensing issues.
- The repository includes schema/sample files to demonstrate structure.
- File paths and server-specific settings are parameterised for portability.

---

## Author
**Muhib Ul Aziz**  
MSc Data Science, London South Bank University

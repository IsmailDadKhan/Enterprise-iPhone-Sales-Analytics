-- ============================================================
-- JUNIOR DATA ANALYST PILOT PROJECT — SQL SCRIPTS
-- Candidate: Ismail Dad Khan
-- Project: BigQuery + SQL + Looker Studio
-- Company: Cellutech FZCO
-- Dataset: cellutech_iphone_sales
-- Source: 10,000 iPhone Transaction Records | 93 SKUs
-- Date: September 2026
-- ============================================================


-- ============================================================
-- SECTION 1: SCHEMA REVIEW & DATA QUALITY CHECKS
-- Run these AFTER uploading CSVs to BigQuery
-- ============================================================

-- 1.1 Row count check (expect: 10,920 raw rows + 93 product master rows)
SELECT 'raw_iphone_transactions' AS table_name, COUNT(*) AS row_count
FROM `cellutech_iphone_sales.raw_iphone_transactions`
UNION ALL
SELECT 'raw_product_master' AS table_name, COUNT(*) AS row_count
FROM `cellutech_iphone_sales.raw_product_master`;

-- 1.2 Null audit on all columns
-- Result: 920 nulls detected uniformly across ALL columns,
-- indicating 920 completely blank trailing rows from Excel source formatting
SELECT
  COUNT(*) AS total_rows,
  COUNTIF(Trandate IS NULL)    AS null_trandate,
  COUNTIF(Tranid IS NULL)      AS null_tranid,
  COUNTIF(Entity IS NULL)      AS null_entity,
  COUNTIF(Quantity IS NULL)    AS null_quantity,
  COUNTIF(Type IS NULL)        AS null_type,
  COUNTIF(Item_ID IS NULL)     AS null_item_id,
  COUNTIF(Unit_Price IS NULL)  AS null_unit_price,
  COUNTIF(Amount IS NULL)      AS null_amount,
  COUNTIF(LastInvDate IS NULL) AS null_last_inv_date,
  COUNTIF(Country IS NULL)     AS null_country,
  COUNTIF(Subsidiary IS NULL)  AS null_subsidiary
FROM `cellutech_iphone_sales.raw_iphone_transactions`;

-- 1.3 Quantify blank rows from Excel upload
-- The source Excel file contained formatting that extended beyond the actual
-- 10,000 data rows. BigQuery loaded these as 920 completely null records.
SELECT
  COUNT(*)                      AS total_raw_rows,
  COUNTIF(Tranid IS NOT NULL)   AS valid_data_rows,
  COUNTIF(Tranid IS NULL)       AS blank_ghost_rows,
  ROUND(COUNTIF(Tranid IS NULL) * 100.0 / COUNT(*), 1) AS blank_pct
FROM `cellutech_iphone_sales.raw_iphone_transactions`;

-- 1.4 Distinct value counts on valid rows only
-- Verify against assignment spec: 93 SKUs, 12 entities, 12 countries, 4 subsidiaries, 4 types
SELECT
  COUNT(DISTINCT Item_ID)     AS distinct_skus,
  COUNT(DISTINCT Entity)      AS distinct_entities,
  COUNT(DISTINCT Country)     AS distinct_countries,
  COUNT(DISTINCT Subsidiary)  AS distinct_subsidiaries,
  COUNT(DISTINCT Type)        AS distinct_types,
  COUNT(DISTINCT Class)       AS distinct_classes
FROM `cellutech_iphone_sales.raw_iphone_transactions`
WHERE Tranid IS NOT NULL;

-- 1.5 Check date range (assignment states: 01 Jan 2025 to 09 Sep 2026)
SELECT
  MIN(Trandate)    AS earliest_transaction,
  MAX(Trandate)    AS latest_transaction,
  MIN(LastInvDate) AS earliest_invoice,
  MAX(LastInvDate) AS latest_invoice
FROM `cellutech_iphone_sales.raw_iphone_transactions`
WHERE Tranid IS NOT NULL;

-- 1.6 Inspect distinct categorical values
SELECT DISTINCT Type FROM `cellutech_iphone_sales.raw_iphone_transactions`
WHERE Tranid IS NOT NULL ORDER BY Type;

SELECT DISTINCT Subsidiary FROM `cellutech_iphone_sales.raw_iphone_transactions`
WHERE Tranid IS NOT NULL ORDER BY Subsidiary;

SELECT DISTINCT Country FROM `cellutech_iphone_sales.raw_iphone_transactions`
WHERE Tranid IS NOT NULL ORDER BY Country;

SELECT DISTINCT Class FROM `cellutech_iphone_sales.raw_iphone_transactions`
WHERE Tranid IS NOT NULL ORDER BY Class;

-- 1.7 Verify Product Master join coverage (expect: 0 unmatched SKUs)
SELECT
  COUNT(DISTINCT t.Item_ID) AS transaction_skus,
  COUNT(DISTINCT pm.Item_ID) AS master_skus,
  COUNT(DISTINCT CASE WHEN pm.Item_ID IS NULL THEN t.Item_ID END) AS unmatched_skus
FROM `cellutech_iphone_sales.raw_iphone_transactions` t
LEFT JOIN `cellutech_iphone_sales.raw_product_master` pm
  ON t.Item_ID = pm.Item_ID
WHERE t.Tranid IS NOT NULL;


-- ============================================================
-- SECTION 2: REPORTING VIEW — MAIN DELIVERABLE
-- This is the primary reporting layer for Looker Studio.
-- Applies: null filtering, type casting, TRIM, calculated fields,
-- CTE structure, CASE statements, date functions, LEFT JOIN.
-- ============================================================

CREATE OR REPLACE VIEW `cellutech_iphone_sales.rpt_iphone_sales` AS
WITH base_transactions AS (
  -- CTE 1: Clean, type-cast, and sanitize raw staging data
  SELECT
    CAST(Trandate AS DATE)                          AS transaction_date,
    Tranid                                          AS transaction_id,
    TRIM(Entity)                                    AS entity_name,
    CAST(Quantity AS INT64)                         AS quantity,
    TRIM(Type)                                      AS transaction_type,
    TRIM(Item_ID)                                   AS item_id,
    TRIM(PO_Description)                            AS product_description,
    CAST(Unit_Price AS NUMERIC)                     AS unit_price,
    -- Recalculate Amount (source Excel had formulas =D2*H2, not actual values)
    ROUND(CAST(Quantity AS INT64) * CAST(Unit_Price AS NUMERIC), 2) AS amount,
    CAST(LastInvDate AS DATE)                       AS last_invoice_date,
    TRIM(Class)                                     AS sales_class,
    TRIM(Country)                                   AS country,
    TRIM(Subsidiary)                                AS subsidiary
  FROM `cellutech_iphone_sales.raw_iphone_transactions`
  -- Data Cleaning: Filter out 920 trailing blank rows from Excel upload
  -- These rows have NULL across every column (Excel formatting artifacts)
  WHERE Tranid IS NOT NULL
    AND Trandate IS NOT NULL
),

enriched AS (
  -- CTE 2: Enrich with product dimensions and add derived analytical fields
  SELECT
    t.*,

    -- Product dimensions from master table (LEFT JOIN for safety)
    pm.Model                                        AS iphone_model,
    pm.Storage                                      AS storage_capacity,
    pm.Color                                        AS color,

    -- Date-derived dimensions for time-series analysis
    EXTRACT(YEAR FROM t.transaction_date)           AS transaction_year,
    EXTRACT(MONTH FROM t.transaction_date)          AS transaction_month,
    EXTRACT(QUARTER FROM t.transaction_date)        AS transaction_quarter,
    FORMAT_DATE('%Y-%m', t.transaction_date)        AS year_month,
    FORMAT_DATE('%B %Y', t.transaction_date)        AS month_name_year,
    FORMAT_DATE('%A', t.transaction_date)            AS day_of_week,

    -- Calculated business metrics
    DATE_DIFF(t.transaction_date, t.last_invoice_date, DAY) AS days_since_last_invoice,

    -- Transaction categorization using CASE
    -- Revenue = customer-facing sales; Procurement = supplier-facing purchases
    CASE
      WHEN t.transaction_type IN ('Sales Order', 'Invoice') THEN 'Revenue'
      WHEN t.transaction_type IN ('Purchase Order', 'Item Receipt') THEN 'Procurement'
      ELSE 'Other'
    END AS transaction_category,

    -- Price tier classification using CASE
    CASE
      WHEN t.unit_price >= 1200 THEN 'Premium (>$1200)'
      WHEN t.unit_price >= 800  THEN 'Mid-Range ($800-$1200)'
      WHEN t.unit_price >= 500  THEN 'Standard ($500-$800)'
      ELSE 'Budget (<$500)'
    END AS price_tier

  FROM base_transactions t
  LEFT JOIN `cellutech_iphone_sales.raw_product_master` pm
    ON t.item_id = pm.Item_ID
)

SELECT * FROM enriched;


-- ============================================================
-- SECTION 3: ANALYSIS QUERIES
-- Key performance analysis by time, product, entity, country
-- ============================================================

-- 3.1 Monthly Trend by Transaction Category (Revenue vs Procurement)
SELECT
  year_month,
  transaction_category,
  COUNT(*) AS transaction_count,
  SUM(quantity) AS total_units,
  ROUND(SUM(amount), 2) AS total_amount,
  ROUND(AVG(unit_price), 2) AS avg_unit_price
FROM `cellutech_iphone_sales.rpt_iphone_sales`
GROUP BY year_month, transaction_category
ORDER BY year_month, transaction_category;

-- 3.2 Quarterly Summary
SELECT
  transaction_year,
  transaction_quarter,
  transaction_category,
  COUNT(*) AS transaction_count,
  SUM(quantity) AS total_units,
  ROUND(SUM(amount), 2) AS total_amount
FROM `cellutech_iphone_sales.rpt_iphone_sales`
GROUP BY transaction_year, transaction_quarter, transaction_category
ORDER BY transaction_year, transaction_quarter, transaction_category;

-- 3.3 Top Entities/Customers by Total Amount
SELECT
  entity_name,
  COUNT(*) AS transaction_count,
  SUM(quantity) AS total_units,
  ROUND(SUM(amount), 2) AS total_amount,
  ROUND(AVG(unit_price), 2) AS avg_unit_price,
  ROUND(SUM(amount) * 100.0 / SUM(SUM(amount)) OVER(), 2) AS pct_of_total
FROM `cellutech_iphone_sales.rpt_iphone_sales`
GROUP BY entity_name
ORDER BY total_amount DESC;

-- 3.4 iPhone Model Performance (with percentage share)
SELECT
  iphone_model,
  COUNT(*) AS transaction_count,
  SUM(quantity) AS total_units,
  ROUND(SUM(amount), 2) AS total_amount,
  ROUND(AVG(unit_price), 2) AS avg_unit_price,
  ROUND(SUM(amount) * 100.0 / SUM(SUM(amount)) OVER(), 2) AS pct_of_total
FROM `cellutech_iphone_sales.rpt_iphone_sales`
GROUP BY iphone_model
ORDER BY total_amount DESC;

-- 3.5 Storage Capacity Analysis
SELECT
  storage_capacity,
  COUNT(*) AS transaction_count,
  SUM(quantity) AS total_units,
  ROUND(SUM(amount), 2) AS total_amount,
  ROUND(AVG(unit_price), 2) AS avg_unit_price
FROM `cellutech_iphone_sales.rpt_iphone_sales`
GROUP BY storage_capacity
ORDER BY total_amount DESC;

-- 3.6 Country Performance (with entity coverage)
SELECT
  country,
  COUNT(*) AS transaction_count,
  COUNT(DISTINCT entity_name) AS unique_entities,
  SUM(quantity) AS total_units,
  ROUND(SUM(amount), 2) AS total_amount,
  ROUND(SUM(amount) * 100.0 / SUM(SUM(amount)) OVER(), 2) AS pct_of_total
FROM `cellutech_iphone_sales.rpt_iphone_sales`
GROUP BY country
ORDER BY total_amount DESC;

-- 3.7 Subsidiary Performance (with market coverage metrics)
SELECT
  subsidiary,
  COUNT(*) AS transaction_count,
  COUNT(DISTINCT entity_name) AS unique_entities,
  COUNT(DISTINCT country) AS countries_served,
  SUM(quantity) AS total_units,
  ROUND(SUM(amount), 2) AS total_amount,
  ROUND(SUM(amount) * 100.0 / SUM(SUM(amount)) OVER(), 2) AS pct_of_total
FROM `cellutech_iphone_sales.rpt_iphone_sales`
GROUP BY subsidiary
ORDER BY total_amount DESC;

-- 3.8 Transaction Type Breakdown (Revenue vs Procurement detail)
-- IMPORTANT: Purchase Order + Item Receipt = Procurement (buying from suppliers)
--            Sales Order + Invoice = Revenue (selling to customers)
SELECT
  transaction_type,
  transaction_category,
  COUNT(*) AS transaction_count,
  SUM(quantity) AS total_units,
  ROUND(SUM(amount), 2) AS total_amount,
  ROUND(SUM(amount) * 100.0 / SUM(SUM(amount)) OVER(), 2) AS pct_of_total
FROM `cellutech_iphone_sales.rpt_iphone_sales`
GROUP BY transaction_type, transaction_category
ORDER BY transaction_category, total_amount DESC;

-- 3.9 Sales Class (Rep) Performance & Workload Distribution
SELECT
  sales_class,
  COUNT(*) AS transaction_count,
  SUM(quantity) AS total_units,
  ROUND(SUM(amount), 2) AS total_amount,
  ROUND(AVG(amount), 2) AS avg_transaction_value,
  COUNT(DISTINCT entity_name) AS unique_entities,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct_workload
FROM `cellutech_iphone_sales.rpt_iphone_sales`
GROUP BY sales_class
ORDER BY total_amount DESC;

-- 3.10 Price Tier Distribution
SELECT
  price_tier,
  COUNT(*) AS transaction_count,
  SUM(quantity) AS total_units,
  ROUND(SUM(amount), 2) AS total_amount,
  ROUND(SUM(amount) * 100.0 / SUM(SUM(amount)) OVER(), 2) AS pct_of_total
FROM `cellutech_iphone_sales.rpt_iphone_sales`
GROUP BY price_tier
ORDER BY total_amount DESC;

-- 3.11 Color Preference Analysis
SELECT
  color,
  COUNT(*) AS transaction_count,
  SUM(quantity) AS total_units,
  ROUND(SUM(amount), 2) AS total_amount
FROM `cellutech_iphone_sales.rpt_iphone_sales`
GROUP BY color
ORDER BY total_amount DESC;

-- 3.12 Year-over-Year Comparison (2025 vs 2026)
SELECT
  transaction_year,
  COUNT(*) AS transaction_count,
  SUM(quantity) AS total_units,
  ROUND(SUM(amount), 2) AS total_amount,
  ROUND(AVG(unit_price), 2) AS avg_unit_price,
  ROUND(AVG(amount), 2) AS avg_transaction_value
FROM `cellutech_iphone_sales.rpt_iphone_sales`
GROUP BY transaction_year
ORDER BY transaction_year;


-- ============================================================
-- SECTION 4: DATA VALIDATION & RECONCILIATION
-- Proves data integrity between raw staging and reporting view
-- ============================================================

-- 4.1 Row Count & Data Cleaning Audit
-- Shows: 10,920 raw rows → 10,000 valid + 920 blank ghost rows
SELECT
  'Raw Table (incl. Excel Trailing Blanks)' AS layer,
  COUNT(*)                      AS total_records,
  COUNTIF(Tranid IS NOT NULL)   AS valid_records,
  COUNTIF(Tranid IS NULL)       AS blank_ghost_rows
FROM `cellutech_iphone_sales.raw_iphone_transactions`

UNION ALL

SELECT
  'Reporting View (Sanitized)',
  COUNT(*),
  COUNTIF(transaction_id IS NOT NULL),
  COUNTIF(transaction_id IS NULL)
FROM `cellutech_iphone_sales.rpt_iphone_sales`;

-- 4.2 Financial Reconciliation (exact dollar match)
SELECT
  'Raw Table (Valid Rows Only)' AS source,
  SUM(CAST(Quantity AS INT64)) AS total_quantity,
  ROUND(SUM(CAST(Quantity AS INT64) * CAST(Unit_Price AS NUMERIC)), 2) AS total_amount
FROM `cellutech_iphone_sales.raw_iphone_transactions`
WHERE Tranid IS NOT NULL

UNION ALL

SELECT
  'Reporting View (Cleaned)' AS source,
  SUM(quantity) AS total_quantity,
  ROUND(SUM(amount), 2) AS total_amount
FROM `cellutech_iphone_sales.rpt_iphone_sales`;

-- 4.3 Distinct Value Validation
SELECT
  'Raw (Valid)' AS source,
  COUNT(DISTINCT Item_ID) AS skus,
  COUNT(DISTINCT Entity) AS entities,
  COUNT(DISTINCT Country) AS countries,
  COUNT(DISTINCT Subsidiary) AS subsidiaries
FROM `cellutech_iphone_sales.raw_iphone_transactions`
WHERE Tranid IS NOT NULL

UNION ALL

SELECT
  'Reporting View' AS source,
  COUNT(DISTINCT item_id) AS skus,
  COUNT(DISTINCT entity_name) AS entities,
  COUNT(DISTINCT country) AS countries,
  COUNT(DISTINCT subsidiary) AS subsidiaries
FROM `cellutech_iphone_sales.rpt_iphone_sales`;

-- 4.4 Duplicate Transaction ID Check (expect: 0 results)
SELECT
  transaction_id,
  COUNT(*) AS occurrences
FROM `cellutech_iphone_sales.rpt_iphone_sales`
GROUP BY transaction_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 20;

-- 4.5 Null check in reporting view (expect: all zeros)
SELECT
  COUNTIF(transaction_date IS NULL) AS null_dates,
  COUNTIF(transaction_id IS NULL) AS null_ids,
  COUNTIF(amount IS NULL) AS null_amounts,
  COUNTIF(iphone_model IS NULL) AS null_models,
  COUNTIF(storage_capacity IS NULL) AS null_storage,
  COUNTIF(color IS NULL) AS null_color
FROM `cellutech_iphone_sales.rpt_iphone_sales`;


-- ============================================================
-- SECTION 5: EXECUTIVE KPI SUMMARY
-- Single-row executive summary for dashboard reference
-- ============================================================

-- 5.1 Overall KPI Summary
SELECT
  COUNT(*)                                          AS total_transactions,
  SUM(quantity)                                     AS total_units,
  ROUND(SUM(amount), 2)                            AS total_business_volume,
  ROUND(AVG(unit_price), 2)                        AS avg_unit_price,
  ROUND(AVG(amount), 2)                            AS avg_transaction_value,
  COUNT(DISTINCT entity_name)                      AS unique_customers,
  COUNT(DISTINCT item_id)                          AS unique_products,
  COUNT(DISTINCT country)                          AS active_markets,
  COUNT(DISTINCT sales_class)                      AS sales_reps,
  MIN(transaction_date)                            AS reporting_from,
  MAX(transaction_date)                            AS reporting_to
FROM `cellutech_iphone_sales.rpt_iphone_sales`;

-- 5.2 Revenue vs Procurement Split
-- CRITICAL: The $1.28B total includes BOTH revenue AND procurement.
-- Sales Order + Invoice = Revenue (selling to customers)
-- Purchase Order + Item Receipt = Procurement (buying from suppliers)
SELECT
  transaction_category,
  COUNT(*) AS transaction_count,
  SUM(quantity) AS total_units,
  ROUND(SUM(amount), 2) AS total_amount,
  ROUND(SUM(amount) * 100.0 / SUM(SUM(amount)) OVER(), 2) AS pct_of_total
FROM `cellutech_iphone_sales.rpt_iphone_sales`
GROUP BY transaction_category
ORDER BY total_amount DESC;

-- ============================================================
-- END OF SQL SCRIPTS
-- ============================================================

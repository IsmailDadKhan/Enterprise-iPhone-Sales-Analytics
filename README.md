# 📱 Enterprise iPhone Sales Analytics — Cloud Data Warehousing & Executive BI

[![Google BigQuery](https://img.shields.io/badge/Google%20BigQuery-Cloud%20Data%20Warehouse-4285F4?style=flat&logo=googlecloud&logoColor=white)](https://cloud.google.com/bigquery)
[![SQL](https://img.shields.io/badge/SQL-Advanced%20Analytics%20%26%20CTEs-CC292B?style=flat&logo=postgresql&logoColor=white)](https://en.wikipedia.org/wiki/SQL)
[![Looker Studio](https://img.shields.io/badge/Looker%20Studio-Executive%20BI%20Dashboard-FFBC00?style=flat&logo=looker&logoColor=black)](https://lookerstudio.google.com/)
[![Python](https://img.shields.io/badge/Python-Data%20Auditing%20%26%20ETL-3776AB?style=flat&logo=python&logoColor=white)](https://www.python.org/)
[![Status](https://img.shields.io/badge/Status-Completed%20%26%20Reconciled-success?style=flat)]()

**Author:** Ismail Dad Khan  
**Role:** Junior Data Analyst  
**Focus:** Cloud Data Warehousing, Data Modeling, Advanced SQL Analytics & Business Intelligence  

---

## 📌 Executive Summary

This project delivers an end-to-end cloud business intelligence solution for global iPhone sales and procurement operations. Analyzing **10,000 multi-market transaction records** valued at **$1.28 Billion ($1,281,559,743.78)** across **93 device SKUs**, **12 countries**, and **4 international subsidiaries**, the project transitions raw transactional data into high-performance analytical views in **Google Cloud BigQuery** and delivers actionable executive insights via **Google Looker Studio**.

### Key Business Metrics at a Glance:
- **Total Gross Volume Analyzed:** **$1,281,559,743.78**
- **Total Physical Units Moved:** **1,255,021 units**
- **Verified Clean Transactions:** **10,000 transactions**
- **Product SKUs Tracked:** **93 unique models** (iPhone 11 through iPhone 15 Pro Max)
- **Financial Variance:** **$0.00 (100% perfect reconciliation)**

---

## 🏗️ System Architecture & Data Pipeline

```text
  ┌─────────────────────────────────────────────────────────────┐
  │                 Raw Data Sources (Excel)                    │
  │  • Iphone Sales Data.xlsx (10,920 rows with formula strings)│
  │  • Product Master.xlsx (93 SKUs with dimensions)            │
  └──────────────────────────────┬──────────────────────────────┘
                                 │ Python ETL / Pre-processing
                                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │                 Google Cloud BigQuery                       │
  │  1. raw_iphone_transactions (Staging Layer)                 │
  │  2. raw_product_master (Dimensional Dimension Layer)        │
  │  3. rpt_iphone_sales (Production Reporting View)            │
  │     - Filtered 920 ghost rows                               │
  │     - Recalculated dynamic formula strings to numeric       │
  │     - Joined product attributes (Model, Storage, Color)     │
  │     - Generated temporal & cohort dimensions                │
  └──────────────────────────────┬──────────────────────────────┘
                                 │ Direct SQL / Connector
                                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │              Google Looker Studio Executive BI              │
  │  • Executive KPI Scorecards & Financial Summaries           │
  │  • Regional & Subsidiary Volume Breakdown                   │
  │  • Product Mix, Tier (Pro vs Standard) & Storage Analysis   │
  │  • Dynamic Entity, Timeframe & Type Multi-Select Filters    │
  └─────────────────────────────────────────────────────────────┘
```

---

## 🔍 Data Cleansing & Engineering Highlights

During schema ingestion and initial auditing, two critical data quality challenges were identified and systematically resolved:

1. **Ghost Row Elimination:**
   - The source Excel workbook contained artifact formatting extending 920 rows past the valid transaction boundary (rows 10,001–10,920).
   - Ingesting raw files into BigQuery created 920 entirely NULL records.
   - **Resolution:** Implemented rigorous CTE filtering (`WHERE Tranid IS NOT NULL AND Trandate IS NOT NULL`), cleanly isolating the exact **10,000 valid business records**.
2. **Formula String Conversion:**
   - Raw transaction amounts were stored as unparsed Excel string references (e.g., `"=D2*H2"`).
   - **Resolution:** Re-computed exact financial totals at the ingestion level via `ROUND(Quantity * Unit_Price, 2)`, establishing deterministic float precision across all financial aggregations.
3. **Dimensional Enrichment:**
   - Transformed flat transactional records into an analytical Star Schema view (`rpt_iphone_sales`) by joining with `raw_product_master`, injecting dimensions: `iphone_model`, `storage_capacity`, `color`, `price_tier`, and `transaction_category` (Revenue vs. Procurement).

---

## 📊 Data Reconciliation & Audit (100% Match)

To guarantee executive trust, all analytical layers were reconciled against the raw source:

| Audit Parameter | Raw Staging Layer | Reporting Layer (`rpt_iphone_sales`) | Variance | Status |
| :--- | :---: | :---: | :---: | :---: |
| **Total Row Count** | 10,920 | 10,000 | -920 *(Blank ghost rows)* | ✅ Cleanly Handled |
| **Valid Transactions** | 10,000 | 10,000 | 0 | ✅ Exact Match |
| **Total Units (Quantity)** | 1,255,021 | 1,255,021 | 0 | ✅ Perfect Match |
| **Total Financial Volume** | $1,281,559,743.78 | $1,281,559,743.78 | **$0.00** | ✅ 100% Reconciled |
| **Unique Product SKUs** | 93 | 93 | 0 | ✅ Full Coverage |
| **Trading Entities** | 12 | 12 | 0 | ✅ Zero Loss |
| **Operating Countries** | 12 | 12 | 0 | ✅ Full Coverage |
| **Global Subsidiaries** | 4 | 4 | 0 | ✅ Full Coverage |

---

## 💡 Key Strategic Business Findings

### 1. Premium "Pro Max" Tiers Command Outsized Revenue Share
- **Finding:** iPhone 14 Pro Max and 15 Pro Max models account for **38.5% of total gross dollar volume**, despite representing only ~26% of physical unit volume.
- **Strategic Recommendation:** Prioritize working capital and safety stock for 256GB and 512GB Pro Max configurations in high-demand finishes (Natural Titanium & Space Black).

### 2. Hub Concentration in UAE & Hong Kong
- **Finding:** Operations in the UAE and Hong Kong subsidiaries generate over **68% of total transactional volume**, functioning as primary re-export and wholesale distribution hubs.
- **Strategic Recommendation:** Negotiate consolidated regional freight corridors and optimize credit terms with key UAE and HK banking partners to decrease working capital cycle times.

### 3. Replenishment Cycle Synchronization
- **Finding:** The distribution of transaction types reveals an active replenishment cadence: `days_since_last_invoice` averages **28–34 days** among key customer entities.
- **Strategic Recommendation:** Establish automated 45-day latency alerts in Looker Studio for account managers to follow up on dormant client accounts before replenishment gaps widen.

---

## 🛠️ Repository Structure

```text
├── README.md                          # Project documentation
├── sql/
│   └── pilot_project_sql_scripts.sql  # 5-part complete SQL suite
├── data/
│   ├── iphone_transactions.csv        # Sanitized transactions (10k rows)
│   └── product_master.csv             # Product dimensional reference (93 SKUs)
├── docs/
│   └── Pilot_Project_Submission_Ismail_Dad_Khan.pdf # Full executive report
└── scripts/
    ├── deep_audit.py                  # Python data quality audit script
    └── convert_to_csv.py              # Excel to CSV ETL converter
```

---

## 💻 SQL Scripts Suite Overview (`pilot_project_sql_scripts.sql`)

The repository includes enterprise-grade, commented SQL queries partitioned into 5 key sections:
1. **Section 1: Data Auditing & Schema Checks** — Column-level null profiling, ghost row quantification, and distinct value validation.
2. **Section 2: Production Reporting View** — `rpt_iphone_sales` view definition with clean type casting, calculations, and joins.
3. **Section 3: 12 Analytical Business Queries** — Running totals (`SUM() OVER`), monthly velocity, cohort retention, ASP comparisons, and Pareto distributions.
4. **Section 4: Financial Reconciliation** — Multi-table reconciliation queries verifying sums, averages, and counts.
5. **Section 5: Executive KPI Synthesis** — High-level single-query KPI extraction for dashboard cards.

---

## 🚀 How to Replicate This Project

1. **Clone this repository:**
   ```bash
   git clone https://github.com/IsmailDadKhan/Enterprise-iPhone-Sales-Analytics.git
   ```
2. **Setup Google BigQuery:**
   - Create a dataset named `cellutech_iphone_sales`.
   - Upload `data/iphone_transactions.csv` as table `raw_iphone_transactions`.
   - Upload `data/product_master.csv` as table `raw_product_master`.
3. **Execute SQL Suite:**
   - Run Section 2 in `sql/pilot_project_sql_scripts.sql` to build the `rpt_iphone_sales` view.
   - Run Section 3 queries to generate analytics.
4. **Connect Looker Studio:**
   - Connect BigQuery datasource pointing directly to `rpt_iphone_sales`.
   - Configure charts, scorecards, and interactive filters.

---

## 📬 Contact & Portfolio

- **LinkedIn:** [Ismail Dad Khan](https://www.linkedin.com/in/ismail-dad-khan/)
- **Interactive DashBoard:** [Looker Studio](https://datastudio.google.com/reporting/174be905-0103-405b-be1f-d405acb45fdb/page/c0p9F)
- **GitHub:** [@IsmailDadKhan](https://github.com/IsmailDadKhan)

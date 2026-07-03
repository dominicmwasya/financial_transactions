#  Financial Transactions Performance Dashboard
### End-to-End Data Analytics Project | Python • MySQL • Power BI

![Dashboard](Dashboard_preview.webp)

---

## Project Overview

This project demonstrates a complete data analytics pipeline built on a real-world-style financial transactions dataset with **100,000 rows** of intentionally dirty data. The goal was to clean, transform, store, query, and visualise the data to surface meaningful business insights — simulating the kind of messy, real-world data encountered in financial environments.

**Tech stack:** Python (pandas, SQLAlchemy) → MySQL → Power BI (DAX)

**Domain:** Retail electronics — Tablet, Laptop, Smartphone, Headphones, Coffee Machine

---

## Repository Structure

```
financial_transactions/
│
├── dirty_financial_transactions.csv                          # Raw dataset (100,000 rows)
├── Data_Analytics_Portfolio_Financial_Transactions.ipynb     # Python cleaning notebook
├── Data_Analytics_Portfolio_Financial_Transactions.sql       # SQL EDA queries
├── assets/
│   └── dashboard.png                                         # Power BI dashboard screenshot
└── README.md
```

---

## Data Quality Issues Found

| Issue | Detail | Rows Affected |
|---|---|---|
| Duplicate rows | Identical rows across all columns | 994 |
| Negative prices | Values like `-$445.34` — entry errors | ~16,500 |
| Price formatting | Mix of `$420.21` strings and raw floats | ~65,000 |
| Negative quantities | Values down to `-10` — entry errors | ~47,000 |
| Payment method variants | `pay pal`, `PayPal`, `PayPal ` — 6 variants of 3 values | All rows |
| Transaction status variants | `completed`, `complete`, `Completed` — 5 variants of 3 values | All rows |
| Invalid dates — month 13 | `2023-13-01` is an impossible calendar date | 31,834 |
| Invalid dates — Feb 30 | `2025-02-30` does not exist | 31,547 |
| Product name truncations | `Tab`, `Cof`, `Smar`, `Lapt`, `H` etc. — 40+ variants of 5 products | All rows |
| Missing values — Price | Blank price fields | 33,131 |
| Missing values — Status | Blank transaction status fields | 16,521 |
| Missing values — Quantity | Blank quantity fields | 4,972 |
| Missing values — Date | Blank transaction date fields | 4,821 |
| Missing values — Customer ID | Blank customer IDs | 4,878 |
| Missing values — Transaction ID | Blank or missing IDs | 5,018 |

###Deep Dive: Invalid Date Analysis

During cleaning, `pd.to_datetime(errors='coerce')` flagged **63,381 records (64% of the dataset)** with impossible dates:

```
2023-13-01    31,834 occurrences   ← month 13 does not exist
2025-02-30    31,547 occurrences   ← February 30 does not exist
```

> **Critical observation:** The fact that exactly two invalid date values each appear tens of thousands of times is not consistent with random human data entry error. This pattern strongly suggests either **synthetically generated dirty data** or a **systematic upstream ETL/system bug** — for example, two source systems writing dates in different formats that were merged without validation.
>
> Rather than inventing replacement dates (which would compromise data integrity), these rows were coerced to `NaT` and documented. All time-based analysis in this project is therefore limited to the **31,440 rows (31.8%)** with valid dates.
>
> *This kind of observation — reasoning about the origin and pattern of errors rather than just cleaning them — is what separates a data analyst from a data janitor.*

---

## Cleaning Pipeline (Python)

```python
import pandas as pd

# Step 1 — Load raw data
df = pd.read_csv('dirty_financial_transactions.csv')
# Shape: (100000, 8)

# Step 2 — Drop duplicates
df = df.drop_duplicates()
# 100,000 → 99,006 rows

# Step 3 — Fix Price (strip $, whitespace, convert, abs)
df['Price'] = df['Price'].str.replace('$', '', regex=False).str.strip()
df['Price'] = pd.to_numeric(df['Price'], errors='coerce')
df['Price'] = df['Price'].abs()
# Negatives flipped to positive; strings coerced to NaN for later filling

# Step 4 — Fix Quantity (abs)
df['Quantity'] = df['Quantity'].abs()
# Min was -10, now min is 1

# Step 5 — Standardise Payment Method
df['Payment_Method'] = df['Payment_Method'].str.strip().replace({
    'pay pal'    : 'PayPal',
    'PayPal'     : 'PayPal',
    'creditcard' : 'Credit Card',
    'credit card': 'Credit Card',
    'Credit Card': 'Credit Card',
    'Cash'       : 'Cash'
})
# 6 variants → 3 clean values: PayPal, Credit Card, Cash

# Step 6 — Standardise Transaction Status
df['Transaction_Status'] = df['Transaction_Status'].str.strip().str.lower().replace({
    'completed' : 'Completed',
    'complete'  : 'Completed',
    'pending'   : 'Pending',
    'failed'    : 'Failed'
})
# 5 variants → 3 clean values: Completed, Pending, Failed

# Step 7 — Fix Transaction Date (invalid dates → NaT)
df['Transaction_Date'] = pd.to_datetime(df['Transaction_Date'], errors='coerce')
# 63,381 impossible dates coerced to NaT (documented above)

# Step 8 — Fix Transaction ID (rebuild clean sequential IDs)
df['Transaction_ID'] = df['Transaction_ID'].astype(str).str.strip()
df['Transaction_ID'] = df['Transaction_ID'].str.extract(r'(\d+)')[0]
df['Transaction_ID'] = pd.to_numeric(df['Transaction_ID'], errors='coerce')
df['Transaction_ID'] = range(1, len(df) + 1)
df['Transaction_ID'] = 'T' + df['Transaction_ID'].astype(str).str.zfill(4)
# Guarantees uniqueness; gaps and duplicates in original replaced entirely

# Step 9 — Fix Product Names (40+ truncated variants → 5 clean categories)
df['Product_Name_temp'] = df['Product_Name'].str.lower().str.strip()
df['Product_Name_temp'] = df['Product_Name_temp'].replace({
    'tab': 'Tablet', 'tabl': 'Tablet', 'table': 'Tablet', 'ta': 'Tablet', 't': 'Tablet',
    'lap': 'Laptop', 'lapt': 'Laptop', 'lapto': 'Laptop', 'la': 'Laptop', 'l': 'Laptop',
    'smar': 'Smartphone', 'smart': 'Smartphone', 'smartp': 'Smartphone',
    'smartph': 'Smartphone', 'smartpho': 'Smartphone', 'smartphon': 'Smartphone',
    'sm': 'Smartphone', 's': 'Smartphone',
    'head': 'Headphones', 'headp': 'Headphones', 'headph': 'Headphones',
    'headpho': 'Headphones', 'headphon': 'Headphones', 'headphone': 'Headphones',
    'hea': 'Headphones', 'he': 'Headphones', 'h': 'Headphones',
    'cof': 'Coffee Machine', 'coff': 'Coffee Machine', 'coffe': 'Coffee Machine',
    'coffee': 'Coffee Machine', 'coffee m': 'Coffee Machine', 'coffee ma': 'Coffee Machine',
    'coffee mac': 'Coffee Machine', 'coffee mach': 'Coffee Machine',
    'coffee machi': 'Coffee Machine', 'coffee machin': 'Coffee Machine',
    'c': 'Coffee Machine', 'co': 'Coffee Machine'
})
df['Product_Name'] = df['Product_Name_temp'].str.title()
df.drop(columns=['Product_Name_temp'], inplace=True)
# Result: exactly 5 clean products, ~20,000 rows each

# Step 10 — Fill remaining nulls
df['Price'] = df['Price'].fillna(df['Price'].median())              # median = ~525
df['Quantity'] = df['Quantity'].fillna(df['Quantity'].median())     # median = 8
df['Transaction_Status'] = df['Transaction_Status'].fillna(df['Transaction_Status'].mode()[0])
df['Customer_ID'] = df['Customer_ID'].fillna(df['Customer_ID'].mode()[0])
# Transaction_Date NaTs intentionally left — documented in date analysis above
```

---

## MySQL Export

```python
from sqlalchemy import create_engine

engine = create_engine("mysql+pymysql://root:password@127.0.0.1:3306/financial_transactions_db")
df.to_sql('financial_transactions', engine, if_exists='replace', index=False)

# Verify
pd.read_sql("SELECT * FROM financial_transactions LIMIT 5;", engine)
```

---

## SQL EDA (Key Queries)

**Revenue by product — completed transactions only:**
```sql
SELECT
    Product_Name,
    COUNT(*) AS Total_Transactions,
    ROUND(SUM(Price * Quantity), 2) AS Total_Revenue
FROM financial_transactions
WHERE Transaction_Status = 'Completed'
GROUP BY Product_Name
ORDER BY Total_Revenue DESC;
```

**Revenue by payment method:**
```sql
SELECT
    Payment_Method,
    COUNT(*) AS Total_Transactions,
    ROUND(SUM(Price * Quantity), 2) AS Total_Revenue
FROM financial_transactions
WHERE Transaction_Status = 'Completed'
GROUP BY Payment_Method
ORDER BY Total_Revenue DESC;
```

**Transaction status breakdown with percentages:**
```sql
SELECT
    Transaction_Status,
    COUNT(*) AS Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS Percentage
FROM financial_transactions
GROUP BY Transaction_Status;
```

**Payment method vs transaction status matrix:**
```sql
SELECT
    Payment_Method,
    Transaction_Status,
    COUNT(*) AS Total_Transactions
FROM financial_transactions
GROUP BY Payment_Method, Transaction_Status
ORDER BY Payment_Method;
```

**Monthly revenue trend — valid dates only:**
```sql
SELECT
    DATE_FORMAT(Transaction_Date, '%Y-%m') AS Month,
    COUNT(*) AS Transactions,
    ROUND(SUM(Price * Quantity), 2) AS Revenue
FROM financial_transactions
WHERE Transaction_Status = 'Completed'
  AND Transaction_Date IS NOT NULL
GROUP BY Month
ORDER BY Month;
```

---

## Key Business Insights

### Revenue
| Metric | Value |
|---|---|
| Total revenue (all transactions) | $9.30B |
| Completed revenue | $6.18B |
| Revenue lost to failed transactions | ~$1.60B |
| Revenue locked in pending transactions | ~$1.52B |
| **Total at-risk revenue** | **~$3.12B (33.4%)** |

### Products
| Product | Completed Revenue | Transactions |
|---|---|---|
| Tablet | $1.90bn | 13,309 |
| Headphones | $1.87bn | 13,144 |
| Smartphone | $1.86bn | 13,165 |
| Laptop | $1.85bn | 13,209 |
| Coffee Machine | $1.82bn | 13,107 |

> All 5 products generate nearly identical revenue — indicative of synthetic data, but useful for demonstrating balanced dashboard design.

### Transaction Status
| Status | Count | % | Revenue |
|---|---|---|---|
| Completed | 65,934 | 66.6% | $6.18B |
| Failed | 16,629 | 16.8% | $1.60B |
| Pending | 16,443 | 16.6% | $1.52B |

> **1 in 3 transactions does not complete.** In a real business context this would be a critical KPI — signalling payment gateway failures, customer drop-off, or fraud.

### Payment Methods
| Method | Completed | Failed | Pending |
|---|---|---|---|
| Credit Card | 28,327 | 7,203 | 7,074 |
| PayPal | 28,245 | 7,101 | 7,003 |
| Cash | 9,362 | 2,325 | 2,366 |

> Credit Card has the highest failure count (7,203) though proportionally all three methods fail at roughly the same rate (~16-17%).

### Customer Anomaly 
| Customer | Revenue | Transactions |
|---|---|---|
| C2023 | $320,906,338 | 4,867 |
| C1590 | $5,000,070 | 24 |
| C1352 | $4,410,812 | 22 |

> **C2023 is a significant outlier** — 4,867 transactions generating $320M while every other customer averages 20-29 transactions and ~$4M. This warrants investigation: possible data quality issue, a duplicate customer ID, or a wholesale/corporate account not segmented from retail data.

### Date Coverage
| Metric | Value |
|---|---|
| Valid date records | 31,440 (31.8%) |
| Invalid date records (NaT) | 67,566 (68.2%) |
| Valid date range | Jan 2020 — Feb 2025 |
| Monthly revenue (avg, valid dates) | ~$31–38M per month |

> Time-based analysis is limited to 31.8% of records. All trend visuals exclude NaT rows explicitly.

---

## DAX Measures (Power BI)

```dax
Total Revenue =
SUMX('financial_transactions',
    'financial_transactions'[Price] * 'financial_transactions'[Quantity])

Completed Revenue =
CALCULATE([Total Revenue],
    'financial_transactions'[Transaction_Status] = "Completed")

Total Transactions = COUNTROWS('financial_transactions')

Completion Rate =
DIVIDE(
    CALCULATE([Total Transactions],
        'financial_transactions'[Transaction_Status] = "Completed"),
    [Total Transactions])

Unique Customers = DISTINCTCOUNT('financial_transactions'[Customer_ID])

Transactions Per Customer =
DIVIDE([Total Transactions], [Unique Customers])

Avg Transaction Value (Completed) =
DIVIDE(
    [Completed Revenue],
    CALCULATE(SUM('financial_transactions'[Quantity]),
        'financial_transactions'[Transaction_Status] = "Completed"))
```

---

## Tools & Libraries

| Tool | Version | Purpose |
|---|---|---|
| Python | 3.x | Data cleaning and transformation |
| pandas | Latest | DataFrame operations |
| SQLAlchemy + pymysql | Latest | MySQL connection and data export |
| MySQL | 8.0+ | Data storage and SQL EDA |
| Power BI Desktop | Latest | Dashboard and DAX measures |


🔗 [GitHub](https://github.com/dominicmwasya) · Open to Data Analyst & Forensic Data Analyst roles in Nairobi

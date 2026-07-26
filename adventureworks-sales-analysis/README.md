#  AdventureWorks Sales & Profitability Analysis

> **TL;DR:** I took a messy enterprise database, fixed critical data modeling issues in SQL, built a Star Schema in Power BI, and uncovered why our profit margins are lower than expected.

---

## Why This Project Exists

Most portfolio projects stop at "Total Sales went up." But revenue doesn't pay the bills—profit does. 

I built this dashboard to answer a harder question: **"Where are we actually losing money?"** Using the AdventureWorks2025 dataset, I moved beyond basic visualization to perform deep-dive profitability analysis, identifying hidden cost drivers and regional inefficiencies.

---

## ️ The Technical Journey (What I Actually Did)

This wasn't just drag-and-drop. Here’s where the real engineering happened:

### 1. Taming the Data (SQL Server)
The raw AdventureWorks tables were deceptive. When I first joined `SalesOrderHeader` with `SalesTerritory` and `CustomerAddress`, my row count exploded from 31k to 121k due to **fan-out issues**. 
-   **The Fix:** I wrote CTE-based views to pre-deduplicate dimension tables *before* joining them to the fact table.
-   **The Result:** A clean, validated `v_Master_Sales_Fact` view with exactly 121,317 unique line items and zero duplicates.

### 2. Building a Proper Star Schema (Power BI)
I refused to use a single flat table. Instead, I modeled a proper **Star Schema**:
-   **Fact Table:** `Fact_Sales` (Grain: Line Item)
-   **Dimensions:** `Dim_Date`, `Dim_Product`, `Dim_Geography`
-   **Challenge:** The Geography dimension had a Many-to-Many relationship. I solved this by creating a composite `GeoKey` to enforce a clean One-to-Many relationship.

### 3. Writing Explicit DAX Measures
No implicit sums here. Every calculation is an explicit measure for performance and reusability:
-   `YoY Growth %`: Uses `SAMEPERIODLASTYEAR` for accurate time intelligence.
-   `Profit Margin %`: Uses `DIVIDE()` to safely handle divide-by-zero errors.
-   `AOV`: Dynamic Average Order Value based on distinct order counts.

---

## 🔍 Key Findings

| Metric | Value | Insight |
| :--- | :--- | :--- |
| **Total Revenue** | $109.8M | Strong top-line growth, but... |
| **Gross Profit** | $93.7M | ...margins tell a different story. |
| **Avg. Margin** | ~8.5% | Lower than industry standard (~25%). Suggests aggressive discounting or underreported COGS. |
| **Top Region** | North America | Dominates volume, but Europe shows higher per-unit profitability. |

**💡 Business Recommendation:** Shift marketing spend toward high-margin categories (like Accessories) rather than just pushing volume in low-margin Bikes.

---

##  How to Run This Locally

1.  **Database:** Restore `AdventureWorks2025.bak` in SQL Server.
2.  **ETL:** Run scripts in `/sql-scripts/` sequentially to create the analytics layer.
3.  **Dashboard:** Open `AdventureWorks_Sales_Analysis.pbix`. All data is imported; no live connection needed.
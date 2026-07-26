# DAX Measures Dictionary

This document lists all explicit measures created for the AdventureWorks Sales Analysis dashboard. All calculations follow best practices using `DIVIDE()` for safety and explicit references for performance.

## 1. Core Financial Metrics

| Measure Name | DAX Formula | Purpose |
| :--- | :--- | :--- |
| **Total Sales** | `SUM('Fact_Sales'[SalesAmount])` | Base metric for revenue analysis. |
| **Total Cost** | `SUM('Fact_Sales'[TotalCost])` | Sum of standard costs for sold items. |
| **Gross Profit** | `[Total Sales] - [Total Cost]` | Absolute profit before overheads. |
| **Profit Margin %** | `DIVIDE([Gross Profit], [Total Sales], 0)` | Profitability ratio (formatted as %). |
| **Order Count** | `DISTINCTCOUNT('Fact_Sales'[SalesOrderID])` | Number of unique transactions. |

## 2. Time Intelligence & Growth

| Measure Name | DAX Formula | Purpose |
| :--- | :--- | :--- |
| **Sales LY** | `CALCULATE([Total Sales], SAMEPERIODLASTYEAR('Dim_Date'[Date]))` | Revenue from the same period last year. |
| **YoY Growth %** | `DIVIDE([Total Sales] - [Sales LY], [Sales LY], 0)` | Year-over-year growth rate. |

## 3. Operational KPIs

| Measure Name | DAX Formula | Purpose |
| :--- | :--- | :--- |
| **AOV** | `DIVIDE([Total Sales], [Order Count], 0)` | Average Order Value per transaction. |
| **Unique Products Sold** | `DISTINCTCOUNT('Fact_Sales'[ProductID])` | Breadth of product portfolio utilization. |

## 💡 Best Practices Applied
-   **Explicit Measures Only:** No implicit sums dragged directly to visuals.
-   **Safe Division:** Always used `DIVIDE(numerator, denominator, 0)` instead of `/` to prevent Infinity errors.
-   **Variable Reuse:** Complex measures reference simpler base measures (e.g., `YoY Growth %` uses `[Total Sales]` and `[Sales LY]`).
-   **Granularity Awareness:** `Order Count` uses `DISTINCTCOUNT` because the fact table is at line-item level.
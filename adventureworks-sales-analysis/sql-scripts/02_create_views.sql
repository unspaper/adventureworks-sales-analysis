-- 1. Create the schema if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Analytics')
BEGIN
    EXEC('CREATE SCHEMA Analytics');
END
GO

-- 2. Now create your view
CREATE VIEW [Analytics].[v_Sales_Dates] AS
SELECT 
    SalesOrderID,
    OrderDate,
    YEAR(OrderDate) AS OrderYear,
    MONTH(OrderDate) AS OrderMonth,
    DATENAME(MONTH, OrderDate) AS OrderMonthName,
    DATEPART(QUARTER, OrderDate) AS OrderQuarter,
    CONCAT(YEAR(OrderDate), '-Q', DATEPART(QUARTER, OrderDate)) AS YearQuarter,
    ShipDate,
    DueDate
FROM Sales.SalesOrderHeader;
GO


CREATE VIEW [Analytics].[v_Product_Hierarchy] AS
SELECT 
    p.ProductID,
    p.Name AS ProductName,
    p.Color,
    p.Size,
    p.StandardCost,
    p.ListPrice,
    ISNULL(ps.Name, 'No Subcategory') AS Subcategory,
    ISNULL(pc.Name, 'No Category') AS Category
FROM Production.Product p
LEFT JOIN Production.ProductSubcategory ps 
    ON p.ProductSubcategoryID = ps.ProductSubcategoryID
LEFT JOIN Production.ProductCategory pc 
    ON ps.ProductCategoryID = pc.ProductCategoryID;
GO



CREATE VIEW [Analytics].[v_Master_Sales_Fact] AS
SELECT 
    -- Keys
    soh.SalesOrderID,
    soh.OrderDate,
    soh.CustomerID,
    sod.ProductID,
    
    -- Location Dimensions
    sp.Name AS StateProvince,
    cr.Name AS CountryRegion,
    st.Name AS TerritoryName,
    
    -- Product Dimensions
    p.Name AS ProductName,
    p.Color,
    pc.Name AS ProductCategory,
    ps.Name AS ProductSubcategory,
    
    -- Financials
    sod.OrderQty,
    sod.UnitPrice,
    sod.UnitPriceDiscount,
    sod.LineTotal AS SalesAmount,
    p.StandardCost,
    
    -- Calculated Metrics
    (sod.OrderQty * p.StandardCost) AS TotalCost,
    (sod.LineTotal - (sod.OrderQty * p.StandardCost)) AS GrossProfit,
    
    -- Flags
    CASE 
        WHEN sod.UnitPriceDiscount > 0 THEN 'Yes'
        ELSE 'No'
    END AS IsDiscounted

FROM Sales.SalesOrderHeader soh
JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
JOIN Production.Product p ON sod.ProductID = p.ProductID
LEFT JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
LEFT JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
JOIN Person.Person per ON c.PersonID = per.BusinessEntityID
JOIN Person.BusinessEntityAddress bea ON per.BusinessEntityID = bea.BusinessEntityID
JOIN Person.Address a ON bea.AddressID = a.AddressID
JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
JOIN Person.CountryRegion cr ON sp.CountryRegionCode = cr.CountryRegionCode
JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID;
GO


-- Safely drop the view if it exists
IF OBJECT_ID('[Analytics].[v_Master_Sales_Fact]', 'V') IS NOT NULL
    DROP VIEW [Analytics].[v_Master_Sales_Fact];
GO

-- Now create the fixed version
CREATE VIEW [Analytics].[v_Master_Sales_Fact] AS
SELECT 
    soh.SalesOrderID,
    soh.OrderDate,
    soh.CustomerID,
    sod.ProductID,
    sp.Name AS StateProvince,
    cr.Name AS CountryRegion,
    st.Name AS TerritoryName,
    p.Name AS ProductName,
    p.Color,
    pc.Name AS ProductCategory,
    ps.Name AS ProductSubcategory,
    sod.OrderQty,
    sod.UnitPrice,
    sod.UnitPriceDiscount,
    sod.LineTotal AS SalesAmount,
    p.StandardCost,
    (sod.OrderQty * p.StandardCost) AS TotalCost,
    (sod.LineTotal - (sod.OrderQty * p.StandardCost)) AS GrossProfit,
    CASE WHEN sod.UnitPriceDiscount > 0 THEN 'Yes' ELSE 'No' END AS IsDiscounted
FROM Sales.SalesOrderHeader soh
JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
JOIN Production.Product p ON sod.ProductID = p.ProductID
LEFT JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
LEFT JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
JOIN Person.Person per ON c.PersonID = per.BusinessEntityID
JOIN Person.BusinessEntityAddress bea 
    ON per.BusinessEntityID = bea.BusinessEntityID
    AND bea.AddressTypeID = 2  -- Primary/Home address only
JOIN Person.Address a ON bea.AddressID = a.AddressID
JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
JOIN Person.CountryRegion cr ON sp.CountryRegionCode = cr.CountryRegionCode
JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID;
GO




SELECT COUNT(*) FROM [Analytics].[v_Master_Sales_Fact];


SELECT TOP 10 * 
FROM [Analytics].[v_Master_Sales_Fact] 
WHERE CountryRegion IS NULL;



SELECT TOP 5 SalesAmount, TotalCost, GrossProfit 
FROM [Analytics].[v_Master_Sales_Fact] 
ORDER BY GrossProfit DESC;

-- Should return ~31,465 rows now
SELECT COUNT(*) AS [RowCount] FROM [Analytics].[v_Master_Sales_Fact];

-- Confirm zero duplicates
SELECT SalesOrderID, COUNT(*) AS DupCount
FROM [Analytics].[v_Master_Sales_Fact]
GROUP BY SalesOrderID
HAVING COUNT(*) > 1;
-- Expected: 0 rows returned




CREATE OR ALTER VIEW [Analytics].[v_Master_Sales_Fact] AS
SELECT 
    soh.SalesOrderID,
    soh.OrderDate,
    soh.CustomerID,
    sod.ProductID,
    
    -- Location from the ORDER'S ship-to address (not customer's home address)
    sp.Name AS StateProvince,
    cr.Name AS CountryRegion,
    st.Name AS TerritoryName,
    
    -- Product Dimensions
    p.Name AS ProductName,
    p.Color,
    pc.Name AS ProductCategory,
    ps.Name AS ProductSubcategory,
    
    -- Financials
    sod.OrderQty,
    sod.UnitPrice,
    sod.UnitPriceDiscount,
    sod.LineTotal AS SalesAmount,
    p.StandardCost,
    
    -- Calculated Metrics
    (sod.OrderQty * p.StandardCost) AS TotalCost,
    (sod.LineTotal - (sod.OrderQty * p.StandardCost)) AS GrossProfit,
    
    CASE WHEN sod.UnitPriceDiscount > 0 THEN 'Yes' ELSE 'No' END AS IsDiscounted

FROM Sales.SalesOrderHeader soh
JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
JOIN Production.Product p ON sod.ProductID = p.ProductID
LEFT JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
LEFT JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID

-- ✅ KEY CHANGE: Use the order's ShipTo address directly
JOIN Person.Address a ON soh.ShipToAddressID = a.AddressID
JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
JOIN Person.CountryRegion cr ON sp.CountryRegionCode = cr.CountryRegionCode

JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID;
GO



-- Should now return exactly 31,465 rows (one per SalesOrderDetail)
SELECT COUNT(*) AS TotalRows 
FROM [Analytics].[v_Master_Sales_Fact];

-- Should return ZERO rows (no duplicates)
SELECT SalesOrderID, COUNT(*) AS DupCount
FROM [Analytics].[v_Master_Sales_Fact]
GROUP BY SalesOrderID
HAVING COUNT(*) > 1;


SELECT 
    soh.SalesOrderID,
    COUNT(*) AS [RowCount]   -- ✅ Added brackets
FROM Sales.SalesOrderHeader soh
JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID
GROUP BY soh.SalesOrderID
HAVING COUNT(*) > 1;

CREATE OR ALTER VIEW [Analytics].[v_Master_Sales_Fact] AS
SELECT 
    soh.SalesOrderID,
    soh.OrderDate,
    soh.CustomerID,
    sod.ProductID,
    sp.Name AS StateProvince,
    cr.Name AS CountryRegion,
    st.TerritoryName,  -- Now guaranteed unique
    p.Name AS ProductName,
    p.Color,
    pc.Name AS ProductCategory,
    ps.Name AS ProductSubcategory,
    sod.OrderQty,
    sod.UnitPrice,
    sod.UnitPriceDiscount,
    sod.LineTotal AS SalesAmount,
    p.StandardCost,
    (sod.OrderQty * p.StandardCost) AS TotalCost,
    (sod.LineTotal - (sod.OrderQty * p.StandardCost)) AS GrossProfit,
    CASE WHEN sod.UnitPriceDiscount > 0 THEN 'Yes' ELSE 'No' END AS IsDiscounted
FROM Sales.SalesOrderHeader soh
JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
JOIN Production.Product p ON sod.ProductID = p.ProductID
LEFT JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
LEFT JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
JOIN Person.Address a ON soh.ShipToAddressID = a.AddressID
JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
JOIN Person.CountryRegion cr ON sp.CountryRegionCode = cr.CountryRegionCode

-- ✅ KEY FIX: Pre-deduplicated territory via subquery
JOIN (
    SELECT TerritoryID, MAX(Name) AS TerritoryName
    FROM Sales.SalesTerritory
    GROUP BY TerritoryID
) st ON soh.TerritoryID = st.TerritoryID;
GO


-- Should return ~31,465 rows
SELECT COUNT(*) AS TotalRows 
FROM [Analytics].[v_Master_Sales_Fact];

-- MUST return 0 rows
SELECT SalesOrderID, COUNT(*) AS DupCount
FROM [Analytics].[v_Master_Sales_Fact]
GROUP BY SalesOrderID
HAVING COUNT(*) > 1;



-- Check if SalesOrderDetail has duplicate line items
SELECT SalesOrderID, ProductID, COUNT(*) AS LineItemCount
FROM Sales.SalesOrderDetail
GROUP BY SalesOrderID, ProductID
HAVING COUNT(*) > 1;



CREATE OR ALTER VIEW [Analytics].[v_Master_Sales_Fact] AS
WITH 
-- 1. تمیز کردن سلسله مراتب محصول
CleanProduct AS (
    SELECT DISTINCT
        p.ProductID,
        p.Name AS ProductName,
        p.Color,
        p.StandardCost,
        ps.Name AS ProductSubcategory,
        pc.Name AS ProductCategory
    FROM Production.Product p
    LEFT JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
    LEFT JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
),
-- 2. تمیز کردن آدرس و منطقه جغرافیایی
CleanAddress AS (
    SELECT DISTINCT
        a.AddressID,
        sp.Name AS StateProvince,
        cr.Name AS CountryRegion
    FROM Person.Address a
    JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
    JOIN Person.CountryRegion cr ON sp.CountryRegionCode = cr.CountryRegionCode
),
-- 3. تمیز کردن قلمروهای فروش (Territory)
CleanTerritory AS (
    SELECT TerritoryID, MAX(Name) AS TerritoryName
    FROM Sales.SalesTerritory
    GROUP BY TerritoryID
)
SELECT 
    soh.SalesOrderID,
    soh.OrderDate,
    soh.CustomerID,
    sod.ProductID,
    ca.StateProvince,
    ca.CountryRegion,
    ct.TerritoryName,
    cp.ProductName,
    cp.Color,
    cp.ProductCategory,
    cp.ProductSubcategory,
    sod.OrderQty,
    sod.UnitPrice,
    sod.UnitPriceDiscount,
    sod.LineTotal AS SalesAmount,
    cp.StandardCost,
    -- محاسبات سود
    (sod.OrderQty * cp.StandardCost) AS TotalCost,
    (sod.LineTotal - (sod.OrderQty * cp.StandardCost)) AS GrossProfit,
    CASE WHEN sod.UnitPriceDiscount > 0 THEN 'Yes' ELSE 'No' END AS IsDiscounted
FROM Sales.SalesOrderHeader soh
JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
JOIN CleanProduct cp ON sod.ProductID = cp.ProductID
JOIN CleanAddress ca ON soh.ShipToAddressID = ca.AddressID
JOIN CleanTerritory ct ON soh.TerritoryID = ct.TerritoryID;
GO



-- الف) تعداد کل ردیف‌ها (باید حدود 31,465 باشد)
SELECT COUNT(*) AS TotalRows 
FROM [Analytics].[v_Master_Sales_Fact];

-- ب) بررسی عدم وجود تکرار (باید 0 ردیف برگرداند)
SELECT SalesOrderID, COUNT(*) AS DupCount
FROM [Analytics].[v_Master_Sales_Fact]
GROUP BY SalesOrderID
HAVING COUNT(*) > 1;



CREATE OR ALTER VIEW [Analytics].[v_Master_Sales_Fact] AS
WITH 
CleanProduct AS (
    SELECT DISTINCT
        p.ProductID, p.Name AS ProductName, p.Color, p.StandardCost,
        ps.Name AS ProductSubcategory, pc.Name AS ProductCategory
    FROM Production.Product p
    LEFT JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
    LEFT JOIN Production.ProductCategory pc ON ps.ProductCategoryID = pc.ProductCategoryID
),
CleanAddress AS (
    SELECT DISTINCT a.AddressID, sp.Name AS StateProvince, cr.Name AS CountryRegion
    FROM Person.Address a
    JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
    JOIN Person.CountryRegion cr ON sp.CountryRegionCode = cr.CountryRegionCode
),
CleanTerritory AS (
    SELECT TerritoryID, MAX(Name) AS TerritoryName
    FROM Sales.SalesTerritory GROUP BY TerritoryID
)
SELECT 
    sod.SalesOrderDetailID, -- ✅ کلید اصلی یکتا برای هر خط فاکتور
    soh.SalesOrderID,
    soh.OrderDate,
    soh.CustomerID,
    sod.ProductID,
    ca.StateProvince,
    ca.CountryRegion,
    ct.TerritoryName,
    cp.ProductName,
    cp.Color,
    cp.ProductCategory,
    cp.ProductSubcategory,
    sod.OrderQty,
    sod.UnitPrice,
    sod.UnitPriceDiscount,
    sod.LineTotal AS SalesAmount,
    cp.StandardCost,
    (sod.OrderQty * cp.StandardCost) AS TotalCost,
    (sod.LineTotal - (sod.OrderQty * cp.StandardCost)) AS GrossProfit,
    CASE WHEN sod.UnitPriceDiscount > 0 THEN 'Yes' ELSE 'No' END AS IsDiscounted
FROM Sales.SalesOrderHeader soh
JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
JOIN CleanProduct cp ON sod.ProductID = cp.ProductID
JOIN CleanAddress ca ON soh.ShipToAddressID = ca.AddressID
JOIN CleanTerritory ct ON soh.TerritoryID = ct.TerritoryID;
GO

-- بررسی یکتایی بر اساس SalesOrderDetailID (کلید واقعی فکت تیبل)
SELECT SalesOrderDetailID, COUNT(*) AS DupCount
FROM [Analytics].[v_Master_Sales_Fact]
GROUP BY SalesOrderDetailID
HAVING COUNT(*) > 1;



-- ==========================================
-- FINAL VALIDATION SCRIPT FOR PHASE 1
-- ==========================================

PRINT '--- 1. CHECKING TOTAL ROW COUNT ---';
SELECT COUNT(*) AS Expected_Rows 
FROM [Analytics].[v_Master_Sales_Fact];
-- ✅ EXPECTED: 121,317 (One row per line item)

PRINT '--- 2. CHECKING UNIQUENESS (NO DUPLICATES) ---';
SELECT COUNT(*) AS Duplicate_Count 
FROM (
    SELECT SalesOrderDetailID, COUNT(*) as cnt
    FROM [Analytics].[v_Master_Sales_Fact]
    GROUP BY SalesOrderDetailID
    HAVING COUNT(*) > 1
) t;
-- ✅ EXPECTED: 0 (Zero duplicates allowed)

PRINT '--- 3. CHECKING FINANCIAL INTEGRITY ---';
SELECT 
    SUM(SalesAmount) AS Total_Revenue,
    SUM(GrossProfit) AS Total_Profit,
    ROUND(SUM(GrossProfit) / NULLIF(SUM(SalesAmount),0) * 100, 2) AS Avg_Profit_Margin_Pct
FROM [Analytics].[v_Master_Sales_Fact];
-- ✅ EXPECTED: Revenue ~98M | Profit ~25M | Margin ~25-26%

PRINT '--- 4. CHECKING DIMENSION COMPLETENESS ---';
SELECT 
    COUNT(CASE WHEN ProductCategory IS NULL THEN 1 END) AS Missing_Categories,
    COUNT(CASE WHEN CountryRegion IS NULL THEN 1 END) AS Missing_Countries,
    COUNT(CASE WHEN TerritoryName IS NULL THEN 1 END) AS Missing_Territories
FROM [Analytics].[v_Master_Sales_Fact];
-- ✅ EXPECTED: All should be 0 or very low (<1%)
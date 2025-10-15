CREATE DATABASE sales_analysis;
USE sales_analysis;

select * from categories;
select * from customers;
select * from products;
select * from shippers;
select * from suppliers;
select * from employees;
select * from order_details;
select * from orders;

/* 1.What is the average number of orders per customer?
Are there high-value repeat customers? */

-- AVG 
with cte as (
  select CustomerID, count(OrderID) as count_orders
  from orders
  group by CustomerID
)
select sum(count_orders) / count(distinct CustomerID) as AVG_ORDperCust
from cte;

-- high value cust
select CustomerID as HighvalueCust, count(o.OrderID) as order_count, round(sum(revenue), 2) as amount_spend
from orders o
join order_details od 
on o.OrderID = od.OrderID
group by CustomerID
having order_count > 2 and sum(revenue) > 10000;

/* 2. How do customer order patterns vary by city or country? */

SELECT
    o.ShipCountry,
    COUNT(DISTINCT o.CustomerID) AS No_OfCustomers,
    COUNT(DISTINCT o.OrderID) AS No_OfOrders,
    ROUND(SUM(od.Revenue), 2) AS TotalRevenue,
    ROUND(SUM(od.Revenue) / COUNT(DISTINCT o.OrderID), 2) AS AvgOrderValue,
    ROUND(CAST(COUNT(DISTINCT o.OrderID) AS REAL) / COUNT(DISTINCT o.CustomerID), 2) AS AvgOrdersPerCustomer
FROM orders o
JOIN order_details od 
ON o.orderID = od.orderID
GROUP BY o.ShipCountry
ORDER BY TotalRevenue DESC
LIMIT 10;

/* Can we cluster customers based on total spend, order count, and preferred categories? */
WITH CustomerSummary AS (
SELECT o.CustomerID, COUNT(DISTINCT o.OrderID) AS OrderCount,
        SUM(od.Revenue) AS TotalSpend FROM orders o
    JOIN order_details od ON o.OrderID = od.OrderID
    GROUP BY o.CustomerID
),
RankedCategories AS (
SELECT o.CustomerID, c.CategoryName,
ROW_NUMBER() OVER(PARTITION BY o.CustomerID ORDER BY SUM(od.Revenue) DESC) as CategoryRank
FROM orders o
JOIN order_details od ON o.OrderID = od.OrderID
JOIN products p ON od.ProductID = p.ProductID
JOIN categories c ON p.CategoryID = c.CategoryID
GROUP BY o.CustomerID, c.CategoryName
)

SELECT cs.CustomerID, ROUND(cs.TotalSpend, 2) AS TotalSpend, cs.OrderCount, 
rc.CategoryName AS PreferredCategory
FROM CustomerSummary cs
JOIN RankedCategories rc ON cs.CustomerID = rc.CustomerID
WHERE rc.CategoryRank = 1
ORDER BY cs.TotalSpend DESC;

/*4.Which product categories or products contribute most to order revenue?
.Are there any correlations between orders and customer location or product category?*/

-- Top Product Categories by Revenue
SELECT
c.CategoryName, ROUND(SUM(od.Revenue), 2) AS TotalCategoryRevenue
FROM categories c
JOIN products p ON c.CategoryID = p.CategoryID
JOIN order_details od ON p.ProductID = od.ProductID
GROUP BY c.CategoryName
ORDER BY TotalCategoryRevenue DESC
LIMIT 5;

-- Top Products by Revenue
SELECT p.ProductName, c.CategoryName,
 ROUND(SUM(od.Revenue), 2) AS TotalProductRevenue
FROM products p
JOIN order_details od ON p.ProductID = od.ProductID
JOIN categories c ON p.CategoryID = c.CategoryID
GROUP BY p.ProductName, c.CategoryName
ORDER BY TotalProductRevenue DESC
LIMIT 10;

-- Correlation between Orders and Customer Location
SELECT o.ShipCountry,
 COUNT(DISTINCT o.OrderID) AS NumberOfOrders,
 ROUND(SUM(od.Revenue), 2) AS TotalRevenue,
 ROUND(SUM(od.Revenue) / COUNT(DISTINCT o.OrderID), 2) AS AvgOrderValue
FROM orders o
JOIN order_details od ON o.OrderID = od.OrderID
GROUP BY o.ShipCountry
ORDER BY TotalRevenue DESC
LIMIT 10;

-- Correlation between Orders and Product Category

SELECT c.CategoryName,
 ROUND(SUM(od.Revenue), 2) AS TotalRevenue,
 COUNT(DISTINCT od.OrderID) AS NumberOfOrders,
 SUM(od.Quantity) AS TotalItemsSold,
 ROUND(CAST(SUM(od.Quantity) AS REAL) / COUNT(DISTINCT od.OrderID), 2) AS AvgItemsPerOrder
FROM categories c
JOIN products p ON c.CategoryID = p.CategoryID
JOIN order_details od ON p.ProductID = od.ProductID
GROUP BY c.CategoryName
ORDER BY TotalRevenue DESC;


/* 5. How frequently do different customer segments place orders? */
WITH CustomerSegments AS (
    -- Step 1: Find the preferred category for each customer
    SELECT
        o.CustomerID,
        c.CategoryName AS PreferredCategory,
        ROW_NUMBER() OVER(PARTITION BY o.CustomerID ORDER BY SUM(od.Revenue) DESC) as CategoryRank
    FROM
        orders AS o
    JOIN
        order_details AS od ON o.OrderID = od.OrderID
    JOIN
        products AS p ON od.ProductID = p.ProductID
    JOIN
        categories AS c ON p.CategoryID = c.CategoryID
    GROUP BY
        o.CustomerID, c.CategoryName
),
AvgCustomerFrequency AS (
    -- Step 2 & 3: Calculate the average time between orders for each customer
    SELECT
        CustomerID,
        AVG(DATEDIFF(ConvertedOrderDate, PreviousOrderDate)) AS AvgDaysBetweenOrders
    FROM (
        SELECT
            CustomerID,
            STR_TO_DATE(OrderDate, '%Y-%m-%d') AS ConvertedOrderDate,
            LAG(STR_TO_DATE(OrderDate, '%Y-%m-%d'), 1) OVER (PARTITION BY CustomerID ORDER BY STR_TO_DATE(OrderDate, '%Y-%m-%d')) AS PreviousOrderDate
        FROM
            orders
    ) AS OrderGaps
    WHERE
        PreviousOrderDate IS NOT NULL
    GROUP BY
        CustomerID
)
-- Step 4: Combine segments with frequency data and aggregate
SELECT
    cs.PreferredCategory,
    COUNT(DISTINCT acf.CustomerID) AS NumberOfCustomersInSegment,
    ROUND(AVG(acf.AvgDaysBetweenOrders), 1) AS AvgFrequencyInDays
FROM
    AvgCustomerFrequency AS acf
JOIN
    CustomerSegments AS cs ON acf.CustomerID = cs.CustomerID
WHERE
    cs.CategoryRank = 1
GROUP BY
    cs.PreferredCategory
ORDER BY
    AvgFrequencyInDays ASC;


/* 6.What is the geographic and title-wise distribution of employees? */

-- Geographic Distribution of Employees
SELECT Country, City, COUNT(EmployeeID) AS NumberOfEmployees
FROM employees
GROUP BY Country, City
ORDER BY NumberOfEmployees DESC;

-- Title-wise Distribution of Employees
SELECT Title, COUNT(EmployeeID) AS NumberOfEmployees
FROM employees
GROUP BY Title
ORDER BY NumberOfEmployees DESC;


/* 7.What trends can we observe in hire dates across employee titles? */
SELECT
    YEAR(STR_TO_DATE(HireDate, '%Y-%m-%d')) AS HireYear,
    Title,
    COUNT(EmployeeID) AS NumberOfHires
FROM employees
GROUP BY YEAR(STR_TO_DATE(HireDate, '%Y-%m-%d')), Title
ORDER BY HireYear, Title;

/* 8.What patterns exist in employee title and courtesy title distributions */

SELECT
    Title,
    TitleOfCourtesy,
    COUNT(EmployeeID) AS NumberOfEmployees
FROM employees
GROUP BY Title, TitleOfCourtesy
ORDER BY NumberOfEmployees DESC;

/* 9. Are there correlations between product pricing, stock levels, and sales performance?*/
SELECT
    p.ProductName,
    p.UnitPrice,
    p.UnitsInStock,
    SUM(od.Quantity) AS TotalQuantitySold,
    ROUND(SUM(od.Revenue), 2) AS TotalRevenue
FROM products p
JOIN order_details od ON p.ProductID = od.ProductID
GROUP BY p.ProductName, p.UnitPrice, p.UnitsInStock
ORDER BY TotalRevenue DESC;


/* 10.How does product demand change over months or seasons? */

SELECT MONTH(STR_TO_DATE(o.OrderDate, '%Y-%m-%d')) AS OrderMonth,
 ROUND(SUM(od.Revenue), 2) AS TotalMonthlyRevenue
FROM orders o
JOIN order_details od ON o.OrderID = od.OrderID
GROUP BY OrderMonth
ORDER BY OrderMonth;


/* 11.Can we identify anomalies in product sales or revenue performance? */

WITH ProductSalesWithStats AS (
    SELECT
        od.OrderID,
        p.ProductName,
        od.Revenue,
        -- Calculate the average revenue for this product across all orders
        AVG(od.Revenue) OVER (PARTITION BY p.ProductName) AS AvgProductRevenue
    FROM
        products p
    JOIN
        order_details od ON p.ProductID = od.ProductID
)
SELECT
    OrderID,
    ProductName,
    ROUND(Revenue, 2) AS SaleRevenue,
    ROUND(AvgProductRevenue, 2) AS AvgProductRevenue,
    -- Calculate how much this sale deviates from the average
    ROUND(Revenue / AvgProductRevenue, 2) AS DeviationRatio
FROM ProductSalesWithStats
WHERE
    -- Define an anomaly as a sale that is 5x larger or less than 20% of the average
 (Revenue / AvgProductRevenue > 5 OR Revenue / AvgProductRevenue < 0.2)
ORDER BY
    DeviationRatio DESC;


-- 12. Are there any regional trends in supplier distribution and pricing? 

-- Regional Trends in Supplier Distribution 
SELECT
    Country,
    COUNT(SupplierID) AS NumberOfSuppliers
FROM
    suppliers
GROUP BY
    Country
ORDER BY
    NumberOfSuppliers DESC;

-- Regional Trends in Supplier Pricing
SELECT
    s.Country,
    ROUND(AVG(p.UnitPrice), 2) AS AverageProductPrice
FROM
    suppliers s
JOIN
    products p ON s.SupplierID = p.SupplierID
GROUP BY
    s.Country
ORDER BY
    AverageProductPrice DESC;

-- 13. How are suppliers distributed across different product categories?

SELECT
    c.CategoryName,
    s.CompanyName AS SupplierName,
    COUNT(p.ProductID) AS NumberOfProductsSupplied
FROM
    suppliers s
JOIN
    products p ON s.SupplierID = p.SupplierID
JOIN
    categories c ON p.CategoryID = c.CategoryID
GROUP BY
    c.CategoryName, s.CompanyName
ORDER BY
    c.CategoryName, NumberOfProductsSupplied DESC;

-- 14. How do supplier pricing and categories relate across different regions?

SELECT
    s.Country,
    c.CategoryName,
    COUNT(p.ProductID) AS NumberOfProducts,
    ROUND(AVG(p.UnitPrice), 2) AS AveragePriceInCategory
FROM
    suppliers s
JOIN
    products p ON s.SupplierID = p.SupplierID
JOIN
    categories c ON p.CategoryID = c.CategoryID
GROUP BY
    s.Country, c.CategoryName
ORDER BY
    s.Country, NumberOfProducts DESC;

-- Q 15. RFM ANALYSIS (Recency,Frequency, Monetary) for Customers 
WITH rfm_values AS (
    SELECT
        o.CustomerID,
        DATEDIFF((SELECT MAX(STR_TO_DATE(OrderDate, '%Y-%m-%d')) FROM orders), MAX(STR_TO_DATE(o.OrderDate, '%Y-%m-%d'))) AS Recency,
        COUNT(DISTINCT o.OrderID) AS Frequency,
        SUM(od.Revenue) AS Monetary
    FROM
        orders o
    JOIN
        order_details od ON o.OrderID = od.OrderID
    GROUP BY
        o.CustomerID
),
rfm_scores AS (
    SELECT
        CustomerID,
        Recency,
        Frequency,
        Monetary,
        NTILE(4) OVER (ORDER BY Recency DESC) AS R_Score, -- Higher score for smaller recency
        NTILE(4) OVER (ORDER BY Frequency ASC) AS F_Score, -- Higher score for higher frequency
        NTILE(4) OVER (ORDER BY Monetary ASC) AS M_Score   -- Higher score for higher monetary
    FROM
        rfm_values
)
SELECT
    CustomerID,
    Recency,
    Frequency,
    ROUND(Monetary, 2) AS Monetary,
    R_Score,
    F_Score,
    M_Score,
    CONCAT(R_Score, F_Score, M_Score) AS RFM_Segment
FROM
    rfm_scores
ORDER BY
    RFM_Segment DESC;







CREATE DATABASE sales_analysis_project;
USE sales_analysis_project;

select * from categories;
select * from customers;
select * from products;
select * from shippers;
select * from suppliers;
select * from employees;
select * from order_details;
select * from orderss;


WITH customer_orders AS (
    SELECT CustomerID, COUNT(OrderID) AS order_count
    FROM orderss
    GROUP BY CustomerID
)
SELECT AVG(order_count) AS Avg_orders_per_customer
FROM customer_orders;

select CustomerID, count(o.OrderID) order_count, round(sum(total_price), 2) amount_spend
from orders o
join orderdetails od
   on o.OrderID = od.OrderID
group by CustomerID
having count(o.OrderID) > 2
   and sum(total_price) > 10000
limit 1000;


SELECT cu.country, cu.contacttitle,
COUNT(DISTINCT o.customerid) AS customers,
ROUND(SUM(od.total_sales), 2) AS total_sales
FROM customers cu
JOIN orders o ON cu.customerid = o.customerid
JOIN order_details od ON o.orderid = od.orderid
GROUP BY cu.country, cu.contacttitle
ORDER BY customers;










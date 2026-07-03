CREATE DATABASE financial_transactions_db;


-- Revenue by Product(Completed only)
SELECT 
    Product_Name,
    COUNT(*) AS Total_Transactions,
    ROUND(SUM(Price * Quantity), 2) AS Total_Revenue
FROM financial_transactions
WHERE Transaction_Status = 'Completed'
GROUP BY Product_Name
ORDER BY Total_Revenue DESC;


-- Revenue by Payment Method
SELECT 
    Payment_Method,
    COUNT(*) AS Total_Transactions,
    ROUND(SUM(Price * Quantity), 2) AS Total_Revenue
FROM financial_transactions
WHERE Transaction_Status = 'Completed'
GROUP BY Payment_Method
ORDER BY Total_Revenue DESC;


-- Transaction Status Breakdown
SELECT 
    Transaction_Status,
    COUNT(*) AS Count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS Percentage
FROM financial_transactions
GROUP BY Transaction_Status;


-- Monthly Trend
SELECT 
    DATE_FORMAT(Transaction_Date, '%Y-%m') AS Month,
    COUNT(*) AS Transactions,
    ROUND(SUM(Price * Quantity), 2) AS Revenue
FROM financial_transactions
WHERE Transaction_Status = 'Completed' AND Transaction_Date IS NOT NULL
GROUP BY Month
ORDER BY Month;
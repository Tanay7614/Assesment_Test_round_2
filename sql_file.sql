-- a. sql_hr schema:
-- -1. Write a query to find the office with highest salary payout

SELECT e.first_name,o.office_id, o.address, o.city, o.state-- , SUM(e.salary) AS total_salary_payout
FROM employees e
JOIN offices o ON e.office_id = o.office_id
GROUP BY o.office_id
ORDER BY total_salary_payout DESC
LIMIT 1;
------------------------------------------------------------------------

-- 2.- Within each office, rank top 3 employees with highest salary in a single query
WITH RankedEmployees AS (
    SELECT office_id, employee_id, first_name, last_name, job_title, salary,
	DENSE_RANK() OVER (PARTITION BY office_id ORDER BY salary DESC) AS salary_rank
    FROM employees
)
SELECT * FROM RankedEmployees
WHERE salary_rank <= 3;
------------------------------------------------------------------------

-- b. sql_invoicing schema:
-- 1. - Write a query to calculate the average invoice total for each client, alongside the total number of invoices they have.
SELECT 
    client_id,
    AVG(invoice_total) AS avg_invoice_total,
    COUNT(*) AS total_invoices
FROM invoices
GROUP BY client_id;
---------------------------------------------------------------------------

-- 2. - Identify the top 3 clients who have the highest invoice totals, considering only invoices within the last 3 months from the overall highest invoice data.
WITH RecentInvoices AS (
    SELECT 
        client_id,
        invoice_total,
        invoice_date
    FROM invoices
    WHERE invoice_date >= DATE_SUB((SELECT MAX(invoice_date) FROM invoices), INTERVAL 3 MONTH)
)
SELECT 
    client_id,
    SUM(invoice_total) AS total_invoice_amount
FROM RecentInvoices
GROUP BY client_id
ORDER BY total_invoice_amount DESC
limit 3;
----------------------------------------------------------
--- 3. Find the most recent invoice for each client, along with the previous invoice date and the difference in days between them.
WITH RankedInvoices AS (
    SELECT 
        client_id,
        invoice_date,
        LAG(invoice_date,1,0) OVER (PARTITION BY client_id ORDER BY invoice_date) AS prev_invoice_date
    FROM invoices
),
MostRecentInvoice AS (
    SELECT
        client_id,
        MAX(invoice_date) AS most_recent_invoice
    FROM invoices
    GROUP BY client_id
)
SELECT 
    R.client_id,
    M.most_recent_invoice,
    R.prev_invoice_date AS previous_invoice,
    DATEDIFF(M.most_recent_invoice, R.prev_invoice_date) AS days_between
FROM RankedInvoices R
JOIN MostRecentInvoice M ON R.client_id = M.client_id AND R.invoice_date = M.most_recent_invoice;
------------------------------------------------------------------------
--- 4. Determine the quartile rank of each client based on their total payments, considering both invoice and payment amounts.
WITH TotalPayments AS (
    SELECT
        c.client_id,
        COALESCE(SUM(i.invoice_total), 0) AS total_invoice_amount,
        COALESCE(SUM(p.amount), 0) AS total_payment_amount
    FROM clients c
    LEFT JOIN invoices i ON c.client_id = i.client_id
    LEFT JOIN payments p ON c.client_id = p.client_id
    GROUP BY c.client_id
)
SELECT
    client_id,
    total_invoice_amount,
    total_payment_amount,
    NTILE(4) OVER (ORDER BY total_invoice_amount + total_payment_amount) AS quartile_rank
FROM TotalPayments;
-----------------------------------------------------------------------------------------
-- 5. Write a query to flag invoices as "paid on time" or "late payment" based on the due date and payment date.
SELECT invoice_id, 
CASE 
        WHEN payment_date IS NULL THEN 'Late Payment'
        WHEN payment_date <= due_date THEN 'Paid on Time'
        ELSE 'Late Payment'
    END AS payment_status
FROM invoices;
------------------------------------------------------------------------------------
- -- 6. Create a query to categorize invoices as "high value" or "low value" based on whether the invoice total is above or below the average invoice total.
SELECT 
    invoice_id,
    CASE 
        WHEN invoice_total > (SELECT AVG(invoice_total) FROM invoices) THEN 'High Value'
        ELSE 'Low Value'
    END AS invoice_category
FROM invoices;

------------------------------------------------------------------------------------
-- c. sql_store schema:
-- 1. Calculate the total quantity of products ordered by each customer, along with their total spending:
SELECT
    o.customer_id,
    c.first_name,
    c.last_name,
    SUM(oi.quantity) AS total_quantity_ordered,
    SUM(oi.quantity * p.unit_price) AS total_spending
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN customers c ON o.customer_id = c.customer_id
JOIN products p ON oi.product_id = p.product_id
GROUP BY o.customer_id, c.first_name, c.last_name
ORDER BY total_spending DESC;

------------------------------------------------------------------------------------
-- 2. - Identify the top 5 customers who have accumulated the highest number of points.
SELECT
    customer_id,
    first_name,
    last_name,
    points
FROM customers
ORDER BY points DESC
LIMIT 5;

---------------------------------------------------------------------------------------
-- -3. Determine the month-over-month growth rate in the total quantity of products ordered.
SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS year_months,
    SUM(quantity) AS total_quantity_ordered,
    SUM(quantity) - LAG(SUM(quantity), 1, 0) OVER (ORDER BY DATE_FORMAT(order_date, '%Y-%m')) AS growth
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY year_months;

-----------------------------------------------------------------------------------------------
--- 4. Write a query to calculate the average time taken to ship orders for each shipper.
SELECT
    s.name AS shipper_name,
    AVG(DATEDIFF(shipped_date, order_date)) AS average_shipment_time
FROM orders o
JOIN shippers s ON o.shipper_id = s.shipper_id
WHERE shipped_date IS NOT NULL
GROUP BY s.name;

-----------------------------------------------------------------------------------------------
-- 5. Identify orders with unusually high or low total spending compared to the average order value.
SELECT
    order_id,
    customer_id,
    order_date,
    total_order_value,
    CASE
        WHEN total_order_value > AVG(total_order_value) OVER () * 1.5 THEN 'High Spending'
        WHEN total_order_value < AVG(total_order_value) OVER () * 0.5 THEN 'Low Spending'
        ELSE 'Normal Spending'
    END AS spending_category
FROM (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,
        SUM(oi.quantity * p.unit_price) AS total_order_value
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    GROUP BY o.order_id, o.customer_id, o.order_date
) AS order_totals;

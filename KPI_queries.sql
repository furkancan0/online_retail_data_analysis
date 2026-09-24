-- Headline

SELECT SUM(sales_amount) AS total_sales, SUM(return_amount) AS total_returns,
    SUM(sales_amount) - SUM(return_amount) AS net_sales,
    CAST(100.0 * SUM(return_amount) / SUM(sales_amount) AS DECIMAL(5,2)) AS return_rate_pct,
    COUNT(DISTINCT order_number) AS total_orders,
    CAST(SUM(sales_amount) / COUNT(DISTINCT order_number) AS DECIMAL(18,2)) AS avg_order_value
FROM vw_sales WHERE product_type = 'Product';

--Sales by month - last month is not complete yet
SELECT month_start,
    SUM(sales_amount) AS total_sales,
    SUM(return_amount)AS total_returns,
    SUM(sales_amount) - SUM(return_amount) AS net_sales,
    COUNT(DISTINCT order_number) AS total_orders,
    CAST(SUM(sales_amount) / NULLIF(COUNT(DISTINCT order_number), 0) AS DECIMAL(18,2)) AS avg_order_value
FROM vw_sales WHERE product_type = 'Product' GROUP BY month_start ORDER BY month_start;

--Top 10 products by net sales
SELECT TOP 10 stock_code, description, SUM(sales_amount) - SUM(return_amount) AS net_sales
FROM vw_sales WHERE product_type = 'Product'
GROUP BY stock_code, description ORDER BY net_sales DESC;

--Top 10 countries by net sales
SELECT TOP 10 country,
    SUM(sales_amount) - SUM(return_amount) AS net_sales,
    COUNT(DISTINCT order_number) AS total_orders
FROM vw_sales WHERE product_type = 'Product' 
GROUP BY country ORDER BY net_sales DESC;

--Registered customers vs Guests
SELECT customer_type,
    SUM(sales_amount) - SUM(return_amount) AS net_sales,
    COUNT(DISTINCT order_number) AS total_orders
FROM vw_sales WHERE product_type = 'Product' GROUP BY customer_type;

-- Repeat customers
WITH customer_orders AS (
    SELECT customer_id, COUNT(DISTINCT order_number) AS orders FROM vw_sales
    WHERE customer_type = 'Registered' AND product_type = 'Product' AND is_return = 0
    GROUP BY customer_id
)
SELECT COUNT(*) AS total_customers,
    SUM(CASE WHEN orders >= 2 THEN 1 ELSE 0 END)  AS repeat_customers,
    CAST(100.0 * SUM(CASE WHEN orders >= 2 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,1)) AS repeat_rate_pct
FROM customer_orders;


--Monthly net revenue vs previous month
WITH monthly AS (
    SELECT
        month_start,
        SUM(sales_amount) - SUM(return_amount) AS net_revenue,
        COUNT(DISTINCT order_number)           AS total_orders
    FROM vw_sales
    WHERE product_type = 'Product'
    GROUP BY month_start
)
SELECT month_start, net_revenue, total_orders,
    LAG(net_revenue) OVER (ORDER BY month_start) AS previous_month_revenue,
    CAST(100.0 * (net_revenue - LAG(net_revenue) OVER (ORDER BY month_start))
               / NULLIF(LAG(net_revenue) OVER (ORDER BY month_start), 0) AS DECIMAL(9,1)) AS growth_pct
FROM monthly ORDER BY month_start;

--Top 3 products in every country
WITH product_sales AS (
    SELECT country, stock_code, description,
        SUM(sales_amount) - SUM(return_amount) AS net_revenue
    FROM vw_sales WHERE product_type = 'Product'
    GROUP BY country, stock_code, description
),
ranked AS (
    SELECT * ,ROW_NUMBER() OVER (PARTITION BY country ORDER BY net_revenue DESC, stock_code) AS rank_in_country
    FROM product_sales
)
SELECT country, rank_in_country, stock_code, description, net_revenue
FROM ranked
WHERE rank_in_country <= 3
ORDER BY country, rank_in_country;

--Registered vs returning customers by month
WITH customer_months AS (
    SELECT customer_id, month_start,
        SUM(sales_amount) AS month_sales
    FROM vw_sales
    WHERE customer_type = 'Registered'
      AND product_type  = 'Product'
      AND is_return     = 0
    GROUP BY customer_id, month_start
),
labeled AS (
    SELECT *, MIN(month_start) OVER (PARTITION BY customer_id) AS first_month
    FROM customer_months
)
SELECT month_start,
    COUNT(CASE WHEN month_start  = first_month THEN 1 END) AS new_customers,
    COUNT(CASE WHEN month_start  > first_month THEN 1 END) AS returning_customers,
    SUM(CASE WHEN month_start    = first_month THEN month_sales ELSE 0 END) AS new_customer_sales,
    SUM(CASE WHEN month_start    > first_month THEN month_sales ELSE 0 END) AS returning_customer_sales
FROM labeled
GROUP BY month_start  ORDER BY month_start;
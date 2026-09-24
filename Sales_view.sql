--A view for shorter queries
CREATE VIEW vw_sales AS
SELECT f.invoice, CASE WHEN f.is_return = 0 THEN f.invoice END AS order_number,
    d.full_date, d.month_start, c.customer_id, c.customer_type, p.stock_code, p.description,
    p.product_type, co.country, f.quantity, f.sales_amount, f.return_amount, f.is_return
FROM fact_sales AS f
JOIN dim_date  AS d  ON d.date_key = f.date_key
JOIN dim_customer AS c  ON c.customer_key = f.customer_key
JOIN dim_product  AS p  ON p.product_key  = f.product_key
JOIN dim_country  AS co ON co.country_key = f.country_key;
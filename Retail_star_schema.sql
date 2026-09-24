DROP VIEW  IF EXISTS vw_sales;
DROP TABLE IF EXISTS fact_sales;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_customer;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_country;
 
-- Customer dimension
SELECT ROW_NUMBER() OVER (ORDER BY customer_id) AS customer_key, customer_id, customer_type
INTO dim_customer
FROM (SELECT DISTINCT customer_id, customer_type FROM cleaned_online_retail) AS x;
 
 
-- Product dimension
SELECT
    ROW_NUMBER() OVER (ORDER BY stock_code) AS product_key, stock_code,
    ISNULL(MAX(CASE WHEN description <> 'UNKNOWN' THEN description END), 'UNKNOWN') AS description,
    MAX(product_type) AS product_type
INTO dim_product FROM cleaned_online_retail
GROUP BY stock_code;
 
 
-- Date dimension
DECLARE @start_date DATE = (SELECT MIN(invoice_date) FROM cleaned_online_retail);
DECLARE @end_date   DATE = (SELECT MAX(invoice_date) FROM cleaned_online_retail);
 
WITH calendar AS (
    SELECT @start_date AS full_date
    UNION ALL
    SELECT DATEADD(DAY, 1, full_date) FROM calendar WHERE full_date < @end_date
)
SELECT ROW_NUMBER() OVER (ORDER BY full_date) AS date_key, full_date,
    YEAR(full_date) AS year_num,
    MONTH(full_date) AS month_num,
    DATENAME(MONTH, full_date) AS month_name,
    DATEFROMPARTS(YEAR(full_date), MONTH(full_date), 1) AS month_start,
    DATENAME(WEEKDAY, full_date) AS day_name
INTO dim_date
FROM calendar
OPTION (MAXRECURSION 0);
 

-- Country dimension
SELECT ROW_NUMBER() OVER (ORDER BY country) AS country_key, country
INTO dim_country
FROM (SELECT DISTINCT country FROM cleaned_online_retail) AS x;
 
-- Fact sales
SELECT ROW_NUMBER() OVER (ORDER BY r.invoice_timestamp) AS sales_key,
    r.invoice, d.date_key, c.customer_key, p.product_key, co.country_key, r.quantity, r.price AS unit_price,
    CASE WHEN r.is_return = 0 THEN CAST( r.quantity * r.price AS DECIMAL(18,2)) ELSE 0 END AS sales_amount,
    CASE WHEN r.is_return = 1 THEN CAST(-r.quantity * r.price AS DECIMAL(18,2)) ELSE 0 END AS return_amount,
    r.is_return 
    INTO fact_sales
FROM cleaned_online_retail AS r
JOIN dim_date     AS d  ON d.full_date   = r.invoice_date
JOIN dim_customer AS c  ON c.customer_id = r.customer_id
JOIN dim_product  AS p  ON p.stock_code  = r.stock_code
JOIN dim_country  AS co ON co.country    = r.country;

--Primary key
ALTER TABLE dim_customer ALTER COLUMN customer_key BIGINT NOT NULL;
ALTER TABLE dim_product  ALTER COLUMN product_key  BIGINT NOT NULL;
ALTER TABLE dim_date     ALTER COLUMN date_key     BIGINT NOT NULL;
ALTER TABLE dim_country  ALTER COLUMN country_key  BIGINT NOT NULL;
 
ALTER TABLE dim_customer ADD CONSTRAINT pk_dim_customer PRIMARY KEY (customer_key);
ALTER TABLE dim_product  ADD CONSTRAINT pk_dim_product  PRIMARY KEY (product_key);
ALTER TABLE dim_date     ADD CONSTRAINT pk_dim_date     PRIMARY KEY (date_key);
ALTER TABLE dim_country  ADD CONSTRAINT pk_dim_country  PRIMARY KEY (country_key);
 
-- Columnstore index on the fact table
CREATE CLUSTERED COLUMNSTORE INDEX cci_fact_sales ON fact_sales;
CREATE NONCLUSTERED INDEX ix_fact_sales_customer ON fact_sales (customer_key);
CREATE NONCLUSTERED INDEX ix_fact_sales_product  ON fact_sales (product_key);
CREATE NONCLUSTERED INDEX ix_fact_sales_invoice  ON fact_sales (invoice);

-- Join Check : Both numbers in each pair must be equal.
SELECT (SELECT COUNT(*) FROM cleaned_online_retail) AS source_rows,
(SELECT COUNT(*) FROM fact_sales) AS fact_rows,
(SELECT SUM(quantity * price) FROM cleaned_online_retail) AS source_amount,
(SELECT SUM(sales_amount) - SUM(return_amount) FROM fact_sales) AS fact_amount;

-- Check : Product and Non-product.
SELECT product_type, COUNT(*) AS number_of_stock_codes
FROM dim_product
GROUP BY product_type;
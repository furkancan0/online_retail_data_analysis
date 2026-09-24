WITH normalized AS (
    SELECT TRIM(Invoice) AS invoice,
        UPPER(TRIM(StockCode)) AS stock_code,
        NULLIF(TRIM(Description), '') AS description,
        Quantity AS quantity,
        InvoiceDate AS invoice_timestamp,
        CAST(InvoiceDate AS DATE) AS invoice_date,
        CAST(Price AS NUMERIC(14,4)) AS price,
        NULLIF(TRIM(Customer_ID), '') AS customer_id_raw,
        TRIM(Country) AS country
    FROM online_retail_II WHERE Price > 0
),

classified AS (
    SELECT n.invoice, n.stock_code,
        COALESCE(n.description, 'UNKNOWN') AS description,
        n.quantity, n.invoice_date, n.invoice_timestamp, n.price, n.country,

        CASE WHEN n.customer_id_raw IS NULL THEN 'GUEST-' || TRIM(n.country)
            ELSE REGEXP_REPLACE(n.customer_id_raw, '\.0$', '')
        END AS customer_id,

        CASE WHEN n.customer_id_raw IS NULL THEN 'Guest'
            ELSE 'Registered'
        END AS customer_type,

        CASE WHEN n.quantity < 0 THEN 1
            ELSE 0
        END AS is_return,

        CASE WHEN LEFT(n.stock_code, 5) NOT LIKE '%[^0-9]%'
             AND LEN(LEFT(n.stock_code, 5)) = 5 THEN 'Product'
            ELSE 'Non-product'
        END AS product_type

    FROM normalized n
),

deduplicated AS (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY invoice, stock_code, description,
                quantity, invoice_timestamp, price, customer_id, country
        ORDER BY invoice_timestamp) AS rn FROM classified 
)

SELECT invoice, stock_code, description, quantity, invoice_date, invoice_timestamp,
    price, customer_id, country, customer_type, is_return,
    product_type INTO cleaned_online_retail
FROM deduplicated
WHERE rn = 1;

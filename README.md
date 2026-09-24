# online_retail_data_analysis  

Dataset:  
https://www.kaggle.com/datasets/mashlyn/online-retail-ii-uci  

Run order:
1) Clean the data — run Cleaned_online_retail.sql against the raw online_retail_II table. Produces cleaned_online_retail.  
2) Build the schema — run retail_star_schema_simple.sql top to bottom.  
Produces dim_customer, dim_product, dim_date, dim_country, fact_sales, the vw_sales view.
3) Build Sales_view and run KPI_queries   


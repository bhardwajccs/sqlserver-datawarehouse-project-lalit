/*

GOLD Layer

*/

-- Gold Layer Business Logics like
-- 1 Data Integration -- like Gender Unification
-- 2 User Friendly names to Columns
-- 3 Sorting Columns into logical groups to improve readability -- what column to display where
-- 4 Deciding table as dim / fact table -- But dim tables need PK wheich we can give as SURROGATE Key is missing from Source data.
		-- SK is system genertaed unique identifier assigned to each record.
		-- Using IDENTIY Col
		-- Uisng ROW_NUMBER WIndows functions

-- Final Solution
-- Customer's Data

Create OR Alter View Gold.dim_customers 
AS
	Select
		ROW_NUMBER() OVER(ORDER BY cst_id) AS customer_key, -- SURROGATE KEY
		ci.cst_id AS customer_id,
		ci.cst_key AS customer_number,		ci.cst_firstname AS first_name,
		ci.cst_lastname AS last_name,
		la.cntry AS country,
		ci.cst_marital_status AS marital_status,
		-- ci.cst_gndr,
		CASE
			WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr -- CRM data is Master for Gender Info
			ELSE COALESCE(ca.gen, 'n/a')
		END AS gender,
		ca.bdate AS birth_date,
		ci.cst_create_date AS create_date
		-- ca.gen,
	from Silver.crm_cust_info AS ci
	LEFT JOIN Silver.erp_cust_az12 AS ca
	ON ci.cst_key = ca.cid
	LEFT JOIN Silver.erp_loc_a101 la
	ON ci.cst_key = la.cid

-- TEST
Select * from Gold.dim_customers
		
	-- Data Integration -- GENDER


-- We get Two genders from CRM and ERP Data
-- Check Issues in Gender Values-- Like Male, Female -- PROBLEM
-- Consider MASTER Data here CRM Gender Values

-- TEST Query

	Select	
		ci.cst_gndr,
		ca.gen,
		CASE
			WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr -- CRM data is Master for Gender Info
			ELSE COALESCE(ca.gen, 'n/a')
		END AS New_gen 
	from Silver.crm_cust_info AS ci
	LEFT JOIN Silver.erp_cust_az12 AS ca
		ON ci.cst_key = ca.cid
	LEFT JOIN Silver.erp_loc_a101 la
		ON ci.cst_key = la.cid
	Order By 1,2



-- 2 All Products Info from two source system

-- Reorder Columns
-- Good Names to columns -- Snake notation -- lowercase w underscore
-- Filter only Current Products
-- dim / fact and give SK if dim
-- make as View in Gold Layer

GO
CREATE VIEW Gold.dim_products AS
	Select 
		ROW_NUMBER() OVER(ORDER BY prd_start_dt, prd_key) AS product_key, -- Surrogate Key
		pn.prd_id AS product_id,
		pn.prd_key AS product_number,
		pn.prd_nm AS product_name,
		pn.cat_id AS category_id,
		pc.cat AS category,
		pc.subcat AS subcategory,
		pc.maintenance,
		pn.prd_cost AS product_cost,
		pn.prd_line AS product_line,
		pn.prd_start_dt AS start_date
	
	from Silver.crm_prd_info AS pn
	LEFT JOIN Silver.erp_px_cat_g1v2 AS pc
		ON pn.cat_id = pc.id
	where prd_end_dt IS NULL -- Select only Current products -- No Historical Info

-- TEST

Select * from Gold.dim_products

-- After Joing Tables in Gold Layer
-- check Uniqueness of Records

Select T.prd_key, COUNT(*) FROM
(
	Select 
		pn.prd_id,
		pn.cat_id,
		pn.prd_key,
		pn.prd_nm,
		pn.prd_cost,
		pn.prd_line,
		pn.prd_start_dt,
		pc.cat,
		pc.subcat,
		pc.maintenance
	from Silver.crm_prd_info AS pn
	LEFT JOIN Silver.erp_px_cat_g1v2 AS pc
		ON pn.cat_id = pc.id
	where prd_end_dt IS NULL -- Select only Current products -- No Historical Info
) T
Group By prd_key
Having COUNT(*) > 1


-- fact_Sales
-- If table has lots of metrics, keys, dates columns -- Fact table
-- Use dim "Surrogate Keys" rather than keys to connect w fact tabvles
		-- So for that Join those Dimensions in gold w fact tables -- called " Data LOOKUP "

GO
CREATE OR ALTER VIEW gold.fact_sales AS
	SELECT
		sd.sls_ord_num  AS order_number,
		pr.product_key  AS product_key,    -- Surrogate Key
		cu.customer_key AS customer_key,   -- SK
		sd.sls_order_dt AS order_date,
		sd.sls_ship_dt  AS shipping_date,
		sd.sls_due_dt   AS due_date,
		sd.sls_sales    AS sales_amount,
		sd.sls_quantity AS quantity,
		sd.sls_price    AS price
	FROM silver.crm_sales_details sd
	LEFT JOIN gold.dim_products pr
		ON sd.sls_prd_key = pr.product_number
	LEFT JOIN gold.dim_customers cu
		ON sd.sls_cust_id = cu.customer_id;
	GO

Select * from gold.fact_sales

-- imp checks
-- Check if all dim tables successfully joins to fact table.
-- FK integrity -- dimensions

Select * 
from	Gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
LEFT JOIN Gold.dim_customers c
ON f.customer_key = c.customer_key
where p.product_key IS NULL


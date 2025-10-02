/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.
		
Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC Silver.load_silver;
===============================================================================
*/

CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
DECLARE
    batch_start_time TIMESTAMP;
    batch_end_time   TIMESTAMP;
    start_time       TIMESTAMP;
    end_time         TIMESTAMP;
BEGIN
    -- Track overall batch start time
    batch_start_time := clock_timestamp();

    RAISE NOTICE '============================================';
    RAISE NOTICE 'Loading Silver Layer';
    RAISE NOTICE '============================================';

    -------------------------------------------------------------------
    -- CRM TABLES
    -------------------------------------------------------------------

    RAISE NOTICE '============================================';
    RAISE NOTICE 'Loading CRM Tables';
    RAISE NOTICE '============================================';

    -- ===================== CRM CUSTOMER =====================

    start_time := clock_timestamp();
    RAISE NOTICE 'Truncating Table: silver.crm_cust_info';
    TRUNCATE TABLE silver.crm_cust_info;    

    RAISE NOTICE 'Copying Data Into: silver.crm_cust_info';

    INSERT INTO silver.crm_cust_info (
        cst_id,
        cst_key,
        cst_firstname,
        cst_lastname,
        cst_marital_status,
        cst_gndr,
        cst_create_date
    )
    SELECT
        CAST(cst_id AS INTEGER),
        CAST(cst_key AS VARCHAR(128)),
        TRIM(cst_firstname),
        TRIM(cst_lastname),
        CASE 
            WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
            WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
            ELSE 'N/A'
        END AS cst_marital_status,
        CASE 
            WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
            WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
            ELSE 'N/A'
        END AS cst_gndr,
        CAST(cst_create_date AS DATE) -- Normalize creation date
    FROM (
        SELECT *,
               ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS rnk
        FROM bronze.crm_cust_info
    ) sub
    WHERE rnk = 1;  -- Keep only latest record per customer

    end_time := clock_timestamp();
    RAISE NOTICE 'Load Duration (CRM Customer): % Seconds', EXTRACT(EPOCH FROM (end_time - start_time));


    -- ===================== CRM PRODUCT =====================

    start_time := clock_timestamp();
    RAISE NOTICE 'Truncating Table: silver.crm_prd_info';
    TRUNCATE TABLE silver.crm_prd_info;    

    RAISE NOTICE 'Copying Data Into: silver.crm_prd_info';

    INSERT INTO silver.crm_prd_info (
        prd_id,
        prd_key,
        cat_id,
        prd_nm,
        prd_cost,
        prd_line,
        prd_start_dt,
        prd_end_dt
    )
    SELECT
        CAST(prd_id AS INTEGER),
        CAST(SUBSTRING(prd_key,7,LENGTH(prd_key)) AS VARCHAR(128)) AS prd_key,  -- Extract product key
        CAST(REPLACE(SUBSTRING(prd_key,1,5),'-','_') AS VARCHAR(128)) AS cat_id, -- Extract category ID
        prd_nm,
        COALESCE(prd_cost,0) AS prd_cost,
        CASE TRIM(UPPER(prd_line))
            WHEN 'M' THEN 'Mountain'
            WHEN 'R' THEN 'Road'
            WHEN 'S' THEN 'Other Sales'
            WHEN 'T' THEN 'Touring'
            ELSE 'N/A'
        END AS prd_line,
        CAST(prd_start_dt AS DATE) AS prd_start_dt,
        CAST(
            LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt) - INTERVAL '1 day'
            AS DATE
        ) AS prd_end_dt -- End date is one day before next start date
    FROM bronze.crm_prd_info;

    end_time := clock_timestamp();
    RAISE NOTICE 'Load Duration (CRM Product): % Seconds', EXTRACT(EPOCH FROM (end_time - start_time));


    -- ===================== CRM SALES =====================

    start_time := clock_timestamp();
    RAISE NOTICE 'Truncating Table: silver.crm_sales_details';
    TRUNCATE TABLE silver.crm_sales_details;    

    RAISE NOTICE 'Copying Data Into: silver.crm_sales_details';

    INSERT INTO silver.crm_sales_details (
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        sls_order_dt,
        sls_ship_dt,
        sls_due_dt,
        sls_sales,
        sls_quantity,
        sls_price
    )
    SELECT
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        CASE WHEN sls_order_dt = 0 OR LENGTH(sls_order_dt::TEXT) != 8 THEN NULL
             ELSE TO_DATE(sls_order_dt::TEXT,'YYYYMMDD')
        END,
        CASE WHEN sls_ship_dt = 0 OR LENGTH(sls_ship_dt::TEXT) != 8 THEN NULL
             ELSE TO_DATE(sls_ship_dt::TEXT,'YYYYMMDD')
        END,
        CASE WHEN sls_due_dt = 0 OR LENGTH(sls_due_dt::TEXT) != 8 THEN NULL
             ELSE TO_DATE(sls_due_dt::TEXT,'YYYYMMDD')
        END,
        CASE WHEN sls_sales IS NULL OR sls_sales <= 0 
                  OR sls_sales != (sls_quantity * ABS(sls_price))
             THEN (sls_quantity * ABS(sls_price))
             ELSE sls_sales
        END AS sls_sales, -- Fix missing or incorrect sales
        sls_quantity,
        CASE WHEN sls_price IS NULL OR sls_price <= 0
             THEN (sls_sales/NULLIF(sls_quantity,0))
             ELSE sls_price
        END AS sls_price -- Derive price if invalid
    FROM bronze.crm_sales_details;

    end_time := clock_timestamp();
    RAISE NOTICE 'Load Duration (CRM Sales): % Seconds', EXTRACT(EPOCH FROM (end_time - start_time));


    -------------------------------------------------------------------
    -- ERP TABLES
    -------------------------------------------------------------------

    RAISE NOTICE '============================================';
    RAISE NOTICE 'Loading ERP Tables';
    RAISE NOTICE '============================================';

    -- ===================== ERP CUSTOMER =====================
    start_time := clock_timestamp();
    RAISE NOTICE 'Truncating Table: silver.erp_cust_az12';
    TRUNCATE TABLE silver.erp_cust_az12;    

    RAISE NOTICE 'Copying Data Into: silver.erp_cust_az12';

    INSERT INTO silver.erp_cust_az12 (
        cid,
        bdate,
        gen
    )
    SELECT 
        CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,LENGTH(cid))
             ELSE cid
        END AS cid,
        CASE WHEN bdate > CURRENT_DATE THEN NULL
             ELSE bdate
        END AS bdate, -- Remove future birthdates
        CASE
            WHEN TRIM(UPPER(gen)) IN ('F','FEMALE') THEN 'Female'
            WHEN TRIM(UPPER(gen)) IN ('M','MALE')   THEN 'Male'
            ELSE 'N/A'
        END AS gen
    FROM bronze.erp_cust_az12;

    end_time := clock_timestamp();
    RAISE NOTICE 'Load Duration (ERP Customer): % Seconds', EXTRACT(EPOCH FROM (end_time - start_time));


    -- ===================== ERP LOCATION =====================

    start_time := clock_timestamp();
    RAISE NOTICE 'Truncating Table: silver.erp_loc_a101';
    TRUNCATE TABLE silver.erp_loc_a101;    

    RAISE NOTICE 'Copying Data Into: silver.erp_loc_a101';

    INSERT INTO silver.erp_loc_a101 (
        cid,
        cntry
    )
    SELECT 
        REPLACE(cid,'-','') AS cid,
        CASE
            WHEN TRIM(cntry) IN ('US','USA') THEN 'United States'
            WHEN TRIM(cntry) = 'DE'          THEN 'Germany'
            WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'N/A'
            ELSE cntry
        END AS cntry -- Normalize country codes
    FROM bronze.erp_loc_a101;

    end_time := clock_timestamp();
    RAISE NOTICE 'Load Duration (ERP Location): % Seconds', EXTRACT(EPOCH FROM (end_time - start_time));


    -- ===================== ERP PRODUCT CATEGORY =====================

    start_time := clock_timestamp();
    RAISE NOTICE 'Truncating Table: silver.erp_px_cat_g1v2';
    TRUNCATE TABLE silver.erp_px_cat_g1v2;    

    RAISE NOTICE 'Copying Data Into: silver.erp_px_cat_g1v2';

    INSERT INTO silver.erp_px_cat_g1v2 (
        id,
        cat,
        subcat,
        maintenance
    )
    SELECT id, cat, subcat, maintenance
    FROM bronze.erp_px_cat_g1v2;

    end_time := clock_timestamp();
    RAISE NOTICE 'Load Duration (ERP Product Category): % Seconds', EXTRACT(EPOCH FROM (end_time - start_time));

    -------------------------------------------------------------------
    -- Batch End
    -------------------------------------------------------------------

    batch_end_time := clock_timestamp();
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Silver Layer Load Completed in % Seconds',
                 EXTRACT(EPOCH FROM (batch_end_time - batch_start_time));
    RAISE NOTICE '============================================';

EXCEPTION
	WHEN OTHERS THEN
	RAISE NOTICE '==========================================';
	RAISE NOTICE 'ERROR OCCURED DURING LOADING SILVER LAYER';
	RAISE NOTICE 'Error Message: %',SQLERRM; --Error Text 
	RAISE NOTICE 'Error Message: %',SQLSTATE; --SQLSTATE code
	RAISE NOTICE '==========================================';
END;
$$;

CALL silver.load_silver();


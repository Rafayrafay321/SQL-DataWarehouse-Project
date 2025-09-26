/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'bronze' schema from external CSV files. 
    It performs the following actions:
    - Truncates the bronze tables before loading data.
    - Uses the `COPY (Postgres)` command to load data in bulk from csv Files to bronze tables.

Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    CALL bronze.load_bronze;
===============================================================================
*/
CREATE OR REPLACE PROCEDURE bronze.load_bronze()
LANGUAGE plpgsql
AS $$
DECLARE
	batch_start_time TIMESTAMP;
	batch_end_time TIMESTAMP;
	start_time TIMESTAMP;
	end_time TIMESTAMP;
BEGIN
	batch_start_time := clock_timestamp();
	RAISE NOTICE '==============================================';
	RAISE NOTICE 'Loading Bronze layer';
	RAISE NOTICE '==============================================';

	RAISE NOTICE '----------------------------------------------';
	RAISE NOTICE 'Loading CRM Tables';
	RAISE NOTICE '----------------------------------------------';

	--Load CRM Customer Info
	start_time := clock_timestamp();
	RAISE NOTICE '>> Truncating Table: bronze.crm_cust_info';
	TRUNCATE TABLE bronze.crm_cust_info;

	RAISE NOTICE '>> Copying Data Into: bronze.crm_cust_info';
	EXECUTE format(
		'COPY bronze.crm_cust_info FROM %L CSV HEADER',
		'C:\SQL-warehouse-dataset\source_crm\cust_info.csv'
	);
	
	end_time := clock_timestamp();
	RAISE NOTICE '>> Load Duration: % Seconds',
		EXTRACT(EPOCH FROM (end_time - start_time));
	RAISE NOTICE '>> ----------------------';
	
	-- CRM Product Info
	start_time := clock_timestamp();
	RAISE NOTICE '>> Truncating Table: bronze.crm_prd_info';
	TRUNCATE TABLE bronze.crm_prd_info;

	RAISE NOTICE '>> Copying Data Into: bronze.crm_prd_info';
	EXECUTE format(
		'COPY bronze.crm_prd_info FROM %L CSV HEADER',
		'C:/SQL-warehouse-dataset/source_crm/prd_info.csv'
	);
	
	end_time := clock_timestamp();
	RAISE NOTICE '>> Load Duration: % Seconds',
		EXTRACT(EPOCH FROM (end_time - start_time));
	RAISE NOTICE '>> ----------------------';

	-- CRM Sales Details
	start_time := clock_timestamp();
	RAISE NOTICE '>> Truncating Table: bronze.crm_sales_details';
	TRUNCATE TABLE bronze.crm_sales_details;

	RAISE NOTICE '>> Copying Data Into: bronze.crm_sales_details';
	EXECUTE format(
		'COPY bronze.crm_sales_details FROM %L CSV HEADER',
		'C:/SQL-warehouse-dataset/source_crm/sales_details.csv'
	);
	
	end_time := clock_timestamp();
	RAISE NOTICE '>> Load Duration: % Seconds',
		EXTRACT(EPOCH FROM (end_time - start_time));
	RAISE NOTICE '>> ----------------------';

	RAISE NOTICE '----------------------------------------------';
	RAISE NOTICE 'Loading ERP Tables';
	RAISE NOTICE '----------------------------------------------';

	-- ERP Customer
	start_time := clock_timestamp();
	RAISE NOTICE '>> Truncating Table: bronze.erp_cust_az12';
	TRUNCATE TABLE bronze.erp_cust_az12;

	RAISE NOTICE '>> Copying Data Into: bronze.erp_cust_az12';
	EXECUTE format(
		'COPY bronze.erp_cust_az12 FROM %L CSV HEADER',
		'C:/SQL-warehouse-dataset/source_erp/cust_az12.csv'
	);
	
	end_time := clock_timestamp();
	RAISE NOTICE '>> Load Duration: % Seconds',
		EXTRACT(EPOCH FROM (end_time - start_time));
	RAISE NOTICE '>> ----------------------';

	-- ERP Location
	start_time := clock_timestamp();
	RAISE NOTICE '>> Truncating Table: bronze.erp_loc_a101';
	TRUNCATE TABLE bronze.erp_loc_a101;

	RAISE NOTICE '>> Copying Data Into: bronze.erp_loc_a101';
	EXECUTE format(
		'COPY bronze.erp_loc_a101 FROM %L CSV HEADER',
		'C:/SQL-warehouse-dataset/source_erp/loc_a101.csv'
	);
	
	end_time := clock_timestamp();
	RAISE NOTICE '>> Load Duration: % Seconds',
		EXTRACT(EPOCH FROM (end_time - start_time));
	RAISE NOTICE '>> ----------------------';

	-- ERP Price Category
	start_time := clock_timestamp();
	RAISE NOTICE '>> Truncating Table: bronze.erp_px_cat_g1v2';
	TRUNCATE TABLE bronze.erp_px_cat_g1v2;

	RAISE NOTICE '>> Copying Data Into: bronze.erp_px_cat_g1v2';
	EXECUTE format(
		'COPY bronze.erp_px_cat_g1v2 FROM %L CSV HEADER',
		'C:/SQL-warehouse-dataset/source_erp/px_cat_g1v2.csv'
	);
	
	end_time := clock_timestamp();
	RAISE NOTICE '>> Load Duration: % Seconds',
		EXTRACT(EPOCH FROM (end_time - start_time));
	RAISE NOTICE '>> ----------------------';
	 
	 batch_end_time := clock_timestamp();
	 RAISE NOTICE '==========================================';
     RAISE NOTICE 'Loading Bronze Layer is Completed';
     RAISE NOTICE '   - Total Load Duration: % seconds',
     	EXTRACT(EPOCH FROM (batch_end_time - batch_start_time));
     RAISE NOTICE '==========================================';

EXCEPTION
	WHEN OTHERS THEN
	 	RAISE NOTICE '================================================';
     	RAISE NOTICE 'ERROR OCCURRED DURING LOADING BRONZE LAYER';
     	RAISE NOTICE 'Error Message: %', SQLERRM;
     	RAISE NOTICE 'Error State: %', SQLSTATE;
     	RAISE NOTICE '================================================';
END;
$$;

-- Run the procedure
CALL bronze.load_bronze();

-- =====================================================
-- VERIFICATION: Database Tab CSV Generation
-- =====================================================
-- This script verifies that the database_tab CSV file
-- is being generated correctly and contains the right data
-- =====================================================

USE ROLE fdd_admin_role;
USE DATABASE hl_fdd_poc;
USE SCHEMA fdd_schema;
USE WAREHOUSE fdd_wh;

SELECT '=== STEP 1: Check if database_tab view has data ===' AS status;

-- Check the pivoted view
SELECT COUNT(*) AS row_count,
       MIN(deal_id) AS deal_id,
       COUNT(DISTINCT account_number) AS account_count
FROM v_database_tab_pivoted
WHERE deal_id = 'DEAL_HL_001';

SELECT '=== STEP 2: Sample data from database_tab view ===' AS status;

-- Show first 5 rows
SELECT deal_id, account_number, account_name, 
       period_01_label, period_01,
       period_02_label, period_02,
       period_03_label, period_03
FROM v_database_tab_pivoted
WHERE deal_id = 'DEAL_HL_001'
LIMIT 5;

SELECT '=== STEP 3: Check audit log for export_database_tab ===' AS status;

-- Check if export_database_tab was called and succeeded
SELECT 
    procedure_name,
    deal_id,
    status,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    duration_seconds,
    rows_affected,
    message,
    error_message
FROM audit_log
WHERE procedure_name = 'export_database_tab'
ORDER BY start_time DESC
LIMIT 5;

SELECT '=== STEP 4: List all files in output stage ===' AS status;

-- List ALL files in the output stage
LIST @fdd_output_stage;

SELECT '=== STEP 5: Try to manually export database_tab ===' AS status;

-- Manually call the export procedure
CALL export_database_tab('DEAL_HL_001');

SELECT '=== STEP 6: List files again to see if database_tab was created ===' AS status;

LIST @fdd_output_stage;

SELECT '=== STEP 7: Check the new file ===' AS status;

-- If the file exists, let's check its size
SELECT 
    "name",
    "size",
    TO_CHAR("last_modified", 'YYYY-MM-DD HH24:MI:SS') AS last_modified
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "name" LIKE '%database_tab%';

SELECT '=== VERIFICATION COMPLETE ===' AS status;

SELECT '
📋 ANALYSIS:

1. If v_database_tab_pivoted shows 29 rows (one per account) → ✅ VIEW IS GOOD
2. If audit_log shows export_database_tab with STATUS = ''SUCCESS'' → ✅ PROCEDURE RAN
3. If LIST shows database_tab_DEAL_HL_001.csv → ✅ FILE WAS CREATED
4. If file does NOT exist → ❌ INVESTIGATE ERROR MESSAGE

Next Steps:
-----------
A. If file exists: Download it and verify it has the right structure
B. If file missing: Check audit_log.error_message for the failure reason
C. If procedure never ran: Check why generate_fdd_schedules skipped it

Expected File Structure:
------------------------
DEAL_ID,DEAL_NAME,ENTITY,ACCOUNT_NUMBER,ACCOUNT_NAME,UNIQUE_ID,
MAPPING_LEVEL_1,MAPPING_LEVEL_2,MAPPING_LEVEL_3,STATEMENT_TYPE,
SORT_ORDER_L1,SORT_ORDER_L2,
PERIOD_01_LABEL,PERIOD_02_LABEL,...,PERIOD_24_LABEL,
PERIOD_01,PERIOD_02,...,PERIOD_24

This file should have:
- 29 rows (one per account)
- 50+ columns (metadata + 24 label columns + 24 value columns)
- Values should be ready for Excel SUMIF formulas
' AS instructions;


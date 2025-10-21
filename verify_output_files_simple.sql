-- =====================================================
-- SIMPLE VERIFICATION: Check All Output Files Exist
-- =====================================================
-- Run this in Snowsight to verify the database_tab CSV
-- and all other output files were created correctly
-- =====================================================

USE ROLE fdd_admin_role;
USE DATABASE hl_fdd_poc;
USE SCHEMA fdd_schema;
USE WAREHOUSE fdd_wh;

-- ==================================================
-- STEP 1: List all files in output stage
-- ==================================================
SELECT '=== ALL OUTPUT FILES ===' AS step;

LIST @fdd_output_stage;

-- ==================================================
-- STEP 2: Count files by type
-- ==================================================
SELECT '=== FILE COUNT BY TYPE ===' AS step;

WITH files AS (
    SELECT "name" AS file_name, "size" AS file_size
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
)
SELECT 
    CASE 
        WHEN file_name LIKE '%database_tab%' THEN 'database_tab (CRITICAL)'
        WHEN file_name LIKE '%income_statement%' THEN 'income_statement'
        WHEN file_name LIKE '%balance_sheet%' THEN 'balance_sheet'
        WHEN file_name LIKE '%ai_insights%' THEN 'ai_insights'
        ELSE 'other'
    END AS file_type,
    COUNT(*) AS file_count,
    SUM(file_size) AS total_size_bytes,
    ROUND(SUM(file_size) / 1024, 2) AS total_size_kb
FROM files
GROUP BY file_type
ORDER BY file_type;

-- ==================================================
-- STEP 3: Check database_tab view has data
-- ==================================================
SELECT '=== DATABASE_TAB VIEW CHECK ===' AS step;

SELECT 
    COUNT(*) AS total_rows,
    COUNT(DISTINCT deal_id) AS unique_deals,
    COUNT(DISTINCT account_number) AS unique_accounts,
    COUNT(DISTINCT period_01_label) AS period_01_label_count,
    MIN(period_01_label) AS first_period,
    MAX(period_24_label) AS last_period
FROM v_database_tab_pivoted
WHERE deal_id = 'DEAL_HL_001';

-- ==================================================
-- STEP 4: Sample data from database_tab view
-- ==================================================
SELECT '=== SAMPLE DATA (First 3 Accounts) ===' AS step;

SELECT 
    account_number,
    account_name,
    mapping_level_1,
    statement_type,
    period_01_label,
    ROUND(period_01, 2) AS period_01_value,
    period_02_label,
    ROUND(period_02, 2) AS period_02_value,
    period_24_label,
    ROUND(period_24, 2) AS period_24_value
FROM v_database_tab_pivoted
WHERE deal_id = 'DEAL_HL_001'
ORDER BY account_number
LIMIT 3;

-- ==================================================
-- STEP 5: Check audit log for export_database_tab
-- ==================================================
SELECT '=== EXPORT_DATABASE_TAB AUDIT LOG ===' AS step;

SELECT 
    procedure_name,
    deal_id,
    status,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    duration_seconds,
    rows_affected,
    SUBSTRING(message, 1, 100) AS message,
    SUBSTRING(error_message, 1, 100) AS error_message
FROM audit_log
WHERE procedure_name = 'export_database_tab'
ORDER BY start_time DESC
LIMIT 5;

-- ==================================================
-- STEP 6: If database_tab file is missing, try to export it
-- ==================================================
SELECT '=== MANUAL EXPORT TEST ===' AS step;

-- Check if file exists first
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ database_tab file EXISTS'
        ELSE '❌ database_tab file MISSING - Running manual export...'
    END AS file_status
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID(-5)))
WHERE "name" LIKE '%database_tab%';

-- If missing, uncomment and run this line:
-- CALL export_database_tab('DEAL_HL_001');

-- Then list files again:
-- LIST @fdd_output_stage;

-- ==================================================
-- VERIFICATION SUMMARY
-- ==================================================
SELECT '=== ✅ VERIFICATION COMPLETE ===' AS step;

SELECT '

📋 EXPECTED RESULTS:
-------------------
STEP 1: Should show 4 files (database_tab, income_statement, balance_sheet, ai_insights)
STEP 2: Should show 1 database_tab file
STEP 3: Should show 29 rows, 1 deal, 29 accounts
STEP 4: Should show 3 sample accounts with data in period_01, period_02, period_24
STEP 5: Should show export_database_tab with STATUS = ''SUCCESS''

❌ IF DATABASE_TAB FILE IS MISSING:
-----------------------------------
1. Check STEP 5 for error_message
2. Run: CALL export_database_tab(''DEAL_HL_001'');
3. Run: LIST @fdd_output_stage;
4. If still fails, share the error message

✅ IF ALL FILES EXIST:
----------------------
1. Download database_tab_DEAL_HL_001.csv from Snowsight
2. Import into Excel Database tab
3. Your Excel SUMIF formulas will then work!

📥 HOW TO DOWNLOAD FROM SNOWSIGHT:
-----------------------------------
Data → Databases → HL_FDD_POC → FDD_SCHEMA → Stages → FDD_OUTPUT_STAGE
Click on database_tab_DEAL_HL_001.csv → Download

🔍 WHAT THE EXCEL FORMULAS DO:
-------------------------------
The Excel Income Statement tab has formulas like:
  =SUMIF(Database!$E:$E, "Net Sales", Database!N:N)

This means:
- Look in the Database tab (imported from database_tab CSV)
- Find all rows where column E (account_name) = "Net Sales"  
- Sum the values in column N (period_01 values)

The Snowflake export creates the Database tab source data.
Excel SUMIF formulas consume that data to populate schedules.

' AS instructions;


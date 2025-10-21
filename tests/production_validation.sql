-- =====================================================
-- PRODUCTION VALIDATION TEST
-- =====================================================
-- Complete end-to-end validation of the FDD solution
-- Run this after deployment to verify all components work
-- =====================================================

USE DATABASE HL_FDD_POC;
USE SCHEMA TRIAL_BALANCE;
USE WAREHOUSE FDD_POC_WH;

-- =====================================================
-- PHASE 1: Environment Validation
-- =====================================================
SELECT '=== PHASE 1: Environment Validation ===' AS phase;

-- Check database and schema
SELECT CURRENT_DATABASE() AS database_name, 
       CURRENT_SCHEMA() AS schema_name,
       CURRENT_WAREHOUSE() AS warehouse_name,
       CURRENT_ROLE() AS role_name;

-- Verify all tables exist
SELECT 'Tables Check' AS validation,
       COUNT(*) AS table_count,
       CASE WHEN COUNT(*) >= 11 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'TRIAL_BALANCE'
  AND TABLE_TYPE = 'BASE TABLE';

-- Verify all views exist  
SELECT 'Views Check' AS validation,
       COUNT(*) AS view_count,
       CASE WHEN COUNT(*) >= 3 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'TRIAL_BALANCE';

-- Verify all procedures exist
SELECT 'Procedures Check' AS validation,
       COUNT(*) AS procedure_count,
       CASE WHEN COUNT(*) >= 15 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM INFORMATION_SCHEMA.PROCEDURES
WHERE PROCEDURE_SCHEMA = 'TRIAL_BALANCE';

-- Verify stages exist
SHOW STAGES;

-- =====================================================
-- PHASE 2: Data Load Validation
-- =====================================================
SELECT '=== PHASE 2: Data Load Validation ===' AS phase;

-- Clean slate for testing
TRUNCATE TABLE trial_balance_raw;
TRUNCATE TABLE account_mappings;
TRUNCATE TABLE income_statement_structure;
TRUNCATE TABLE balance_sheet_structure;
TRUNCATE TABLE ai_insights;
REMOVE @fdd_output_stage PATTERN='.*DEAL_HL_001.*';

-- Load trial balance
CALL load_trial_balance();

-- Verify trial balance loaded
SELECT 'Trial Balance Load' AS validation,
       COUNT(*) AS row_count,
       CASE WHEN COUNT(*) = 696 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM trial_balance_raw
WHERE deal_id = 'DEAL_HL_001';

-- Load account mappings
CALL load_account_mappings();

-- Verify account mappings loaded
SELECT 'Account Mappings Load' AS validation,
       COUNT(*) AS row_count,
       CASE WHEN COUNT(*) = 29 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM account_mappings
WHERE deal_id = 'DEAL_HL_001';

-- CRITICAL: Verify is_active is set correctly
SELECT 'Account Mappings is_active' AS validation,
       COUNT(*) AS active_count,
       CASE WHEN COUNT(*) = 29 THEN '✅ PASS' ELSE '❌ FAIL - DATABASE TAB WILL NOT WORK!' END AS status
FROM account_mappings
WHERE deal_id = 'DEAL_HL_001'
  AND is_active = TRUE;

-- =====================================================
-- PHASE 3: View Validation
-- =====================================================
SELECT '=== PHASE 3: View Validation ===' AS phase;

-- Test v_trial_balance_for_schedules
SELECT 'v_trial_balance_for_schedules' AS validation,
       COUNT(*) AS row_count,
       CASE WHEN COUNT(*) = 696 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM v_trial_balance_for_schedules
WHERE deal_id = 'DEAL_HL_001';

-- Test v_database_tab_pivoted (CRITICAL for Excel)
SELECT 'v_database_tab_pivoted' AS validation,
       COUNT(*) AS row_count,
       CASE WHEN COUNT(*) = 29 THEN '✅ PASS' ELSE '❌ FAIL - DATABASE TAB CSV WILL BE EMPTY!' END AS status
FROM v_database_tab_pivoted
WHERE deal_id = 'DEAL_HL_001';

-- =====================================================
-- PHASE 4: Schedule Generation Validation
-- =====================================================
SELECT '=== PHASE 4: Schedule Generation Validation ===' AS phase;

-- Generate Income Statement
CALL generate_income_statement('DEAL_HL_001');

-- Verify Income Statement created
SELECT 'Income Statement Generation' AS validation,
       COUNT(*) AS row_count,
       CASE WHEN COUNT(*) >= 10 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM income_statement_structure
WHERE deal_id = 'DEAL_HL_001';

-- Generate Balance Sheet
CALL generate_balance_sheet('DEAL_HL_001');

-- Verify Balance Sheet created
SELECT 'Balance Sheet Generation' AS validation,
       COUNT(*) AS row_count,
       CASE WHEN COUNT(*) >= 5 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM balance_sheet_structure
WHERE deal_id = 'DEAL_HL_001';

-- =====================================================
-- PHASE 5: AI Insights Validation
-- =====================================================
SELECT '=== PHASE 5: AI Insights Validation ===' AS phase;

-- Generate AI Insights
CALL generate_ai_insights('DEAL_HL_001');

-- Verify AI Insights created
SELECT 'AI Insights Generation' AS validation,
       COUNT(*) AS insight_count,
       CASE WHEN COUNT(*) >= 10 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM ai_insights
WHERE deal_id = 'DEAL_HL_001';

-- =====================================================
-- PHASE 6: Export Validation (CRITICAL)
-- =====================================================
SELECT '=== PHASE 6: Export Validation ===' AS phase;

-- Export all files
CALL export_database_tab('DEAL_HL_001');
CALL export_income_statement_structure('DEAL_HL_001');
CALL export_balance_sheet_structure('DEAL_HL_001');
CALL export_ai_insights('DEAL_HL_001');

-- List all output files
LIST @fdd_output_stage;

-- Verify all 4 files exist
SELECT 'Output Files Created' AS validation,
       COUNT(*) AS file_count,
       CASE WHEN COUNT(*) >= 4 THEN '✅ PASS - All 4 files exported' 
            ELSE '❌ FAIL - Expected 4 files, found ' || COUNT(*) END AS status
FROM (
    SELECT "name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
    WHERE "name" LIKE '%DEAL_HL_001%'
);

-- Verify database_tab file exists and has data
SELECT 'Database Tab CSV (CRITICAL)' AS validation,
       "size" AS file_size_bytes,
       CASE WHEN "size" > 15000 THEN '✅ PASS - File has data (Excel SUMIF will work)'
            WHEN "size" > 0 THEN '⚠️ WARNING - File too small, may be missing data'
            ELSE '❌ FAIL - File empty or missing' END AS status
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID(-2)))
WHERE "name" LIKE '%database_tab%';

-- =====================================================
-- PHASE 7: End-to-End Test (Complete PoC)
-- =====================================================
SELECT '=== PHASE 7: Complete PoC Test ===' AS phase;

-- Clean up and run complete PoC
TRUNCATE TABLE trial_balance_raw;
TRUNCATE TABLE account_mappings;
TRUNCATE TABLE income_statement_structure;
TRUNCATE TABLE balance_sheet_structure;
TRUNCATE TABLE ai_insights;
REMOVE @fdd_output_stage PATTERN='.*DEAL_HL_001.*';

-- Run complete PoC (loads data, generates schedules, exports files)
CALL run_complete_poc();

-- Verify all outputs
LIST @fdd_output_stage;

SELECT 'Complete PoC Test' AS validation,
       COUNT(*) AS file_count,
       CASE WHEN COUNT(*) >= 4 THEN '✅ PASS - Full workflow successful' 
            ELSE '❌ FAIL - Complete PoC did not generate all files' END AS status
FROM (
    SELECT "name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
    WHERE "name" LIKE '%DEAL_HL_001%'
);

-- =====================================================
-- VALIDATION SUMMARY
-- =====================================================
SELECT '=== VALIDATION COMPLETE ===' AS phase;

SELECT '
📊 PRODUCTION VALIDATION SUMMARY

✅ = PASS  ❌ = FAIL  ⚠️ = WARNING

Expected Results:
-----------------
Phase 1: Environment Validation
  - Tables: 11+ ✅
  - Views: 3+ ✅
  - Procedures: 15+ ✅
  - Stages: 2 (input, output) ✅

Phase 2: Data Load
  - Trial Balance: 696 rows ✅
  - Account Mappings: 29 rows ✅
  - is_active = TRUE: 29 rows ✅ (CRITICAL!)

Phase 3: Views
  - v_trial_balance_for_schedules: 696 rows ✅
  - v_database_tab_pivoted: 29 rows ✅ (CRITICAL!)

Phase 4: Schedules
  - Income Statement: 10+ rows ✅
  - Balance Sheet: 5+ rows ✅

Phase 5: AI Insights
  - AI Insights: 10+ rows ✅

Phase 6: Exports
  - Total Files: 4 ✅
  - database_tab.csv: >15KB ✅ (CRITICAL!)
  - income_statement.csv: >1KB ✅
  - balance_sheet.csv: >500B ✅
  - ai_insights.csv: >10KB ✅

Phase 7: End-to-End
  - run_complete_poc(): 4 files ✅

PRODUCTION READY: ✅
-----------------
If all checks pass, the solution is ready for production use!

Next Steps:
-----------
1. Download CSV files from @fdd_output_stage
2. Import database_tab CSV into Excel Database tab
3. Verify Excel SUMIF formulas populate correctly
4. Document any environment-specific configuration
5. Train end users on the workflow

' AS summary;


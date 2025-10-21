-- ============================================================================
-- COMPREHENSIVE END-TO-END TEST SCRIPT
-- ============================================================================

-- Test execution timestamp
SELECT 'Starting Comprehensive End-to-End Test' AS status, CURRENT_TIMESTAMP() AS test_start_time;

-- ============================================================================
-- PHASE 1: VERIFY DEPLOYMENT
-- ============================================================================

SELECT '=== PHASE 1: DEPLOYMENT VERIFICATION ===' AS phase;

-- Check database and schema
SELECT 'Database: ' || CURRENT_DATABASE() AS check_1;
SELECT 'Schema: ' || CURRENT_SCHEMA() AS check_2;
SELECT 'Warehouse: ' || CURRENT_WAREHOUSE() AS check_3;

-- ============================================================================
-- PHASE 2: OBJECT VALIDATION
-- ============================================================================

SELECT '=== PHASE 2: OBJECT VALIDATION ===' AS phase;

-- Count objects by type
SELECT 'Tables' AS object_type, COUNT(*) AS object_count 
FROM information_schema.tables 
WHERE table_schema = 'TRIAL_BALANCE' AND table_type = 'BASE TABLE';

SELECT 'Views' AS object_type, COUNT(*) AS object_count 
FROM information_schema.views 
WHERE table_schema = 'TRIAL_BALANCE';

SELECT 'Procedures' AS object_type, COUNT(*) AS object_count 
FROM information_schema.procedures 
WHERE procedure_schema = 'TRIAL_BALANCE';

SELECT 'Functions' AS object_type, COUNT(*) AS object_count 
FROM information_schema.functions 
WHERE function_schema = 'TRIAL_BALANCE';

-- Verify system configuration
SELECT 'System Config Entries' AS check_name, COUNT(*) AS count FROM system_config;

-- ============================================================================
-- PHASE 3: DATA LOADING TESTS
-- ============================================================================

SELECT '=== PHASE 3: DATA LOADING TESTS ===' AS phase;

-- Check if files exist in stage
LIST @fdd_input_stage;

-- Load trial balance data
CALL load_trial_balance('01_sample_trial_balance_24mo.csv', 'DEAL_HL_001');

-- Load account mappings
CALL load_account_mappings('02_sample_account_mappings_24mo.csv', 'DEAL_HL_001');

-- Verify data loaded
SELECT 'Trial Balance Rows' AS check_name, COUNT(*) AS row_count FROM trial_balance_raw WHERE deal_id = 'DEAL_HL_001';
SELECT 'Account Mappings Rows' AS check_name, COUNT(*) AS row_count FROM account_mappings WHERE deal_id = 'DEAL_HL_001';

-- Check distinct periods
SELECT 'Distinct Periods in Trial Balance' AS check_name, COUNT(DISTINCT period_date) AS period_count 
FROM trial_balance_raw WHERE deal_id = 'DEAL_HL_001';

-- ============================================================================
-- PHASE 4: DATA QUALITY VALIDATION
-- ============================================================================

SELECT '=== PHASE 4: DATA QUALITY VALIDATION ===' AS phase;

-- Run data quality checks
CALL validate_data_quality('DEAL_HL_001');

-- ============================================================================
-- PHASE 5: SCHEDULE GENERATION TESTS
-- ============================================================================

SELECT '=== PHASE 5: SCHEDULE GENERATION TESTS ===' AS phase;

-- Generate Income Statement
CALL generate_income_statement('DEAL_HL_001');

-- Verify IS structure created (check temp table via information_schema won't work, so check audit log)
SELECT 'Income Statement Generation' AS check_name, status, message 
FROM audit_log 
WHERE procedure_name = 'generate_income_statement' 
AND deal_id = 'DEAL_HL_001'
ORDER BY start_time DESC LIMIT 1;

-- Generate Balance Sheet
CALL generate_balance_sheet('DEAL_HL_001');

-- Verify BS structure created
SELECT 'Balance Sheet Generation' AS check_name, status, message 
FROM audit_log 
WHERE procedure_name = 'generate_balance_sheet' 
AND deal_id = 'DEAL_HL_001'
ORDER BY start_time DESC LIMIT 1;

-- ============================================================================
-- PHASE 6: AI INSIGHTS TESTS
-- ============================================================================

SELECT '=== PHASE 6: AI INSIGHTS TESTS ===' AS phase;

-- Generate AI insights
CALL generate_ai_insights('DEAL_HL_001');

-- Verify insights created
SELECT 'AI Insights Generated' AS check_name, COUNT(*) AS insight_count 
FROM ai_insights WHERE deal_id = 'DEAL_HL_001';

-- Sample insights
SELECT insight_type, severity, LEFT(insight_text, 100) AS insight_preview
FROM ai_insights 
WHERE deal_id = 'DEAL_HL_001'
ORDER BY priority DESC, confidence_score DESC
LIMIT 5;

-- ============================================================================
-- PHASE 7: EXPORT TESTS
-- ============================================================================

SELECT '=== PHASE 7: EXPORT TESTS ===' AS phase;

-- Export database tab
CALL export_database_tab('DEAL_HL_001');

-- Export income statement
CALL export_income_statement_structure('DEAL_HL_001');

-- Export balance sheet
CALL export_balance_sheet_structure('DEAL_HL_001');

-- Export AI insights
CALL export_ai_insights('DEAL_HL_001');

-- List output files
SELECT 'Output Files Created:' AS status;
LIST @fdd_output_stage PATTERN='.*DEAL_HL_001.*';

-- ============================================================================
-- PHASE 9: VIEW TESTS
-- ============================================================================

SELECT '=== PHASE 9: VIEW TESTS ===' AS phase;

-- Test v_database_tab_pivoted (sample rows)
SELECT 'v_database_tab_pivoted Sample' AS view_name;
SELECT deal_id, account_number, account_name, mapping_level_1, period_01_label, period_01
FROM v_database_tab_pivoted
WHERE deal_id = 'DEAL_HL_001'
LIMIT 10;

-- Test v_trial_balance_for_schedules (sample rows)
SELECT 'v_trial_balance_for_schedules Sample' AS view_name;
SELECT deal_id, period_date, account_number, account_name, amount_for_display
FROM v_trial_balance_for_schedules
WHERE deal_id = 'DEAL_HL_001'
LIMIT 10;

-- Test v_portfolio_summary
SELECT 'v_portfolio_summary' AS view_name;
SELECT * FROM v_portfolio_summary;

-- ============================================================================
-- PHASE 10: CONFIGURATION & SECURITY TESTS
-- ============================================================================

SELECT '=== PHASE 10: CONFIGURATION TESTS ===' AS phase;

-- Test configuration functions
SELECT 'get_config_string' AS function_test, get_config_string('environment') AS result;
SELECT 'get_config_number' AS function_test, get_config_number('max_pivot_periods') AS result;
SELECT 'get_config_boolean' AS function_test, get_config_boolean('enable_row_level_security') AS result;

-- Test validation functions
SELECT 'validate_deal_id' AS function_test, 
       validate_deal_id('DEAL_HL_001') AS valid_id,
       validate_deal_id('invalid@id') AS invalid_id;

-- Test sanitize function
SELECT 'sanitize_deal_id' AS function_test,
       sanitize_deal_id('DEAL_HL_001') AS clean_id;

-- ============================================================================
-- FINAL STATUS
-- ============================================================================

SELECT '=== TEST COMPLETE ===' AS status, CURRENT_TIMESTAMP() AS test_end_time;

-- Summary of audit log
SELECT 'Audit Log Summary' AS report;
SELECT procedure_name, status, COUNT(*) AS execution_count
FROM audit_log
WHERE start_time >= DATEADD(minute, -10, CURRENT_TIMESTAMP())
GROUP BY procedure_name, status
ORDER BY procedure_name, status;


-- ============================================================================
-- FINAL END-TO-END TEST WITH DATA LOADING
-- ============================================================================

SELECT '=== STARTING FINAL E2E TEST ===' AS status, CURRENT_TIMESTAMP() AS test_start;

-- Check files in stage
SELECT '1. Files in input stage:' AS step;
LIST @fdd_input_stage;

-- Load trial balance data
SELECT '2. Loading trial balance data...' AS step;
CALL load_trial_balance('01_sample_trial_balance_24mo.csv', 'DEAL_HL_001');

-- Load account mappings
SELECT '3. Loading account mappings...' AS step;
CALL load_account_mappings('02_sample_account_mappings_24mo.csv', 'DEAL_HL_001');

-- Verify data loaded
SELECT '4. Verify data loaded:' AS step;
SELECT 'Trial Balance' AS table_name, COUNT(*) AS row_count, COUNT(DISTINCT period_date) AS period_count 
FROM trial_balance_raw WHERE deal_id = 'DEAL_HL_001';

SELECT 'Account Mappings' AS table_name, COUNT(*) AS row_count 
FROM account_mappings WHERE deal_id = 'DEAL_HL_001';

-- Run data quality validation
SELECT '5. Data quality validation:' AS step;
CALL validate_data_quality('DEAL_HL_001');

-- Generate schedules
SELECT '6. Generating Income Statement...' AS step;
CALL generate_income_statement('DEAL_HL_001');

SELECT '7. Generating Balance Sheet...' AS step;
CALL generate_balance_sheet('DEAL_HL_001');

-- Generate AI insights (may take a while)
SELECT '8. Generating AI insights...' AS step;
CALL generate_ai_insights('DEAL_HL_001');

-- Check AI insights created
SELECT 'AI Insights' AS check_name, COUNT(*) AS count FROM ai_insights WHERE deal_id = 'DEAL_HL_001';

-- Export all outputs
SELECT '9. Exporting outputs...' AS step;
CALL export_database_tab('DEAL_HL_001');
CALL export_income_statement_structure('DEAL_HL_001');
CALL export_balance_sheet_structure('DEAL_HL_001');
CALL export_ai_insights('DEAL_HL_001');

-- List output files
SELECT '10. Output files created:' AS step;
LIST @fdd_output_stage PATTERN='.*DEAL_HL_001.*';

-- Test views
SELECT '11. Testing views...' AS step;
SELECT 'v_database_tab_pivoted' AS view_name, COUNT(*) AS row_count 
FROM v_database_tab_pivoted WHERE deal_id = 'DEAL_HL_001';

SELECT 'v_trial_balance_for_schedules' AS view_name, COUNT(*) AS row_count 
FROM v_trial_balance_for_schedules WHERE deal_id = 'DEAL_HL_001';

SELECT * FROM v_portfolio_summary;

-- Test configuration functions
SELECT '12. Testing configuration functions...' AS step;
SELECT 
    get_config_string('environment') AS environment,
    get_config_number('max_pivot_periods') AS max_periods,
    get_config_boolean('enable_row_level_security') AS rls_enabled;

-- Summary
SELECT '=== TEST COMPLETE ===' AS status, CURRENT_TIMESTAMP() AS test_end;

-- Audit log summary
SELECT procedure_name, status, COUNT(*) AS execution_count, MAX(end_time) AS last_run
FROM audit_log
WHERE start_time >= DATEADD(minute, -10, CURRENT_TIMESTAMP())
GROUP BY procedure_name, status
ORDER BY last_run DESC;

-- ============================================================================
-- Houlihan Lokey FDD Automation - Test Suite
-- ============================================================================
-- Description: Automated tests for validation and regression testing
-- Version: 1.0.0
-- Last Updated: 2025-10-20
-- ============================================================================

-- Create testing schema and results table
CREATE SCHEMA IF NOT EXISTS TESTING;
USE SCHEMA TESTING;

CREATE OR REPLACE TABLE test_results (
    test_id VARCHAR(50) DEFAULT UUID_STRING() PRIMARY KEY,
    test_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    test_name VARCHAR(200) NOT NULL,
    test_category VARCHAR(50),
    status VARCHAR(20),  -- 'PASS', 'FAIL', 'ERROR', 'SKIP'
    execution_time_ms NUMBER,
    expected_result VARCHAR(5000),
    actual_result VARCHAR(5000),
    error_message VARCHAR(5000),
    run_by VARCHAR(100) DEFAULT CURRENT_USER()
);

-- ============================================================================
-- TEST HELPER PROCEDURES
-- ============================================================================

CREATE OR REPLACE PROCEDURE log_test_result(
    test_name_param VARCHAR,
    category_param VARCHAR,
    status_param VARCHAR,
    expected_param VARCHAR DEFAULT NULL,
    actual_param VARCHAR DEFAULT NULL,
    error_param VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO test_results (test_name, test_category, status, expected_result, actual_result, error_message)
    VALUES (:test_name_param, :category_param, :status_param, :expected_param, :actual_param, :error_param);
    
    RETURN status_param || ': ' || test_name_param;
END;
$$;

-- ============================================================================
-- TEST 1: SYSTEM CONFIGURATION
-- ============================================================================

CREATE OR REPLACE PROCEDURE test_system_config()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    config_count NUMBER;
    expected_min NUMBER DEFAULT 20;
BEGIN
    SELECT COUNT(*) INTO :config_count FROM TRIAL_BALANCE.system_config;
    
    IF (:config_count >= :expected_min) THEN
        CALL log_test_result(
            'System Configuration Exists',
            'Setup',
            'PASS',
            'At least ' || :expected_min || ' config entries',
            :config_count || ' config entries found',
            NULL
        );
        RETURN 'PASS';
    ELSE
        CALL log_test_result(
            'System Configuration Exists',
            'Setup',
            'FAIL',
            'At least ' || :expected_min || ' config entries',
            'Only ' || :config_count || ' found',
            'Insufficient configuration entries'
        );
        RETURN 'FAIL';
    END IF;
EXCEPTION
    WHEN OTHER THEN
        CALL log_test_result(
            'System Configuration Exists',
            'Setup',
            'ERROR',
            NULL,
            NULL,
            SQLERRM
        );
        RETURN 'ERROR';
END;
$$;

-- ============================================================================
-- TEST 2: CORE TABLES EXIST
-- ============================================================================

CREATE OR REPLACE PROCEDURE test_core_tables()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    table_count NUMBER;
    required_tables ARRAY DEFAULT ARRAY_CONSTRUCT(
        'TRIAL_BALANCE_RAW', 'ACCOUNT_MAPPINGS', 'AI_INSIGHTS',
        'AUDIT_LOG', 'LOAD_ERRORS', 'DATA_QUALITY_CHECKS',
        'USER_DEAL_PERMISSIONS', 'SCHEMA_MIGRATIONS', 'SYSTEM_CONFIG'
    );
BEGIN
    SELECT COUNT(*) INTO :table_count
    FROM information_schema.tables
    WHERE table_schema = 'TRIAL_BALANCE'
    AND table_name IN (
        'TRIAL_BALANCE_RAW', 'ACCOUNT_MAPPINGS', 'AI_INSIGHTS',
        'AUDIT_LOG', 'LOAD_ERRORS', 'DATA_QUALITY_CHECKS',
        'USER_DEAL_PERMISSIONS', 'SCHEMA_MIGRATIONS', 'SYSTEM_CONFIG'
    );
    
    IF (:table_count >= 9) THEN
        CALL log_test_result(
            'Core Tables Exist',
            'Setup',
            'PASS',
            '9 required tables',
            :table_count || ' tables found',
            NULL
        );
        RETURN 'PASS';
    ELSE
        CALL log_test_result(
            'Core Tables Exist',
            'Setup',
            'FAIL',
            '9 required tables',
            'Only ' || :table_count || ' found',
            'Missing core tables'
        );
        RETURN 'FAIL';
    END IF;
EXCEPTION
    WHEN OTHER THEN
        CALL log_test_result('Core Tables Exist', 'Setup', 'ERROR', NULL, NULL, SQLERRM);
        RETURN 'ERROR';
END;
$$;

-- ============================================================================
-- TEST 3: INPUT VALIDATION FUNCTIONS
-- ============================================================================

CREATE OR REPLACE PROCEDURE test_deal_id_validation()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    valid_test BOOLEAN;
    invalid_test BOOLEAN;
BEGIN
    -- Test valid deal IDs
    SELECT TRIAL_BALANCE.validate_deal_id('DEAL_HL_001') INTO :valid_test;
    
    -- Test invalid deal IDs
    SELECT TRIAL_BALANCE.validate_deal_id('DEAL@INVALID') INTO :invalid_test;
    
    IF (:valid_test = TRUE AND :invalid_test = FALSE) THEN
        CALL log_test_result(
            'Deal ID Validation Function',
            'Security',
            'PASS',
            'Valid IDs accepted, invalid rejected',
            'Validation working correctly',
            NULL
        );
        RETURN 'PASS';
    ELSE
        CALL log_test_result(
            'Deal ID Validation Function',
            'Security',
            'FAIL',
            'Valid IDs accepted, invalid rejected',
            'Validation not working',
            'validate_deal_id() not functioning correctly'
        );
        RETURN 'FAIL';
    END IF;
EXCEPTION
    WHEN OTHER THEN
        CALL log_test_result('Deal ID Validation Function', 'Security', 'ERROR', NULL, NULL, SQLERRM);
        RETURN 'ERROR';
END;
$$;

-- ============================================================================
-- TEST 4: DATA LOADING (with test data)
-- ============================================================================

CREATE OR REPLACE PROCEDURE test_trial_balance_load()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    initial_count NUMBER;
    result_cursor RESULTSET;
    load_status VARCHAR;
BEGIN
    -- Get initial count
    SELECT COUNT(*) INTO :initial_count FROM TRIAL_BALANCE.trial_balance_raw WHERE deal_id = 'TEST_DEAL_001';
    
    -- Clean up any existing test data
    DELETE FROM TRIAL_BALANCE.trial_balance_raw WHERE deal_id = 'TEST_DEAL_001';
    
    -- Insert test data
    INSERT INTO TRIAL_BALANCE.trial_balance_raw (
        deal_id, deal_name, entity, period_date, account_number, account_name,
        debit_amount, credit_amount, net_amount
    )
    VALUES 
        ('TEST_DEAL_001', 'Test Company', 'TestCo', '2024-01-31', '1000', 'Cash', 10000.00, 0.00, 10000.00),
        ('TEST_DEAL_001', 'Test Company', 'TestCo', '2024-01-31', '4000', 'Revenue', 0.00, 10000.00, -10000.00);
    
    -- Verify insertion
    SELECT COUNT(*) INTO :initial_count FROM TRIAL_BALANCE.trial_balance_raw WHERE deal_id = 'TEST_DEAL_001';
    
    IF (:initial_count = 2) THEN
        CALL log_test_result(
            'Trial Balance Data Loading',
            'Data',
            'PASS',
            '2 test records inserted',
            :initial_count || ' records found',
            NULL
        );
        load_status := 'PASS';
    ELSE
        CALL log_test_result(
            'Trial Balance Data Loading',
            'Data',
            'FAIL',
            '2 test records inserted',
            :initial_count || ' records found',
            'Data insertion failed'
        );
        load_status := 'FAIL';
    END IF;
    
    -- Clean up test data
    DELETE FROM TRIAL_BALANCE.trial_balance_raw WHERE deal_id = 'TEST_DEAL_001';
    
    RETURN load_status;
EXCEPTION
    WHEN OTHER THEN
        CALL log_test_result('Trial Balance Data Loading', 'Data', 'ERROR', NULL, NULL, SQLERRM);
        RETURN 'ERROR';
END;
$$;

-- ============================================================================
-- TEST 5: SQL INJECTION PREVENTION
-- ============================================================================

CREATE OR REPLACE PROCEDURE test_sql_injection_prevention()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    malicious_input VARCHAR DEFAULT 'DEAL''; DROP TABLE trial_balance_raw; --';
    validation_result BOOLEAN;
BEGIN
    -- Test that malicious input is rejected
    SELECT TRIAL_BALANCE.validate_deal_id(:malicious_input) INTO :validation_result;
    
    IF (:validation_result = FALSE) THEN
        CALL log_test_result(
            'SQL Injection Prevention',
            'Security',
            'PASS',
            'Malicious input rejected',
            'Input validation blocked SQL injection attempt',
            NULL
        );
        RETURN 'PASS';
    ELSE
        CALL log_test_result(
            'SQL Injection Prevention',
            'Security',
            'FAIL',
            'Malicious input rejected',
            'Malicious input was accepted!',
            'SECURITY VULNERABILITY: SQL injection not prevented'
        );
        RETURN 'FAIL';
    END IF;
EXCEPTION
    WHEN OTHER THEN
        CALL log_test_result('SQL Injection Prevention', 'Security', 'ERROR', NULL, NULL, SQLERRM);
        RETURN 'ERROR';
END;
$$;

-- ============================================================================
-- TEST 6: AUDIT LOGGING
-- ============================================================================

CREATE OR REPLACE PROCEDURE test_audit_logging()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    initial_count NUMBER;
    final_count NUMBER;
    test_log_id VARCHAR DEFAULT UUID_STRING();
BEGIN
    SELECT COUNT(*) INTO :initial_count FROM TRIAL_BALANCE.audit_log;
    
    -- Insert test audit log entry
    INSERT INTO TRIAL_BALANCE.audit_log (log_id, procedure_name, deal_id, status, message)
    VALUES (:test_log_id, 'test_procedure', 'TEST_DEAL', 'SUCCESS', 'Test audit entry');
    
    SELECT COUNT(*) INTO :final_count FROM TRIAL_BALANCE.audit_log;
    
    IF (:final_count > :initial_count) THEN
        CALL log_test_result(
            'Audit Logging Functionality',
            'Observability',
            'PASS',
            'Audit log entry created',
            'Successfully logged to audit_log table',
            NULL
        );
        
        -- Clean up test entry
        DELETE FROM TRIAL_BALANCE.audit_log WHERE log_id = :test_log_id;
        
        RETURN 'PASS';
    ELSE
        CALL log_test_result(
            'Audit Logging Functionality',
            'Observability',
            'FAIL',
            'Audit log entry created',
            'Audit log insertion failed',
            'Could not insert into audit_log'
        );
        RETURN 'FAIL';
    END IF;
EXCEPTION
    WHEN OTHER THEN
        CALL log_test_result('Audit Logging Functionality', 'Observability', 'ERROR', NULL, NULL, SQLERRM);
        RETURN 'ERROR';
END;
$$;

-- ============================================================================
-- TEST 7: CONFIGURATION RETRIEVAL
-- ============================================================================

CREATE OR REPLACE PROCEDURE test_configuration_functions()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    config_value VARIANT;
    config_string VARCHAR;
    config_number NUMBER;
BEGIN
    -- Test configuration retrieval
    SELECT TRIAL_BALANCE.get_config('environment') INTO :config_value;
    SELECT TRIAL_BALANCE.get_config_string('environment') INTO :config_string;
    SELECT TRIAL_BALANCE.get_config_number('max_ai_insights') INTO :config_number;
    
    IF (:config_value IS NOT NULL AND :config_string IS NOT NULL AND :config_number IS NOT NULL) THEN
        CALL log_test_result(
            'Configuration Functions',
            'Configuration',
            'PASS',
            'All config functions return values',
            'get_config(), get_config_string(), get_config_number() working',
            NULL
        );
        RETURN 'PASS';
    ELSE
        CALL log_test_result(
            'Configuration Functions',
            'Configuration',
            'FAIL',
            'All config functions return values',
            'Some functions returned NULL',
            'Configuration retrieval failed'
        );
        RETURN 'FAIL';
    END IF;
EXCEPTION
    WHEN OTHER THEN
        CALL log_test_result('Configuration Functions', 'Configuration', 'ERROR', NULL, NULL, SQLERRM);
        RETURN 'ERROR';
END;
$$;

-- ============================================================================
-- MASTER TEST RUNNER
-- ============================================================================

CREATE OR REPLACE PROCEDURE run_all_tests()
RETURNS TABLE(test_name VARCHAR, status VARCHAR, message VARCHAR)
LANGUAGE SQL
AS
$$
DECLARE
    result_cursor RESULTSET;
BEGIN
    -- Clear previous test results
    TRUNCATE TABLE test_results;
    
    -- Run all tests
    CALL test_system_config();
    CALL test_core_tables();
    CALL test_deal_id_validation();
    CALL test_trial_balance_load();
    CALL test_sql_injection_prevention();
    CALL test_audit_logging();
    CALL test_configuration_functions();
    
    -- Return summary
    result_cursor := (
        SELECT 
            test_name,
            status,
            CASE 
                WHEN status = 'PASS' THEN '✓ ' || test_name || ' - PASSED'
                WHEN status = 'FAIL' THEN '✗ ' || test_name || ' - FAILED: ' || COALESCE(error_message, 'Unknown error')
                WHEN status = 'ERROR' THEN '⚠ ' || test_name || ' - ERROR: ' || COALESCE(error_message, 'Unknown error')
                ELSE '? ' || test_name || ' - ' || status
            END AS message
        FROM test_results
        ORDER BY 
            CASE status WHEN 'FAIL' THEN 1 WHEN 'ERROR' THEN 2 WHEN 'PASS' THEN 3 ELSE 4 END,
            test_timestamp
    );
    
    RETURN TABLE(result_cursor);
END;
$$;

-- ============================================================================
-- USAGE INSTRUCTIONS
-- ============================================================================

/*

RUNNING THE TEST SUITE:

1. Basic test execution:
   CALL run_all_tests();

2. View detailed results:
   SELECT * FROM TESTING.test_results ORDER BY test_timestamp DESC;

3. Check pass rate:
   SELECT 
       status,
       COUNT(*) AS test_count,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
   FROM TESTING.test_results
   GROUP BY status;

4. Run individual tests:
   CALL test_system_config();
   CALL test_core_tables();
   -- etc.

5. View failed tests only:
   SELECT * FROM TESTING.test_results WHERE status IN ('FAIL', 'ERROR');

EXPECTED OUTPUT:

✓ System Configuration Exists - PASSED
✓ Core Tables Exist - PASSED
✓ Deal ID Validation Function - PASSED
✓ Trial Balance Data Loading - PASSED
✓ SQL Injection Prevention - PASSED
✓ Audit Logging Functionality - PASSED
✓ Configuration Functions - PASSED

All tests should PASS for production-ready deployment.

*/

SELECT 'Test suite created successfully. Run: CALL run_all_tests();' AS status;



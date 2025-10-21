-- ============================================================================
-- Houlihan Lokey FDD Automation - Master Deployment Script
-- ============================================================================
-- Description: Main deployment script that orchestrates all setup
-- Version: 1.0.0
-- Last Updated: 2025-10-20
-- ============================================================================
-- 
-- USAGE:
--   1. Configure environment variables below
--   2. Run this script as ACCOUNTADMIN (or equivalent)
--   3. Script will create database, schema, warehouse, and all objects
--   4. After completion, grant FDD_ANALYST_ROLE to your users
-- 
-- ENVIRONMENT CUSTOMIZATION:
--   - Set ENVIRONMENT_NAME ('DEVELOPMENT', 'STAGING', 'PRODUCTION')
--   - Adjust warehouse size, retention policies, IP restrictions as needed
-- 
-- ============================================================================

-- ============================================================================
-- STEP 0: ENVIRONMENT CONFIGURATION
-- ============================================================================

-- Set environment variables (customize for your deployment)
SET ENVIRONMENT_NAME = 'PRODUCTION';  -- Options: DEVELOPMENT, STAGING, PRODUCTION
SET DATABASE_NAME = 'HL_FDD_POC';
SET SCHEMA_NAME = 'TRIAL_BALANCE';
SET WAREHOUSE_NAME = 'FDD_POC_WH';
SET WAREHOUSE_SIZE = 'SMALL';  -- Options: XSMALL, SMALL, MEDIUM, LARGE
SET AUTO_SUSPEND_SECONDS = 60;

-- Display deployment configuration
SELECT 
    'Starting FDD Automation Deployment' AS status,
    $ENVIRONMENT_NAME AS environment,
    $DATABASE_NAME AS database,
    $WAREHOUSE_NAME AS warehouse,
    CURRENT_ROLE() AS deployment_role,
    CURRENT_USER() AS deployed_by,
    CURRENT_TIMESTAMP() AS deployment_time;

-- ============================================================================
-- STEP 1: CREATE ENVIRONMENT
-- ============================================================================

-- Create database
CREATE DATABASE IF NOT EXISTS IDENTIFIER($DATABASE_NAME)
    COMMENT = 'Houlihan Lokey FDD Automation - Financial Due Diligence Platform';

USE DATABASE IDENTIFIER($DATABASE_NAME);

-- Create schema
CREATE SCHEMA IF NOT EXISTS IDENTIFIER($SCHEMA_NAME)
    COMMENT = 'Trial balance, account mappings, and generated schedules';

USE SCHEMA IDENTIFIER($SCHEMA_NAME);

-- Create warehouse with auto-scaling
-- Note: IDENTIFIER() and WITH keywords cause issues with warehouses, use direct concatenation
EXECUTE IMMEDIATE 
    'CREATE WAREHOUSE IF NOT EXISTS ' || $WAREHOUSE_NAME || 
    ' WAREHOUSE_SIZE = ' || $WAREHOUSE_SIZE ||
    ' AUTO_SUSPEND = ' || $AUTO_SUSPEND_SECONDS ||
    ' AUTO_RESUME = TRUE' ||
    ' MIN_CLUSTER_COUNT = 1' ||
    ' MAX_CLUSTER_COUNT = 3' ||
    ' SCALING_POLICY = ''STANDARD''' ||
    ' INITIALLY_SUSPENDED = FALSE' ||
    ' COMMENT = ''Warehouse for FDD data processing and AI analysis''';

EXECUTE IMMEDIATE 'USE WAREHOUSE ' || $WAREHOUSE_NAME;

-- Record deployment in schema migrations
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(20) PRIMARY KEY,
    description VARCHAR(500),
    migration_file VARCHAR(200),
    applied_by VARCHAR(100) DEFAULT CURRENT_USER(),
    applied_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    execution_time_seconds NUMBER(10,2),
    checksum VARCHAR(64),
    status VARCHAR(20) DEFAULT 'SUCCESS'
);

-- Record this deployment
INSERT INTO schema_migrations (version, description, migration_file, status)
VALUES ('1.0.0', 'Initial production deployment', 'deploy.sql', 'IN_PROGRESS');

SELECT 'Step 1: Environment created - ' || $DATABASE_NAME || '.' || $SCHEMA_NAME AS status;

-- ============================================================================
-- STEP 2: EXECUTE MODULAR SQL SCRIPTS
-- ============================================================================

-- Execute configuration setup
!source 00_system_config.sql

-- Execute core schema
!source 01_schema.sql

-- Execute security configuration
!source 02_security.sql

-- Execute data procedures
!source 03_data_procedures.sql

-- Execute schedule generation
!source 04_schedule_generation.sql

-- Execute AI and export procedures
!source 05_ai_and_export.sql

-- Execute testing framework (optional)
-- !source 06_testing.sql

SELECT 'Step 2: All SQL modules executed successfully' AS status;

-- ============================================================================
-- STEP 3: POST-DEPLOYMENT VALIDATION
-- ============================================================================

-- Validate all critical objects exist
SELECT 
    'Validation: Core Tables' AS check_type,
    COUNT(*) AS object_count,
    CASE WHEN COUNT(*) >= 10 THEN 'PASS' ELSE 'FAIL' END AS status
FROM information_schema.tables
WHERE table_schema = $SCHEMA_NAME
AND table_name IN (
    'TRIAL_BALANCE_RAW', 'ACCOUNT_MAPPINGS', 'AI_INSIGHTS', 
    'AUDIT_LOG', 'LOAD_ERRORS', 'DATA_QUALITY_CHECKS',
    'USER_DEAL_PERMISSIONS', 'SCHEMA_MIGRATIONS', 'SYSTEM_CONFIG'
)

UNION ALL

SELECT 
    'Validation: Views',
    COUNT(*),
    CASE WHEN COUNT(*) >= 3 THEN 'PASS' ELSE 'FAIL' END
FROM information_schema.views
WHERE table_schema = $SCHEMA_NAME

UNION ALL

SELECT 
    'Validation: Procedures',
    COUNT(*),
    CASE WHEN COUNT(*) >= 10 THEN 'PASS' ELSE 'FAIL' END
FROM information_schema.procedures
WHERE procedure_schema = $SCHEMA_NAME

UNION ALL

SELECT 
    'Validation: Functions',
    COUNT(*),
    CASE WHEN COUNT(*) >= 4 THEN 'PASS' ELSE 'FAIL' END
FROM information_schema.functions
WHERE function_schema = $SCHEMA_NAME

UNION ALL

SELECT 
    'Validation: Roles',
    COUNT(*),
    CASE WHEN COUNT(*) >= 4 THEN 'PASS' ELSE 'FAIL' END
FROM information_schema.roles
WHERE name LIKE 'FDD_%_ROLE';

-- ============================================================================
-- STEP 4: INITIAL DATA SETUP (Optional)
-- ============================================================================

-- Sample data loading procedure
CREATE OR REPLACE PROCEDURE load_sample_data()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    tb_result RESULTSET;
    am_result RESULTSET;
BEGIN
    -- Load trial balance
    CALL load_trial_balance() INTO :tb_result;
    
    -- Load account mappings  
    CALL load_account_mappings() INTO :am_result;
    
    RETURN 'SUCCESS: Sample data loaded. Ready for schedule generation.';
EXCEPTION
    WHEN OTHER THEN
        RETURN 'ERROR: Sample data load failed - ' || SQLERRM;
END;
$$;

-- Convenience procedure for PoC/Demo
CREATE OR REPLACE PROCEDURE run_complete_poc()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    load_result VARCHAR;
    gen_result VARCHAR;
BEGIN
    -- Load sample data
    CALL load_sample_data() INTO :load_result;
    
    -- Generate schedules for sample deal
    CALL generate_fdd_schedules('DEAL_HL_001') INTO :gen_result;
    
    RETURN 'PoC Complete! ' || :gen_result || ' Run "LIST @fdd_output_stage;" to see output files.';
EXCEPTION
    WHEN OTHER THEN
        RETURN 'ERROR: PoC execution failed - ' || SQLERRM;
END;
$$;

SELECT 'Step 3-4: Validation and helper procedures created' AS status;

-- ============================================================================
-- STEP 5: GRANT PERMISSIONS TO USERS (Customize for your organization)
-- ============================================================================

-- Example: Grant analyst role to specific users
-- Uncomment and customize with your actual usernames

/*
GRANT ROLE FDD_ANALYST_ROLE TO USER john_smith;
GRANT ROLE FDD_ANALYST_ROLE TO USER jane_doe;
GRANT ROLE FDD_READONLY_ROLE TO USER auditor_user;

-- Grant initial deal permissions
CALL grant_deal_access('john_smith', 'DEAL_HL_001', 'WRITE', 90);
CALL grant_deal_access('jane_doe', 'DEAL_HL_001', 'READ', 90);
*/

SELECT 'Step 5: User permissions configured (review and customize grants above)' AS status;

-- ============================================================================
-- STEP 6: FINALIZE DEPLOYMENT
-- ============================================================================

-- Update migration record
UPDATE schema_migrations
SET status = 'SUCCESS',
    execution_time_seconds = DATEDIFF(second, applied_at, CURRENT_TIMESTAMP())
WHERE version = '1.0.0';

-- Log deployment in audit log
INSERT INTO audit_log (procedure_name, status, message)
VALUES (
    'deploy.sql',
    'SUCCESS',
    'Production deployment v1.0.0 completed in environment: ' || $ENVIRONMENT_NAME
);

-- Display final status
SELECT 
    '✓ DEPLOYMENT SUCCESSFUL' AS status,
    'Version 1.0.0' AS version,
    $ENVIRONMENT_NAME AS environment,
    $DATABASE_NAME AS database,
    $SCHEMA_NAME AS schema,
    $WAREHOUSE_NAME AS warehouse,
    CURRENT_USER() AS deployed_by,
    CURRENT_TIMESTAMP() AS completed_at;

-- Display next steps
SELECT '
================================================================================
DEPLOYMENT COMPLETE - Next Steps:
================================================================================

1. GRANT PERMISSIONS:
   - Review and uncomment user grants in Step 5 above
   - Grant FDD_ANALYST_ROLE to your team members
   - Configure user_deal_permissions for deal access

2. UPLOAD DATA:
   - PUT files to @fdd_input_stage:
     PUT file:///path/to/01_sample_trial_balance_24mo.csv @fdd_input_stage AUTO_COMPRESS=FALSE;
     PUT file:///path/to/02_sample_account_mappings_24mo.csv @fdd_input_stage AUTO_COMPRESS=FALSE;

3. LOAD DATA:
   CALL load_trial_balance();
   CALL load_account_mappings();

4. GENERATE SCHEDULES:
   CALL generate_fdd_schedules(''DEAL_HL_001'');

5. RETRIEVE OUTPUTS:
   LIST @fdd_output_stage;
   GET @fdd_output_stage/database_tab_DEAL_HL_001.csv file:///local/path/;

6. ENABLE ROW-LEVEL SECURITY (Optional):
   - Review 02_security.sql and uncomment row access policy application
   - Ensure user_deal_permissions are configured first

7. MONITOR OPERATIONS:
   - Query audit_log table for execution history
   - Query load_errors for data quality issues
   - Query data_quality_checks for validation results

8. FOR POC/DEMO:
   CALL run_complete_poc();
   -- This loads sample data and generates all outputs automatically

Documentation: See README.md and docs/ directory for detailed guides

================================================================================
' AS next_steps;

-- Display configuration summary
SELECT * FROM v_system_config;

SELECT 'Deployment script completed successfully!' AS final_status;



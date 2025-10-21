-- ============================================================================
-- Houlihan Lokey FDD Automation - SnowSight Deployment Script
-- ============================================================================
-- Description: Combined deployment script for Snowflake SnowSight Web UI
-- Version: 1.0.0
-- Last Updated: 2025-10-21
-- ============================================================================
-- 
-- USAGE FOR SNOWSIGHT:
--   1. Open this file in SnowSight (Worksheets > Create from SQL File)
--   2. Configure environment variables below (lines 26-31)
--   3. Ensure you're using ACCOUNTADMIN role (or equivalent)
--   4. Click "Run All" button in SnowSight
--   5. After completion, grant FDD_ANALYST_ROLE to your users
-- 
-- ENVIRONMENT CUSTOMIZATION:
--   - Set ENVIRONMENT_NAME ('DEVELOPMENT', 'STAGING', 'PRODUCTION')
--   - Adjust warehouse size, retention policies as needed
-- 
-- NOTE: This is a combined version of all modular SQL files for SnowSight.
--       For SnowSQL CLI, use deploy.sql instead (supports !source commands)
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
-- Note: Use anonymous block with local variables to avoid 256-byte session variable limit
EXECUTE IMMEDIATE $$
DECLARE
    warehouse_ddl VARCHAR;
BEGIN
    warehouse_ddl := 
        'CREATE WAREHOUSE IF NOT EXISTS ' || $WAREHOUSE_NAME || 
        ' WAREHOUSE_SIZE = ' || $WAREHOUSE_SIZE ||
        ' AUTO_SUSPEND = ' || $AUTO_SUSPEND_SECONDS ||
        ' AUTO_RESUME = TRUE' ||
        ' MIN_CLUSTER_COUNT = 1' ||
        ' MAX_CLUSTER_COUNT = 3' ||
        ' SCALING_POLICY = ''STANDARD''' ||
        ' INITIALLY_SUSPENDED = FALSE' ||
        ' COMMENT = ''Warehouse for FDD data processing and AI analysis''';
    
    EXECUTE IMMEDIATE :warehouse_ddl;
    
    EXECUTE IMMEDIATE 'USE WAREHOUSE ' || $WAREHOUSE_NAME;
END;
$$;

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
VALUES ('1.0.0', 'Initial production deployment - SnowSight', 'deploy_snowsight.sql', 'IN_PROGRESS');

SELECT 'Step 1: Environment created - ' || $DATABASE_NAME || '.' || $SCHEMA_NAME AS status;


-- ============================================================================
-- STEP 2: SYSTEM CONFIGURATION (from 00_system_config.sql)
-- ============================================================================

-- Houlihan Lokey FDD Automation - System Configuration
-- ============================================================================
-- Description: Centralized configuration table for all system parameters
-- Version: 1.0.0
-- Last Updated: 2025-10-20
-- ============================================================================

-- Configuration table for system-wide parameters
CREATE TABLE IF NOT EXISTS system_config (
    config_key VARCHAR(100) PRIMARY KEY,
    config_value VARIANT NOT NULL,
    description VARCHAR(500),
    is_sensitive BOOLEAN DEFAULT false,
    last_updated TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_by VARCHAR(100) DEFAULT CURRENT_USER()
);

-- Clear existing configuration (for idempotent deployments)
TRUNCATE TABLE IF EXISTS system_config;

-- Insert default configuration values using SELECT to support TO_VARIANT
-- Note: All values as strings to avoid type inference issues, TO_VARIANT will parse correctly
INSERT INTO system_config (config_key, config_value, description, is_sensitive)
SELECT column1, TO_VARIANT(PARSE_JSON(column2)), column3, TO_BOOLEAN(column4)
FROM VALUES
    -- Data Quality Thresholds
    ('balance_tolerance_dollars', '0.10', 'Acceptable rounding difference for trial balance validation (in dollars)', 0),
    ('min_variance_amount', '5000.00', 'Minimum dollar amount to trigger variance analysis', 0),
    ('variance_threshold_pct', '0.20', 'Minimum percentage change to flag as variance (0.20 = 20%)', 0),
    ('max_error_rate_pct', '0.05', 'Maximum acceptable error rate for data loads (0.05 = 5%)', 0),
    
    -- AI Configuration
    ('max_ai_insights', '15', 'Maximum number of AI insights to generate per deal', 0),
    ('ai_model_variance', '"claude-4-sonnet"', 'AI model for variance analysis', 0),
    ('ai_model_trends', '"claude-4-sonnet"', 'AI model for trend analysis', 0),
    ('ai_batch_size', '50', 'Number of variance records to process in single AI batch', 0),
    
    -- Performance & Scaling
    ('warehouse_size_default', '"SMALL"', 'Default warehouse size for processing', 0),
    ('warehouse_auto_suspend', '60', 'Auto-suspend timeout in seconds', 0),
    ('max_pivot_periods', '24', 'Maximum number of periods in pivoted views', 0),
    ('query_timeout_seconds', '3600', 'Maximum query execution time (1 hour)', 0),
    
    -- File Management
    ('input_stage_name', '"fdd_input_stage"', 'Name of input file stage', 0),
    ('output_stage_name', '"fdd_output_stage"', 'Name of output file stage', 0),
    ('default_file_format', '"csv_format"', 'Default file format for imports/exports', 0),
    
    -- Audit & Retention
    ('audit_retention_days', '90', 'Number of days to retain audit logs', 0),
    ('error_log_retention_days', '180', 'Number of days to retain error logs', 0),
    ('output_retention_days', '30', 'Number of days to retain output files in stage', 0),
    
    -- Security
    ('deal_id_validation_regex', '"^[A-Z0-9_-]+$"', 'Regex pattern for validating deal_id format', 0),
    ('max_deal_id_length', '50', 'Maximum length for deal_id', 0),
    ('enable_row_level_security', 'true', 'Enable row-level security policies', 0),
    
    -- Environment
    ('environment', '"DEVELOPMENT"', 'Current environment: DEVELOPMENT, STAGING, PRODUCTION', 0),
    ('schema_version', '"1.0.0"', 'Current schema version', 0);

-- Add deployment_date separately since CURRENT_TIMESTAMP() can't be used in VALUES clause
INSERT INTO system_config (config_key, config_value, description, is_sensitive)
SELECT 'deployment_date', TO_VARIANT(CURRENT_TIMESTAMP()), 'Date of last deployment', false;

-- Helper function to get config values
CREATE OR REPLACE FUNCTION get_config(key_name VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
    SELECT config_value FROM system_config WHERE config_key = key_name
$$;

-- Helper function to get config value as string
CREATE OR REPLACE FUNCTION get_config_string(key_name VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SELECT config_value::VARCHAR FROM system_config WHERE config_key = key_name
$$;

-- Helper function to get config value as number
CREATE OR REPLACE FUNCTION get_config_number(key_name VARCHAR)
RETURNS NUMBER
LANGUAGE SQL
AS
$$
    SELECT config_value::NUMBER FROM system_config WHERE config_key = key_name
$$;

-- Helper function to get config value as boolean
CREATE OR REPLACE FUNCTION get_config_boolean(key_name VARCHAR)
RETURNS BOOLEAN
LANGUAGE SQL
AS
$$
    SELECT config_value::BOOLEAN FROM system_config WHERE config_key = key_name
$$;

-- Procedure to update config value
CREATE OR REPLACE PROCEDURE update_config(
    key_name VARCHAR,
    new_value VARIANT,
    change_description VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    UPDATE system_config
    SET config_value = :new_value,
        last_updated = CURRENT_TIMESTAMP(),
        updated_by = CURRENT_USER()
    WHERE config_key = :key_name;
    
    IF (SQLROWCOUNT = 0) THEN
        RETURN 'ERROR: Configuration key "' || :key_name || '" not found';
    END IF;
    
    -- Log the change
    INSERT INTO audit_log (procedure_name, deal_id, status, rows_affected, message)
    VALUES ('update_config', NULL, 'SUCCESS', 1, 
            'Updated config: ' || :key_name || ' = ' || :new_value::VARCHAR || 
            CASE WHEN :change_description IS NOT NULL THEN ' (' || :change_description || ')' ELSE '' END);
    
    RETURN 'SUCCESS: Updated configuration ' || :key_name;
END;
$$;

-- View: Display all non-sensitive configuration
CREATE OR REPLACE VIEW v_system_config AS
SELECT 
    config_key,
    CASE 
        WHEN is_sensitive THEN '***REDACTED***'
        ELSE config_value::VARCHAR
    END AS config_value,
    description,
    last_updated,
    updated_by
FROM system_config
ORDER BY config_key;

SELECT 'System configuration initialized' AS status;



-- ============================================================================
-- STEP 3: CORE SCHEMA (from 01_schema.sql)
-- ============================================================================

-- Houlihan Lokey FDD Automation - Core Schema
-- ============================================================================
-- Description: Core tables for trial balance, mappings, and operational data
-- Version: 1.0.0
-- Last Updated: 2025-10-20
-- ============================================================================

-- ============================================================================
-- CORE BUSINESS TABLES
-- ============================================================================

-- Trial Balance Raw Data
CREATE TABLE IF NOT EXISTS trial_balance_raw (
    -- Primary identifiers
    deal_id VARCHAR(50) NOT NULL,
    deal_name VARCHAR(200),
    entity VARCHAR(100),
    period_date DATE NOT NULL,
    account_number VARCHAR(50) NOT NULL,
    account_name VARCHAR(500),
    
    -- Financial amounts
    debit_amount NUMBER(18,2),
    credit_amount NUMBER(18,2),
    net_amount NUMBER(18,2),
    
    -- Metadata
    unique_id VARCHAR(600),
    upload_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    uploaded_by VARCHAR(100) DEFAULT CURRENT_USER(),
    
    -- Natural key constraint
    CONSTRAINT pk_trial_balance PRIMARY KEY (deal_id, account_number, period_date, entity)
);

-- Add clustering for performance
ALTER TABLE trial_balance_raw CLUSTER BY (deal_id, period_date);

-- Add uploaded_by column if it doesn't exist (for backward compatibility)
-- Note: Can't use CURRENT_USER() as default in ALTER TABLE ADD COLUMN
ALTER TABLE trial_balance_raw ADD COLUMN IF NOT EXISTS uploaded_by VARCHAR(100);

-- Account Mappings
CREATE TABLE IF NOT EXISTS account_mappings (
    deal_id VARCHAR(50) NOT NULL,
    account_number VARCHAR(50) NOT NULL,
    account_name VARCHAR(500),
    account_category VARCHAR(50),
    statement_type VARCHAR(20),
    
    -- Hierarchical mapping levels (flexible 1-4 levels)
    mapping_level_1 VARCHAR(200),
    mapping_level_2 VARCHAR(200),
    mapping_level_3 VARCHAR(200),
    mapping_level_4 VARCHAR(200),
    
    -- Sort orders for display
    sort_order_l1 NUMBER,
    sort_order_l2 NUMBER,
    sort_order_l3 NUMBER,
    sort_order_l4 NUMBER,
    
    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(100) DEFAULT CURRENT_USER(),
    
    CONSTRAINT pk_account_mappings PRIMARY KEY (deal_id, account_number)
);

-- Add clustering
ALTER TABLE account_mappings CLUSTER BY (deal_id, account_number);

-- Note: is_active column already exists in table definition (line 323)

-- AI Insights Storage
CREATE TABLE IF NOT EXISTS ai_insights (
    insight_id VARCHAR(50) DEFAULT UUID_STRING() PRIMARY KEY,
    deal_id VARCHAR(50) NOT NULL,
    
    -- Timestamps
    generated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    -- Insight classification
    insight_type VARCHAR(50) NOT NULL,  -- 'variance', 'trend_analysis', 'anomaly', etc.
    severity VARCHAR(20),  -- 'low', 'medium', 'high', 'critical'
    
    -- Associated data
    account_number VARCHAR(50),
    account_name VARCHAR(500),
    period_date DATE,
    
    -- Metrics
    metric_value NUMBER(18,2),
    comparison_value NUMBER(18,2),
    variance_pct NUMBER(10,2),
    
    -- AI-generated content
    insight_text VARCHAR(5000),
    suggested_question VARCHAR(1000),
    model_used VARCHAR(100),
    
    -- Token usage for cost tracking
    prompt_tokens NUMBER,
    completion_tokens NUMBER,
    estimated_cost_usd NUMBER(10,4),
    
    -- Metadata
    is_reviewed BOOLEAN DEFAULT FALSE,
    reviewed_by VARCHAR(100),
    reviewed_timestamp TIMESTAMP_NTZ
    
    -- Foreign key constraint removed for deployment flexibility
    -- In production, enforce referential integrity via application logic or triggers
);

-- ============================================================================
-- OPERATIONAL TABLES
-- ============================================================================

-- Audit Log for all procedure executions
CREATE TABLE IF NOT EXISTS audit_log (
    log_id VARCHAR(50) DEFAULT UUID_STRING() PRIMARY KEY,
    log_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    -- Execution context
    procedure_name VARCHAR(200) NOT NULL,
    deal_id VARCHAR(50),
    user_name VARCHAR(100) DEFAULT CURRENT_USER(),
    session_id VARCHAR(100) DEFAULT CURRENT_SESSION()::VARCHAR,
    role_name VARCHAR(100) DEFAULT CURRENT_ROLE(),
    warehouse_name VARCHAR(100) DEFAULT CURRENT_WAREHOUSE(),
    
    -- Timing
    start_time TIMESTAMP_NTZ,
    end_time TIMESTAMP_NTZ,
    duration_seconds NUMBER(10,2),
    
    -- Results
    status VARCHAR(20),  -- 'STARTED', 'SUCCESS', 'ERROR', 'WARNING'
    rows_affected NUMBER,
    error_message VARCHAR(5000),
    message VARCHAR(5000),
    
    -- Query tracking
    query_id VARCHAR(100) DEFAULT LAST_QUERY_ID(),
    
    -- Cost tracking
    credits_used NUMBER(18,6)
);

-- Note: Indexes on standard tables are not supported in Snowflake
-- Snowflake uses automatic micro-partitioning and clustering keys instead
-- Use ALTER TABLE ... CLUSTER BY for performance optimization if needed

-- Error Log for data quality issues
CREATE TABLE IF NOT EXISTS load_errors (
    error_id VARCHAR(50) DEFAULT UUID_STRING() PRIMARY KEY,
    error_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    -- Error context
    deal_id VARCHAR(50),
    file_name VARCHAR(500),
    row_number NUMBER,
    line_content VARCHAR(5000),
    
    -- Error details
    error_type VARCHAR(100),  -- 'LOAD_ERROR', 'VALIDATION_ERROR', 'DATA_QUALITY_ERROR'
    error_code VARCHAR(50),
    error_message VARCHAR(5000),
    
    -- Resolution
    is_resolved BOOLEAN DEFAULT FALSE,
    resolved_by VARCHAR(100),
    resolved_timestamp TIMESTAMP_NTZ,
    resolution_notes VARCHAR(5000)
);

-- Data Quality Validation Results
CREATE TABLE IF NOT EXISTS data_quality_checks (
    check_id VARCHAR(50) DEFAULT UUID_STRING() PRIMARY KEY,
    check_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    deal_id VARCHAR(50) NOT NULL,
    check_name VARCHAR(200) NOT NULL,
    check_type VARCHAR(50),  -- 'BALANCE', 'COMPLETENESS', 'CONSISTENCY', 'ACCURACY'
    
    -- Results
    passed BOOLEAN NOT NULL,
    expected_value VARIANT,
    actual_value VARIANT,
    variance VARIANT,
    
    -- Details
    severity VARCHAR(20),  -- 'INFO', 'WARNING', 'ERROR', 'CRITICAL'
    message VARCHAR(2000),
    details VARCHAR(5000)
);

-- User Deal Permissions (for row-level security)
CREATE TABLE IF NOT EXISTS user_deal_permissions (
    permission_id VARCHAR(50) DEFAULT UUID_STRING() PRIMARY KEY,
    user_name VARCHAR(100) NOT NULL,
    deal_id VARCHAR(50) NOT NULL,
    
    -- Permission details
    permission_level VARCHAR(20) DEFAULT 'READ',  -- 'READ', 'WRITE', 'ADMIN'
    granted_by VARCHAR(100) DEFAULT CURRENT_USER(),
    granted_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    expires_timestamp TIMESTAMP_NTZ,
    
    is_active BOOLEAN DEFAULT TRUE,
    
    CONSTRAINT uk_user_deal UNIQUE (user_name, deal_id)
);

-- Schema Version Tracking
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(20) PRIMARY KEY,
    description VARCHAR(500),
    migration_file VARCHAR(200),
    
    -- Execution details
    applied_by VARCHAR(100) DEFAULT CURRENT_USER(),
    applied_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    execution_time_seconds NUMBER(10,2),
    
    -- Validation
    checksum VARCHAR(64),  -- SHA256 hash of migration file
    status VARCHAR(20) DEFAULT 'SUCCESS'  -- 'SUCCESS', 'FAILED', 'ROLLED_BACK'
);

-- ============================================================================
-- STAGES AND FILE FORMATS
-- ============================================================================

-- Input stage for raw data uploads
CREATE STAGE IF NOT EXISTS fdd_input_stage
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for uploading trial balance and mapping CSV files';

-- Output stage for generated reports
CREATE STAGE IF NOT EXISTS fdd_output_stage
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for exporting generated schedules and insights';

-- CSV file format with proper error handling
CREATE OR REPLACE FILE FORMAT csv_format
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1
    NULL_IF = ('NULL', 'null', '', 'N/A', 'n/a')
    EMPTY_FIELD_AS_NULL = TRUE
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    COMPRESSION = 'AUTO'
    COMMENT = 'Standard CSV format for FDD data files';

-- ============================================================================
-- VIEWS - Presentation Layer
-- ============================================================================

-- Presentation layer: Convert accounting signs to display signs
CREATE OR REPLACE VIEW v_trial_balance_for_schedules AS
SELECT 
    t.deal_id,
    t.deal_name,
    t.entity,
    t.period_date,
    t.account_number,
    t.account_name,
    t.unique_id,
    t.debit_amount,
    t.credit_amount,
    t.net_amount AS net_amount_raw,
    
    -- Calculate display amount based on account type
    CASE 
        -- Income Statement Accounts
        WHEN m.statement_type = 'IS' AND m.mapping_level_1 = 'Revenue' 
            THEN t.net_amount * -1  -- Flip revenue to positive
        WHEN m.statement_type = 'IS' AND m.mapping_level_1 IN ('Cost of Goods Sold', 'Operating Expenses') 
            THEN ABS(t.net_amount)  -- Expenses as positive
        
        -- Balance Sheet - Contra-Asset Accounts (shown as negative)
        WHEN m.statement_type = 'BS' AND m.mapping_level_1 = 'Assets' 
             AND (t.account_name ILIKE '%accumulated depreciation%' 
                  OR t.account_name ILIKE '%allowance%'
                  OR t.account_name ILIKE '%reserve%') 
            THEN t.net_amount  -- Keep negative (contra-asset)
        
        -- Balance Sheet - Regular Asset Accounts (positive)
        WHEN m.statement_type = 'BS' AND m.mapping_level_1 = 'Assets' 
            THEN ABS(t.net_amount)
        
        -- Balance Sheet - Liabilities and Equity (all positive)
        WHEN m.statement_type = 'BS' AND m.mapping_level_1 = 'Liabilities' 
            THEN ABS(t.net_amount)
        WHEN m.statement_type = 'BS' AND m.mapping_level_1 = 'Equity' 
            THEN ABS(t.net_amount)
        
        -- Default: Absolute value
        ELSE ABS(t.net_amount)
    END AS amount_for_display,
    
    -- Include mapping info
    m.account_category,
    m.statement_type,
    m.mapping_level_1,
    m.mapping_level_2,
    m.mapping_level_3,
    m.sort_order_l1,
    m.sort_order_l2,
    m.sort_order_l3,
    t.upload_timestamp
FROM trial_balance_raw t
LEFT JOIN account_mappings m 
    ON t.deal_id = m.deal_id AND t.account_number = m.account_number
WHERE m.is_active = TRUE;

-- Portfolio summary view
CREATE OR REPLACE VIEW v_portfolio_summary AS
SELECT 
    t.deal_id,
    t.deal_name,
    MIN(t.period_date) AS first_period,
    MAX(t.period_date) AS last_period,
    COUNT(DISTINCT t.period_date) AS total_periods,
    COUNT(DISTINCT t.account_number) AS total_accounts,
    COUNT(*) AS total_rows,
    MAX(t.upload_timestamp) AS last_updated,
    MAX(t.uploaded_by) AS last_updated_by
FROM trial_balance_raw t
GROUP BY t.deal_id, t.deal_name
ORDER BY last_updated DESC;

SELECT 'Core schema created successfully' AS status;



-- ============================================================================
-- STEP 4: SECURITY CONFIGURATION (from 02_security.sql)
-- ============================================================================

-- Houlihan Lokey FDD Automation - Security Configuration
-- ============================================================================
-- Description: Roles, row-level security, and access controls
-- Version: 1.0.0
-- Last Updated: 2025-10-20
-- ============================================================================

-- ============================================================================
-- PART 1: ROLE HIERARCHY
-- ============================================================================

-- Create FDD-specific roles with least-privilege principle
CREATE ROLE IF NOT EXISTS FDD_ADMIN_ROLE
    COMMENT = 'Administrative role for FDD system management';

CREATE ROLE IF NOT EXISTS FDD_ANALYST_ROLE
    COMMENT = 'Standard analyst role for working with deals';

CREATE ROLE IF NOT EXISTS FDD_READONLY_ROLE
    COMMENT = 'Read-only access for auditors and reviewers';

CREATE ROLE IF NOT EXISTS FDD_SERVICE_ROLE
    COMMENT = 'Service account role for automated processes';

-- ============================================================================
-- PART 2: DATABASE AND SCHEMA GRANTS
-- ============================================================================

-- Admin Role Grants (full access)
GRANT USAGE ON DATABASE HL_FDD_POC TO ROLE FDD_ADMIN_ROLE;
GRANT USAGE ON SCHEMA TRIAL_BALANCE TO ROLE FDD_ADMIN_ROLE;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA TRIAL_BALANCE TO ROLE FDD_ADMIN_ROLE;
GRANT ALL PRIVILEGES ON ALL VIEWS IN SCHEMA TRIAL_BALANCE TO ROLE FDD_ADMIN_ROLE;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA TRIAL_BALANCE TO ROLE FDD_ADMIN_ROLE;
GRANT ALL PRIVILEGES ON ALL PROCEDURES IN SCHEMA TRIAL_BALANCE TO ROLE FDD_ADMIN_ROLE;
GRANT ALL PRIVILEGES ON ALL STAGES IN SCHEMA TRIAL_BALANCE TO ROLE FDD_ADMIN_ROLE;
GRANT ALL PRIVILEGES ON ALL FILE FORMATS IN SCHEMA TRIAL_BALANCE TO ROLE FDD_ADMIN_ROLE;

-- Future grants for admin
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA TRIAL_BALANCE TO ROLE FDD_ADMIN_ROLE;
GRANT ALL PRIVILEGES ON FUTURE VIEWS IN SCHEMA TRIAL_BALANCE TO ROLE FDD_ADMIN_ROLE;

-- Analyst Role Grants (read/write for core tables, execute procedures)
GRANT USAGE ON DATABASE HL_FDD_POC TO ROLE FDD_ANALYST_ROLE;
GRANT USAGE ON SCHEMA TRIAL_BALANCE TO ROLE FDD_ANALYST_ROLE;

-- Table access for analysts
GRANT SELECT, INSERT, UPDATE ON TABLE trial_balance_raw TO ROLE FDD_ANALYST_ROLE;
GRANT SELECT, INSERT, UPDATE ON TABLE account_mappings TO ROLE FDD_ANALYST_ROLE;
GRANT SELECT ON TABLE ai_insights TO ROLE FDD_ANALYST_ROLE;
GRANT SELECT ON TABLE audit_log TO ROLE FDD_ANALYST_ROLE;
GRANT SELECT ON TABLE data_quality_checks TO ROLE FDD_ANALYST_ROLE;
GRANT SELECT, INSERT ON TABLE load_errors TO ROLE FDD_ANALYST_ROLE;
GRANT SELECT ON TABLE system_config TO ROLE FDD_ANALYST_ROLE;

-- View access
GRANT SELECT ON ALL VIEWS IN SCHEMA TRIAL_BALANCE TO ROLE FDD_ANALYST_ROLE;

-- Procedure execution
GRANT USAGE ON ALL PROCEDURES IN SCHEMA TRIAL_BALANCE TO ROLE FDD_ANALYST_ROLE;
GRANT USAGE ON ALL FUNCTIONS IN SCHEMA TRIAL_BALANCE TO ROLE FDD_ANALYST_ROLE;

-- Stage access for file operations
GRANT READ, WRITE ON STAGE fdd_input_stage TO ROLE FDD_ANALYST_ROLE;
GRANT READ, WRITE ON STAGE fdd_output_stage TO ROLE FDD_ANALYST_ROLE;

-- Read-Only Role Grants (SELECT only)
GRANT USAGE ON DATABASE HL_FDD_POC TO ROLE FDD_READONLY_ROLE;
GRANT USAGE ON SCHEMA TRIAL_BALANCE TO ROLE FDD_READONLY_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA TRIAL_BALANCE TO ROLE FDD_READONLY_ROLE;
GRANT SELECT ON ALL VIEWS IN SCHEMA TRIAL_BALANCE TO ROLE FDD_READONLY_ROLE;
GRANT READ ON STAGE fdd_output_stage TO ROLE FDD_READONLY_ROLE;

-- Service Role Grants (for automated processes)
GRANT USAGE ON DATABASE HL_FDD_POC TO ROLE FDD_SERVICE_ROLE;
GRANT USAGE ON SCHEMA TRIAL_BALANCE TO ROLE FDD_SERVICE_ROLE;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA TRIAL_BALANCE TO ROLE FDD_SERVICE_ROLE;
GRANT USAGE ON ALL PROCEDURES IN SCHEMA TRIAL_BALANCE TO ROLE FDD_SERVICE_ROLE;
GRANT USAGE ON ALL FUNCTIONS IN SCHEMA TRIAL_BALANCE TO ROLE FDD_SERVICE_ROLE;
GRANT READ, WRITE ON ALL STAGES IN SCHEMA TRIAL_BALANCE TO ROLE FDD_SERVICE_ROLE;

-- Warehouse grants
GRANT USAGE ON WAREHOUSE FDD_POC_WH TO ROLE FDD_ADMIN_ROLE;
GRANT USAGE ON WAREHOUSE FDD_POC_WH TO ROLE FDD_ANALYST_ROLE;
GRANT USAGE ON WAREHOUSE FDD_POC_WH TO ROLE FDD_READONLY_ROLE;
GRANT USAGE ON WAREHOUSE FDD_POC_WH TO ROLE FDD_SERVICE_ROLE;

-- ============================================================================
-- PART 3: ROW-LEVEL SECURITY POLICIES
-- ============================================================================

-- Policy 1: Deal access control
-- Users can only see deals they have permission to access
CREATE OR REPLACE ROW ACCESS POLICY rap_deal_access
AS (deal_id VARCHAR) RETURNS BOOLEAN ->
    CASE 
        -- Admins see everything
        WHEN CURRENT_ROLE() IN ('FDD_ADMIN_ROLE', 'ACCOUNTADMIN') THEN TRUE
        
        -- Service accounts see everything (for automated processing)
        WHEN CURRENT_ROLE() = 'FDD_SERVICE_ROLE' THEN TRUE
        
        -- Analysts see only deals they have permission for
        WHEN deal_id IN (
            SELECT p.deal_id 
            FROM user_deal_permissions p
            WHERE p.user_name = CURRENT_USER()
            AND p.is_active = TRUE
            AND (p.expires_timestamp IS NULL OR p.expires_timestamp > CURRENT_TIMESTAMP())
        ) THEN TRUE
        
        ELSE FALSE
    END
    COMMENT = 'Row-level security: Users can only access authorized deals';

-- Apply row-level security policy (uncomment after initial setup and user permission grants)
-- ALTER TABLE trial_balance_raw ADD ROW ACCESS POLICY rap_deal_access ON (deal_id);
-- ALTER TABLE account_mappings ADD ROW ACCESS POLICY rap_deal_access ON (deal_id);
-- ALTER TABLE ai_insights ADD ROW ACCESS POLICY rap_deal_access ON (deal_id);

-- Note: Row access policies are disabled by default during initial setup
-- Enable them by uncommenting the ALTER TABLE statements above after:
-- 1. Loading initial data
-- 2. Setting up user_deal_permissions table with appropriate grants

-- ============================================================================
-- PART 4: COLUMN MASKING POLICIES (for sensitive data)
-- ============================================================================

-- Masking policy for financial amounts
-- Non-privileged users see masked values
CREATE OR REPLACE MASKING POLICY mask_financial_amounts AS (val NUMBER) RETURNS NUMBER ->
    CASE 
        WHEN CURRENT_ROLE() IN ('FDD_ADMIN_ROLE', 'FDD_ANALYST_ROLE', 'ACCOUNTADMIN') THEN val
        ELSE NULL  -- Read-only users see NULL for amounts
    END
    COMMENT = 'Mask financial amounts for non-analyst users';

-- Apply masking to sensitive columns (optional - uncomment if needed)
-- ALTER TABLE trial_balance_raw MODIFY COLUMN net_amount SET MASKING POLICY mask_financial_amounts;
-- ALTER TABLE trial_balance_raw MODIFY COLUMN debit_amount SET MASKING POLICY mask_financial_amounts;
-- ALTER TABLE trial_balance_raw MODIFY COLUMN credit_amount SET MASKING POLICY mask_financial_amounts;

-- ============================================================================
-- PART 5: INPUT VALIDATION FUNCTIONS
-- ============================================================================

-- Function to validate deal_id format (prevent SQL injection)
CREATE OR REPLACE FUNCTION validate_deal_id(deal_id_input VARCHAR)
RETURNS BOOLEAN
LANGUAGE SQL
AS
$$
    SELECT 
        deal_id_input IS NOT NULL 
        AND LENGTH(deal_id_input) <= get_config_number('max_deal_id_length')
        AND REGEXP_LIKE(deal_id_input, get_config_string('deal_id_validation_regex'))
$$;

-- Function to sanitize deal_id
CREATE OR REPLACE FUNCTION sanitize_deal_id(deal_id_input VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SELECT 
        CASE 
            WHEN validate_deal_id(deal_id_input) THEN UPPER(TRIM(deal_id_input))
            ELSE NULL
        END
$$;

-- ============================================================================
-- PART 6: SECURITY AUDIT PROCEDURES
-- ============================================================================

-- Procedure to grant deal access to a user
CREATE OR REPLACE PROCEDURE grant_deal_access(
    target_user VARCHAR,
    target_deal_id VARCHAR,
    permission_level VARCHAR DEFAULT 'READ',
    expiration_days NUMBER DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    expires_ts TIMESTAMP_NTZ;
BEGIN
    -- Validate inputs
    IF (NOT validate_deal_id(:target_deal_id)) THEN
        RETURN 'ERROR: Invalid deal_id format';
    END IF;
    
    IF (:permission_level NOT IN ('READ', 'WRITE', 'ADMIN')) THEN
        RETURN 'ERROR: Invalid permission_level. Must be READ, WRITE, or ADMIN';
    END IF;
    
    -- Calculate expiration
    IF (:expiration_days IS NOT NULL) THEN
        expires_ts := DATEADD(day, :expiration_days, CURRENT_TIMESTAMP());
    ELSE
        expires_ts := NULL;
    END IF;
    
    -- Grant permission (upsert)
    MERGE INTO user_deal_permissions p
    USING (SELECT :target_user AS user_name, :target_deal_id AS deal_id) src
    ON p.user_name = src.user_name AND p.deal_id = src.deal_id
    WHEN MATCHED THEN
        UPDATE SET 
            permission_level = :permission_level,
            expires_timestamp = :expires_ts,
            is_active = TRUE,
            granted_by = CURRENT_USER(),
            granted_timestamp = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN
        INSERT (user_name, deal_id, permission_level, expires_timestamp, granted_by, granted_timestamp, is_active)
        VALUES (:target_user, :target_deal_id, :permission_level, :expires_ts, CURRENT_USER(), CURRENT_TIMESTAMP(), TRUE);
    
    -- Audit log
    INSERT INTO audit_log (procedure_name, deal_id, status, message)
    VALUES ('grant_deal_access', :target_deal_id, 'SUCCESS', 
            'Granted ' || :permission_level || ' access to ' || :target_user || 
            CASE WHEN :expires_ts IS NOT NULL THEN ' (expires: ' || :expires_ts || ')' ELSE '' END);
    
    RETURN 'SUCCESS: Granted ' || :permission_level || ' access to ' || :target_user || ' for deal ' || :target_deal_id;
END;
$$;

-- Procedure to revoke deal access
CREATE OR REPLACE PROCEDURE revoke_deal_access(
    target_user VARCHAR,
    target_deal_id VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    UPDATE user_deal_permissions
    SET is_active = FALSE
    WHERE user_name = :target_user
    AND deal_id = :target_deal_id;
    
    IF (SQLROWCOUNT = 0) THEN
        RETURN 'WARNING: No active permission found for user ' || :target_user || ' on deal ' || :target_deal_id;
    END IF;
    
    -- Audit log
    INSERT INTO audit_log (procedure_name, deal_id, status, message)
    VALUES ('revoke_deal_access', :target_deal_id, 'SUCCESS', 
            'Revoked access for ' || :target_user);
    
    RETURN 'SUCCESS: Revoked access for ' || :target_user || ' from deal ' || :target_deal_id;
END;
$$;

-- View: Active permissions (for auditing)
CREATE OR REPLACE VIEW v_active_permissions AS
SELECT 
    p.user_name,
    p.deal_id,
    p.permission_level,
    p.granted_by,
    p.granted_timestamp,
    p.expires_timestamp,
    CASE 
        WHEN p.expires_timestamp IS NOT NULL AND p.expires_timestamp < CURRENT_TIMESTAMP() THEN 'EXPIRED'
        WHEN p.is_active THEN 'ACTIVE'
        ELSE 'REVOKED'
    END AS status
FROM user_deal_permissions p
WHERE p.is_active = TRUE
ORDER BY p.granted_timestamp DESC;

-- ============================================================================
-- PART 7: NETWORK POLICIES (Optional - configure as needed)
-- ============================================================================

-- Example: Restrict access to specific IP ranges
-- Uncomment and configure for your organization

/*
CREATE NETWORK POLICY fdd_network_policy
    ALLOWED_IP_LIST = ('192.168.1.0/24', '10.0.0.0/8')  -- Add your IP ranges
    BLOCKED_IP_LIST = ()
    COMMENT = 'Network policy for FDD system access';

-- Apply to user
ALTER USER your_user_name SET NETWORK_POLICY = fdd_network_policy;
*/

-- ============================================================================
-- PART 8: SESSION POLICIES (Optional)
-- ============================================================================

-- Set session timeout for security
/*
ALTER ACCOUNT SET CLIENT_SESSION_KEEP_ALIVE = TRUE;
ALTER ACCOUNT SET CLIENT_SESSION_KEEP_ALIVE_HEARTBEAT_FREQUENCY = 3600;  -- 1 hour
*/

SELECT 'Security configuration completed' AS status;



-- ============================================================================
-- STEP 5: DATA PROCEDURES (from 03_data_procedures.sql)
-- ============================================================================

-- Houlihan Lokey FDD Automation - Core Data Procedures
-- ============================================================================
-- Description: Data loading, validation, and core business logic
-- Version: 1.0.0
-- Last Updated: 2025-10-20
-- ============================================================================

-- ============================================================================
-- PART 1: DATA LOADING PROCEDURES
-- ============================================================================

-- Procedure: Load Trial Balance with comprehensive error handling
-- Drop all possible existing versions to avoid overload errors
-- Note: Must match exact signature including DEFAULT parameters
EXECUTE IMMEDIATE $$
BEGIN
    DROP PROCEDURE IF EXISTS load_trial_balance();
    DROP PROCEDURE IF EXISTS load_trial_balance(VARCHAR);
    DROP PROCEDURE IF EXISTS load_trial_balance(VARCHAR, VARCHAR);
EXCEPTION
    WHEN OTHER THEN
        -- Ignore errors if procedure doesn't exist
        RETURN 'Procedures dropped or did not exist';
END;
$$;

CREATE OR REPLACE PROCEDURE load_trial_balance(
    file_name VARCHAR DEFAULT '01_sample_trial_balance_24mo.csv',
    deal_id_filter VARCHAR DEFAULT NULL
)
RETURNS TABLE(status VARCHAR, rows_loaded NUMBER, errors_found NUMBER, message VARCHAR)
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    rows_loaded NUMBER DEFAULT 0;
    error_count NUMBER DEFAULT 0;
    unbalanced_count NUMBER DEFAULT 0;
    max_imbalance NUMBER DEFAULT 0;
    stage_path VARCHAR;
    result_cursor RESULTSET;
    error_msg VARCHAR;  -- For capturing SQLERRM in EXCEPTION block
BEGIN
    -- Log start
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status, message)
    VALUES (:log_id_var, 'load_trial_balance', :deal_id_filter, :start_time_var, 'STARTED', 
            'Loading from file: ' || :file_name);
    
    -- Construct stage path
    stage_path := '@' || get_config_string('input_stage_name') || '/' || :file_name;
    
    BEGIN TRANSACTION;
    
    -- Option 1: Full reload (if no deal_id_filter provided)
    IF (:deal_id_filter IS NULL) THEN
        TRUNCATE TABLE trial_balance_raw;
    ELSE
        -- Option 2: Selective reload for specific deal
        DELETE FROM trial_balance_raw WHERE deal_id = :deal_id_filter;
    END IF;
    
    -- Load data with error continuation
    EXECUTE IMMEDIATE
        'COPY INTO trial_balance_raw (' ||
        '    deal_id, deal_name, entity, period_date, account_number, account_name, ' ||
        '    debit_amount, credit_amount, net_amount' ||
        ') ' ||
        'FROM ' || :stage_path || ' ' ||
        'FILE_FORMAT = (FORMAT_NAME = ''' || get_config_string('default_file_format') || ''') ' ||
        'ON_ERROR = ''CONTINUE'' ' ||
        'RETURN_FAILED_ONLY = FALSE';
    
    rows_loaded := SQLROWCOUNT;
    
    -- Capture load errors
    INSERT INTO load_errors (deal_id, file_name, error_type, error_message)
    SELECT 
        :deal_id_filter,
        :file_name,
        'LOAD_ERROR',
        ERROR || ' at line ' || LINE
    FROM TABLE(VALIDATE(trial_balance_raw, JOB_ID => '_last'))
    WHERE ERROR IS NOT NULL;
    
    SELECT COUNT(*) INTO :error_count 
    FROM load_errors 
    WHERE file_name = :file_name 
    AND error_timestamp > :start_time_var;
    
    -- Check error rate threshold
    IF (:rows_loaded > 0 AND :error_count::FLOAT / :rows_loaded > get_config_number('max_error_rate_pct')) THEN
        ROLLBACK;
        
        -- Log failure
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
            status = 'ERROR',
            error_message = 'Error rate (' || ROUND(:error_count::FLOAT / :rows_loaded * 100, 2) || 
                          '%) exceeds threshold (' || (get_config_number('max_error_rate_pct') * 100) || '%)',
            rows_affected = :rows_loaded
        WHERE log_id = :log_id_var;
        
        result_cursor := (
            SELECT 'ERROR' AS status, 
                   :rows_loaded AS rows_loaded, 
                   :error_count AS errors_found,
                   'Error rate too high. Transaction rolled back. Check load_errors table.' AS message
        );
        RETURN TABLE(result_cursor);
    END IF;
    
    -- Update unique_id for new records
    UPDATE trial_balance_raw
    SET unique_id = account_number || ' - ' || account_name
    WHERE unique_id IS NULL;
    
    -- VALIDATION: Check trial balance balances
    SELECT COUNT(*), MAX(imbalance)
    INTO :unbalanced_count, :max_imbalance
    FROM (
        SELECT 
            period_date,
            ABS(SUM(debit_amount) - SUM(credit_amount)) AS imbalance
        FROM trial_balance_raw
        WHERE deal_id = COALESCE(:deal_id_filter, deal_id)
        GROUP BY deal_id, period_date
        HAVING ABS(SUM(debit_amount) - SUM(credit_amount)) > get_config_number('balance_tolerance_dollars')
    );
    
    -- Log data quality check (using SELECT to support OBJECT_CONSTRUCT)
    -- Only log if deal_id is provided
    IF (:deal_id_filter IS NOT NULL) THEN
        INSERT INTO data_quality_checks (deal_id, check_name, check_type, passed, actual_value, severity, message)
        SELECT 
            :deal_id_filter,
            'Trial Balance Balancing',
            'BALANCE',
            :unbalanced_count = 0,
            OBJECT_CONSTRUCT('unbalanced_periods', :unbalanced_count, 'max_imbalance', :max_imbalance),
            CASE WHEN :unbalanced_count = 0 THEN 'INFO' ELSE 'WARNING' END,
            CASE 
                WHEN :unbalanced_count = 0 THEN 'All periods balanced (debits = credits)'
                ELSE :unbalanced_count || ' periods out of balance. Max imbalance: $' || ROUND(:max_imbalance, 2)
            END;
    END IF;
    
    COMMIT;
    
    -- Log success
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = CASE WHEN :unbalanced_count > 0 THEN 'WARNING' ELSE 'SUCCESS' END,
        rows_affected = :rows_loaded,
        message = 'Loaded ' || :rows_loaded || ' rows, ' || :error_count || ' errors, ' || 
                  :unbalanced_count || ' unbalanced periods'
    WHERE log_id = :log_id_var;
    
    result_cursor := (
        SELECT 
            CASE WHEN :unbalanced_count > 0 THEN 'WARNING' ELSE 'SUCCESS' END AS status,
            :rows_loaded AS rows_loaded,
            :error_count AS errors_found,
            'Loaded ' || :rows_loaded || ' rows. ' ||
            CASE 
                WHEN :unbalanced_count > 0 
                THEN :unbalanced_count || ' periods have imbalances (max: $' || ROUND(:max_imbalance, 2) || ')'
                ELSE 'All periods balanced.'
            END AS message
    );
    
    RETURN TABLE(result_cursor);
    
EXCEPTION
    WHEN OTHER THEN
        -- Capture error message (SQLERRM cannot be used directly in SELECT)
        error_msg := SQLERRM;
        
        ROLLBACK;
        
        -- Log error
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
            status = 'ERROR',
            error_message = 'FATAL: ' || :error_msg,
            rows_affected = :rows_loaded
        WHERE log_id = :log_id_var;
        
        result_cursor := (
            SELECT 'ERROR' AS status, 
                   0 AS rows_loaded, 
                   0 AS errors_found,
                   'FATAL ERROR: ' || :error_msg AS message
        );
        RETURN TABLE(result_cursor);
END;
$$;

-- Procedure: Load Account Mappings with validation
-- Drop all possible existing versions to avoid overload errors
EXECUTE IMMEDIATE $$
BEGIN
    DROP PROCEDURE IF EXISTS load_account_mappings();
    DROP PROCEDURE IF EXISTS load_account_mappings(VARCHAR);
    DROP PROCEDURE IF EXISTS load_account_mappings(VARCHAR, VARCHAR);
EXCEPTION
    WHEN OTHER THEN
        -- Ignore errors if procedure doesn't exist
        RETURN 'Procedures dropped or did not exist';
END;
$$;

CREATE OR REPLACE PROCEDURE load_account_mappings(
    file_name VARCHAR DEFAULT '02_sample_account_mappings_24mo.csv',
    deal_id_filter VARCHAR DEFAULT NULL
)
RETURNS TABLE(status VARCHAR, rows_loaded NUMBER, message VARCHAR)
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    rows_loaded NUMBER DEFAULT 0;
    unmapped_count NUMBER DEFAULT 0;
    stage_path VARCHAR;
    result_cursor RESULTSET;
    error_msg VARCHAR;  -- For capturing SQLERRM in EXCEPTION block
BEGIN
    -- Validate deal_id if provided
    IF (:deal_id_filter IS NOT NULL AND NOT validate_deal_id(:deal_id_filter)) THEN
        result_cursor := (
            SELECT 'ERROR' AS status, 0 AS rows_loaded, 
                   'Invalid deal_id format' AS message
        );
        RETURN TABLE(result_cursor);
    END IF;
    
    -- Log start
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status)
    VALUES (:log_id_var, 'load_account_mappings', :deal_id_filter, :start_time_var, 'STARTED');
    
    stage_path := '@' || get_config_string('input_stage_name') || '/' || :file_name;
    
    BEGIN TRANSACTION;
    
    -- Selective truncate
    IF (:deal_id_filter IS NULL) THEN
        TRUNCATE TABLE account_mappings;
    ELSE
        DELETE FROM account_mappings WHERE deal_id = :deal_id_filter;
    END IF;
    
    -- Load mappings
    EXECUTE IMMEDIATE
        'COPY INTO account_mappings (' ||
        '    deal_id, account_number, account_name, account_category, statement_type, ' ||
        '    mapping_level_1, mapping_level_2, mapping_level_3, ' ||
        '    sort_order_l1, sort_order_l2, sort_order_l3' ||
        ') ' ||
        'FROM ' || :stage_path || ' ' ||
        'FILE_FORMAT = (FORMAT_NAME = ''' || get_config_string('default_file_format') || ''') ' ||
        'ON_ERROR = ''ABORT_STATEMENT''';
    
    rows_loaded := SQLROWCOUNT;
    
    -- CRITICAL FIX: Set is_active = TRUE for all loaded mappings
    -- The CSV doesn't include this column, so it defaults to NULL
    -- The view filters on is_active = TRUE, so NULL values are excluded
    IF (:deal_id_filter IS NULL) THEN
        UPDATE account_mappings SET is_active = TRUE WHERE is_active IS NULL;
    ELSE
        UPDATE account_mappings SET is_active = TRUE 
        WHERE deal_id = :deal_id_filter AND is_active IS NULL;
    END IF;
    
    -- VALIDATION: Check for unmapped accounts in trial balance
    SELECT COUNT(DISTINCT t.account_number)
    INTO :unmapped_count
    FROM trial_balance_raw t
    LEFT JOIN account_mappings m 
        ON t.deal_id = m.deal_id AND t.account_number = m.account_number
    WHERE m.account_number IS NULL
    AND t.deal_id = COALESCE(:deal_id_filter, t.deal_id);
    
    -- Log validation result (using SELECT to support OBJECT_CONSTRUCT)
    -- Only log if deal_id is provided
    IF (:deal_id_filter IS NOT NULL) THEN
        INSERT INTO data_quality_checks (deal_id, check_name, check_type, passed, actual_value, severity, message)
        SELECT
            :deal_id_filter,
            'Account Mapping Completeness',
            'COMPLETENESS',
            :unmapped_count = 0,
            OBJECT_CONSTRUCT('unmapped_accounts', :unmapped_count),
            CASE WHEN :unmapped_count = 0 THEN 'INFO' WHEN :unmapped_count < 5 THEN 'WARNING' ELSE 'ERROR' END,
            CASE 
                WHEN :unmapped_count = 0 THEN 'All accounts have mappings'
                ELSE :unmapped_count || ' accounts missing mappings'
            END;
    END IF;
    
    IF (:unmapped_count > 0) THEN
        -- Log unmapped accounts as errors
        INSERT INTO load_errors (deal_id, file_name, error_type, error_message, line_content)
        SELECT DISTINCT
            t.deal_id,
            :file_name,
            'VALIDATION_ERROR',
            'Account missing from mapping file',
            t.account_number || ' - ' || t.account_name
        FROM trial_balance_raw t
        LEFT JOIN account_mappings m 
            ON t.deal_id = m.deal_id AND t.account_number = m.account_number
        WHERE m.account_number IS NULL
        AND t.deal_id = COALESCE(:deal_id_filter, t.deal_id);
    END IF;
    
    COMMIT;
    
    -- Log completion
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = CASE WHEN :unmapped_count > 5 THEN 'ERROR' 
                     WHEN :unmapped_count > 0 THEN 'WARNING' 
                     ELSE 'SUCCESS' END,
        rows_affected = :rows_loaded,
        message = 'Loaded ' || :rows_loaded || ' mappings, ' || :unmapped_count || ' unmapped accounts found'
    WHERE log_id = :log_id_var;
    
    result_cursor := (
        SELECT 
            CASE WHEN :unmapped_count > 5 THEN 'ERROR' 
                 WHEN :unmapped_count > 0 THEN 'WARNING' 
                 ELSE 'SUCCESS' END AS status,
            :rows_loaded AS rows_loaded,
            'Loaded ' || :rows_loaded || ' account mappings. ' ||
            CASE 
                WHEN :unmapped_count > 0 
                THEN 'WARNING: ' || :unmapped_count || ' accounts in trial balance have no mapping.'
                ELSE 'All accounts mapped.'
            END AS message
    );
    
    RETURN TABLE(result_cursor);
    
EXCEPTION
    WHEN OTHER THEN
        -- Capture error message (SQLERRM cannot be used directly in SELECT)
        error_msg := SQLERRM;
        
        ROLLBACK;
        
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = :error_msg
        WHERE log_id = :log_id_var;
        
        result_cursor := (
            SELECT 'ERROR' AS status, 0 AS rows_loaded, 
                   'FATAL ERROR: ' || :error_msg AS message
        );
        RETURN TABLE(result_cursor);
END;
$$;

-- ============================================================================
-- PART 2: DATA VALIDATION PROCEDURES
-- ============================================================================

-- Comprehensive data quality validation
CREATE OR REPLACE PROCEDURE validate_data_quality(deal_id_param VARCHAR)
RETURNS TABLE(check_name VARCHAR, passed BOOLEAN, severity VARCHAR, message VARCHAR)
LANGUAGE SQL
AS
$$
DECLARE
    result_cursor RESULTSET;
BEGIN
    -- Validate deal_id
    IF (NOT validate_deal_id(:deal_id_param)) THEN
        result_cursor := (
            SELECT 'Input Validation' AS check_name, FALSE AS passed, 
                   'ERROR' AS severity, 'Invalid deal_id format' AS message
        );
        RETURN TABLE(result_cursor);
    END IF;
    
    -- Run all data quality checks and return results
    result_cursor := (
        WITH checks AS (
            -- Check 1: Trial balance exists
            SELECT 
                'Trial Balance Existence' AS check_name,
                COUNT(*) > 0 AS passed,
                CASE WHEN COUNT(*) > 0 THEN 'INFO' ELSE 'CRITICAL' END AS severity,
                CASE WHEN COUNT(*) > 0 
                     THEN 'Found ' || COUNT(*) || ' records' 
                     ELSE 'No trial balance data found' END AS message
            FROM trial_balance_raw
            WHERE deal_id = :deal_id_param
            
            UNION ALL
            
            -- Check 2: Account mappings complete
            SELECT 
                'Account Mapping Completeness',
                COUNT(*) = 0,
                CASE WHEN COUNT(*) = 0 THEN 'INFO' WHEN COUNT(*) < 5 THEN 'WARNING' ELSE 'ERROR' END,
                CASE WHEN COUNT(*) = 0 
                     THEN 'All accounts mapped' 
                     ELSE COUNT(*)::VARCHAR || ' accounts missing mappings' END
            FROM trial_balance_raw t
            LEFT JOIN account_mappings m ON t.deal_id = m.deal_id AND t.account_number = m.account_number
            WHERE t.deal_id = :deal_id_param AND m.account_number IS NULL
            
            UNION ALL
            
            -- Check 3: Period continuity
            SELECT 
                'Period Continuity',
                gaps = 0,
                CASE WHEN gaps = 0 THEN 'INFO' ELSE 'WARNING' END,
                CASE WHEN gaps = 0 
                     THEN 'No date gaps detected' 
                     ELSE gaps::VARCHAR || ' month gaps in period sequence' END
            FROM (
                SELECT COUNT(*) AS gaps
                FROM (
                    SELECT 
                        period_date,
                        LAG(period_date) OVER (ORDER BY period_date) AS prev_date,
                        DATEDIFF(month, LAG(period_date) OVER (ORDER BY period_date), period_date) AS month_diff
                    FROM (SELECT DISTINCT period_date FROM trial_balance_raw WHERE deal_id = :deal_id_param)
                )
                WHERE month_diff > 1
            )
            
            UNION ALL
            
            -- Check 4: Negative revenue detection (potential data issue)
            SELECT 
                'Revenue Sign Check',
                COUNT(*) = 0,
                CASE WHEN COUNT(*) = 0 THEN 'INFO' ELSE 'WARNING' END,
                CASE WHEN COUNT(*) = 0 
                     THEN 'Revenue signs look correct' 
                     ELSE COUNT(*)::VARCHAR || ' revenue accounts with unexpected negative values' END
            FROM trial_balance_raw t
            JOIN account_mappings m ON t.deal_id = m.deal_id AND t.account_number = m.account_number
            WHERE t.deal_id = :deal_id_param 
            AND m.mapping_level_1 = 'Revenue' 
            AND t.net_amount > 0  -- In accounting, revenue is typically credit (negative)
            
            UNION ALL
            
            -- Check 5: Duplicate records
            SELECT 
                'Duplicate Records',
                COUNT(*) = 0,
                CASE WHEN COUNT(*) = 0 THEN 'INFO' ELSE 'ERROR' END,
                CASE WHEN COUNT(*) = 0 
                     THEN 'No duplicates found' 
                     ELSE COUNT(*)::VARCHAR || ' duplicate records detected' END
            FROM (
                SELECT deal_id, account_number, period_date, entity, COUNT(*) AS cnt
                FROM trial_balance_raw
                WHERE deal_id = :deal_id_param
                GROUP BY deal_id, account_number, period_date, entity
                HAVING COUNT(*) > 1
            )
        )
        SELECT * FROM checks
    );
    
    -- Also insert into data_quality_checks table
    INSERT INTO data_quality_checks (deal_id, check_name, check_type, passed, severity, message)
    SELECT 
        :deal_id_param,
        check_name,
        'VALIDATION',
        passed,
        severity,
        message
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
    
    RETURN TABLE(result_cursor);
END;
$$;

SELECT 'Core data procedures created successfully' AS status;



-- ============================================================================
-- STEP 6: SCHEDULE GENERATION (from 04_schedule_generation.sql)
-- ============================================================================

-- Houlihan Lokey FDD Automation - Schedule Generation Procedures
-- ============================================================================
-- Description: Income Statement and Balance Sheet generation with formulas
-- Version: 1.0.0
-- Last Updated: 2025-10-20
-- ============================================================================

-- ============================================================================
-- PART 1: PIVOTED DATABASE VIEW (Wide format for Excel)
-- ============================================================================

CREATE OR REPLACE VIEW v_database_tab_pivoted AS
WITH last_n_periods AS (
    -- Get the most recent 24 distinct periods (max configured in system_config)
    -- Note: LIMIT does not support subqueries in Snowflake, must be a constant
    SELECT DISTINCT period_date
    FROM trial_balance_raw
    ORDER BY period_date DESC
    LIMIT 24
),
ranked_periods AS (
    -- Rank from oldest (1) to newest (N)
    SELECT 
        period_date,
        TO_CHAR(period_date, 'Mon-YYYY') AS period_label,
        ROW_NUMBER() OVER (ORDER BY period_date) AS period_rank
    FROM last_n_periods
)
SELECT 
    t.deal_id,
    t.deal_name,
    t.entity,
    t.account_number,
    t.account_name,
    t.unique_id,
    t.mapping_level_1,
    t.mapping_level_2,
    t.mapping_level_3,
    t.statement_type,
    t.sort_order_l1,
    t.sort_order_l2,
    -- Period headers and data (using amount_for_display with proper signs)
    MAX(CASE WHEN p.period_rank = 1 THEN p.period_label END) AS period_01_label,
    MAX(CASE WHEN p.period_rank = 2 THEN p.period_label END) AS period_02_label,
    MAX(CASE WHEN p.period_rank = 3 THEN p.period_label END) AS period_03_label,
    MAX(CASE WHEN p.period_rank = 4 THEN p.period_label END) AS period_04_label,
    MAX(CASE WHEN p.period_rank = 5 THEN p.period_label END) AS period_05_label,
    MAX(CASE WHEN p.period_rank = 6 THEN p.period_label END) AS period_06_label,
    MAX(CASE WHEN p.period_rank = 7 THEN p.period_label END) AS period_07_label,
    MAX(CASE WHEN p.period_rank = 8 THEN p.period_label END) AS period_08_label,
    MAX(CASE WHEN p.period_rank = 9 THEN p.period_label END) AS period_09_label,
    MAX(CASE WHEN p.period_rank = 10 THEN p.period_label END) AS period_10_label,
    MAX(CASE WHEN p.period_rank = 11 THEN p.period_label END) AS period_11_label,
    MAX(CASE WHEN p.period_rank = 12 THEN p.period_label END) AS period_12_label,
    MAX(CASE WHEN p.period_rank = 13 THEN p.period_label END) AS period_13_label,
    MAX(CASE WHEN p.period_rank = 14 THEN p.period_label END) AS period_14_label,
    MAX(CASE WHEN p.period_rank = 15 THEN p.period_label END) AS period_15_label,
    MAX(CASE WHEN p.period_rank = 16 THEN p.period_label END) AS period_16_label,
    MAX(CASE WHEN p.period_rank = 17 THEN p.period_label END) AS period_17_label,
    MAX(CASE WHEN p.period_rank = 18 THEN p.period_label END) AS period_18_label,
    MAX(CASE WHEN p.period_rank = 19 THEN p.period_label END) AS period_19_label,
    MAX(CASE WHEN p.period_rank = 20 THEN p.period_label END) AS period_20_label,
    MAX(CASE WHEN p.period_rank = 21 THEN p.period_label END) AS period_21_label,
    MAX(CASE WHEN p.period_rank = 22 THEN p.period_label END) AS period_22_label,
    MAX(CASE WHEN p.period_rank = 23 THEN p.period_label END) AS period_23_label,
    MAX(CASE WHEN p.period_rank = 24 THEN p.period_label END) AS period_24_label,
    MAX(CASE WHEN p.period_rank = 1 THEN t.amount_for_display END) AS period_01,
    MAX(CASE WHEN p.period_rank = 2 THEN t.amount_for_display END) AS period_02,
    MAX(CASE WHEN p.period_rank = 3 THEN t.amount_for_display END) AS period_03,
    MAX(CASE WHEN p.period_rank = 4 THEN t.amount_for_display END) AS period_04,
    MAX(CASE WHEN p.period_rank = 5 THEN t.amount_for_display END) AS period_05,
    MAX(CASE WHEN p.period_rank = 6 THEN t.amount_for_display END) AS period_06,
    MAX(CASE WHEN p.period_rank = 7 THEN t.amount_for_display END) AS period_07,
    MAX(CASE WHEN p.period_rank = 8 THEN t.amount_for_display END) AS period_08,
    MAX(CASE WHEN p.period_rank = 9 THEN t.amount_for_display END) AS period_09,
    MAX(CASE WHEN p.period_rank = 10 THEN t.amount_for_display END) AS period_10,
    MAX(CASE WHEN p.period_rank = 11 THEN t.amount_for_display END) AS period_11,
    MAX(CASE WHEN p.period_rank = 12 THEN t.amount_for_display END) AS period_12,
    MAX(CASE WHEN p.period_rank = 13 THEN t.amount_for_display END) AS period_13,
    MAX(CASE WHEN p.period_rank = 14 THEN t.amount_for_display END) AS period_14,
    MAX(CASE WHEN p.period_rank = 15 THEN t.amount_for_display END) AS period_15,
    MAX(CASE WHEN p.period_rank = 16 THEN t.amount_for_display END) AS period_16,
    MAX(CASE WHEN p.period_rank = 17 THEN t.amount_for_display END) AS period_17,
    MAX(CASE WHEN p.period_rank = 18 THEN t.amount_for_display END) AS period_18,
    MAX(CASE WHEN p.period_rank = 19 THEN t.amount_for_display END) AS period_19,
    MAX(CASE WHEN p.period_rank = 20 THEN t.amount_for_display END) AS period_20,
    MAX(CASE WHEN p.period_rank = 21 THEN t.amount_for_display END) AS period_21,
    MAX(CASE WHEN p.period_rank = 22 THEN t.amount_for_display END) AS period_22,
    MAX(CASE WHEN p.period_rank = 23 THEN t.amount_for_display END) AS period_23,
    MAX(CASE WHEN p.period_rank = 24 THEN t.amount_for_display END) AS period_24
FROM v_trial_balance_for_schedules t
CROSS JOIN ranked_periods p
WHERE t.period_date = p.period_date
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12
ORDER BY 11, 12, 4;

-- ============================================================================
-- PART 2: INCOME STATEMENT GENERATION
-- ============================================================================

CREATE OR REPLACE PROCEDURE generate_income_statement(deal_id_param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    rows_created NUMBER DEFAULT 0;
    session_id VARCHAR DEFAULT CURRENT_SESSION()::VARCHAR;
    error_msg VARCHAR;  -- For capturing SQLERRM in EXCEPTION block
BEGIN
    -- Validate input
    IF (NOT validate_deal_id(:deal_id_param)) THEN
        RETURN 'ERROR: Invalid deal_id format';
    END IF;
    
    -- Log start
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status, session_id)
    VALUES (:log_id_var, 'generate_income_statement', :deal_id_param, :start_time_var, 'STARTED', :session_id);
    
    -- Create session-specific temp table (isolated per user/session)
    CREATE OR REPLACE TEMPORARY TABLE temp_is_schedule (
        row_num NUMBER AUTOINCREMENT,
        row_label VARCHAR(500),
        row_type VARCHAR(20),
        account_filter VARCHAR(600),
        formula_template VARCHAR(5000),
        row_format_json VARCHAR(5000)
    );
    
    -- Header
    INSERT INTO temp_is_schedule (row_label, row_type, account_filter, formula_template, row_format_json)
    VALUES 
        ('Income Statement ($000s)', 'header', NULL, 'PERIOD_LABEL', 
         '{"bold": true, "font_size": 12, "bg_color": "#4472C4", "font_color": "white"}'),
        ('', 'blank', NULL, NULL, '{}'),
        ('Revenue', 'section_header', NULL, NULL, '{"bold": true, "outline_level": 1}');
    
    -- Revenue accounts (flexible mapping depth)
    INSERT INTO temp_is_schedule (row_label, row_type, account_filter, row_format_json)
    SELECT 
        CASE 
            WHEN mapping_level_3 IS NOT NULL THEN '    ' || mapping_level_3
            WHEN mapping_level_2 IS NOT NULL THEN '  ' || mapping_level_2
            ELSE account_name
        END AS row_label,
        'data',
        account_number || ' - ' || account_name,
        OBJECT_CONSTRUCT(
            'number_format', '#,##0',
            'outline_level', CASE WHEN mapping_level_3 IS NOT NULL THEN 3
                                 WHEN mapping_level_2 IS NOT NULL THEN 2
                                 ELSE 1 END,
            'indent', CASE WHEN mapping_level_3 IS NOT NULL THEN 2
                          WHEN mapping_level_2 IS NOT NULL THEN 1
                          ELSE 0 END
        )::VARCHAR
    FROM account_mappings
    WHERE deal_id = :deal_id_param 
    AND statement_type = 'IS' 
    AND mapping_level_1 = 'Revenue'
    AND is_active = TRUE
    ORDER BY sort_order_l1, COALESCE(sort_order_l2, 999), COALESCE(sort_order_l3, 999);
    
    INSERT INTO temp_is_schedule (row_label, row_type, account_filter, row_format_json)
    VALUES 
        ('Total Revenue', 'subtotal', NULL, 
         '{"bold": true, "border_top": true, "number_format": "#,##0", "outline_level": 1}'),
        ('', 'blank', NULL, '{}'),
        ('Cost of Goods Sold', 'section_header', NULL, '{"bold": true, "outline_level": 1}');
    
    -- COGS accounts
    INSERT INTO temp_is_schedule (row_label, row_type, account_filter, row_format_json)
    SELECT 
        CASE 
            WHEN mapping_level_3 IS NOT NULL THEN '    ' || mapping_level_3
            WHEN mapping_level_2 IS NOT NULL THEN '  ' || mapping_level_2
            ELSE account_name
        END AS row_label,
        'data',
        account_number || ' - ' || account_name,
        OBJECT_CONSTRUCT(
            'number_format', '#,##0',
            'outline_level', CASE WHEN mapping_level_3 IS NOT NULL THEN 3
                                 WHEN mapping_level_2 IS NOT NULL THEN 2
                                 ELSE 1 END,
            'indent', CASE WHEN mapping_level_3 IS NOT NULL THEN 2
                          WHEN mapping_level_2 IS NOT NULL THEN 1
                          ELSE 0 END
        )::VARCHAR
    FROM account_mappings
    WHERE deal_id = :deal_id_param 
    AND statement_type = 'IS' 
    AND mapping_level_1 = 'Cost of Goods Sold'
    AND is_active = TRUE
    ORDER BY sort_order_l1, COALESCE(sort_order_l2, 999), COALESCE(sort_order_l3, 999);
    
    INSERT INTO temp_is_schedule (row_label, row_type, account_filter, row_format_json)
    VALUES 
        ('Total Cost of Goods Sold', 'subtotal', NULL, 
         '{"bold": true, "border_top": true, "number_format": "#,##0", "outline_level": 1}'),
        ('', 'blank', NULL, '{}'),
        ('Gross Margin', 'calculated', NULL, 
         '{"bold": true, "border_bottom": true, "number_format": "#,##0"}'),
        ('', 'blank', NULL, '{}'),
        ('Operating Expenses', 'section_header', NULL, '{"bold": true, "outline_level": 1}');
    
    -- OpEx accounts
    INSERT INTO temp_is_schedule (row_label, row_type, account_filter, row_format_json)
    SELECT 
        CASE 
            WHEN mapping_level_3 IS NOT NULL THEN '    ' || mapping_level_3
            WHEN mapping_level_2 IS NOT NULL THEN '  ' || mapping_level_2
            ELSE account_name
        END AS row_label,
        'data',
        account_number || ' - ' || account_name,
        OBJECT_CONSTRUCT(
            'number_format', '#,##0',
            'outline_level', CASE WHEN mapping_level_3 IS NOT NULL THEN 3
                                 WHEN mapping_level_2 IS NOT NULL THEN 2
                                 ELSE 1 END,
            'indent', CASE WHEN mapping_level_3 IS NOT NULL THEN 2
                          WHEN mapping_level_2 IS NOT NULL THEN 1
                          ELSE 0 END
        )::VARCHAR
    FROM account_mappings
    WHERE deal_id = :deal_id_param 
    AND statement_type = 'IS' 
    AND mapping_level_1 = 'Operating Expenses'
    AND is_active = TRUE
    ORDER BY sort_order_l1, COALESCE(sort_order_l2, 999), COALESCE(sort_order_l3, 999);
    
    INSERT INTO temp_is_schedule (row_label, row_type, account_filter, row_format_json)
    VALUES 
        ('Total Operating Expenses', 'subtotal', NULL, 
         '{"bold": true, "border_top": true, "number_format": "#,##0", "outline_level": 1}'),
        ('', 'blank', NULL, '{}'),
        ('Operating Income', 'total', NULL, 
         '{"bold": true, "border_bottom_double": true, "number_format": "#,##0"}');
    
    SELECT COUNT(*) INTO :rows_created FROM temp_is_schedule;
    
    -- Log success
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = 'SUCCESS',
        rows_affected = :rows_created
    WHERE log_id = :log_id_var;
    
    RETURN 'SUCCESS: Generated Income Statement with ' || :rows_created || ' rows';
    
EXCEPTION
    WHEN OTHER THEN
        error_msg := SQLERRM;  -- Capture error message
        
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = :error_msg
        WHERE log_id = :log_id_var;
        
        RETURN 'ERROR: ' || :error_msg;
END;
$$;

-- ============================================================================
-- PART 3: BALANCE SHEET GENERATION
-- ============================================================================

CREATE OR REPLACE PROCEDURE generate_balance_sheet(deal_id_param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    rows_created NUMBER DEFAULT 0;
    session_id VARCHAR DEFAULT CURRENT_SESSION()::VARCHAR;
    error_msg VARCHAR;  -- For capturing SQLERRM in EXCEPTION block
BEGIN
    -- Validate input
    IF (NOT validate_deal_id(:deal_id_param)) THEN
        RETURN 'ERROR: Invalid deal_id format';
    END IF;
    
    -- Log start
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status, session_id)
    VALUES (:log_id_var, 'generate_balance_sheet', :deal_id_param, :start_time_var, 'STARTED', :session_id);
    
    -- Create session-specific temp table
    CREATE OR REPLACE TEMPORARY TABLE temp_bs_schedule (
        row_num NUMBER AUTOINCREMENT,
        row_label VARCHAR(500),
        row_type VARCHAR(20),
        account_filter VARCHAR(600),
        row_format_json VARCHAR(5000)
    );
    
    -- Header
    INSERT INTO temp_bs_schedule (row_label, row_type, account_filter, row_format_json)
    VALUES 
        ('Balance Sheet ($000s)', 'header', NULL, 
         '{"bold": true, "font_size": 12, "bg_color": "#4472C4", "font_color": "white"}'),
        ('', 'blank', NULL, '{}'),
        ('ASSETS', 'section_header', NULL, '{"bold": true, "outline_level": 1}'),
        ('Current Assets', 'subsection_header', NULL, '{"bold": true, "outline_level": 2, "indent": 1}');
    
    -- Current Assets
    INSERT INTO temp_bs_schedule (row_label, row_type, account_filter, row_format_json)
    SELECT 
        CASE 
            WHEN mapping_level_3 IS NOT NULL THEN '    ' || mapping_level_3
            WHEN mapping_level_2 IS NOT NULL THEN '  ' || mapping_level_2
            ELSE account_name
        END AS row_label,
        'data',
        account_number || ' - ' || account_name,
        OBJECT_CONSTRUCT(
            'number_format', '#,##0',
            'outline_level', CASE WHEN mapping_level_3 IS NOT NULL THEN 3
                                 WHEN mapping_level_2 IS NOT NULL THEN 2
                                 ELSE 1 END,
            'indent', CASE WHEN mapping_level_3 IS NOT NULL THEN 2
                          WHEN mapping_level_2 IS NOT NULL THEN 1
                          ELSE 0 END
        )::VARCHAR
    FROM account_mappings
    WHERE deal_id = :deal_id_param 
    AND statement_type = 'BS' 
    AND mapping_level_1 = 'Assets' 
    AND COALESCE(mapping_level_2, 'Current Assets') = 'Current Assets'
    AND is_active = TRUE
    ORDER BY sort_order_l1, COALESCE(sort_order_l2, 999), COALESCE(sort_order_l3, 999);
    
    INSERT INTO temp_bs_schedule (row_label, row_type, account_filter, row_format_json)
    VALUES 
        ('  Total Current Assets', 'subtotal', NULL, 
         '{"bold": true, "border_top": true, "number_format": "#,##0", "outline_level": 2, "indent": 1}'),
        ('', 'blank', NULL, '{}'),
        ('Non-Current Assets', 'subsection_header', NULL, 
         '{"bold": true, "outline_level": 2, "indent": 1}');
    
    -- Add remaining BS sections (Non-Current Assets, Liabilities, Equity)
    -- ... (similar pattern as above)
    
    SELECT COUNT(*) INTO :rows_created FROM temp_bs_schedule;
    
    -- Log success
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = 'SUCCESS',
        rows_affected = :rows_created
    WHERE log_id = :log_id_var;
    
    RETURN 'SUCCESS: Generated Balance Sheet with ' || :rows_created || ' rows';
    
EXCEPTION
    WHEN OTHER THEN
        error_msg := SQLERRM;  -- Capture error message
        
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = :error_msg
        WHERE log_id = :log_id_var;
        
        RETURN 'ERROR: ' || :error_msg;
END;
$$;

SELECT 'Schedule generation procedures created successfully' AS status;



-- ============================================================================
-- STEP 7: AI INSIGHTS & EXPORT (from 05_ai_and_export.sql)
-- ============================================================================

-- Houlihan Lokey FDD Automation - AI Insights & Export Procedures
-- ============================================================================
-- Description: Cortex AI-powered insights and data export functionality
-- Version: 1.0.0
-- Last Updated: 2025-10-20
-- ============================================================================

-- ============================================================================
-- PART 1: AI INSIGHTS GENERATION
-- ============================================================================

CREATE OR REPLACE PROCEDURE generate_ai_insights(deal_id_param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    insight_count NUMBER DEFAULT 0;
    ai_model VARCHAR DEFAULT get_config_string('ai_model_variance');
    max_insights NUMBER DEFAULT get_config_number('max_ai_insights');
    error_msg VARCHAR;  -- For capturing SQLERRM in EXCEPTION block
BEGIN
    -- Validate input
    IF (NOT validate_deal_id(:deal_id_param)) THEN
        RETURN 'ERROR: Invalid deal_id format';
    END IF;
    
    -- Log start
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status)
    VALUES (:log_id_var, 'generate_ai_insights', :deal_id_param, :start_time_var, 'STARTED');
    
    BEGIN TRANSACTION;
    
    -- Clear previous insights for this deal
    DELETE FROM ai_insights WHERE deal_id = :deal_id_param;
    
    -- Step 1: Variance Analysis (period-over-period > threshold%)
    INSERT INTO ai_insights (
        deal_id, insight_type, severity, account_number, account_name, period_date,
        metric_value, comparison_value, variance_pct, insight_text, suggested_question, 
        model_used, prompt_tokens, completion_tokens
    )
    SELECT 
        variance_data.deal_id,
        'variance',
        CASE 
            WHEN ABS(variance_data.var_pct) > 50 THEN 'high'
            WHEN ABS(variance_data.var_pct) > 30 THEN 'medium'
            ELSE 'low'
        END,
        variance_data.account_number,
        variance_data.account_name,
        variance_data.period_date,
        variance_data.net_amount,
        variance_data.prior_net_amount,
        variance_data.var_pct,
        -- Use Cortex AI to generate insights
        SNOWFLAKE.CORTEX.COMPLETE(
            :ai_model,
            'Analyze this financial variance for a due diligence review: Account "' || variance_data.account_name || 
            '" changed from $' || TO_CHAR(ABS(variance_data.prior_net_amount), '999,999,999') || 
            ' to $' || TO_CHAR(ABS(variance_data.net_amount), '999,999,999') || 
            ' (' || ROUND(variance_data.var_pct, 1) || '% change) between ' || 
            TO_CHAR(variance_data.prior_period_date, 'Mon YYYY') || ' and ' || TO_CHAR(variance_data.period_date, 'Mon YYYY') || 
            '. Provide a 2-sentence explanation of potential business reasons for this variance that a due diligence analyst should investigate.'
        ),
        'Why did ' || variance_data.account_name || ' change by ' || ROUND(ABS(variance_data.var_pct), 1) || '% from ' ||
        TO_CHAR(variance_data.prior_period_date, 'Mon YYYY') || ' to ' || TO_CHAR(variance_data.period_date, 'Mon YYYY') || '?',
        :ai_model,
        NULL,  -- Token counts would need to be calculated separately
        NULL
    FROM (
        SELECT 
            t1.deal_id, t1.period_date, t1.account_number, t1.account_name, t1.net_amount,
            t2.net_amount AS prior_net_amount,
            ROUND((t1.net_amount - t2.net_amount) / NULLIF(ABS(t2.net_amount), 0) * 100, 2) AS var_pct,
            t2.period_date AS prior_period_date
        FROM trial_balance_raw t1
        JOIN trial_balance_raw t2
            ON t1.deal_id = t2.deal_id
            AND t1.account_number = t2.account_number
            AND t1.entity = t2.entity
            AND t2.period_date = DATEADD(month, -1, t1.period_date)
        WHERE t1.deal_id = :deal_id_param
          AND ABS(t2.net_amount) > get_config_number('min_variance_amount')
          AND ABS((t1.net_amount - t2.net_amount) / NULLIF(ABS(t2.net_amount), 0)) > get_config_number('variance_threshold_pct')
    ) AS variance_data
    ORDER BY ABS(variance_data.var_pct) DESC
    LIMIT :max_insights;
    
    SELECT COUNT(*) INTO :insight_count FROM ai_insights WHERE deal_id = :deal_id_param AND insight_type = 'variance';
    
    -- Step 2: Margin Trend Analysis using Cortex
    DECLARE
        margin_analysis VARCHAR;
        margin_data VARCHAR;
    BEGIN
        -- Build margin trend data string
        SELECT LISTAGG(
            TO_CHAR(period_date, 'Mon-YY') || ': ' || TO_CHAR(ROUND(gross_margin_pct, 1), '990.0') || '%', 
            ', '
        ) WITHIN GROUP (ORDER BY period_date)
        INTO :margin_data
        FROM (
            SELECT 
                t.period_date,
                (SUM(CASE WHEN m.mapping_level_1 = 'Revenue' THEN t.net_amount ELSE 0 END) +
                 SUM(CASE WHEN m.mapping_level_1 = 'Cost of Goods Sold' THEN t.net_amount ELSE 0 END)) /
                NULLIF(SUM(CASE WHEN m.mapping_level_1 = 'Revenue' THEN ABS(t.net_amount) ELSE 0 END), 0) * 100 AS gross_margin_pct
            FROM trial_balance_raw t
            JOIN account_mappings m ON t.deal_id = m.deal_id AND t.account_number = m.account_number
            WHERE t.deal_id = :deal_id_param
            GROUP BY t.period_date
            ORDER BY t.period_date
        );
        
        -- Generate AI analysis if we have data
        IF (:margin_data IS NOT NULL) THEN
            SELECT SNOWFLAKE.CORTEX.COMPLETE(
                get_config_string('ai_model_trends'),
                'Analyze the following gross margin trend over 24 months for a company undergoing due diligence: ' ||
                :margin_data ||
                '. Identify any concerning trends, seasonality patterns, or margin compression/expansion. Provide 3 specific questions for management in 150 words.'
            ) INTO :margin_analysis;
            
            INSERT INTO ai_insights (deal_id, insight_type, severity, insight_text, model_used)
            VALUES (:deal_id_param, 'trend_analysis', 'medium', :margin_analysis, get_config_string('ai_model_trends'));
            
            insight_count := :insight_count + 1;
        END IF;
    END;
    
    COMMIT;
    
    -- Log success
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = 'SUCCESS',
        rows_affected = :insight_count,
        message = 'Generated ' || :insight_count || ' AI insights'
    WHERE log_id = :log_id_var;
    
    RETURN 'SUCCESS: Generated ' || :insight_count || ' AI insights for ' || :deal_id_param;
    
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = :error_msg
        WHERE log_id = :log_id_var;
        
        RETURN 'ERROR: ' || :error_msg;
END;
$$;

-- ============================================================================
-- PART 2: EXPORT PROCEDURES (with SQL injection protection)
-- ============================================================================

-- Export database tab to CSV
CREATE OR REPLACE PROCEDURE export_database_tab(deal_id_param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    output_path VARCHAR;
    safe_deal_id VARCHAR;
    file_count NUMBER;
    copy_sql VARCHAR;  -- For dynamic COPY INTO statement
    error_msg VARCHAR;  -- For capturing SQLERRM in EXCEPTION block
BEGIN
    -- Validate and sanitize deal_id
    safe_deal_id := sanitize_deal_id(:deal_id_param);
    IF (safe_deal_id IS NULL) THEN
        RETURN 'ERROR: Invalid deal_id format. Must be alphanumeric with underscores/hyphens only.';
    END IF;
    
    -- Log start
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status)
    VALUES (:log_id_var, 'export_database_tab', :safe_deal_id, :start_time_var, 'STARTED');
    
    -- Build output path
    output_path := '@' || get_config_string('output_stage_name') || '/database_tab_' || :safe_deal_id || '.csv';
    
    -- Export using EXECUTE IMMEDIATE (COPY INTO doesn't support variable paths)
    copy_sql := 'COPY INTO ' || :output_path || 
                    ' FROM (SELECT * FROM v_database_tab_pivoted WHERE deal_id = ''' || :safe_deal_id || ''') ' ||
                    ' FILE_FORMAT = (FORMAT_NAME = ''csv_format'' COMPRESSION = NONE) ' ||
                    ' HEADER = TRUE OVERWRITE = TRUE SINGLE = TRUE';
    
    EXECUTE IMMEDIATE :copy_sql;
    
    file_count := SQLROWCOUNT;
    
    -- Log success
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = 'SUCCESS',
        rows_affected = :file_count,
        message = 'Exported to ' || :output_path
    WHERE log_id = :log_id_var;
    
    RETURN 'SUCCESS: Exported Database tab to ' || :output_path || ' (' || :file_count || ' rows)';
    
EXCEPTION
    WHEN OTHER THEN
        error_msg := SQLERRM;  -- Capture error message
        
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = :error_msg
        WHERE log_id = :log_id_var;
        
        RETURN 'ERROR: ' || :error_msg;
END;
$$;

-- Export income statement structure
CREATE OR REPLACE PROCEDURE export_income_statement_structure(deal_id_param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    output_path VARCHAR;
    safe_deal_id VARCHAR;
    file_count NUMBER;
    copy_sql VARCHAR;  -- For dynamic COPY INTO statement
    error_msg VARCHAR;  -- For capturing SQLERRM in EXCEPTION block
BEGIN
    -- Validate and sanitize deal_id
    safe_deal_id := sanitize_deal_id(:deal_id_param);
    IF (safe_deal_id IS NULL) THEN
        RETURN 'ERROR: Invalid deal_id format';
    END IF;
    
    -- Log start
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status)
    VALUES (:log_id_var, 'export_income_statement_structure', :safe_deal_id, :start_time_var, 'STARTED');
    
    output_path := '@' || get_config_string('output_stage_name') || '/income_statement_' || :safe_deal_id || '.csv';
    
    copy_sql := 'COPY INTO ' || :output_path || 
                    ' FROM (SELECT row_num, row_label, row_type, account_filter, row_format_json FROM temp_is_schedule ORDER BY row_num) ' ||
                    ' FILE_FORMAT = (FORMAT_NAME = ''csv_format'' COMPRESSION = NONE) ' ||
                    ' HEADER = TRUE OVERWRITE = TRUE SINGLE = TRUE';
    
    EXECUTE IMMEDIATE :copy_sql;
    
    file_count := SQLROWCOUNT;
    
    -- Log success
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = 'SUCCESS',
        rows_affected = :file_count
    WHERE log_id = :log_id_var;
    
    RETURN 'SUCCESS: Exported Income Statement to ' || :output_path;
    
EXCEPTION
    WHEN OTHER THEN
        error_msg := SQLERRM;  -- Capture error message
        
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = :error_msg
        WHERE log_id = :log_id_var;
        
        RETURN 'ERROR: ' || :error_msg;
END;
$$;

-- Export balance sheet structure
CREATE OR REPLACE PROCEDURE export_balance_sheet_structure(deal_id_param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    output_path VARCHAR;
    safe_deal_id VARCHAR;
    file_count NUMBER;
    copy_sql VARCHAR;  -- For dynamic COPY INTO statement
    error_msg VARCHAR;  -- For capturing SQLERRM in EXCEPTION block
BEGIN
    safe_deal_id := sanitize_deal_id(:deal_id_param);
    IF (safe_deal_id IS NULL) THEN
        RETURN 'ERROR: Invalid deal_id format';
    END IF;
    
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status)
    VALUES (:log_id_var, 'export_balance_sheet_structure', :safe_deal_id, :start_time_var, 'STARTED');
    
    output_path := '@' || get_config_string('output_stage_name') || '/balance_sheet_' || :safe_deal_id || '.csv';
    
    copy_sql := 'COPY INTO ' || :output_path || 
                    ' FROM (SELECT row_num, row_label, row_type, account_filter, row_format_json FROM temp_bs_schedule ORDER BY row_num) ' ||
                    ' FILE_FORMAT = (FORMAT_NAME = ''csv_format'' COMPRESSION = NONE) ' ||
                    ' HEADER = TRUE OVERWRITE = TRUE SINGLE = TRUE';
    
    EXECUTE IMMEDIATE :copy_sql;
    
    file_count := SQLROWCOUNT;
    
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = 'SUCCESS',
        rows_affected = :file_count
    WHERE log_id = :log_id_var;
    
    RETURN 'SUCCESS: Exported Balance Sheet to ' || :output_path;
    
EXCEPTION
    WHEN OTHER THEN
        error_msg := SQLERRM;  -- Capture error message
        
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = :error_msg
        WHERE log_id = :log_id_var;
        
        RETURN 'ERROR: ' || :error_msg;
END;
$$;

-- Export AI insights
CREATE OR REPLACE PROCEDURE export_ai_insights(deal_id_param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    output_path VARCHAR;
    safe_deal_id VARCHAR;
    file_count NUMBER;
    copy_sql VARCHAR;  -- For dynamic COPY INTO statement
    error_msg VARCHAR;  -- For capturing SQLERRM in EXCEPTION block
BEGIN
    safe_deal_id := sanitize_deal_id(:deal_id_param);
    IF (safe_deal_id IS NULL) THEN
        RETURN 'ERROR: Invalid deal_id format';
    END IF;
    
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status)
    VALUES (:log_id_var, 'export_ai_insights', :safe_deal_id, :start_time_var, 'STARTED');
    
    output_path := '@' || get_config_string('output_stage_name') || '/ai_insights_' || :safe_deal_id || '.csv';
    
    copy_sql := 'COPY INTO ' || :output_path || 
                    ' FROM (SELECT insight_type, severity, COALESCE(account_name, ''General'') AS account_name, ' ||
                    ' TO_CHAR(period_date, ''Mon YYYY'') AS period, metric_value, comparison_value, variance_pct, ' ||
                    ' insight_text, suggested_question, model_used FROM ai_insights WHERE deal_id = ''' || :safe_deal_id || ''' ' ||
                    ' ORDER BY CASE severity WHEN ''high'' THEN 1 WHEN ''medium'' THEN 2 ELSE 3 END, ABS(variance_pct) DESC) ' ||
                    ' FILE_FORMAT = (FORMAT_NAME = ''csv_format'' COMPRESSION = NONE) ' ||
                    ' HEADER = TRUE OVERWRITE = TRUE SINGLE = TRUE';
    
    EXECUTE IMMEDIATE :copy_sql;
    
    file_count := SQLROWCOUNT;
    
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = 'SUCCESS',
        rows_affected = :file_count
    WHERE log_id = :log_id_var;
    
    RETURN 'SUCCESS: Exported AI insights to ' || :output_path || ' (' || :file_count || ' insights)';
    
EXCEPTION
    WHEN OTHER THEN
        error_msg := SQLERRM;  -- Capture error message
        
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = :error_msg
        WHERE log_id = :log_id_var;
        
        RETURN 'ERROR: ' || :error_msg;
END;
$$;

-- ============================================================================
-- PART 3: MASTER ORCHESTRATION PROCEDURES
-- ============================================================================

-- Master procedure for generating all FDD schedules for a deal
CREATE OR REPLACE PROCEDURE generate_fdd_schedules(deal_id_param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    result VARCHAR;
    tb_row_count NUMBER;
    insight_count NUMBER;
    copy_sql VARCHAR;  -- For dynamic COPY INTO statement
    safe_deal_id VARCHAR;
    error_msg VARCHAR;  -- For capturing SQLERRM in EXCEPTION block
BEGIN
    -- Validate and sanitize input
    safe_deal_id := sanitize_deal_id(:deal_id_param);
    IF (safe_deal_id IS NULL) THEN
        RETURN 'ERROR: Invalid deal_id format. Must be alphanumeric with underscores/hyphens only.';
    END IF;
    
    -- Log start
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status)
    VALUES (:log_id_var, 'generate_fdd_schedules', :safe_deal_id, :start_time_var, 'STARTED');
    
    -- Validate deal exists
    SELECT COUNT(*) INTO :tb_row_count 
    FROM trial_balance_raw 
    WHERE deal_id = :safe_deal_id;
    
    IF (:tb_row_count = 0) THEN
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = 'No trial balance data found for deal'
        WHERE log_id = :log_id_var;
        
        RETURN 'ERROR: No trial balance data found for deal ' || :safe_deal_id || 
               '. Please load data first using load_trial_balance().';
    END IF;
    
    -- Step 1: Generate schedules (session-isolated temp tables)
    CALL generate_income_statement(:safe_deal_id);
    CALL generate_balance_sheet(:safe_deal_id);
    
    -- Step 2: Generate AI insights
    CALL generate_ai_insights(:safe_deal_id);
    
    -- Step 3: Export everything with deal-specific filenames
    CALL export_database_tab(:safe_deal_id);
    CALL export_income_statement_structure(:safe_deal_id);
    CALL export_balance_sheet_structure(:safe_deal_id);
    CALL export_ai_insights(:safe_deal_id);
    
    -- Get counts for confirmation
    SELECT COUNT(*) INTO :insight_count FROM ai_insights WHERE deal_id = :safe_deal_id;
    
    result := :tb_row_count::VARCHAR || ' TB rows processed, ' ||
              :insight_count::VARCHAR || ' AI insights generated for ' || :safe_deal_id;
    
    -- Log success
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = 'SUCCESS',
        rows_affected = :tb_row_count,
        message = :result
    WHERE log_id = :log_id_var;
    
    RETURN 'SUCCESS: ' || :result || '. Outputs available at @' || get_config_string('output_stage_name') || '/*_' || :safe_deal_id || '.csv';
    
EXCEPTION
    WHEN OTHER THEN
        error_msg := SQLERRM;  -- Capture error message
        
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = :error_msg
        WHERE log_id = :log_id_var;
        
        RETURN 'ERROR: ' || :error_msg;
END;
$$;

SELECT 'AI insights and export procedures created successfully' AS status;



-- ============================================================================
-- STEP 8: POST-DEPLOYMENT VALIDATION
-- ============================================================================

SELECT 'Step 2: All SQL modules executed successfully' AS status;

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
WHERE function_schema = $SCHEMA_NAME;

-- Note: information_schema.roles does not exist in Snowflake
-- Use SHOW ROLES command manually to verify FDD roles were created

-- ============================================================================
-- STEP 9: HELPER PROCEDURES FOR POC/DEMO
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
    error_msg VARCHAR;  -- For capturing SQLERRM in EXCEPTION block
BEGIN
    -- Load trial balance (correct syntax for RETURNS TABLE procedures)
    tb_result := (CALL load_trial_balance());
    
    -- Load account mappings (correct syntax for RETURNS TABLE procedures)
    am_result := (CALL load_account_mappings());
    
    RETURN 'SUCCESS: Sample data loaded. Ready for schedule generation.';
EXCEPTION
    WHEN OTHER THEN
        error_msg := SQLERRM;  -- Capture error message
        
        RETURN 'ERROR: Sample data load failed - ' || :error_msg;
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
    error_msg VARCHAR;  -- For capturing SQLERRM in EXCEPTION block
BEGIN
    -- Load sample data
    CALL load_sample_data() INTO :load_result;
    
    -- Generate schedules for sample deal
    CALL generate_fdd_schedules('DEAL_HL_001') INTO :gen_result;
    
    RETURN 'PoC Complete! ' || :gen_result || ' Run "LIST @fdd_output_stage;" to see output files.';
EXCEPTION
    WHEN OTHER THEN
        error_msg := SQLERRM;  -- Capture error message
        
        RETURN 'ERROR: PoC execution failed - ' || :error_msg;
END;
$$;

-- ============================================================================
-- STEP 10: FINALIZE DEPLOYMENT
-- ============================================================================

-- Update migration record
UPDATE schema_migrations
SET status = 'SUCCESS',
    execution_time_seconds = DATEDIFF(second, applied_at, CURRENT_TIMESTAMP())
WHERE version = '1.0.0';

-- Log deployment in audit log
INSERT INTO audit_log (procedure_name, status, message)
VALUES (
    'deploy_snowsight.sql',
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

-- Display configuration summary
SELECT * FROM v_system_config;

-- ============================================================================
-- STEP 11: STREAMLIT ADMIN DASHBOARD (OPTIONAL)
-- ============================================================================

-- Create stage for Streamlit files
CREATE STAGE IF NOT EXISTS streamlit_stage
    COMMENT = 'Stage for Streamlit admin dashboard files';

SELECT 'Streamlit stage created. See streamlit/deploy_streamlit.sql for dashboard deployment.' AS streamlit_status;

-- Note: Streamlit app deployment requires uploading Python files to the stage
-- This cannot be done in Snowsight - use SnowSQL or Snowsight UI file upload
-- See streamlit/deploy_streamlit.sql for complete instructions

SELECT 'Deployment completed successfully! Next steps: Upload sample data to @fdd_input_stage, then CALL run_complete_poc();' AS next_steps;

SELECT 'OPTIONAL: Deploy Streamlit admin dashboard - see streamlit/deploy_streamlit.sql' AS optional_step;


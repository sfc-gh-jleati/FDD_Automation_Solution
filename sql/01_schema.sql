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
    reviewed_timestamp TIMESTAMP_NTZ,
    
    CONSTRAINT fk_ai_deal FOREIGN KEY (deal_id) REFERENCES trial_balance_raw(deal_id)
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

-- Index for common queries
CREATE INDEX IF NOT EXISTS idx_audit_deal_time ON audit_log(deal_id, log_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_status ON audit_log(status, log_timestamp DESC);

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

CREATE INDEX IF NOT EXISTS idx_errors_unresolved ON load_errors(deal_id, is_resolved, error_timestamp DESC);

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

CREATE INDEX IF NOT EXISTS idx_dq_deal_time ON data_quality_checks(deal_id, check_timestamp DESC);

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



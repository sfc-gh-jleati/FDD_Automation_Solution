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

-- Insert default configuration values
INSERT INTO system_config (config_key, config_value, description, is_sensitive)
VALUES
    -- Data Quality Thresholds
    ('balance_tolerance_dollars', TO_VARIANT(0.10), 'Acceptable rounding difference for trial balance validation (in dollars)', false),
    ('min_variance_amount', TO_VARIANT(5000.00), 'Minimum dollar amount to trigger variance analysis', false),
    ('variance_threshold_pct', TO_VARIANT(0.20), 'Minimum percentage change to flag as variance (0.20 = 20%)', false),
    ('max_error_rate_pct', TO_VARIANT(0.05), 'Maximum acceptable error rate for data loads (0.05 = 5%)', false),
    
    -- AI Configuration
    ('max_ai_insights', TO_VARIANT(15), 'Maximum number of AI insights to generate per deal', false),
    ('ai_model_variance', TO_VARIANT('claude-4-sonnet'), 'AI model for variance analysis', false),
    ('ai_model_trends', TO_VARIANT('claude-4-sonnet'), 'AI model for trend analysis', false),
    ('ai_batch_size', TO_VARIANT(50), 'Number of variance records to process in single AI batch', false),
    
    -- Performance & Scaling
    ('warehouse_size_default', TO_VARIANT('SMALL'), 'Default warehouse size for processing', false),
    ('warehouse_auto_suspend', TO_VARIANT(60), 'Auto-suspend timeout in seconds', false),
    ('max_pivot_periods', TO_VARIANT(24), 'Maximum number of periods in pivoted views', false),
    ('query_timeout_seconds', TO_VARIANT(3600), 'Maximum query execution time (1 hour)', false),
    
    -- File Management
    ('input_stage_name', TO_VARIANT('fdd_input_stage'), 'Name of input file stage', false),
    ('output_stage_name', TO_VARIANT('fdd_output_stage'), 'Name of output file stage', false),
    ('default_file_format', TO_VARIANT('csv_format'), 'Default file format for imports/exports', false),
    
    -- Audit & Retention
    ('audit_retention_days', TO_VARIANT(90), 'Number of days to retain audit logs', false),
    ('error_log_retention_days', TO_VARIANT(180), 'Number of days to retain error logs', false),
    ('output_retention_days', TO_VARIANT(30), 'Number of days to retain output files in stage', false),
    
    -- Security
    ('deal_id_validation_regex', TO_VARIANT('^[A-Z0-9_-]+$'), 'Regex pattern for validating deal_id format', false),
    ('max_deal_id_length', TO_VARIANT(50), 'Maximum length for deal_id', false),
    ('enable_row_level_security', TO_VARIANT(true), 'Enable row-level security policies', false),
    
    -- Environment
    ('environment', TO_VARIANT('DEVELOPMENT'), 'Current environment: DEVELOPMENT, STAGING, PRODUCTION', false),
    ('schema_version', TO_VARIANT('1.0.0'), 'Current schema version', false),
    ('deployment_date', TO_VARIANT(CURRENT_TIMESTAMP()), 'Date of last deployment', false);

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



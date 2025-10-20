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
    is_sensitive BOOLEAN DEFAULT FALSE,
    last_updated TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_by VARCHAR(100) DEFAULT CURRENT_USER()
);

-- Insert default configuration values
INSERT INTO system_config (config_key, config_value, description, is_sensitive)
VALUES
    -- Data Quality Thresholds
    ('balance_tolerance_dollars', 0.10, 'Acceptable rounding difference for trial balance validation (in dollars)', FALSE),
    ('min_variance_amount', 5000.00, 'Minimum dollar amount to trigger variance analysis', FALSE),
    ('variance_threshold_pct', 0.20, 'Minimum percentage change to flag as variance (0.20 = 20%)', FALSE),
    ('max_error_rate_pct', 0.05, 'Maximum acceptable error rate for data loads (0.05 = 5%)', FALSE),
    
    -- AI Configuration
    ('max_ai_insights', 15, 'Maximum number of AI insights to generate per deal', FALSE),
    ('ai_model_variance', 'claude-4-sonnet', 'AI model for variance analysis', FALSE),
    ('ai_model_trends', 'claude-4-sonnet', 'AI model for trend analysis', FALSE),
    ('ai_batch_size', 50, 'Number of variance records to process in single AI batch', FALSE),
    
    -- Performance & Scaling
    ('warehouse_size_default', 'SMALL', 'Default warehouse size for processing', FALSE),
    ('warehouse_auto_suspend', 60, 'Auto-suspend timeout in seconds', FALSE),
    ('max_pivot_periods', 24, 'Maximum number of periods in pivoted views', FALSE),
    ('query_timeout_seconds', 3600, 'Maximum query execution time (1 hour)', FALSE),
    
    -- File Management
    ('input_stage_name', 'fdd_input_stage', 'Name of input file stage', FALSE),
    ('output_stage_name', 'fdd_output_stage', 'Name of output file stage', FALSE),
    ('default_file_format', 'csv_format', 'Default file format for imports/exports', FALSE),
    
    -- Audit & Retention
    ('audit_retention_days', 90, 'Number of days to retain audit logs', FALSE),
    ('error_log_retention_days', 180, 'Number of days to retain error logs', FALSE),
    ('output_retention_days', 30, 'Number of days to retain output files in stage', FALSE),
    
    -- Security
    ('deal_id_validation_regex', '^[A-Z0-9_-]+$', 'Regex pattern for validating deal_id format', FALSE),
    ('max_deal_id_length', 50, 'Maximum length for deal_id', FALSE),
    ('enable_row_level_security', TRUE, 'Enable row-level security policies', FALSE),
    
    -- Environment
    ('environment', 'DEVELOPMENT', 'Current environment: DEVELOPMENT, STAGING, PRODUCTION', FALSE),
    ('schema_version', '1.0.0', 'Current schema version', FALSE),
    ('deployment_date', CURRENT_TIMESTAMP(), 'Date of last deployment', FALSE)
ON CONFLICT (config_key) DO NOTHING;

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


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


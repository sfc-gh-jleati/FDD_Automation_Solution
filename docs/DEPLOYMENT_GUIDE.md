# Houlihan Lokey FDD Automation - Production Deployment Guide

## Overview

This production-ready package provides a **comprehensive Financial Due Diligence (FDD) automation platform** built on Snowflake. The system automates trial balance processing, generates financial schedules (Income Statement & Balance Sheet), and leverages Snowflake Cortex AI for intelligent variance analysis.

### Key Features

- ✅ **Production-Grade Architecture**: Modular, maintainable, and scalable code structure
- ✅ **Comprehensive Security**: Role-based access control, row-level security, SQL injection protection
- ✅ **Enterprise Error Handling**: Transaction management, audit logging, data quality validation
- ✅ **Multi-User Isolation**: Session-specific temporary tables, deal-specific outputs
- ✅ **AI-Powered Insights**: Cortex AI (Claude 4 Sonnet) for variance detection and trend analysis
- ✅ **Flexible Account Mapping**: Support for 1-4 level hierarchical chart of accounts
- ✅ **Rolling 24-Month Support**: Dynamic period detection and pivoting
- ✅ **Complete Observability**: Audit logs, error tracking, data quality checks, performance metrics

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Deployment Instructions](#deployment-instructions)
3. [Configuration](#configuration)
4. [User Management](#user-management)
5. [Operational Procedures](#operational-procedures)
6. [Monitoring & Troubleshooting](#monitoring--troubleshooting)
7. [Security Considerations](#security-considerations)
8. [Cost Optimization](#cost-optimization)

---

## Prerequisites

### Snowflake Requirements

- Snowflake account (Business Critical or higher recommended for production)
- `ACCOUNTADMIN` role access (for initial setup) or equivalent privileges
- Snowflake Cortex AI enabled (for AI insights feature)
- Minimum warehouse size: `SMALL` (can scale to `LARGE` for high-volume processing)

### User Privileges Required

```sql
-- Deployment user needs these privileges:
- CREATE DATABASE
- CREATE WAREHOUSE
- CREATE ROLE
- GRANT ROLE
- USAGE ON CORTEX FUNCTIONS
```

### Data Format Requirements

**Trial Balance CSV** (`01_sample_trial_balance_24mo.csv`):
```
deal_id,deal_name,entity,period_date,account_number,account_name,debit_amount,credit_amount,net_amount
DEAL_HL_001,Sample Company Inc,MainCo,2023-01-31,1000,Cash,50000.00,0.00,50000.00
...
```

**Account Mappings CSV** (`02_sample_account_mappings_24mo.csv`):
```
deal_id,account_number,account_name,account_category,statement_type,mapping_level_1,mapping_level_2,mapping_level_3,sort_order_l1,sort_order_l2,sort_order_l3
DEAL_HL_001,4000,Product Revenue,Revenue,IS,Revenue,Product Sales,,10,10,
...
```

---

## Deployment Instructions

### Step 1: Clone Repository

```bash
git clone <repository-url>
cd hl-fdd-automation/production
```

### Step 2: Configure Environment

Edit `sql/deploy.sql` and set your environment variables:

```sql
SET ENVIRONMENT_NAME = 'PRODUCTION';  -- Options: DEVELOPMENT, STAGING, PRODUCTION
SET DATABASE_NAME = 'HL_FDD_POC';
SET SCHEMA_NAME = 'TRIAL_BALANCE';
SET WAREHOUSE_NAME = 'FDD_POC_WH';
SET WAREHOUSE_SIZE = 'SMALL';  -- Adjust based on data volume
SET AUTO_SUSPEND_SECONDS = 60;
```

### Step 3: Execute Deployment

**Option A: Using Snowflake Web UI (SnowSight)**

1. Connect to Snowflake as `ACCOUNTADMIN` or equivalent
2. Open `sql/deploy.sql` in the SQL worksheet
3. Execute the entire script

**Option B: Using SnowSQL CLI**

```bash
snowsql -a <account> -u <username> -r ACCOUNTADMIN -f sql/deploy.sql
```

**Option C: Manual Modular Deployment**

If the `!source` command doesn't work in your Snowflake version, execute scripts manually:

```bash
snowsql -a <account> -u <username> -r ACCOUNTADMIN \
  -f sql/00_system_config.sql \
  -f sql/01_schema.sql \
  -f sql/02_security.sql \
  -f sql/03_data_procedures.sql \
  -f sql/04_schedule_generation.sql \
  -f sql/05_ai_and_export.sql
```

### Step 4: Verify Deployment

```sql
-- Check deployment status
SELECT * FROM schema_migrations WHERE version = '1.0.0';

-- Verify all objects created
SELECT 
    table_schema, 
    table_type, 
    COUNT(*) AS object_count
FROM information_schema.tables
WHERE table_schema = 'TRIAL_BALANCE'
GROUP BY table_schema, table_type;

-- Should see:
-- BASE TABLE: ~10 tables
-- VIEW: ~3 views
```

### Step 5: Grant User Permissions

```sql
-- Grant analyst role to your team members
GRANT ROLE FDD_ANALYST_ROLE TO USER john.smith@houlihanlokey.com;
GRANT ROLE FDD_ANALYST_ROLE TO USER jane.doe@houlihanlokey.com;

-- Grant deal-specific access
CALL grant_deal_access('john.smith@houlihanlokey.com', 'DEAL_HL_001', 'WRITE', 90);
CALL grant_deal_access('jane.doe@houlihanlokey.com', 'DEAL_HL_001', 'READ', 90);

-- View active permissions
SELECT * FROM v_active_permissions;
```

---

## Configuration

### System Configuration Management

All system parameters are centralized in the `system_config` table. No hardcoded values in procedures.

```sql
-- View current configuration
SELECT * FROM v_system_config;

-- Update configuration (example: increase AI insights limit)
CALL update_config('max_ai_insights', 25, 'Increased for large deals');

-- Update AI model
CALL update_config('ai_model_variance', 'claude-3-opus', 'Using more powerful model');
```

### Key Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `balance_tolerance_dollars` | 0.10 | Acceptable rounding difference for trial balance validation |
| `variance_threshold_pct` | 0.20 | Minimum % change to flag as variance (20%) |
| `max_ai_insights` | 15 | Maximum AI insights per deal |
| `max_error_rate_pct` | 0.05 | Maximum acceptable error rate for data loads (5%) |
| `warehouse_size_default` | SMALL | Default warehouse size |

### Environment-Specific Configuration

For multi-environment deployments (DEV/STAGING/PROD):

```sql
-- Development environment
UPDATE system_config SET config_value = 'DEVELOPMENT' WHERE config_key = 'environment';
UPDATE system_config SET config_value = 'XSMALL' WHERE config_key = 'warehouse_size_default';

-- Production environment
UPDATE system_config SET config_value = 'PRODUCTION' WHERE config_key = 'environment';
UPDATE system_config SET config_value = 'LARGE' WHERE config_key = 'warehouse_size_default';
```

---

## User Management

### Role Hierarchy

```
FDD_ADMIN_ROLE
├── Full access to all tables, procedures, and configurations
├── Can grant/revoke permissions
└── Manage system configuration

FDD_ANALYST_ROLE
├── Create/update deals (row-level security applied)
├── Execute all procedures
├── Read/write to stages
└── Cannot modify system config

FDD_READONLY_ROLE
├── Read-only access to all data
├── Download exports from output stage
└── No write permissions

FDD_SERVICE_ROLE
├── Automated process execution
├── Used by scheduled tasks or APIs
└── Full read/write access (no user login)
```

### Granting Deal Access

```sql
-- Grant write access to a deal (expires in 90 days)
CALL grant_deal_access('analyst@company.com', 'DEAL_ABC_2025', 'WRITE', 90);

-- Grant read-only access (no expiration)
CALL grant_deal_access('reviewer@company.com', 'DEAL_ABC_2025', 'READ', NULL);

-- Revoke access
CALL revoke_deal_access('analyst@company.com', 'DEAL_ABC_2025');

-- View all permissions
SELECT * FROM v_active_permissions;
```

### Enabling Row-Level Security

**Important**: Row-level security is **disabled by default** to allow initial data loading. Enable after setup:

```sql
-- Apply row access policy to tables
ALTER TABLE trial_balance_raw ADD ROW ACCESS POLICY rap_deal_access ON (deal_id);
ALTER TABLE account_mappings ADD ROW ACCESS POLICY rap_deal_access ON (deal_id);
ALTER TABLE ai_insights ADD ROW ACCESS POLICY rap_deal_access ON (deal_id);

-- Verify policy applied
SHOW ROW ACCESS POLICIES;
```

---

## Operational Procedures

### 1. Loading New Deal Data

```sql
-- Step 1: Upload CSV files to stage
PUT file:///local/path/trial_balance_deal_xyz.csv @fdd_input_stage AUTO_COMPRESS=FALSE;
PUT file:///local/path/account_mappings_deal_xyz.csv @fdd_input_stage AUTO_COMPRESS=FALSE;

-- Step 2: Load trial balance
CALL load_trial_balance('trial_balance_deal_xyz.csv', 'DEAL_XYZ_2025');
-- Returns: status, rows_loaded, errors_found, message

-- Step 3: Load account mappings
CALL load_account_mappings('account_mappings_deal_xyz.csv', 'DEAL_XYZ_2025');
-- Returns: status, rows_loaded, message

-- Step 4: Validate data quality
CALL validate_data_quality('DEAL_XYZ_2025');
-- Returns: check_name, passed, severity, message

-- Review any errors
SELECT * FROM load_errors WHERE deal_id = 'DEAL_XYZ_2025' ORDER BY error_timestamp DESC;
```

### 2. Generating Financial Schedules

```sql
-- Generate all schedules and AI insights for a deal
CALL generate_fdd_schedules('DEAL_XYZ_2025');

-- Output files created in @fdd_output_stage:
-- - database_tab_DEAL_XYZ_2025.csv (pivoted trial balance)
-- - income_statement_DEAL_XYZ_2025.csv (IS structure with metadata)
-- - balance_sheet_DEAL_XYZ_2025.csv (BS structure with metadata)
-- - ai_insights_DEAL_XYZ_2025.csv (AI-generated variance analysis)
```

### 3. Downloading Outputs

```sql
-- List available output files
LIST @fdd_output_stage;

-- Download to local machine
GET @fdd_output_stage/database_tab_DEAL_XYZ_2025.csv file:///local/download/path/;
GET @fdd_output_stage/ai_insights_DEAL_XYZ_2025.csv file:///local/download/path/;

-- Or download via SnowSight UI: Data > Stages > fdd_output_stage > Select file > Download
```

### 4. Running the Complete PoC Demo

```sql
-- One-command demo execution
CALL run_complete_poc();

-- This automatically:
-- 1. Loads sample data (DEAL_HL_001)
-- 2. Generates all schedules
-- 3. Exports to @fdd_output_stage

-- Retrieve outputs
GET @fdd_output_stage/database_tab_DEAL_HL_001.csv file:///local/path/;
```

---

## Monitoring & Troubleshooting

### Audit Log Queries

```sql
-- View recent procedure executions
SELECT 
    log_timestamp,
    procedure_name,
    deal_id,
    user_name,
    status,
    duration_seconds,
    rows_affected,
    message
FROM audit_log
ORDER BY log_timestamp DESC
LIMIT 50;

-- Failed operations
SELECT * FROM audit_log 
WHERE status = 'ERROR' 
ORDER BY log_timestamp DESC;

-- Performance analysis
SELECT 
    procedure_name,
    COUNT(*) AS execution_count,
    AVG(duration_seconds) AS avg_duration,
    MAX(duration_seconds) AS max_duration
FROM audit_log
WHERE status = 'SUCCESS'
GROUP BY procedure_name
ORDER BY avg_duration DESC;
```

### Data Quality Monitoring

```sql
-- Recent data quality checks
SELECT 
    check_timestamp,
    deal_id,
    check_name,
    passed,
    severity,
    message
FROM data_quality_checks
ORDER BY check_timestamp DESC
LIMIT 20;

-- Failed checks requiring attention
SELECT * FROM data_quality_checks
WHERE NOT passed AND severity IN ('ERROR', 'CRITICAL')
ORDER BY check_timestamp DESC;
```

### Error Investigation

```sql
-- View recent errors
SELECT 
    error_timestamp,
    deal_id,
    file_name,
    error_type,
    error_message,
    line_content
FROM load_errors
WHERE NOT is_resolved
ORDER BY error_timestamp DESC;

-- Mark errors as resolved
UPDATE load_errors
SET is_resolved = TRUE,
    resolved_by = CURRENT_USER(),
    resolved_timestamp = CURRENT_TIMESTAMP(),
    resolution_notes = 'Data corrected and reloaded'
WHERE error_id = '<error_id>';
```

### Performance Monitoring

```sql
-- Query warehouse credit usage
SELECT 
    DATE_TRUNC('day', start_time) AS date,
    warehouse_name,
    SUM(credits_used) AS total_credits,
    COUNT(*) AS query_count
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE warehouse_name = 'FDD_POC_WH'
AND start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY 1, 2
ORDER BY 1 DESC;

-- Identify slow queries
SELECT 
    query_id,
    query_text,
    execution_time / 1000 AS execution_seconds,
    total_elapsed_time / 1000 AS total_seconds,
    rows_produced,
    bytes_scanned
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE warehouse_name = 'FDD_POC_WH'
AND start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY execution_time DESC
LIMIT 10;
```

---

## Security Considerations

### 1. SQL Injection Protection

All procedures use **input validation** and **parameterized queries**:

```sql
-- Example: deal_id validation
IF (NOT validate_deal_id(:deal_id_param)) THEN
    RETURN 'ERROR: Invalid deal_id format';
END IF;

-- Sanitization before use
safe_deal_id := sanitize_deal_id(:deal_id_param);
```

Deal IDs must match regex: `^[A-Z0-9_-]+$` (alphanumeric with underscores/hyphens only).

### 2. Least-Privilege Access

- **Never use `ACCOUNTADMIN` for daily operations**
- Analysts use `FDD_ANALYST_ROLE` with limited permissions
- Service accounts use `FDD_SERVICE_ROLE` with no user login
- Read-only users get `FDD_READONLY_ROLE`

### 3. Network Security (Optional)

Restrict access to specific IP ranges:

```sql
CREATE NETWORK POLICY fdd_network_policy
    ALLOWED_IP_LIST = ('203.0.113.0/24', '198.51.100.0/24')  -- Your office IPs
    COMMENT = 'Restrict FDD system access to corporate network';

ALTER USER analyst@company.com SET NETWORK_POLICY = fdd_network_policy;
```

### 4. Data Masking (Optional)

Enable column masking for sensitive financial amounts:

```sql
-- Apply masking policy (already created, just uncomment)
ALTER TABLE trial_balance_raw MODIFY COLUMN net_amount SET MASKING POLICY mask_financial_amounts;
ALTER TABLE trial_balance_raw MODIFY COLUMN debit_amount SET MASKING POLICY mask_financial_amounts;
ALTER TABLE trial_balance_raw MODIFY COLUMN credit_amount SET MASKING POLICY mask_financial_amounts;

-- Read-only users will see NULL instead of actual amounts
```

### 5. Audit Compliance

All operations are automatically logged:

```sql
-- Export audit trail for compliance review
COPY INTO @fdd_output_stage/audit_trail_2025Q1.csv
FROM (
    SELECT * FROM audit_log 
    WHERE log_timestamp BETWEEN '2025-01-01' AND '2025-03-31'
)
FILE_FORMAT = csv_format
HEADER = TRUE;
```

---

## Cost Optimization

### Warehouse Management

```sql
-- Monitor warehouse utilization
SELECT 
    DATE_TRUNC('hour', start_time) AS hour,
    COUNT(*) AS query_count,
    SUM(execution_time) / 1000 / 3600 AS compute_hours,
    SUM(credits_used) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE warehouse_name = 'FDD_POC_WH'
AND start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY 1
ORDER BY 1 DESC;

-- Adjust auto-suspend (default: 60 seconds)
ALTER WAREHOUSE FDD_POC_WH SET AUTO_SUSPEND = 120;  -- 2 minutes

-- Enable multi-cluster auto-scaling
ALTER WAREHOUSE FDD_POC_WH SET 
    MIN_CLUSTER_COUNT = 1,
    MAX_CLUSTER_COUNT = 3,
    SCALING_POLICY = 'STANDARD';
```

### Cortex AI Cost Tracking

```sql
-- Track AI usage and estimated costs
SELECT 
    deal_id,
    model_used,
    COUNT(*) AS insight_count,
    SUM(prompt_tokens) AS total_prompt_tokens,
    SUM(completion_tokens) AS total_completion_tokens,
    SUM(estimated_cost_usd) AS estimated_cost
FROM ai_insights
WHERE generated_timestamp >= DATEADD(month, -1, CURRENT_TIMESTAMP())
GROUP BY deal_id, model_used
ORDER BY estimated_cost DESC;

-- Reduce AI costs by lowering max_ai_insights
CALL update_config('max_ai_insights', 10, 'Cost optimization');
```

### Data Retention Policies

```sql
-- Clean up old audit logs (retain 90 days by default)
DELETE FROM audit_log 
WHERE log_timestamp < DATEADD(day, -90, CURRENT_TIMESTAMP());

-- Clean up resolved errors (retain 180 days)
DELETE FROM load_errors 
WHERE is_resolved = TRUE 
AND resolved_timestamp < DATEADD(day, -180, CURRENT_TIMESTAMP());

-- Archive old outputs from stage
REMOVE @fdd_output_stage PATTERN='.*_DEAL_.*\.csv' 
WHERE last_modified < DATEADD(day, -30, CURRENT_TIMESTAMP());
```

---

## Support & Escalation

### Common Issues & Solutions

**Issue**: "No trial balance data found"
```sql
-- Check if data was loaded
SELECT deal_id, COUNT(*) FROM trial_balance_raw GROUP BY deal_id;

-- Reload if needed
CALL load_trial_balance('file.csv', 'DEAL_ID');
```

**Issue**: "ERROR: Invalid deal_id format"
```
Solution: Deal IDs must be alphanumeric with underscores/hyphens only
Valid: DEAL_HL_001, DEAL-ABC-2025
Invalid: DEAL@123, DEAL#XYZ
```

**Issue**: "X accounts missing mappings"
```sql
-- Identify unmapped accounts
SELECT DISTINCT t.account_number, t.account_name
FROM trial_balance_raw t
LEFT JOIN account_mappings m ON t.deal_id = m.deal_id AND t.account_number = m.account_number
WHERE t.deal_id = 'DEAL_ID' AND m.account_number IS NULL;

-- Add missing mappings to CSV and reload
```

### Contact Information

For technical support with this deployment package:
- **Email**: support@example.com
- **Documentation**: See `docs/` directory
- **GitHub Issues**: <repository-url>/issues

---

## Appendix: File Structure

```
production/
├── sql/
│   ├── 00_system_config.sql        # Configuration management
│   ├── 01_schema.sql                # Core tables and views
│   ├── 02_security.sql              # Roles, RLS, permissions
│   ├── 03_data_procedures.sql       # Load & validation procedures
│   ├── 04_schedule_generation.sql   # Income Statement & Balance Sheet
│   ├── 05_ai_and_export.sql         # AI insights & export procedures
│   └── deploy.sql                   # Master deployment script
├── docs/
│   ├── DEPLOYMENT_GUIDE.md          # This file
│   ├── OPERATIONS_MANUAL.md         # Day-to-day operations
│   ├── SECURITY_GUIDE.md            # Detailed security configuration
│   └── API_REFERENCE.md             # Procedure/function reference
├── tests/
│   └── test_suite.sql               # Automated test cases
└── README.md                        # Quick start guide
```

---

**Deployment Guide Version**: 1.0.0  
**Last Updated**: October 20, 2025  
**Snowflake Compatibility**: Enterprise Edition (Business Critical recommended)


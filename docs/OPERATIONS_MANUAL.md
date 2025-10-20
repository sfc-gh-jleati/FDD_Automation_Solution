# Houlihan Lokey FDD Automation - Operations Manual

## Daily Operations Guide

This manual provides step-by-step instructions for analysts performing financial due diligence using the FDD Automation platform.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Loading New Deal Data](#loading-new-deal-data)
3. [Generating Financial Schedules](#generating-financial-schedules)
4. [Working with AI Insights](#working-with-ai-insights)
5. [Troubleshooting Common Issues](#troubleshooting-common-issues)
6. [Best Practices](#best-practices)

---

## Getting Started

### Accessing Snowflake

1. **Login to Snowflake**
   - URL: `https://<your-account>.snowflakecomputing.com`
   - Use your corporate SSO credentials

2. **Switch to FDD Role**
   ```sql
   USE ROLE FDD_ANALYST_ROLE;
   USE DATABASE HL_FDD_POC;
   USE SCHEMA TRIAL_BALANCE;
   USE WAREHOUSE FDD_POC_WH;
   ```

3. **Verify Your Permissions**
   ```sql
   -- View deals you have access to
   SELECT DISTINCT deal_id FROM trial_balance_raw;
   
   -- View your permissions
   SELECT * FROM v_active_permissions WHERE user_name = CURRENT_USER();
   ```

---

## Loading New Deal Data

### Prerequisites

- Trial balance CSV file (monthly or periodic data)
- Account mappings CSV file (chart of accounts with hierarchy)
- Deal access permissions granted by admin

### Step 1: Prepare Your Data Files

**Trial Balance Format:**
```csv
deal_id,deal_name,entity,period_date,account_number,account_name,debit_amount,credit_amount,net_amount
DEAL_ABC_2025,ABC Manufacturing,ABC Corp,2024-01-31,1000,Cash,50000.00,0.00,50000.00
DEAL_ABC_2025,ABC Manufacturing,ABC Corp,2024-01-31,4000,Revenue,0.00,100000.00,-100000.00
```

**Account Mappings Format:**
```csv
deal_id,account_number,account_name,account_category,statement_type,mapping_level_1,mapping_level_2,mapping_level_3,sort_order_l1,sort_order_l2,sort_order_l3
DEAL_ABC_2025,4000,Revenue,Revenue,IS,Revenue,Product Sales,,10,10,
DEAL_ABC_2025,5000,COGS,COGS,IS,Cost of Goods Sold,Direct Materials,,20,10,
```

### Step 2: Upload Files to Snowflake

**Using SnowSight Web UI:**
1. Navigate to: Data > Databases > HL_FDD_POC > TRIAL_BALANCE > Stages
2. Click on `fdd_input_stage`
3. Click "+ Files" and upload your CSV files

**Using SnowSQL CLI:**
```bash
snowsql -a <account> -u <username>

PUT file:///Users/john/Downloads/trial_balance_ABC.csv @fdd_input_stage AUTO_COMPRESS=FALSE;
PUT file:///Users/john/Downloads/account_mappings_ABC.csv @fdd_input_stage AUTO_COMPRESS=FALSE;
```

### Step 3: Load Trial Balance

```sql
-- Load trial balance data
CALL load_trial_balance('trial_balance_ABC.csv', 'DEAL_ABC_2025');

-- Expected output:
-- status    | rows_loaded | errors_found | message
-- SUCCESS   | 1200        | 0            | Loaded 1200 rows. All periods balanced.
```

**Interpret Results:**
- ✅ **SUCCESS**: Data loaded successfully, all validation checks passed
- ⚠️ **WARNING**: Data loaded but some periods are unbalanced (check details)
- ❌ **ERROR**: Load failed due to high error rate or critical issues

### Step 4: Load Account Mappings

```sql
-- Load account mappings
CALL load_account_mappings('account_mappings_ABC.csv', 'DEAL_ABC_2025');

-- Expected output:
-- status    | rows_loaded | message
-- SUCCESS   | 25          | Loaded 25 account mappings. All accounts mapped.
```

**If you see warnings about unmapped accounts:**
```sql
-- Identify unmapped accounts
SELECT DISTINCT t.account_number, t.account_name
FROM trial_balance_raw t
LEFT JOIN account_mappings m ON t.deal_id = m.deal_id AND t.account_number = m.account_number
WHERE t.deal_id = 'DEAL_ABC_2025' AND m.account_number IS NULL;

-- Add missing accounts to your mapping file and reload
```

### Step 5: Validate Data Quality

```sql
-- Run comprehensive validation
CALL validate_data_quality('DEAL_ABC_2025');

-- Review results:
-- check_name                    | passed | severity | message
-- Trial Balance Existence       | TRUE   | INFO     | Found 1200 records
-- Account Mapping Completeness  | TRUE   | INFO     | All accounts mapped
-- Period Continuity             | FALSE  | WARNING  | 1 month gap in period sequence
-- Revenue Sign Check            | TRUE   | INFO     | Revenue signs look correct
-- Duplicate Records             | TRUE   | INFO     | No duplicates found
```

**Action Required if checks fail:**
- **CRITICAL**: Fix immediately - data cannot be processed
- **ERROR**: Fix soon - will cause issues in schedules
- **WARNING**: Review - may indicate data quality issues but processing can continue
- **INFO**: Passed - no action needed

---

## Generating Financial Schedules

### Quick Generation (One Command)

```sql
-- Generate all schedules and AI insights
CALL generate_fdd_schedules('DEAL_ABC_2025');

-- This will:
-- 1. Generate Income Statement structure
-- 2. Generate Balance Sheet structure
-- 3. Create AI-powered variance insights
-- 4. Export all outputs to @fdd_output_stage

-- Expected output:
-- SUCCESS: 1200 TB rows processed, 15 AI insights generated for DEAL_ABC_2025.
-- Outputs available at @fdd_output_stage/*_DEAL_ABC_2025.csv
```

### Step-by-Step Generation (Advanced)

If you need more control:

```sql
-- Step 1: Generate Income Statement
CALL generate_income_statement('DEAL_ABC_2025');

-- Step 2: Generate Balance Sheet
CALL generate_balance_sheet('DEAL_ABC_2025');

-- Step 3: Generate AI insights
CALL generate_ai_insights('DEAL_ABC_2025');

-- Step 4: Export each component
CALL export_database_tab('DEAL_ABC_2025');
CALL export_income_statement_structure('DEAL_ABC_2025');
CALL export_balance_sheet_structure('DEAL_ABC_2025');
CALL export_ai_insights('DEAL_ABC_2025');
```

### Downloading Output Files

**Using SnowSight Web UI:**
1. Navigate to: Data > Stages > fdd_output_stage
2. Find your files (prefixed with `DEAL_ABC_2025`)
3. Click download icon

**Using SnowSQL:**
```bash
# List available files
LIST @fdd_output_stage PATTERN='.*_DEAL_ABC_2025.*';

# Download all files for a deal
GET @fdd_output_stage/database_tab_DEAL_ABC_2025.csv file:///Users/john/Downloads/;
GET @fdd_output_stage/income_statement_DEAL_ABC_2025.csv file:///Users/john/Downloads/;
GET @fdd_output_stage/balance_sheet_DEAL_ABC_2025.csv file:///Users/john/Downloads/;
GET @fdd_output_stage/ai_insights_DEAL_ABC_2025.csv file:///Users/john/Downloads/;
```

---

## Working with AI Insights

### Understanding AI-Generated Insights

The system uses **Snowflake Cortex AI (Claude 4 Sonnet)** to automatically identify and explain significant variances.

**Example AI Insight:**
```
Account: Cost of Goods Sold - Raw Materials
Change: $45,000 to $72,000 (60% increase) from Jan-2024 to Feb-2024
Severity: HIGH

AI Analysis:
"This 60% month-over-month increase in raw materials costs could indicate 
supplier price increases, changes in product mix requiring more expensive 
inputs, or inventory build-up ahead of anticipated demand. The analyst 
should verify whether this correlates with revenue growth or represents 
margin compression requiring management explanation."

Suggested Question for Management:
"Why did raw materials costs increase by 60% from Jan-2024 to Feb-2024?"
```

### Reviewing AI Insights

```sql
-- View all insights for a deal, ordered by severity
SELECT 
    insight_type,
    severity,
    account_name,
    TO_CHAR(period_date, 'Mon YYYY') AS period,
    variance_pct,
    insight_text,
    suggested_question
FROM ai_insights
WHERE deal_id = 'DEAL_ABC_2025'
ORDER BY 
    CASE severity WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    ABS(variance_pct) DESC;

-- Filter to high-severity insights only
SELECT * FROM ai_insights
WHERE deal_id = 'DEAL_ABC_2025'
AND severity = 'high';
```

### Customizing AI Insights

```sql
-- Increase number of insights generated (default: 15)
CALL update_config('max_ai_insights', 25, 'Large deal with many accounts');

-- Change variance threshold (default: 20%)
CALL update_config('variance_threshold_pct', 0.15, 'More sensitive variance detection');

-- Regenerate insights with new settings
CALL generate_ai_insights('DEAL_ABC_2025');
```

### Cost Considerations

AI insight generation uses Snowflake Cortex, which has associated costs:

```sql
-- Estimate cost for last 30 days
SELECT 
    COUNT(*) AS total_insights,
    SUM(prompt_tokens) AS prompt_tokens,
    SUM(completion_tokens) AS completion_tokens,
    ROUND(SUM(estimated_cost_usd), 2) AS estimated_cost_usd
FROM ai_insights
WHERE generated_timestamp >= DATEADD(day, -30, CURRENT_TIMESTAMP());

-- Typical cost: $0.01 - $0.05 per insight (varies by model and complexity)
```

---

## Troubleshooting Common Issues

### Issue 1: "ERROR: Invalid deal_id format"

**Cause**: Deal ID contains invalid characters

**Solution**: Use only alphanumeric characters, underscores, and hyphens
```
✅ Valid: DEAL_HL_001, DEAL-ABC-2025, DEAL_XYZ_Q1
❌ Invalid: DEAL@123, DEAL#ABC, DEAL 001 (spaces)
```

### Issue 2: "No trial balance data found"

**Cause**: Data not loaded or wrong deal_id

**Solution**:
```sql
-- Check if data exists
SELECT deal_id, COUNT(*) AS row_count
FROM trial_balance_raw
GROUP BY deal_id;

-- Reload data if missing
CALL load_trial_balance('file.csv', 'CORRECT_DEAL_ID');
```

### Issue 3: "X accounts missing mappings"

**Cause**: Account mappings file incomplete

**Solution**:
```sql
-- Identify unmapped accounts
SELECT DISTINCT t.account_number, t.account_name
FROM trial_balance_raw t
LEFT JOIN account_mappings m ON t.deal_id = m.deal_id AND t.account_number = m.account_number
WHERE t.deal_id = 'DEAL_ABC_2025' AND m.account_number IS NULL;

-- Export list for easy mapping creation
COPY INTO @fdd_output_stage/unmapped_accounts_DEAL_ABC_2025.csv
FROM (
    SELECT DISTINCT t.account_number, t.account_name, '' AS mapping_level_1
    FROM trial_balance_raw t
    LEFT JOIN account_mappings m ON t.deal_id = m.deal_id AND t.account_number = m.account_number
    WHERE t.deal_id = 'DEAL_ABC_2025' AND m.account_number IS NULL
)
FILE_FORMAT = csv_format HEADER = TRUE;

-- Download, complete mappings, and reload
```

### Issue 4: "Periods out of balance"

**Cause**: Trial balance debits ≠ credits (accounting error)

**Solution**:
```sql
-- Identify unbalanced periods
SELECT 
    period_date,
    SUM(debit_amount) AS total_debits,
    SUM(credit_amount) AS total_credits,
    SUM(debit_amount) - SUM(credit_amount) AS imbalance
FROM trial_balance_raw
WHERE deal_id = 'DEAL_ABC_2025'
GROUP BY period_date
HAVING ABS(SUM(debit_amount) - SUM(credit_amount)) > 0.10
ORDER BY period_date;

-- This is a data quality issue - contact deal team or client
```

### Issue 5: "ERROR rate too high"

**Cause**: > 5% of rows failed to load due to formatting issues

**Solution**:
```sql
-- Review specific errors
SELECT 
    error_timestamp,
    row_number,
    error_message,
    line_content
FROM load_errors
WHERE deal_id = 'DEAL_ABC_2025'
AND NOT is_resolved
ORDER BY error_timestamp DESC;

-- Common issues:
-- - Extra/missing columns (check CSV format)
-- - Invalid dates (use YYYY-MM-DD format)
-- - Non-numeric amounts (remove $ signs, commas)
-- - Special characters in account names (use quotes)
```

### Issue 6: "Session expired" or "Temp table not found"

**Cause**: Long idle time between procedure calls

**Solution**:
```sql
-- Regenerate temp tables by re-running schedule generation
CALL generate_income_statement('DEAL_ABC_2025');
CALL generate_balance_sheet('DEAL_ABC_2025');

-- Or use the master procedure which handles everything
CALL generate_fdd_schedules('DEAL_ABC_2025');
```

---

## Best Practices

### Data Preparation

1. **Use Consistent Date Formats**: Always YYYY-MM-DD (e.g., 2024-01-31)
2. **Clean Amount Fields**: Remove $ signs, commas, and currency symbols
3. **Standardize Account Numbers**: Use consistent format (e.g., 1000, not 1,000 or 1000.00)
4. **Complete Account Mappings**: Map ALL accounts before loading
5. **Test with Small Dataset**: Validate format with 100 rows before loading full file

### Deal ID Naming Conventions

```
Recommended Format: DEAL_<CLIENT>_<PROJECT>_<YEAR>

Examples:
- DEAL_HL_ABC_2025
- DEAL_MANUFACTURING_Q1_2024
- DEAL_SAAS_SERIES_B_2025

Avoid:
- Generic names (DEAL_001)
- Special characters (@, #, %, spaces)
- Very long names (>50 characters)
```

### Workflow Checklist

**For Each New Deal:**
- [ ] Receive trial balance and mapping files from engagement team
- [ ] Validate file formats and completeness (spot check in Excel)
- [ ] Request deal access from admin if needed
- [ ] Upload files to @fdd_input_stage
- [ ] Load trial balance → review results
- [ ] Load account mappings → review results
- [ ] Run data quality validation → fix any issues
- [ ] Generate schedules → review outputs
- [ ] Download and review AI insights
- [ ] Share outputs with engagement team

### Performance Tips

1. **Schedule Heavy Processing During Off-Hours**
   - AI insight generation can take 5-10 minutes for large deals
   - Run overnight or during low-usage periods

2. **Use Filters When Querying Large Datasets**
   ```sql
   -- Good: Filtered query
   SELECT * FROM trial_balance_raw WHERE deal_id = 'DEAL_ABC_2025';
   
   -- Bad: Full table scan
   SELECT * FROM trial_balance_raw;
   ```

3. **Clean Up Old Files from Stage**
   ```sql
   -- Remove files older than 30 days
   REMOVE @fdd_output_stage PATTERN='.*_DEAL_ABC_.*' 
   WHERE last_modified < DATEADD(day, -30, CURRENT_TIMESTAMP());
   ```

### Audit Trail

All your actions are automatically logged:

```sql
-- View your recent activity
SELECT 
    log_timestamp,
    procedure_name,
    deal_id,
    status,
    duration_seconds,
    message
FROM audit_log
WHERE user_name = CURRENT_USER()
ORDER BY log_timestamp DESC
LIMIT 20;
```

---

## Quick Reference: Essential Commands

```sql
-- Setup
USE ROLE FDD_ANALYST_ROLE;
USE DATABASE HL_FDD_POC;
USE SCHEMA TRIAL_BALANCE;
USE WAREHOUSE FDD_POC_WH;

-- Load Data
CALL load_trial_balance('file.csv', 'DEAL_ID');
CALL load_account_mappings('file.csv', 'DEAL_ID');

-- Validate
CALL validate_data_quality('DEAL_ID');

-- Generate Everything
CALL generate_fdd_schedules('DEAL_ID');

-- Download Outputs
GET @fdd_output_stage/database_tab_DEAL_ID.csv file:///local/path/;

-- Check Status
SELECT * FROM audit_log WHERE deal_id = 'DEAL_ID' ORDER BY log_timestamp DESC;

-- View Errors
SELECT * FROM load_errors WHERE deal_id = 'DEAL_ID' AND NOT is_resolved;
```

---

## Getting Help

**For Technical Issues:**
- Check error message in audit_log table
- Review load_errors table for data quality issues
- Consult this operations manual

**For Access/Permission Issues:**
- Contact your FDD admin or IT team
- Request deal access: "Please grant me access to DEAL_ABC_2025"

**For Data/Business Questions:**
- Contact engagement team lead
- Review AI insights for suggested questions
- Consult deal documentation

---

**Operations Manual Version**: 1.0.0  
**Last Updated**: October 20, 2025  
**Target Audience**: FDD Analysts, Business Users


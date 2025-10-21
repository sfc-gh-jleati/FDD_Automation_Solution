# Deployment Options

This directory contains two deployment scripts depending on your deployment method:

## Option 1: SnowSight (Web UI) - **RECOMMENDED FOR MOST USERS**

**File**: `deploy_snowsight.sql` (2,386 lines, single file)

**When to use**: 
- You're using Snowflake's web interface (SnowSight)
- You want a simple "upload and run" experience
- You prefer clicking "Run All" in a web browser

**How to use**:
1. Open SnowSight (https://app.snowflake.com)
2. Navigate to: **Worksheets** > **︙** (menu) > **Create Worksheet from SQL File**
3. Select `deploy_snowsight.sql`
4. **Important**: Edit lines 26-31 to configure your environment:
   ```sql
   SET ENVIRONMENT_NAME = 'PRODUCTION';  -- or DEVELOPMENT
   SET DATABASE_NAME = 'HL_FDD_POC';
   SET WAREHOUSE_NAME = 'FDD_POC_WH';
   SET WAREHOUSE_SIZE = 'SMALL';  -- Adjust as needed
   SET AUTO_SUSPEND_SECONDS = 60;
   ```
5. Ensure you're using **ACCOUNTADMIN** role (or equivalent)
6. Click **"Run All"** button (▶ dropdown > Run All)
7. Wait 2-5 minutes for completion
8. Verify success: Check for "✓ DEPLOYMENT SUCCESSFUL" message

---

## Option 2: SnowSQL (CLI)

**File**: `deploy.sql` (uses `!source` to load modular files)

**When to use**:
- You're using SnowSQL command-line interface
- You want to maintain modular SQL files separately
- You're automating deployments via CI/CD

**Prerequisites**:
- SnowSQL installed: `brew install snowflake-cli` or download from [Snowflake](https://developers.snowflake.com/snowsql/)
- Configured connection: `snowsql --accountname <account> --username <user>`

**How to use**:
```bash
# Navigate to sql directory
cd production/sql

# Run deployment (will prompt for password)
snowsql -a <account> -u <username> -r ACCOUNTADMIN -f deploy.sql

# Or with config profile
snowsql -c myprofile -r ACCOUNTADMIN -f deploy.sql
```

The `deploy.sql` script uses `!source` commands to load:
- `00_system_config.sql` - Configuration management
- `01_schema.sql` - Core tables and views
- `02_security.sql` - Roles and security policies
- `03_data_procedures.sql` - Data loading procedures
- `04_schedule_generation.sql` - Income Statement & Balance Sheet
- `05_ai_and_export.sql` - AI insights and exports

---

## Which Should I Use?

| Scenario | Recommended Script | Why |
|----------|-------------------|-----|
| First-time deployment | `deploy_snowsight.sql` | Easier, single file, web-based |
| Production deployment | `deploy_snowsight.sql` | More reliable, no CLI dependencies |
| Development/testing | Either | Both work equally well |
| CI/CD automation | `deploy.sql` | Easier to script with SnowSQL |
| Want to modify code | `deploy.sql` | Modular files easier to edit |
| Quick POC/demo | `deploy_snowsight.sql` | Fastest to get started |

---

## Post-Deployment Steps

After successful deployment with **either script**:

1. **Grant User Access**:
   ```sql
   GRANT ROLE FDD_ANALYST_ROLE TO USER john.smith@company.com;
   CALL grant_deal_access('john.smith@company.com', 'DEAL_HL_001', 'WRITE', 90);
   ```

2. **Upload Sample Data** (for testing):
   ```sql
   -- In SnowSight: Data > Stages > fdd_input_stage > + Files
   -- Upload: 01_sample_trial_balance_24mo.csv
   -- Upload: 02_sample_account_mappings_24mo.csv
   
   -- Or via SnowSQL:
   PUT file://../../examples/01_sample_trial_balance_24mo.csv @fdd_input_stage;
   PUT file://../../examples/02_sample_account_mappings_24mo.csv @fdd_input_stage;
   ```

3. **Run POC Demo**:
   ```sql
   CALL run_complete_poc();
   
   -- Download outputs
   LIST @fdd_output_stage;
   GET @fdd_output_stage/database_tab_DEAL_HL_001.csv file:///downloads/;
   ```

4. **Enable Row-Level Security** (after initial testing):
   ```sql
   ALTER TABLE trial_balance_raw ADD ROW ACCESS POLICY rap_deal_access ON (deal_id);
   ALTER TABLE account_mappings ADD ROW ACCESS POLICY rap_deal_access ON (deal_id);
   ALTER TABLE ai_insights ADD ROW ACCESS POLICY rap_deal_access ON (deal_id);
   ```

---

## Troubleshooting

### Error: "syntax error line X unexpected '!'"
- **Cause**: Using `!source` command in SnowSight
- **Solution**: Use `deploy_snowsight.sql` instead of `deploy.sql`

### Error: "value exceeds size limit 256 bytes"
- **Cause**: Session variable size limit
- **Solution**: Already fixed in both scripts (uses anonymous blocks)

### Error: "invalid type of property for 'AUTO_SUSPEND'"
- **Cause**: Old warehouse syntax
- **Solution**: Already fixed in both scripts (uses EXECUTE IMMEDIATE)

### Deployment takes > 10 minutes
- **Normal**: First deployment can take 5-10 minutes
- **Check**: Look for error messages in output
- **Verify**: Run validation query:
  ```sql
  SELECT * FROM schema_migrations WHERE version = '1.0.0';
  ```

---

## File Comparison

| Feature | deploy_snowsight.sql | deploy.sql |
|---------|---------------------|------------|
| Total lines | 2,386 | 331 (+ modular files) |
| File count | 1 file | 7 files |
| SnowSight compatible | ✅ Yes | ❌ No (!source not supported) |
| SnowSQL compatible | ✅ Yes | ✅ Yes |
| Easier to edit | ❌ Large file | ✅ Modular files |
| Easier to deploy | ✅ Single upload | ❌ CLI required |
| Functionality | 100% identical | 100% identical |

---

## Additional Resources

- **Deployment Guide**: `/production/docs/DEPLOYMENT_GUIDE.md`
- **Operations Manual**: `/production/docs/OPERATIONS_MANUAL.md`
- **GitHub Repository**: https://github.com/sfc-gh-jleati/FDD_Automation_Solution

**Questions?** See `/production/docs/` directory for comprehensive documentation.


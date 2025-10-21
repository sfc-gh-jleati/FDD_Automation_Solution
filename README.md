# Houlihan Lokey FDD Automation Solution

**Enterprise-grade Financial Due Diligence automation powered by Snowflake and AI**

---

## 📋 Overview

This solution automates the generation of Financial Due Diligence (FDD) schedules for M&A transactions, reducing manual effort from hours to seconds while leveraging Snowflake's Cortex AI for intelligent variance analysis.

### Key Capabilities

- **Automated Schedule Generation**: Income Statement and Balance Sheet structures with Excel-compatible formatting
- **AI-Powered Insights**: Variance analysis and trend detection using Snowflake Cortex
- **Data Quality Validation**: Comprehensive checks for trial balance integrity
- **Audit Trail**: Complete tracking of all data loads and transformations
- **Excel Integration**: Exports CSV files formatted for direct Excel import with SUMIF formula compatibility
- **🆕 Admin Dashboard**: Streamlit-based web UI for monitoring, configuration, and management

### Business Value

- ⏱️ **Time Savings**: Reduce schedule generation from 2-4 hours to <1 minute
- 🎯 **Accuracy**: Eliminate manual errors in data aggregation and calculations
- 🔍 **Intelligence**: AI-generated insights highlight key variances and trends
- 📊 **Scalability**: Process multiple deals concurrently with deal-level isolation
- 🔒 **Security**: Row-level security and role-based access control

---

## 🏗️ Architecture

### Technology Stack

- **Platform**: Snowflake Data Cloud
- **AI/ML**: Snowflake Cortex (Claude 4 Sonnet)
- **Language**: Snowflake SQL + Snowflake Scripting
- **Integration**: CSV-based data exchange with Excel

### Key Components

1. **Data Layer**: Trial balance and account mapping tables with versioning
2. **Processing Layer**: Stored procedures for data validation and transformation
3. **Presentation Layer**: Views that pivot data into Excel-compatible formats
4. **Export Layer**: CSV generation with proper formatting for Excel import
5. **AI Layer**: Cortex-powered variance analysis and insights

---

## 🚀 Quick Start

### Prerequisites

- Snowflake account with `ACCOUNTADMIN` privileges
- Warehouse with size `SMALL` or larger
- CSV files with trial balance and account mapping data

### Deployment (5 minutes)

**Option 1: Snowsight UI (Recommended)**
1. Open [Snowsight](https://app.snowflake.com/)
2. Create new worksheet
3. Copy entire contents of `sql/deploy_snowsight.sql`
4. Execute all (⌘+Enter or Ctrl+Enter)
5. Wait ~2-3 minutes for completion

**Option 2: SnowSQL CLI**
```bash
snowsql -c your_connection
!source sql/deploy.sql
```

### Verification

```sql
-- Run production validation
!source tests/production_validation.sql
```

Expected output: All checks show ✅ PASS

### Optional: Deploy Admin Dashboard (Streamlit)

```sql
-- See streamlit/README.md for complete instructions
-- Upload files to @streamlit_stage via Snowsight UI, then:
!source streamlit/deploy_streamlit.sql
```

Access via: **Projects → Streamlit → FDD Automation Admin Dashboard**

---

## 📂 Repository Structure

```
production/
├── README.md                           # This file
├── HANDOFF_CHECKLIST.md                # Client acceptance checklist
├── HANDOFF.md                          # Detailed handoff documentation
├── PRODUCTION_TEST_RESULTS.md          # Final validation results
├── REPOSITORY_STATUS.md                # Production readiness status
├── REFACTORING_SUMMARY.md              # Technical improvements made
│
├── sql/                                # Snowflake SQL scripts
│   ├── deploy_snowsight.sql            # Complete deployment (Snowsight)
│   ├── deploy.sql                      # Complete deployment (SnowSQL)
│   ├── 00_system_config.sql            # Configuration parameters
│   ├── 01_schema.sql                   # Tables, stages, views
│   ├── 02_security.sql                 # Roles and permissions
│   ├── 03_data_procedures.sql          # Data loading procedures
│   ├── 04_schedule_generation.sql      # Schedule creation procedures
│   ├── 05_ai_and_export.sql            # AI insights and CSV export
│   └── README.md                       # SQL deployment guide
│
├── streamlit/                          # 🆕 Admin Dashboard (Streamlit)
│   ├── fdd_admin_dashboard.py          # Main dashboard application
│   ├── environment.yml                 # Python dependencies
│   ├── deploy_streamlit.sql            # Streamlit deployment script
│   ├── README.md                       # Dashboard documentation
│   └── SNOWSIGHT_DEPLOYMENT_GUIDE.md   # UI deployment guide
│
├── docs/                               # User documentation
│   ├── DEPLOYMENT_GUIDE.md             # Step-by-step deployment instructions
│   └── OPERATIONS_MANUAL.md            # Day-to-day operations guide
│
├── tests/                              # Validation and testing
│   ├── test_suite.sql                  # Automated test suite
│   └── production_validation.sql       # Production readiness validation
│
└── examples/                           # Sample data for testing
    ├── 01_sample_trial_balance_24mo.csv
    └── 02_sample_account_mappings_24mo.csv
```

---

## 💻 Usage

### Basic Workflow

```sql
USE DATABASE HL_FDD_POC;
USE SCHEMA TRIAL_BALANCE;

-- Run complete PoC for demo
CALL run_complete_poc();

-- List generated files
LIST @fdd_output_stage;

-- Download files from Snowsight UI:
-- Data → Databases → HL_FDD_POC → TRIAL_BALANCE → Stages → FDD_OUTPUT_STAGE
```

### Production Workflow

```sql
-- 1. Load trial balance data
CALL load_trial_balance();

-- 2. Load account mappings
CALL load_account_mappings();

-- 3. Generate schedules
CALL generate_fdd_schedules('DEAL_ID');

-- 4. Download CSV files and import into Excel
```

### Output Files

| File | Purpose | Size | Excel Tab |
|------|---------|------|-----------|
| `database_tab_DEAL_ID.csv` | Pivoted data for SUMIF lookups | ~20 KB | Database |
| `income_statement_DEAL_ID.csv` | IS structure with formatting | ~1 KB | Income Statement |
| `balance_sheet_DEAL_ID.csv` | BS structure with formatting | ~700 B | Balance Sheet |
| `ai_insights_DEAL_ID.csv` | AI-generated variance analysis | ~12 KB | AI Insights |

---

## 🆕 Admin Dashboard (Streamlit)

**New Feature:** A comprehensive web-based admin interface for managing the FDD automation solution.

### Dashboard Capabilities

- **📊 Real-time Monitoring**: Track procedure executions, performance metrics, and system health
- **⚙️ Configuration Management**: Update system parameters without writing SQL
- **🎯 AI Threshold Tuning**: Adjust variance thresholds with live impact preview
- **✅ Data Quality Monitoring**: View validation results and failed checks
- **📁 Stage File Management**: Browse and manage input/output files
- **📜 Audit Log Viewer**: Filter and export execution history
- **🚨 Error Diagnostics**: Analyze errors with trend charts and details
- **🧪 System Health Check**: One-click validation of all components

**Access:** `Projects → Streamlit → FDD Automation Admin Dashboard`

**Deployment:** See `streamlit/README.md` for deployment instructions

---

## 🎯 Key Features

### 1. Data Quality Validation

- Trial balance balancing checks (debits = credits)
- Account mapping completeness validation
- Duplicate record detection
- Missing data identification
- Automated error logging

### 2. AI-Powered Insights

- Variance analysis (threshold-based filtering)
- Trend detection across periods
- Contextual explanations generated by Cortex
- Suggested questions for management
- Severity classification (high/medium/low)

### 3. Excel Integration

- CSV files formatted for direct Excel import
- Database tab provides lookup table for SUMIF formulas
- JSON formatting metadata for Excel styling
- Header preservation and column structure

### 4. Security & Governance

- Role-based access control (admin, analyst, viewer roles)
- Row-level security for multi-deal environments
- Comprehensive audit logging
- Secure data handling (no hardcoded credentials)

### 5. Configuration Management

- Centralized system configuration table
- Environment-specific settings (dev/staging/prod)
- Configurable thresholds and parameters
- Version tracking

---

## 🔧 Configuration

### System Parameters

Key configuration parameters in `system_config` table:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `balance_tolerance_dollars` | 0.10 | Acceptable rounding difference |
| `variance_threshold_pct` | 0.20 | Minimum variance to flag (20%) |
| `min_variance_amount` | 5000.00 | Minimum dollar variance to analyze |
| `max_ai_insights` | 15 | Maximum AI insights per deal |
| `ai_model_variance` | claude-4-sonnet | AI model for variance analysis |

### Customization

Modify configuration:
```sql
UPDATE system_config
SET config_value = TO_VARIANT(10000.00)
WHERE config_key = 'min_variance_amount';
```

---

## 📊 Sample Data

Included sample data represents a 24-month trial balance for a fictional company:

- **Periods**: January 2023 - December 2024
- **Accounts**: 29 accounts across Income Statement and Balance Sheet
- **Transactions**: 696 account-period combinations
- **Deal ID**: `DEAL_HL_001`

Use this data to validate deployment and test the solution before production use.

---

## 🛡️ Security Considerations

### Production Deployment

- **Change Default Passwords**: Update all user passwords before production use
- **Review Role Assignments**: Assign users to appropriate roles based on least privilege
- **Enable Row-Level Security**: Uncomment RLS policies in `02_security.sql` if needed
- **Audit Log Retention**: Configure retention periods per compliance requirements
- **Network Policies**: Consider Snowflake network policies for IP whitelisting

### Sensitive Data

- Account mappings may contain proprietary business logic
- AI insights may reveal confidential financial information
- Ensure proper access controls are in place

---

## 📚 Documentation

| Document | Purpose | Audience |
|----------|---------|----------|
| `HANDOFF.md` | Complete technical handoff | Technical team |
| `docs/DEPLOYMENT_GUIDE.md` | Deployment instructions | DevOps/DBAs |
| `docs/OPERATIONS_MANUAL.md` | Daily operations guide | End users |
| `REFACTORING_SUMMARY.md` | Technical improvements made | Architects |
| `sql/README.md` | SQL deployment details | Developers |

---

## 🧪 Testing

### Automated Test Suite

```sql
!source tests/test_suite.sql
```

### Production Validation

```sql
!source tests/production_validation.sql
```

### Manual Testing

1. Load sample data
2. Generate schedules
3. Export CSV files
4. Download and import into Excel
5. Verify SUMIF formulas populate correctly

---

## 🆘 Troubleshooting

### Common Issues

**Issue**: Database tab CSV is empty or missing  
**Solution**: Verify `account_mappings` table has `is_active = TRUE` for all rows
```sql
SELECT COUNT(*) FROM account_mappings WHERE is_active = TRUE;
-- Should return 29 for sample data
```

**Issue**: AI insights generation fails  
**Solution**: Ensure Cortex is enabled in your Snowflake account
```sql
SELECT SNOWFLAKE.CORTEX.COMPLETE('claude-4-sonnet', 'test');
```

**Issue**: Views return 0 rows  
**Solution**: Check data was loaded correctly
```sql
SELECT COUNT(*) FROM trial_balance_raw;  -- Should return 696
SELECT COUNT(*) FROM account_mappings WHERE is_active = TRUE;  -- Should return 29
```

### Support Resources

- **Documentation**: See `docs/` folder for detailed guides
- **Audit Logs**: Query `audit_log` table for execution history
- **Error Logs**: Query `load_errors` table for data quality issues
- **Data Quality**: Query `data_quality_checks` table for validation results

---

## 📈 Performance

### Benchmarks (Sample Data - 696 rows, 29 accounts, 24 periods)

| Operation | Duration | Warehouse Size |
|-----------|----------|----------------|
| Full Deployment | ~120s | N/A (DDL operations) |
| Load Trial Balance | ~2s | SMALL |
| Load Account Mappings | ~1s | SMALL |
| Generate Schedules | ~5s | SMALL |
| Generate AI Insights | ~20s | SMALL |
| Export All CSVs | ~3s | SMALL |
| **Complete PoC** | **~35s** | **SMALL** |

### Scaling Considerations

- **Larger Datasets**: Consider upgrading to MEDIUM or LARGE warehouse
- **Multiple Concurrent Deals**: Leverage multi-cluster warehouses
- **Historical Data**: Partition tables by year if storing >5 years of history

---

## 🔄 Maintenance

### Regular Tasks

- **Weekly**: Review audit logs for errors
- **Monthly**: Clean up old audit logs per retention policy
- **Quarterly**: Review and update AI model versions
- **Annually**: Review and update account mappings

### Schema Migrations

Schema version is tracked in `schema_migrations` table. Future updates will include migration scripts to upgrade existing deployments.

---

## 🤝 Contributing

This solution was developed by Snowflake Professional Services for Houlihan Lokey. For enhancements or issues:

1. Review existing documentation in `docs/` folder
2. Check `HANDOFF.md` for technical details
3. Test changes using `tests/test_suite.sql`
4. Document all modifications

---

## 📄 License

Proprietary - Houlihan Lokey  
© 2025 Snowflake Inc. All rights reserved.

---

## 🎓 Training Resources

### For Developers

1. Review `REFACTORING_SUMMARY.md` for architecture decisions
2. Study `sql/` scripts to understand component interactions
3. Experiment with sample data before production deployment

### For End Users

1. Read `docs/OPERATIONS_MANUAL.md` for daily workflows
2. Practice with sample data (`DEAL_HL_001`)
3. Understand Excel integration requirements

### For Administrators

1. Follow `docs/DEPLOYMENT_GUIDE.md` for initial setup
2. Configure security settings per organizational policies
3. Establish backup and recovery procedures

---

## ✅ Production Readiness Checklist

- [ ] Deployment completed successfully
- [ ] Production validation passed (all tests ✅)
- [ ] Sample data processed correctly
- [ ] All 4 CSV files generated
- [ ] Excel integration verified
- [ ] Security roles configured
- [ ] Passwords changed from defaults
- [ ] Audit logging enabled
- [ ] Documentation reviewed
- [ ] Team training completed

---

**Version**: 1.0.0  
**Last Updated**: October 2025  
**Status**: Production Ready ✅

For questions or support, refer to `HANDOFF.md` or contact Snowflake Professional Services.

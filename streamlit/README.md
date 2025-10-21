# FDD Automation Admin Dashboard

**Streamlit in Snowflake Application**

A comprehensive admin interface for monitoring, managing, and configuring the Houlihan Lokey FDD Automation solution.

---

## 📊 Features

### 🏠 Overview Dashboard
- Real-time key metrics (deals, rows, insights, errors)
- Recent activity feed (last 24 hours)
- System health summary
- Quick performance indicators

### 📊 Monitoring & Performance
- Procedure execution statistics
- Success/failure rates
- Average execution times
- Performance trend charts
- Time range filtering

### ⚙️ Configuration Management
- View all system configuration parameters
- Category-based filtering
- Live configuration editor
- Update values with validation
- Configuration presets (dev, prod)

### 🎯 AI Threshold Tuning
- Variance threshold slider (5% - 100%)
- Minimum variance amount configuration
- AI model selection (Claude, Mistral, Llama)
- Maximum insights limit
- Impact analysis preview

### ✅ Data Quality Dashboard
- Quality check summary by type
- Pass/fail statistics
- Severity distribution (Error/Warning/Info)
- Recent failed checks viewer
- Historical quality trends

### 📁 Stage File Management
- Browse input and output stages
- File size statistics
- File metadata viewer
- Individual file removal
- Bulk cleanup operations

### 📜 Audit Log Viewer
- Filterable audit log browser
- Time range selection
- Status filtering
- Procedure filtering
- Deal-specific filtering
- Export to CSV

### 🚨 Error Diagnostics
- Error summary by procedure
- Affected deals count
- Error trend visualization
- Recent error details
- Data load error viewer

### 🧪 System Health Check
- Database object validation (tables, views, procedures)
- Data integrity checks
- View health verification
- Recent execution success rates
- Overall health score calculation
- Quick diagnostic tools

---

## 🚀 Deployment Instructions

### Prerequisites

1. ✅ Main FDD solution deployed (run `sql/deploy_snowsight.sql` first)
2. ✅ Warehouse available (FDD_WH or similar)
3. ✅ Admin role access (fdd_admin_role)

### Option 1: Deploy via SnowSQL (Recommended)

```bash
# Navigate to the streamlit directory
cd production/streamlit

# Upload Streamlit files to stage
snowsql -c your_connection -q "
USE DATABASE HL_FDD_POC;
USE SCHEMA TRIAL_BALANCE;

PUT file://$(pwd)/fdd_admin_dashboard.py @streamlit_stage OVERWRITE=TRUE AUTO_COMPRESS=FALSE;
PUT file://$(pwd)/environment.yml @streamlit_stage OVERWRITE=TRUE AUTO_COMPRESS=FALSE;

LIST @streamlit_stage;
"

# Deploy the Streamlit app
snowsql -c your_connection -f deploy_streamlit.sql
```

### Option 2: Deploy via Snowsight UI

**Step 1: Upload Files to Stage**

1. Open Snowsight → Navigate to:  
   `Data → Databases → HL_FDD_POC → TRIAL_BALANCE → Stages → STREAMLIT_STAGE`

2. Click **"+ Files"** button

3. Upload these files:
   - `fdd_admin_dashboard.py`
   - `environment.yml`

4. Verify files uploaded:
   ```sql
   LIST @streamlit_stage;
   ```

**Step 2: Create Streamlit App**

Copy and paste this SQL into Snowsight:

```sql
USE DATABASE HL_FDD_POC;
USE SCHEMA TRIAL_BALANCE;

CREATE OR REPLACE STREAMLIT fdd_admin_dashboard
    ROOT_LOCATION = '@streamlit_stage'
    MAIN_FILE = 'fdd_admin_dashboard.py'
    QUERY_WAREHOUSE = fdd_wh
    TITLE = 'FDD Automation Admin Dashboard'
    COMMENT = 'Admin dashboard for FDD automation';

GRANT USAGE ON STREAMLIT fdd_admin_dashboard TO ROLE fdd_admin_role;

SELECT 'Streamlit app deployed!' AS status;
```

**Step 3: Access the Dashboard**

1. In Snowsight, navigate to: **Projects → Streamlit**
2. Find: **"FDD Automation Admin Dashboard"**
3. Click to open and use!

---

## 📖 Usage Guide

### Accessing the Dashboard

1. **Via Snowsight:**
   - Navigate to: **Projects → Streamlit**
   - Click: **"FDD Automation Admin Dashboard"**

2. **Direct URL:**
   - `https://app.snowflake.com/[account]/[locator]/#/streamlit-apps/HL_FDD_POC.TRIAL_BALANCE.FDD_ADMIN_DASHBOARD`

### Common Tasks

#### Monitor Recent Activity
1. Navigate to: **🏠 Overview**
2. View recent executions in the activity table
3. Check error count metric
4. Review system health summary

#### Update Configuration
1. Navigate to: **⚙️ Configuration Management**
2. Select category or view all
3. Choose configuration to update
4. Enter new value
5. Click **"💾 Update Configuration"**

#### Tune AI Thresholds
1. Navigate to: **🎯 AI Threshold Tuning**
2. Adjust **Variance Threshold** slider
3. Set **Minimum Variance Amount**
4. Click **"📊 Preview Impact"** to see how many insights would generate
5. Click **"💾 Save"** when satisfied

#### Check Data Quality
1. Navigate to: **✅ Data Quality Dashboard**
2. Review summary statistics
3. Check failed checks details
4. Export for further analysis if needed

#### Manage Stage Files
1. Navigate to: **📁 Stage File Management**
2. Select stage (input or output)
3. View file list and sizes
4. Remove individual files or bulk cleanup

#### Troubleshoot Errors
1. Navigate to: **🚨 Error Diagnostics**
2. Review error summary
3. Check error trend chart
4. Examine recent error details
5. Review load errors if applicable

#### Run Health Check
1. Navigate to: **🧪 System Health Check**
2. Click **"▶️ Run Complete Health Check"**
3. Review all validation results
4. Check overall health score
5. Use quick diagnostics for specific issues

---

## 🔧 Customization

### Adding New Metrics

Edit `fdd_admin_dashboard.py` and add new queries in the appropriate section:

```python
# Example: Add new metric
new_metric = session.sql("SELECT COUNT(*) FROM your_table").collect()[0][0]
st.metric("Your Metric", new_metric)
```

### Adding New Pages

Add new navigation options in the sidebar:

```python
page = st.sidebar.radio(
    "Navigation",
    [
        "🏠 Overview",
        # ... existing pages ...
        "🆕 Your New Page"  # Add here
    ]
)

# Add page logic
elif page == "🆕 Your New Page":
    st.title("Your New Page")
    # Your page content
```

### Updating Dependencies

Edit `environment.yml` to add new Python packages:

```yaml
dependencies:
  - streamlit
  - pandas
  - plotly
  - your-new-package  # Add here
```

Then redeploy the Streamlit app to apply changes.

---

## 🔒 Security

### Access Control

The dashboard is restricted to users with the `fdd_admin_role`:

```sql
GRANT USAGE ON STREAMLIT fdd_admin_dashboard TO ROLE fdd_admin_role;
```

### Sensitive Configuration

Configuration marked as `is_sensitive = TRUE` is masked in the UI for security.

### Audit Trail

All configuration changes made via the dashboard are logged with:
- Timestamp
- User who made the change
- Old and new values

---

## 🐛 Troubleshooting

### Issue: Streamlit app doesn't load

**Solution:**
1. Verify files are in the stage:
   ```sql
   LIST @streamlit_stage;
   ```
2. Check the app exists:
   ```sql
   SHOW STREAMLITS IN SCHEMA TRIAL_BALANCE;
   ```
3. Verify you have the correct role:
   ```sql
   SHOW GRANTS ON STREAMLIT fdd_admin_dashboard;
   ```

### Issue: Error when running queries

**Solution:**
1. Ensure the warehouse is running:
   ```sql
   SHOW WAREHOUSES LIKE 'fdd_wh';
   ```
2. Check you have permissions on the tables:
   ```sql
   SELECT CURRENT_ROLE();
   ```

### Issue: Configuration updates not persisting

**Solution:**
1. Check audit log for errors
2. Verify you have UPDATE permission on `system_config` table
3. Check the data type of the value being set

---

## 📈 Performance Considerations

### Warehouse Usage

The dashboard runs on the query warehouse specified during creation (`fdd_wh`). The warehouse:
- Activates when the app is opened
- Remains active while the app is in use
- Auto-suspends ~15 minutes after closing the app

**Recommendation:** Use a SMALL warehouse for the admin dashboard (sufficient for admin queries).

### Query Optimization

- Dashboard uses efficient queries with appropriate LIMIT clauses
- Time range filters reduce data scanned
- Caching is used for frequently accessed data

### Cost Management

- Close the dashboard when not in use (allows warehouse to auto-suspend)
- Use time range filters to limit data scanned
- Limit AI threshold preview queries to necessary ranges

---

## 🔄 Maintenance

### Updating the Dashboard

1. Edit `fdd_admin_dashboard.py` locally
2. Upload to stage:
   ```sql
   PUT file:///path/to/fdd_admin_dashboard.py @streamlit_stage OVERWRITE=TRUE;
   ```
3. Streamlit will automatically reload with new code

### Version Updates

Update the version number in the dashboard code and redeploy:

```python
st.sidebar.info("**Version:** 1.1.0  \n**Database:** HL_FDD_POC")
```

---

## 📚 Additional Resources

- **Streamlit Documentation:** https://docs.streamlit.io/
- **Snowflake Streamlit Docs:** https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit
- **Plotly Documentation:** https://plotly.com/python/
- **Main FDD Solution Docs:** See `../docs/` folder

---

## ✅ Quick Reference

### Deployment Commands

```sql
-- Upload files (SnowSQL)
PUT file:///path/to/fdd_admin_dashboard.py @streamlit_stage OVERWRITE=TRUE AUTO_COMPRESS=FALSE;
PUT file:///path/to/environment.yml @streamlit_stage OVERWRITE=TRUE AUTO_COMPRESS=FALSE;

-- Create app
CREATE OR REPLACE STREAMLIT fdd_admin_dashboard
    ROOT_LOCATION = '@streamlit_stage'
    MAIN_FILE = 'fdd_admin_dashboard.py'
    QUERY_WAREHOUSE = fdd_wh
    TITLE = 'FDD Automation Admin Dashboard';

-- Grant access
GRANT USAGE ON STREAMLIT fdd_admin_dashboard TO ROLE fdd_admin_role;
```

### Access URL Pattern

```
https://app.snowflake.com/[account]/[region]/#/streamlit-apps/HL_FDD_POC.TRIAL_BALANCE.FDD_ADMIN_DASHBOARD
```

### Useful Commands

```sql
-- List Streamlit apps
SHOW STREAMLITS;

-- Describe app
DESCRIBE STREAMLIT fdd_admin_dashboard;

-- Drop app (if needed)
DROP STREAMLIT fdd_admin_dashboard;

-- List files in stage
LIST @streamlit_stage;

-- Remove file from stage
REMOVE @streamlit_stage/fdd_admin_dashboard.py;
```

---

**For questions or issues, refer to the main FDD solution documentation or contact Snowflake support.** 🚀


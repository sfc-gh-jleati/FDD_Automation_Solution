# Deploy Streamlit Admin Dashboard via Snowsight UI

**Easy step-by-step guide for deploying the FDD Admin Dashboard using only the Snowsight web interface**

---

## ✅ Prerequisites

- [x] Main FDD solution deployed (run `sql/deploy_snowsight.sql` first)
- [x] Access to Snowsight (https://app.snowflake.com)
- [x] `fdd_admin_role` assigned to your user
- [x] Files ready: `fdd_admin_dashboard.py` and `environment.yml`

---

## 📋 Step-by-Step Deployment (10 minutes)

### STEP 1: Access Snowsight
1. Open browser and navigate to: https://app.snowflake.com/
2. Log in with your Snowflake credentials
3. Select your account

### STEP 2: Navigate to Stages
1. In the left sidebar, click: **Data**
2. Expand: **Databases**
3. Find and expand: **HL_FDD_POC**
4. Expand: **TRIAL_BALANCE** (schema)
5. Click: **Stages**
6. Find: **STREAMLIT_STAGE**

### STEP 3: Upload Streamlit Files
1. Click on **STREAMLIT_STAGE** to open it
2. Click the **"+ Files"** button (top right)
3. In the file upload dialog:
   - Click **"Browse"** or drag and drop
   - Select: `fdd_admin_dashboard.py`
   - Click **"Upload"**
4. Repeat to upload:
   - Select: `environment.yml`
   - Click **"Upload"**
5. Verify both files appear in the stage file list

### STEP 4: Create the Streamlit App
1. Click **"Worksheets"** in the left sidebar (or **"+"** → **"SQL Worksheet"**)
2. Copy this SQL code:

```sql
USE DATABASE HL_FDD_POC;
USE SCHEMA TRIAL_BALANCE;

CREATE OR REPLACE STREAMLIT fdd_admin_dashboard
    ROOT_LOCATION = '@streamlit_stage'
    MAIN_FILE = 'fdd_admin_dashboard.py'
    QUERY_WAREHOUSE = FDD_POC_WH
    TITLE = 'FDD Automation Admin Dashboard'
    COMMENT = 'Comprehensive admin interface for FDD automation';

GRANT USAGE ON STREAMLIT fdd_admin_dashboard TO ROLE fdd_admin_role;

SELECT 'Streamlit app deployed successfully!' AS status;
```

3. Paste into the worksheet
4. Click **"Run All"** (▶️ button) or press **Ctrl+Enter** (Windows) / **Cmd+Enter** (Mac)
5. Wait for completion (~5 seconds)
6. You should see: "Streamlit app deployed successfully!"

### STEP 5: Open the Dashboard
1. In the left sidebar, click: **Projects**
2. Click: **Streamlit**
3. Find: **"FDD Automation Admin Dashboard"**
4. Click on the app name to open it

### STEP 6: Verify Deployment
The dashboard should load and display:
- Header: "📊 FDD Automation Admin Dashboard"
- Sidebar navigation with 9 pages
- Overview page with key metrics
- If you see this, deployment was successful! ✅

---

## 🎨 Alternative: Create Directly in Snowsight (2025_01 Bundle)

**Note:** This method requires the 2025_01 behavior change bundle to be enabled in your account.

### Steps:

1. In Snowsight, click: **Projects → Streamlit**
2. Click: **"+ Streamlit"**
3. Enter app details:
   - **Name:** fdd_admin_dashboard
   - **Warehouse:** fdd_wh
   - **App location:** HL_FDD_POC.TRIAL_BALANCE
4. Click: **"Create"**
5. In the editor, replace the default code with the contents of `fdd_admin_dashboard.py`
6. Click: **"Run"** to test the app
7. App is now deployed and accessible!

---

## ✅ Post-Deployment Verification

### Test Each Feature

1. **Overview Page:**
   - Check if metrics load (Total Deals, TB Rows, etc.)
   - Verify recent activity table displays
   - Confirm no error messages

2. **Monitoring Page:**
   - Select different time ranges
   - Verify charts render
   - Check execution statistics table

3. **Configuration Page:**
   - Browse configuration parameters
   - Try updating a test parameter (e.g., `audit_retention_days`)
   - Verify update saves successfully

4. **AI Threshold Tuning:**
   - Adjust variance threshold slider
   - Click "Preview Impact"
   - Verify impact analysis displays

5. **Data Quality:**
   - Check quality summary displays
   - Review any failed checks

6. **Stage Management:**
   - Select input stage
   - Verify file list displays
   - Check file sizes shown correctly

7. **Audit Log:**
   - Apply filters
   - Verify log entries display
   - Test CSV export

8. **Error Diagnostics:**
   - Check if error summary displays
   - Verify error details load

9. **Health Check:**
   - Click "Run Complete Health Check"
   - Verify all checks pass
   - Review health score

---

## 🔧 Troubleshooting

### Problem: Files won't upload to stage

**Solution:**
- Ensure you have WRITE permission on the stage
- Try using SnowSQL instead of UI
- Check file path is correct

### Problem: CREATE STREAMLIT fails

**Solution:**
- Verify files are in the stage: `LIST @streamlit_stage;`
- Check warehouse exists: `SHOW WAREHOUSES LIKE 'fdd_wh';`
- Ensure you have CREATE STREAMLIT privilege

### Problem: Dashboard shows errors when loading

**Solution:**
- Check warehouse is running: `SHOW WAREHOUSES LIKE 'fdd_wh';`
- Verify tables exist: `SHOW TABLES IN TRIAL_BALANCE;`
- Review error message in the dashboard

### Problem: Can't find the app in Snowsight

**Solution:**
- Refresh the Streamlit page
- Verify app exists: `SHOW STREAMLITS;`
- Check you have the correct role: `SELECT CURRENT_ROLE();`
- Switch to fdd_admin_role: `USE ROLE fdd_admin_role;`

### Problem: Metrics show 0 or no data

**Solution:**
- Verify main FDD solution is deployed
- Check sample data is loaded: `SELECT COUNT(*) FROM trial_balance_raw;`
- Run the complete PoC: `CALL run_complete_poc();`

---

## 🔄 Updating the Dashboard

### After Making Changes to the Code

1. **Edit locally:** Make changes to `fdd_admin_dashboard.py`
2. **Upload updated file:**
   ```sql
   PUT file:///path/to/fdd_admin_dashboard.py @streamlit_stage OVERWRITE=TRUE AUTO_COMPRESS=FALSE;
   ```
3. **Refresh the app:** The dashboard will automatically reload with the new code

### Updating Dependencies

1. Edit `environment.yml` to add/remove packages
2. Upload updated file:
   ```sql
   PUT file:///path/to/environment.yml @streamlit_stage OVERWRITE=TRUE AUTO_COMPRESS=FALSE;
   ```
3. Recreate the app (run CREATE OR REPLACE STREAMLIT again)

---

## 📊 Dashboard Capabilities Reference

| Page | Key Features | Use Cases |
|------|--------------|-----------|
| **Overview** | Metrics, recent activity, health summary | Daily monitoring, quick status check |
| **Monitoring** | Performance stats, charts, trends | Performance analysis, bottleneck identification |
| **Configuration** | View and edit system config | Adjust thresholds, change settings |
| **AI Tuning** | Threshold sliders, model selection | Optimize AI insight generation |
| **Data Quality** | Check results, severity analysis | Validate data integrity |
| **File Management** | Stage browser, file operations | Clean up old files, manage storage |
| **Audit Log** | Filterable execution history | Troubleshooting, compliance |
| **Error Diagnostics** | Error trends, details | Root cause analysis |
| **Health Check** | System validation, diagnostics | Pre-flight checks, validation |

---

## 🎓 Best Practices

### For Admins

1. **Daily:** Check Overview page for errors and performance
2. **Weekly:** Review Data Quality and Error Diagnostics
3. **Monthly:** Run full Health Check and review configuration
4. **As Needed:** Tune AI thresholds based on insight quality

### For Performance

1. **Close the app** when not in use (allows warehouse to suspend)
2. **Use time filters** to limit data scanned
3. **Export large result sets** rather than displaying in browser

### For Security

1. **Limit access** to admin role only
2. **Review audit logs** regularly for unauthorized changes
3. **Document configuration changes** outside the system
4. **Use read-only viewers** for non-admin users (future enhancement)

---

## 📞 Support

For issues or questions:
1. Check this README for troubleshooting steps
2. Review main FDD documentation in `../docs/`
3. Check Snowflake Streamlit docs: https://docs.snowflake.com/en/developer-guide/streamlit
4. Contact Snowflake support

---

**Enjoy your new admin dashboard!** 🎉

This powerful interface makes managing the FDD automation solution intuitive and efficient.


-- =====================================================
-- STREAMLIT ADMIN DASHBOARD DEPLOYMENT
-- =====================================================
-- This script deploys the FDD Admin Dashboard Streamlit app
-- Run this AFTER deploying the main FDD solution
-- =====================================================

USE DATABASE HL_FDD_POC;
USE SCHEMA TRIAL_BALANCE;

-- =====================================================
-- STEP 1: Create Stage for Streamlit Files
-- =====================================================

CREATE STAGE IF NOT EXISTS streamlit_stage
    COMMENT = 'Stage for Streamlit admin dashboard files';

SELECT 'Streamlit stage created' AS status;

-- =====================================================
-- STEP 2: Upload Streamlit Files
-- =====================================================

-- NOTE: You need to upload the files manually using PUT command or Snowsight UI
-- From SnowSQL, run:
--   PUT file:///path/to/streamlit/fdd_admin_dashboard.py @streamlit_stage OVERWRITE=TRUE AUTO_COMPRESS=FALSE;
--   PUT file:///path/to/streamlit/environment.yml @streamlit_stage OVERWRITE=TRUE AUTO_COMPRESS=FALSE;
--
-- From Snowsight:
--   1. Go to Data → Databases → HL_FDD_POC → TRIAL_BALANCE → Stages → STREAMLIT_STAGE
--   2. Click "+ Files" button
--   3. Upload fdd_admin_dashboard.py and environment.yml

-- Verify files uploaded
-- LIST @streamlit_stage;

SELECT '
📋 MANUAL STEP REQUIRED:
------------------------
Upload the following files to @streamlit_stage:
1. streamlit/fdd_admin_dashboard.py
2. streamlit/environment.yml

Using SnowSQL:
PUT file:///full/path/to/production/streamlit/fdd_admin_dashboard.py @streamlit_stage OVERWRITE=TRUE AUTO_COMPRESS=FALSE;
PUT file:///full/path/to/production/streamlit/environment.yml @streamlit_stage OVERWRITE=TRUE AUTO_COMPRESS=FALSE;

Using Snowsight:
Data → HL_FDD_POC → TRIAL_BALANCE → Stages → STREAMLIT_STAGE → + Files

Then continue with STEP 3 below.
' AS instructions;

-- Uncomment and run after files are uploaded:
-- LIST @streamlit_stage;

-- =====================================================
-- STEP 3: Create Streamlit Application
-- =====================================================

-- Run this AFTER uploading the files to the stage

CREATE OR REPLACE STREAMLIT fdd_admin_dashboard
    ROOT_LOCATION = '@streamlit_stage'
    MAIN_FILE = 'fdd_admin_dashboard.py'
    QUERY_WAREHOUSE = FDD_POC_WH
    TITLE = 'FDD Automation Admin Dashboard'
    COMMENT = 'Admin dashboard for monitoring, configuration, and management of FDD automation';

SELECT 'Streamlit app created successfully!' AS status;

-- =====================================================
-- STEP 4: Grant Access to Admin Role
-- =====================================================

GRANT USAGE ON STREAMLIT fdd_admin_dashboard TO ROLE fdd_admin_role;

SELECT 'Access granted to fdd_admin_role' AS status;

-- =====================================================
-- DEPLOYMENT COMPLETE
-- =====================================================

SELECT '
✅ STREAMLIT DEPLOYMENT COMPLETE!

To access the admin dashboard:
-------------------------------
1. In Snowsight, go to: Projects → Streamlit
2. Find: FDD Automation Admin Dashboard
3. Click to open the app

The dashboard provides:
- 🏠 Overview - Key metrics and recent activity
- 📊 Monitoring - Performance analytics
- ⚙️ Configuration - System settings management
- 🎯 AI Tuning - Variance threshold configuration
- ✅ Data Quality - Validation monitoring
- 📁 File Management - Stage file operations
- 📜 Audit Logs - Complete execution history
- 🚨 Error Diagnostics - Error analysis and troubleshooting
- 🧪 Health Check - System validation

Enjoy your new admin dashboard! 🚀
' AS completion_message;


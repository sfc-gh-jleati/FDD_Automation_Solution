-- Quick deployment to fix load_account_mappings procedure
USE DATABASE HL_FDD_POC;
USE SCHEMA TRIAL_BALANCE;

-- First, manually update any existing mappings to have is_active = TRUE
UPDATE account_mappings SET is_active = TRUE WHERE is_active IS NULL;

-- Clean up data and reload with the fixed procedure available via !source
-- User must run the full deploy_snowsight.sql or just load it via Snowsight UI

SELECT '
🔧 DEPLOYMENT INSTRUCTIONS:

The load_account_mappings procedure has been fixed in the code.

TO DEPLOY:
----------
1. Copy the entire contents of sql/deploy_snowsight.sql
2. Paste into a new Snowsight worksheet
3. Execute all

OR (Faster - just update the one procedure):
--------------------------------------------
1. Open sql/03_data_procedures.sql
2. Find the CREATE OR REPLACE PROCEDURE load_account_mappings section (lines 179-294)
3. Copy just that procedure definition
4. Paste into Snowsight and execute

THEN TEST:
----------
CALL run_complete_poc();
LIST @fdd_output_stage;

You should now see all 4 files including database_tab_DEAL_HL_001.csv! ✅

' AS instructions;


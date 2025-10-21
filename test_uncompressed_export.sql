-- =====================================================
-- TEST: Verify Uncompressed CSV Export
-- =====================================================
-- This script tests that CSV files are exported uncompressed
-- after the COMPRESSION = NONE fix

USE ROLE fdd_admin_role;
USE DATABASE hl_fdd_poc;
USE SCHEMA fdd_schema;
USE WAREHOUSE fdd_wh;

-- Step 1: Clean up previous test outputs
REMOVE @fdd_output_stage PATTERN='.*test_uncompressed.*';

-- Step 2: Truncate output tables for clean test
TRUNCATE TABLE IF EXISTS income_statement_structure;
TRUNCATE TABLE IF EXISTS balance_sheet_structure;
TRUNCATE TABLE IF EXISTS ai_insights;

-- Step 3: Generate fresh schedules and insights (using existing data)
SELECT '=== Generating FDD Schedules ===' AS step;
CALL run_complete_poc();

-- Step 4: List output files
SELECT '=== Output Files Generated ===' AS step;
LIST @fdd_output_stage;

-- Step 5: Download and inspect one file to verify it's uncompressed
-- Note: In Snowsight, you can manually download a file from the stage browser
-- and verify it's a plain CSV (not gzipped) by opening in a text editor
-- A gzipped file would show binary/garbled content
-- An uncompressed CSV would show readable text

SELECT '=== VERIFICATION INSTRUCTIONS ===' AS instructions;
SELECT 'Download one of the CSV files from @fdd_output_stage' AS step_1;
SELECT 'Open the file in a text editor (e.g., VS Code, Notepad)' AS step_2;
SELECT 'If you see readable CSV content → SUCCESS (uncompressed)' AS step_3;
SELECT 'If you see binary/garbled content → FAIL (still compressed)' AS step_4;

-- Alternative: Get file to local machine using SnowSQL
-- GET @fdd_output_stage/income_statement_DEAL_HL_001.csv file:///tmp/;


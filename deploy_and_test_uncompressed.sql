-- =====================================================
-- DEPLOYMENT AND TEST: Uncompressed CSV Export
-- =====================================================
-- This script:
-- 1. Re-deploys the FDD solution with COMPRESSION = NONE fix
-- 2. Runs the complete PoC
-- 3. Verifies output files are uncompressed
-- =====================================================

-- =====================================================
-- PART 1: REDEPLOY UPDATED PROCEDURES
-- =====================================================
-- We only need to update the export procedures, not the entire schema

USE ROLE fdd_admin_role;
USE DATABASE hl_fdd_poc;
USE SCHEMA fdd_schema;
USE WAREHOUSE fdd_wh;

SELECT '=== STEP 1: Updating Export Procedures ===' AS status;

-- Update export_database_tab with COMPRESSION = NONE
CREATE OR REPLACE PROCEDURE export_database_tab(deal_id_param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    output_path VARCHAR;
    safe_deal_id VARCHAR;
    file_count NUMBER;
    copy_sql VARCHAR;
    error_msg VARCHAR;
BEGIN
    safe_deal_id := sanitize_deal_id(:deal_id_param);
    IF (safe_deal_id IS NULL) THEN
        RETURN 'ERROR: Invalid deal_id format. Must be alphanumeric with underscores/hyphens only.';
    END IF;
    
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status)
    VALUES (:log_id_var, 'export_database_tab', :safe_deal_id, :start_time_var, 'STARTED');
    
    output_path := '@' || get_config_string('output_stage_name') || '/database_tab_' || :safe_deal_id || '.csv';
    
    copy_sql := 'COPY INTO ' || :output_path || 
                    ' FROM (SELECT * FROM v_database_tab_pivoted WHERE deal_id = ''' || :safe_deal_id || ''') ' ||
                    ' FILE_FORMAT = (FORMAT_NAME = ''csv_format'' COMPRESSION = NONE) ' ||
                    ' HEADER = TRUE OVERWRITE = TRUE SINGLE = TRUE';
    
    EXECUTE IMMEDIATE :copy_sql;
    
    file_count := SQLROWCOUNT;
    
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = 'SUCCESS',
        rows_affected = :file_count,
        message = 'Exported to ' || :output_path
    WHERE log_id = :log_id_var;
    
    RETURN 'SUCCESS: Exported Database tab to ' || :output_path || ' (' || :file_count || ' rows)';
    
EXCEPTION
    WHEN OTHER THEN
        error_msg := SQLERRM;
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = :error_msg
        WHERE log_id = :log_id_var;
        RETURN 'ERROR: ' || :error_msg;
END;
$$;

-- Update export_income_statement_structure with COMPRESSION = NONE
CREATE OR REPLACE PROCEDURE export_income_statement_structure(deal_id_param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    output_path VARCHAR;
    safe_deal_id VARCHAR;
    file_count NUMBER;
    copy_sql VARCHAR;
    error_msg VARCHAR;
BEGIN
    safe_deal_id := sanitize_deal_id(:deal_id_param);
    IF (safe_deal_id IS NULL) THEN
        RETURN 'ERROR: Invalid deal_id format. Must be alphanumeric with underscores/hyphens only.';
    END IF;
    
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status)
    VALUES (:log_id_var, 'export_income_statement_structure', :safe_deal_id, :start_time_var, 'STARTED');
    
    output_path := '@' || get_config_string('output_stage_name') || '/income_statement_' || :safe_deal_id || '.csv';
    
    copy_sql := 'COPY INTO ' || :output_path || 
                    ' FROM (SELECT row_num, row_label, row_type, account_filter, row_format_json FROM temp_is_schedule ORDER BY row_num) ' ||
                    ' FILE_FORMAT = (FORMAT_NAME = ''csv_format'' COMPRESSION = NONE) ' ||
                    ' HEADER = TRUE OVERWRITE = TRUE SINGLE = TRUE';
    
    EXECUTE IMMEDIATE :copy_sql;
    
    file_count := SQLROWCOUNT;
    
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = 'SUCCESS',
        rows_affected = :file_count
    WHERE log_id = :log_id_var;
    
    RETURN 'SUCCESS: Exported Income Statement structure to ' || :output_path || ' (' || :file_count || ' rows)';
    
EXCEPTION
    WHEN OTHER THEN
        error_msg := SQLERRM;
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = :error_msg
        WHERE log_id = :log_id_var;
        RETURN 'ERROR: ' || :error_msg;
END;
$$;

-- Update export_balance_sheet_structure with COMPRESSION = NONE
CREATE OR REPLACE PROCEDURE export_balance_sheet_structure(deal_id_param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    output_path VARCHAR;
    safe_deal_id VARCHAR;
    file_count NUMBER;
    copy_sql VARCHAR;
    error_msg VARCHAR;
BEGIN
    safe_deal_id := sanitize_deal_id(:deal_id_param);
    IF (safe_deal_id IS NULL) THEN
        RETURN 'ERROR: Invalid deal_id format. Must be alphanumeric with underscores/hyphens only.';
    END IF;
    
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status)
    VALUES (:log_id_var, 'export_balance_sheet_structure', :safe_deal_id, :start_time_var, 'STARTED');
    
    output_path := '@' || get_config_string('output_stage_name') || '/balance_sheet_' || :safe_deal_id || '.csv';
    
    copy_sql := 'COPY INTO ' || :output_path || 
                    ' FROM (SELECT row_num, row_label, row_type, account_filter, row_format_json FROM temp_bs_schedule ORDER BY row_num) ' ||
                    ' FILE_FORMAT = (FORMAT_NAME = ''csv_format'' COMPRESSION = NONE) ' ||
                    ' HEADER = TRUE OVERWRITE = TRUE SINGLE = TRUE';
    
    EXECUTE IMMEDIATE :copy_sql;
    
    file_count := SQLROWCOUNT;
    
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = 'SUCCESS',
        rows_affected = :file_count
    WHERE log_id = :log_id_var;
    
    RETURN 'SUCCESS: Exported Balance Sheet structure to ' || :output_path || ' (' || :file_count || ' rows)';
    
EXCEPTION
    WHEN OTHER THEN
        error_msg := SQLERRM;
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = :error_msg
        WHERE log_id = :log_id_var;
        RETURN 'ERROR: ' || :error_msg;
END;
$$;

-- Update export_ai_insights with COMPRESSION = NONE
CREATE OR REPLACE PROCEDURE export_ai_insights(deal_id_param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    output_path VARCHAR;
    safe_deal_id VARCHAR;
    file_count NUMBER;
    copy_sql VARCHAR;
    error_msg VARCHAR;
BEGIN
    safe_deal_id := sanitize_deal_id(:deal_id_param);
    IF (safe_deal_id IS NULL) THEN
        RETURN 'ERROR: Invalid deal_id format. Must be alphanumeric with underscores/hyphens only.';
    END IF;
    
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status)
    VALUES (:log_id_var, 'export_ai_insights', :safe_deal_id, :start_time_var, 'STARTED');
    
    output_path := '@' || get_config_string('output_stage_name') || '/ai_insights_' || :safe_deal_id || '.csv';
    
    copy_sql := 'COPY INTO ' || :output_path || 
                    ' FROM (SELECT insight_type, severity, COALESCE(account_name, ''General'') AS account_name, ' ||
                    ' TO_CHAR(period_date, ''Mon YYYY'') AS period, metric_value, comparison_value, variance_pct, ' ||
                    ' insight_text, suggested_question, model_used FROM ai_insights WHERE deal_id = ''' || :safe_deal_id || ''' ' ||
                    ' ORDER BY CASE severity WHEN ''high'' THEN 1 WHEN ''medium'' THEN 2 ELSE 3 END, ABS(variance_pct) DESC) ' ||
                    ' FILE_FORMAT = (FORMAT_NAME = ''csv_format'' COMPRESSION = NONE) ' ||
                    ' HEADER = TRUE OVERWRITE = TRUE SINGLE = TRUE';
    
    EXECUTE IMMEDIATE :copy_sql;
    
    file_count := SQLROWCOUNT;
    
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = 'SUCCESS',
        rows_affected = :file_count
    WHERE log_id = :log_id_var;
    
    RETURN 'SUCCESS: Exported AI insights to ' || :output_path || ' (' || :file_count || ' rows)';
    
EXCEPTION
    WHEN OTHER THEN
        error_msg := SQLERRM;
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = :error_msg
        WHERE log_id = :log_id_var;
        RETURN 'ERROR: ' || :error_msg;
END;
$$;

SELECT '✅ Export procedures updated with COMPRESSION = NONE' AS status;

-- =====================================================
-- PART 2: RUN COMPLETE POC
-- =====================================================

SELECT '=== STEP 2: Running Complete PoC ===' AS status;

-- Clean previous outputs
REMOVE @fdd_output_stage PATTERN='.*DEAL_HL_001.*';

-- Run the complete PoC
CALL run_complete_poc();

-- =====================================================
-- PART 3: VERIFY OUTPUT FILES
-- =====================================================

SELECT '=== STEP 3: Listing Output Files ===' AS status;
LIST @fdd_output_stage;

-- =====================================================
-- PART 4: VERIFICATION INSTRUCTIONS
-- =====================================================

SELECT '=== VERIFICATION COMPLETE ===' AS status;
SELECT '
📋 NEXT STEPS TO VERIFY UNCOMPRESSED OUTPUT:

Method 1: Snowsight UI Download
--------------------------------
1. Navigate to Data → Databases → HL_FDD_POC → FDD_SCHEMA → Stages
2. Click on FDD_OUTPUT_STAGE
3. Download any CSV file (e.g., income_statement_DEAL_HL_001.csv)
4. Open the file in a text editor (VS Code, Notepad++, etc.)
5. ✅ SUCCESS: You see readable CSV text
   ❌ FAIL: You see binary/garbled content (means still compressed)

Method 2: SnowSQL CLI (if available)
------------------------------------
GET @fdd_output_stage/income_statement_DEAL_HL_001.csv file:///tmp/;
-- Then open /tmp/income_statement_DEAL_HL_001.csv in a text editor

Expected Result:
----------------
You should see plain CSV content like:
row_num,row_label,row_type,account_filter,row_format_json
1,Income Statement,header,,"{""bold"":true,""fontSize"":14}"
2,Revenue,section,,"{""bold"":true,""indent"":0}"
...etc

If you see this, the COMPRESSION = NONE fix is working correctly! 🎉
' AS instructions;


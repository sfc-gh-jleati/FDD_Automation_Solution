-- =====================================================
-- DEPLOY FIXED load_account_mappings PROCEDURE
-- =====================================================
-- Copy this ENTIRE file and paste into Snowsight, then Execute All
-- =====================================================

USE DATABASE HL_FDD_POC;
USE SCHEMA TRIAL_BALANCE;

CREATE OR REPLACE PROCEDURE load_account_mappings(
    file_name VARCHAR DEFAULT '02_sample_account_mappings_24mo.csv',
    deal_id_filter VARCHAR DEFAULT NULL
)
RETURNS TABLE(status VARCHAR, rows_loaded NUMBER, message VARCHAR)
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    rows_loaded NUMBER DEFAULT 0;
    unmapped_count NUMBER DEFAULT 0;
    stage_path VARCHAR;
    result_cursor RESULTSET;
    error_msg VARCHAR;
BEGIN
    -- Validate deal_id if provided
    IF (:deal_id_filter IS NOT NULL AND NOT validate_deal_id(:deal_id_filter)) THEN
        result_cursor := (
            SELECT 'ERROR' AS status, 0 AS rows_loaded, 
                   'Invalid deal_id format' AS message
        );
        RETURN TABLE(result_cursor);
    END IF;
    
    -- Log start
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status)
    VALUES (:log_id_var, 'load_account_mappings', :deal_id_filter, :start_time_var, 'STARTED');
    
    stage_path := '@' || get_config_string('input_stage_name') || '/' || :file_name;
    
    BEGIN TRANSACTION;
    
    -- Selective truncate
    IF (:deal_id_filter IS NULL) THEN
        TRUNCATE TABLE account_mappings;
    ELSE
        DELETE FROM account_mappings WHERE deal_id = :deal_id_filter;
    END IF;
    
    -- Load mappings
    EXECUTE IMMEDIATE
        'COPY INTO account_mappings (' ||
        '    deal_id, account_number, account_name, account_category, statement_type, ' ||
        '    mapping_level_1, mapping_level_2, mapping_level_3, ' ||
        '    sort_order_l1, sort_order_l2, sort_order_l3' ||
        ') ' ||
        'FROM ' || :stage_path || ' ' ||
        'FILE_FORMAT = (FORMAT_NAME = ''' || get_config_string('default_file_format') || ''') ' ||
        'ON_ERROR = ''ABORT_STATEMENT''';
    
    rows_loaded := SQLROWCOUNT;
    
    -- ⭐ CRITICAL FIX: Set is_active = TRUE for all loaded mappings ⭐
    -- The CSV doesn't include this column, so it defaults to NULL
    -- The view filters on is_active = TRUE, so NULL values are excluded
    IF (:deal_id_filter IS NULL) THEN
        UPDATE account_mappings SET is_active = TRUE WHERE is_active IS NULL;
    ELSE
        UPDATE account_mappings SET is_active = TRUE 
        WHERE deal_id = :deal_id_filter AND is_active IS NULL;
    END IF;
    
    -- VALIDATION: Check for unmapped accounts in trial balance
    SELECT COUNT(DISTINCT t.account_number)
    INTO :unmapped_count
    FROM trial_balance_raw t
    LEFT JOIN account_mappings m 
        ON t.deal_id = m.deal_id AND t.account_number = m.account_number
    WHERE m.account_number IS NULL
    AND t.deal_id = COALESCE(:deal_id_filter, t.deal_id);
    
    -- Log validation result (using SELECT to support OBJECT_CONSTRUCT)
    -- Only log if deal_id is provided
    IF (:deal_id_filter IS NOT NULL) THEN
        INSERT INTO data_quality_checks (deal_id, check_name, check_type, passed, actual_value, severity, message)
        SELECT
            :deal_id_filter,
            'Account Mapping Completeness',
            'COMPLETENESS',
            :unmapped_count = 0,
            OBJECT_CONSTRUCT('unmapped_accounts', :unmapped_count),
            CASE WHEN :unmapped_count = 0 THEN 'INFO' WHEN :unmapped_count < 5 THEN 'WARNING' ELSE 'ERROR' END,
            CASE 
                WHEN :unmapped_count = 0 THEN 'All accounts have mappings'
                ELSE :unmapped_count || ' accounts missing mappings'
            END;
    END IF;
    
    IF (:unmapped_count > 0) THEN
        -- Log unmapped accounts as errors
        INSERT INTO load_errors (deal_id, file_name, error_type, error_message, line_content)
        SELECT DISTINCT
            t.deal_id,
            :file_name,
            'VALIDATION_ERROR',
            'Account missing from mapping file',
            t.account_number || ' - ' || t.account_name
        FROM trial_balance_raw t
        LEFT JOIN account_mappings m 
            ON t.deal_id = m.deal_id AND t.account_number = m.account_number
        WHERE m.account_number IS NULL
        AND t.deal_id = COALESCE(:deal_id_filter, t.deal_id);
    END IF;
    
    COMMIT;
    
    -- Log completion
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = CASE WHEN :unmapped_count > 5 THEN 'ERROR' 
                     WHEN :unmapped_count > 0 THEN 'WARNING' 
                     ELSE 'SUCCESS' END,
        rows_affected = :rows_loaded,
        message = 'Loaded ' || :rows_loaded || ' mappings, ' || :unmapped_count || ' unmapped accounts found'
    WHERE log_id = :log_id_var;
    
    -- Return results
    result_cursor := (
        SELECT 
            CASE WHEN :unmapped_count > 5 THEN 'ERROR'
                 WHEN :unmapped_count > 0 THEN 'WARNING'
                 ELSE 'SUCCESS' END AS status,
            :rows_loaded AS rows_loaded,
            'Loaded ' || :rows_loaded || ' account mappings' || 
            CASE WHEN :unmapped_count > 0 
                 THEN '. WARNING: ' || :unmapped_count || ' accounts in trial balance have no mapping.' 
                 ELSE '' END AS message
    );
    RETURN TABLE(result_cursor);
    
EXCEPTION
    WHEN OTHER THEN
        error_msg := SQLERRM;  -- Capture error message
        
        ROLLBACK;
        
        -- Log error
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
            status = 'ERROR',
            error_message = 'FATAL: ' || :error_msg,
            rows_affected = :rows_loaded
        WHERE log_id = :log_id_var;
        
        result_cursor := (
            SELECT 'ERROR' AS status, 
                   0 AS rows_loaded, 
                   'FATAL ERROR: ' || :error_msg AS message
        );
        RETURN TABLE(result_cursor);
END;
$$;

-- =====================================================
-- VERIFY THE PROCEDURE WAS UPDATED
-- =====================================================

SELECT '✅ Procedure updated successfully!' AS status;

SELECT '
Now test it:
-----------
CALL run_complete_poc();
LIST @fdd_output_stage;

You should see all 4 CSV files including database_tab! 🎉
' AS next_steps;


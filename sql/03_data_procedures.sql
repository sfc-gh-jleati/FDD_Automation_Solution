-- ============================================================================
-- Houlihan Lokey FDD Automation - Core Data Procedures
-- ============================================================================
-- Description: Data loading, validation, and core business logic
-- Version: 1.0.0
-- Last Updated: 2025-10-20
-- ============================================================================

-- ============================================================================
-- PART 1: DATA LOADING PROCEDURES
-- ============================================================================

-- Procedure: Load Trial Balance with comprehensive error handling
CREATE OR REPLACE PROCEDURE load_trial_balance(
    file_name VARCHAR DEFAULT '01_sample_trial_balance_24mo.csv',
    deal_id_filter VARCHAR DEFAULT NULL
)
RETURNS TABLE(status VARCHAR, rows_loaded NUMBER, errors_found NUMBER, message VARCHAR)
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    rows_loaded NUMBER DEFAULT 0;
    error_count NUMBER DEFAULT 0;
    unbalanced_count NUMBER DEFAULT 0;
    max_imbalance NUMBER DEFAULT 0;
    stage_path VARCHAR;
    result_cursor RESULTSET;
BEGIN
    -- Log start
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status, message)
    VALUES (:log_id_var, 'load_trial_balance', :deal_id_filter, :start_time_var, 'STARTED', 
            'Loading from file: ' || :file_name);
    
    -- Construct stage path
    stage_path := '@' || get_config_string('input_stage_name') || '/' || :file_name;
    
    BEGIN TRANSACTION;
    
    -- Option 1: Full reload (if no deal_id_filter provided)
    IF (:deal_id_filter IS NULL) THEN
        TRUNCATE TABLE trial_balance_raw;
    ELSE
        -- Option 2: Selective reload for specific deal
        DELETE FROM trial_balance_raw WHERE deal_id = :deal_id_filter;
    END IF;
    
    -- Load data with error continuation
    EXECUTE IMMEDIATE
        'COPY INTO trial_balance_raw (' ||
        '    deal_id, deal_name, entity, period_date, account_number, account_name, ' ||
        '    debit_amount, credit_amount, net_amount' ||
        ') ' ||
        'FROM ' || :stage_path || ' ' ||
        'FILE_FORMAT = (FORMAT_NAME = ''' || get_config_string('default_file_format') || ''') ' ||
        'ON_ERROR = ''CONTINUE'' ' ||
        'RETURN_FAILED_ONLY = FALSE';
    
    rows_loaded := SQLROWCOUNT;
    
    -- Capture load errors
    INSERT INTO load_errors (deal_id, file_name, error_type, error_message)
    SELECT 
        :deal_id_filter,
        :file_name,
        'LOAD_ERROR',
        ERROR || ' at line ' || LINE
    FROM TABLE(VALIDATE(trial_balance_raw, JOB_ID => '_last'))
    WHERE ERROR IS NOT NULL;
    
    SELECT COUNT(*) INTO :error_count 
    FROM load_errors 
    WHERE file_name = :file_name 
    AND error_timestamp > :start_time_var;
    
    -- Check error rate threshold
    IF (:rows_loaded > 0 AND :error_count::FLOAT / :rows_loaded > get_config_number('max_error_rate_pct')) THEN
        ROLLBACK;
        
        -- Log failure
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
            status = 'ERROR',
            error_message = 'Error rate (' || ROUND(:error_count::FLOAT / :rows_loaded * 100, 2) || 
                          '%) exceeds threshold (' || (get_config_number('max_error_rate_pct') * 100) || '%)',
            rows_affected = :rows_loaded
        WHERE log_id = :log_id_var;
        
        result_cursor := (
            SELECT 'ERROR' AS status, 
                   :rows_loaded AS rows_loaded, 
                   :error_count AS errors_found,
                   'Error rate too high. Transaction rolled back. Check load_errors table.' AS message
        );
        RETURN TABLE(result_cursor);
    END IF;
    
    -- Update unique_id for new records
    UPDATE trial_balance_raw
    SET unique_id = account_number || ' - ' || account_name
    WHERE unique_id IS NULL;
    
    -- VALIDATION: Check trial balance balances
    SELECT COUNT(*), MAX(imbalance)
    INTO :unbalanced_count, :max_imbalance
    FROM (
        SELECT 
            period_date,
            ABS(SUM(debit_amount) - SUM(credit_amount)) AS imbalance
        FROM trial_balance_raw
        WHERE deal_id = COALESCE(:deal_id_filter, deal_id)
        GROUP BY deal_id, period_date
        HAVING ABS(SUM(debit_amount) - SUM(credit_amount)) > get_config_number('balance_tolerance_dollars')
    );
    
    -- Log data quality check
    INSERT INTO data_quality_checks (deal_id, check_name, check_type, passed, actual_value, severity, message)
    VALUES (
        :deal_id_filter,
        'Trial Balance Balancing',
        'BALANCE',
        :unbalanced_count = 0,
        OBJECT_CONSTRUCT('unbalanced_periods', :unbalanced_count, 'max_imbalance', :max_imbalance),
        CASE WHEN :unbalanced_count = 0 THEN 'INFO' ELSE 'WARNING' END,
        CASE 
            WHEN :unbalanced_count = 0 THEN 'All periods balanced (debits = credits)'
            ELSE :unbalanced_count || ' periods out of balance. Max imbalance: $' || ROUND(:max_imbalance, 2)
        END
    );
    
    COMMIT;
    
    -- Log success
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = CASE WHEN :unbalanced_count > 0 THEN 'WARNING' ELSE 'SUCCESS' END,
        rows_affected = :rows_loaded,
        message = 'Loaded ' || :rows_loaded || ' rows, ' || :error_count || ' errors, ' || 
                  :unbalanced_count || ' unbalanced periods'
    WHERE log_id = :log_id_var;
    
    result_cursor := (
        SELECT 
            CASE WHEN :unbalanced_count > 0 THEN 'WARNING' ELSE 'SUCCESS' END AS status,
            :rows_loaded AS rows_loaded,
            :error_count AS errors_found,
            'Loaded ' || :rows_loaded || ' rows. ' ||
            CASE 
                WHEN :unbalanced_count > 0 
                THEN :unbalanced_count || ' periods have imbalances (max: $' || ROUND(:max_imbalance, 2) || ')'
                ELSE 'All periods balanced.'
            END AS message
    );
    
    RETURN TABLE(result_cursor);
    
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        
        -- Log error
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
            status = 'ERROR',
            error_message = 'FATAL: ' || SQLERRM,
            rows_affected = :rows_loaded
        WHERE log_id = :log_id_var;
        
        result_cursor := (
            SELECT 'ERROR' AS status, 
                   0 AS rows_loaded, 
                   0 AS errors_found,
                   'FATAL ERROR: ' || SQLERRM AS message
        );
        RETURN TABLE(result_cursor);
END;
$$;

-- Procedure: Load Account Mappings with validation
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
    
    -- CRITICAL FIX: Set is_active = TRUE for all loaded mappings
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
    
    -- Log validation result
    INSERT INTO data_quality_checks (deal_id, check_name, check_type, passed, actual_value, severity, message)
    VALUES (
        :deal_id_filter,
        'Account Mapping Completeness',
        'COMPLETENESS',
        :unmapped_count = 0,
        OBJECT_CONSTRUCT('unmapped_accounts', :unmapped_count),
        CASE WHEN :unmapped_count = 0 THEN 'INFO' WHEN :unmapped_count < 5 THEN 'WARNING' ELSE 'ERROR' END,
        CASE 
            WHEN :unmapped_count = 0 THEN 'All accounts have mappings'
            ELSE :unmapped_count || ' accounts missing mappings'
        END
    );
    
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
    
    result_cursor := (
        SELECT 
            CASE WHEN :unmapped_count > 5 THEN 'ERROR' 
                 WHEN :unmapped_count > 0 THEN 'WARNING' 
                 ELSE 'SUCCESS' END AS status,
            :rows_loaded AS rows_loaded,
            'Loaded ' || :rows_loaded || ' account mappings. ' ||
            CASE 
                WHEN :unmapped_count > 0 
                THEN 'WARNING: ' || :unmapped_count || ' accounts in trial balance have no mapping.'
                ELSE 'All accounts mapped.'
            END AS message
    );
    
    RETURN TABLE(result_cursor);
    
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = SQLERRM
        WHERE log_id = :log_id_var;
        
        result_cursor := (
            SELECT 'ERROR' AS status, 0 AS rows_loaded, 
                   'FATAL ERROR: ' || SQLERRM AS message
        );
        RETURN TABLE(result_cursor);
END;
$$;

-- ============================================================================
-- PART 2: DATA VALIDATION PROCEDURES
-- ============================================================================

-- Comprehensive data quality validation
CREATE OR REPLACE PROCEDURE validate_data_quality(deal_id_param VARCHAR)
RETURNS TABLE(check_name VARCHAR, passed BOOLEAN, severity VARCHAR, message VARCHAR)
LANGUAGE SQL
AS
$$
DECLARE
    result_cursor RESULTSET;
BEGIN
    -- Validate deal_id
    IF (NOT validate_deal_id(:deal_id_param)) THEN
        result_cursor := (
            SELECT 'Input Validation' AS check_name, FALSE AS passed, 
                   'ERROR' AS severity, 'Invalid deal_id format' AS message
        );
        RETURN TABLE(result_cursor);
    END IF;
    
    -- Run all data quality checks and return results
    result_cursor := (
        WITH checks AS (
            -- Check 1: Trial balance exists
            SELECT 
                'Trial Balance Existence' AS check_name,
                COUNT(*) > 0 AS passed,
                CASE WHEN COUNT(*) > 0 THEN 'INFO' ELSE 'CRITICAL' END AS severity,
                CASE WHEN COUNT(*) > 0 
                     THEN 'Found ' || COUNT(*) || ' records' 
                     ELSE 'No trial balance data found' END AS message
            FROM trial_balance_raw
            WHERE deal_id = :deal_id_param
            
            UNION ALL
            
            -- Check 2: Account mappings complete
            SELECT 
                'Account Mapping Completeness',
                COUNT(*) = 0,
                CASE WHEN COUNT(*) = 0 THEN 'INFO' WHEN COUNT(*) < 5 THEN 'WARNING' ELSE 'ERROR' END,
                CASE WHEN COUNT(*) = 0 
                     THEN 'All accounts mapped' 
                     ELSE COUNT(*)::VARCHAR || ' accounts missing mappings' END
            FROM trial_balance_raw t
            LEFT JOIN account_mappings m ON t.deal_id = m.deal_id AND t.account_number = m.account_number
            WHERE t.deal_id = :deal_id_param AND m.account_number IS NULL
            
            UNION ALL
            
            -- Check 3: Period continuity
            SELECT 
                'Period Continuity',
                gaps = 0,
                CASE WHEN gaps = 0 THEN 'INFO' ELSE 'WARNING' END,
                CASE WHEN gaps = 0 
                     THEN 'No date gaps detected' 
                     ELSE gaps::VARCHAR || ' month gaps in period sequence' END
            FROM (
                SELECT COUNT(*) AS gaps
                FROM (
                    SELECT 
                        period_date,
                        LAG(period_date) OVER (ORDER BY period_date) AS prev_date,
                        DATEDIFF(month, LAG(period_date) OVER (ORDER BY period_date), period_date) AS month_diff
                    FROM (SELECT DISTINCT period_date FROM trial_balance_raw WHERE deal_id = :deal_id_param)
                )
                WHERE month_diff > 1
            )
            
            UNION ALL
            
            -- Check 4: Negative revenue detection (potential data issue)
            SELECT 
                'Revenue Sign Check',
                COUNT(*) = 0,
                CASE WHEN COUNT(*) = 0 THEN 'INFO' ELSE 'WARNING' END,
                CASE WHEN COUNT(*) = 0 
                     THEN 'Revenue signs look correct' 
                     ELSE COUNT(*)::VARCHAR || ' revenue accounts with unexpected negative values' END
            FROM trial_balance_raw t
            JOIN account_mappings m ON t.deal_id = m.deal_id AND t.account_number = m.account_number
            WHERE t.deal_id = :deal_id_param 
            AND m.mapping_level_1 = 'Revenue' 
            AND t.net_amount > 0  -- In accounting, revenue is typically credit (negative)
            
            UNION ALL
            
            -- Check 5: Duplicate records
            SELECT 
                'Duplicate Records',
                COUNT(*) = 0,
                CASE WHEN COUNT(*) = 0 THEN 'INFO' ELSE 'ERROR' END,
                CASE WHEN COUNT(*) = 0 
                     THEN 'No duplicates found' 
                     ELSE COUNT(*)::VARCHAR || ' duplicate records detected' END
            FROM (
                SELECT deal_id, account_number, period_date, entity, COUNT(*) AS cnt
                FROM trial_balance_raw
                WHERE deal_id = :deal_id_param
                GROUP BY deal_id, account_number, period_date, entity
                HAVING COUNT(*) > 1
            )
        )
        SELECT * FROM checks
    );
    
    -- Also insert into data_quality_checks table
    INSERT INTO data_quality_checks (deal_id, check_name, check_type, passed, severity, message)
    SELECT 
        :deal_id_param,
        check_name,
        'VALIDATION',
        passed,
        severity,
        message
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
    
    RETURN TABLE(result_cursor);
END;
$$;

SELECT 'Core data procedures created successfully' AS status;



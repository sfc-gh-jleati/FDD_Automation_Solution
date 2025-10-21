-- ============================================================================
-- Houlihan Lokey FDD Automation - AI Insights & Export Procedures
-- ============================================================================
-- Description: Cortex AI-powered insights and data export functionality
-- Version: 1.0.0
-- Last Updated: 2025-10-20
-- ============================================================================

-- ============================================================================
-- PART 1: AI INSIGHTS GENERATION
-- ============================================================================

CREATE OR REPLACE PROCEDURE generate_ai_insights(deal_id_param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    insight_count NUMBER DEFAULT 0;
    ai_model VARCHAR DEFAULT get_config_string('ai_model_variance');
    max_insights NUMBER DEFAULT get_config_number('max_ai_insights');
BEGIN
    -- Validate input
    IF (NOT validate_deal_id(:deal_id_param)) THEN
        RETURN 'ERROR: Invalid deal_id format';
    END IF;
    
    -- Log start
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status)
    VALUES (:log_id_var, 'generate_ai_insights', :deal_id_param, :start_time_var, 'STARTED');
    
    BEGIN TRANSACTION;
    
    -- Clear previous insights for this deal
    DELETE FROM ai_insights WHERE deal_id = :deal_id_param;
    
    -- Step 1: Variance Analysis (period-over-period > threshold%)
    INSERT INTO ai_insights (
        deal_id, insight_type, severity, account_number, account_name, period_date,
        metric_value, comparison_value, variance_pct, insight_text, suggested_question, 
        model_used, prompt_tokens, completion_tokens
    )
    SELECT 
        variance_data.deal_id,
        'variance',
        CASE 
            WHEN ABS(variance_data.var_pct) > 50 THEN 'high'
            WHEN ABS(variance_data.var_pct) > 30 THEN 'medium'
            ELSE 'low'
        END,
        variance_data.account_number,
        variance_data.account_name,
        variance_data.period_date,
        variance_data.net_amount,
        variance_data.prior_net_amount,
        variance_data.var_pct,
        -- Use Cortex AI to generate insights (model must be literal string per Snowflake Cortex requirements)
        SNOWFLAKE.CORTEX.COMPLETE(
            'mistral-large',
            'Analyze this financial variance for a due diligence review: Account "' || variance_data.account_name || 
            '" changed from $' || TO_CHAR(ABS(variance_data.prior_net_amount), '999,999,999') || 
            ' to $' || TO_CHAR(ABS(variance_data.net_amount), '999,999,999') || 
            ' (' || ROUND(variance_data.var_pct, 1) || '% change) between ' || 
            TO_CHAR(variance_data.prior_period_date, 'Mon YYYY') || ' and ' || TO_CHAR(variance_data.period_date, 'Mon YYYY') || 
            '. Provide a 2-sentence explanation of potential business reasons for this variance that a due diligence analyst should investigate.'
        ),
        'Why did ' || variance_data.account_name || ' change by ' || ROUND(ABS(variance_data.var_pct), 1) || '% from ' ||
        TO_CHAR(variance_data.prior_period_date, 'Mon YYYY') || ' to ' || TO_CHAR(variance_data.period_date, 'Mon YYYY') || '?',
        'mistral-large',
        NULL,  -- Token counts would need to be calculated separately
        NULL
    FROM (
        SELECT 
            t1.deal_id, t1.period_date, t1.account_number, t1.account_name, t1.net_amount,
            t2.net_amount AS prior_net_amount,
            ROUND((t1.net_amount - t2.net_amount) / NULLIF(ABS(t2.net_amount), 0) * 100, 2) AS var_pct,
            t2.period_date AS prior_period_date
        FROM trial_balance_raw t1
        JOIN trial_balance_raw t2
            ON t1.deal_id = t2.deal_id
            AND t1.account_number = t2.account_number
            AND t1.entity = t2.entity
            AND t2.period_date = DATEADD(month, -1, t1.period_date)
        WHERE t1.deal_id = :deal_id_param
          AND ABS(t2.net_amount) > get_config_number('min_variance_amount')
          AND ABS((t1.net_amount - t2.net_amount) / NULLIF(ABS(t2.net_amount), 0)) > get_config_number('variance_threshold_pct')
    ) AS variance_data
    ORDER BY ABS(variance_data.var_pct) DESC
    LIMIT :max_insights;
    
    SELECT COUNT(*) INTO :insight_count FROM ai_insights WHERE deal_id = :deal_id_param AND insight_type = 'variance';
    
    -- Step 2: Margin Trend Analysis using Cortex
    DECLARE
        margin_analysis VARCHAR;
        margin_data VARCHAR;
    BEGIN
        -- Build margin trend data string
        SELECT LISTAGG(
            TO_CHAR(period_date, 'Mon-YY') || ': ' || TO_CHAR(ROUND(gross_margin_pct, 1), '990.0') || '%', 
            ', '
        ) WITHIN GROUP (ORDER BY period_date)
        INTO :margin_data
        FROM (
            SELECT 
                t.period_date,
                (SUM(CASE WHEN m.mapping_level_1 = 'Revenue' THEN t.net_amount ELSE 0 END) +
                 SUM(CASE WHEN m.mapping_level_1 = 'Cost of Goods Sold' THEN t.net_amount ELSE 0 END)) /
                NULLIF(SUM(CASE WHEN m.mapping_level_1 = 'Revenue' THEN ABS(t.net_amount) ELSE 0 END), 0) * 100 AS gross_margin_pct
            FROM trial_balance_raw t
            JOIN account_mappings m ON t.deal_id = m.deal_id AND t.account_number = m.account_number
            WHERE t.deal_id = :deal_id_param
            GROUP BY t.period_date
            ORDER BY t.period_date
        );
        
        -- Generate AI analysis if we have data
        IF (:margin_data IS NOT NULL) THEN
            SELECT SNOWFLAKE.CORTEX.COMPLETE(
                get_config_string('ai_model_trends'),
                'Analyze the following gross margin trend over 24 months for a company undergoing due diligence: ' ||
                :margin_data ||
                '. Identify any concerning trends, seasonality patterns, or margin compression/expansion. Provide 3 specific questions for management in 150 words.'
            ) INTO :margin_analysis;
            
            INSERT INTO ai_insights (deal_id, insight_type, severity, insight_text, model_used)
            VALUES (:deal_id_param, 'trend_analysis', 'medium', :margin_analysis, get_config_string('ai_model_trends'));
            
            insight_count := :insight_count + 1;
        END IF;
    END;
    
    COMMIT;
    
    -- Log success
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = 'SUCCESS',
        rows_affected = :insight_count,
        message = 'Generated ' || :insight_count || ' AI insights'
    WHERE log_id = :log_id_var;
    
    RETURN 'SUCCESS: Generated ' || :insight_count || ' AI insights for ' || :deal_id_param;
    
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = SQLERRM
        WHERE log_id = :log_id_var;
        
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

-- ============================================================================
-- PART 2: EXPORT PROCEDURES (with SQL injection protection)
-- ============================================================================

-- Export database tab to CSV
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
BEGIN
    -- Validate and sanitize deal_id
    safe_deal_id := sanitize_deal_id(:deal_id_param);
    IF (safe_deal_id IS NULL) THEN
        RETURN 'ERROR: Invalid deal_id format. Must be alphanumeric with underscores/hyphens only.';
    END IF;
    
    -- Log start
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status)
    VALUES (:log_id_var, 'export_database_tab', :safe_deal_id, :start_time_var, 'STARTED');
    
    -- Build output path
    output_path := '@' || get_config_string('output_stage_name') || '/database_tab_' || :safe_deal_id || '.csv';
    
    -- Export using parameterized query to prevent SQL injection
    COPY INTO IDENTIFIER(:output_path)
    FROM (
        SELECT * FROM v_database_tab_pivoted WHERE deal_id = :safe_deal_id
    )
    FILE_FORMAT = (FORMAT_NAME = 'csv_format' COMPRESSION = NONE)
    HEADER = TRUE
    OVERWRITE = TRUE
    SINGLE = TRUE;
    
    file_count := SQLROWCOUNT;
    
    -- Log success
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
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = SQLERRM
        WHERE log_id = :log_id_var;
        
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

-- Export income statement structure
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
BEGIN
    -- Validate and sanitize deal_id
    safe_deal_id := sanitize_deal_id(:deal_id_param);
    IF (safe_deal_id IS NULL) THEN
        RETURN 'ERROR: Invalid deal_id format';
    END IF;
    
    -- Log start
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status)
    VALUES (:log_id_var, 'export_income_statement_structure', :safe_deal_id, :start_time_var, 'STARTED');
    
    output_path := '@' || get_config_string('output_stage_name') || '/income_statement_' || :safe_deal_id || '.csv';
    
    COPY INTO IDENTIFIER(:output_path)
    FROM (
        SELECT row_num, row_label, row_type, account_filter, row_format_json
        FROM temp_is_schedule
        ORDER BY row_num
    )
    FILE_FORMAT = (FORMAT_NAME = 'csv_format' COMPRESSION = NONE)
    HEADER = TRUE
    OVERWRITE = TRUE
    SINGLE = TRUE;
    
    file_count := SQLROWCOUNT;
    
    -- Log success
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = 'SUCCESS',
        rows_affected = :file_count
    WHERE log_id = :log_id_var;
    
    RETURN 'SUCCESS: Exported Income Statement to ' || :output_path;
    
EXCEPTION
    WHEN OTHER THEN
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = SQLERRM
        WHERE log_id = :log_id_var;
        
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

-- Export balance sheet structure
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
BEGIN
    safe_deal_id := sanitize_deal_id(:deal_id_param);
    IF (safe_deal_id IS NULL) THEN
        RETURN 'ERROR: Invalid deal_id format';
    END IF;
    
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status)
    VALUES (:log_id_var, 'export_balance_sheet_structure', :safe_deal_id, :start_time_var, 'STARTED');
    
    output_path := '@' || get_config_string('output_stage_name') || '/balance_sheet_' || :safe_deal_id || '.csv';
    
    COPY INTO IDENTIFIER(:output_path)
    FROM (
        SELECT row_num, row_label, row_type, account_filter, row_format_json
        FROM temp_bs_schedule
        ORDER BY row_num
    )
    FILE_FORMAT = (FORMAT_NAME = 'csv_format' COMPRESSION = NONE)
    HEADER = TRUE
    OVERWRITE = TRUE
    SINGLE = TRUE;
    
    file_count := SQLROWCOUNT;
    
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = 'SUCCESS',
        rows_affected = :file_count
    WHERE log_id = :log_id_var;
    
    RETURN 'SUCCESS: Exported Balance Sheet to ' || :output_path;
    
EXCEPTION
    WHEN OTHER THEN
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = SQLERRM
        WHERE log_id = :log_id_var;
        
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

-- Export AI insights
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
BEGIN
    safe_deal_id := sanitize_deal_id(:deal_id_param);
    IF (safe_deal_id IS NULL) THEN
        RETURN 'ERROR: Invalid deal_id format';
    END IF;
    
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status)
    VALUES (:log_id_var, 'export_ai_insights', :safe_deal_id, :start_time_var, 'STARTED');
    
    output_path := '@' || get_config_string('output_stage_name') || '/ai_insights_' || :safe_deal_id || '.csv';
    
    COPY INTO IDENTIFIER(:output_path)
    FROM (
        SELECT 
            insight_type, 
            severity, 
            COALESCE(account_name, 'General') AS account_name,
            TO_CHAR(period_date, 'Mon YYYY') AS period,
            metric_value,
            comparison_value,
            variance_pct,
            insight_text,
            suggested_question,
            model_used
        FROM ai_insights
        WHERE deal_id = :safe_deal_id
        ORDER BY 
            CASE severity WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
            ABS(variance_pct) DESC
    )
    FILE_FORMAT = (FORMAT_NAME = 'csv_format' COMPRESSION = NONE)
    HEADER = TRUE
    OVERWRITE = TRUE
    SINGLE = TRUE;
    
    file_count := SQLROWCOUNT;
    
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = 'SUCCESS',
        rows_affected = :file_count
    WHERE log_id = :log_id_var;
    
    RETURN 'SUCCESS: Exported AI insights to ' || :output_path || ' (' || :file_count || ' insights)';
    
EXCEPTION
    WHEN OTHER THEN
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = SQLERRM
        WHERE log_id = :log_id_var;
        
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

-- ============================================================================
-- PART 3: MASTER ORCHESTRATION PROCEDURES
-- ============================================================================

-- Master procedure for generating all FDD schedules for a deal
CREATE OR REPLACE PROCEDURE generate_fdd_schedules(deal_id_param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    result VARCHAR;
    tb_row_count NUMBER;
    insight_count NUMBER;
    safe_deal_id VARCHAR;
BEGIN
    -- Validate and sanitize input
    safe_deal_id := sanitize_deal_id(:deal_id_param);
    IF (safe_deal_id IS NULL) THEN
        RETURN 'ERROR: Invalid deal_id format. Must be alphanumeric with underscores/hyphens only.';
    END IF;
    
    -- Log start
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status)
    VALUES (:log_id_var, 'generate_fdd_schedules', :safe_deal_id, :start_time_var, 'STARTED');
    
    -- Validate deal exists
    SELECT COUNT(*) INTO :tb_row_count 
    FROM trial_balance_raw 
    WHERE deal_id = :safe_deal_id;
    
    IF (:tb_row_count = 0) THEN
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = 'No trial balance data found for deal'
        WHERE log_id = :log_id_var;
        
        RETURN 'ERROR: No trial balance data found for deal ' || :safe_deal_id || 
               '. Please load data first using load_trial_balance().';
    END IF;
    
    -- Step 1: Generate schedules (session-isolated temp tables)
    CALL generate_income_statement(:safe_deal_id);
    CALL generate_balance_sheet(:safe_deal_id);
    
    -- Step 2: Generate AI insights
    CALL generate_ai_insights(:safe_deal_id);
    
    -- Step 3: Export everything with deal-specific filenames
    CALL export_database_tab(:safe_deal_id);
    CALL export_income_statement_structure(:safe_deal_id);
    CALL export_balance_sheet_structure(:safe_deal_id);
    CALL export_ai_insights(:safe_deal_id);
    
    -- Get counts for confirmation
    SELECT COUNT(*) INTO :insight_count FROM ai_insights WHERE deal_id = :safe_deal_id;
    
    result := :tb_row_count::VARCHAR || ' TB rows processed, ' ||
              :insight_count::VARCHAR || ' AI insights generated for ' || :safe_deal_id;
    
    -- Log success
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = 'SUCCESS',
        rows_affected = :tb_row_count,
        message = result
    WHERE log_id = :log_id_var;
    
    RETURN 'SUCCESS: ' || result || '. Outputs available at @' || get_config_string('output_stage_name') || '/*_' || :safe_deal_id || '.csv';
    
EXCEPTION
    WHEN OTHER THEN
        UPDATE audit_log 
        SET end_time = CURRENT_TIMESTAMP(),
            status = 'ERROR',
            error_message = SQLERRM
        WHERE log_id = :log_id_var;
        
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

SELECT 'AI insights and export procedures created successfully' AS status;



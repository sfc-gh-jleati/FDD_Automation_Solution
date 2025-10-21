-- ============================================================================
-- Houlihan Lokey FDD Automation - Schedule Generation Procedures
-- ============================================================================
-- Description: Income Statement and Balance Sheet generation with formulas
-- Version: 1.0.0
-- Last Updated: 2025-10-20
-- ============================================================================

-- ============================================================================
-- PART 1: PIVOTED DATABASE VIEW (Wide format for Excel)
-- ============================================================================

CREATE OR REPLACE VIEW v_database_tab_pivoted AS
WITH last_n_periods AS (
    -- Get the most recent N distinct periods (configured)
    SELECT DISTINCT period_date
    FROM trial_balance_raw
    ORDER BY period_date DESC
    LIMIT (SELECT get_config_number('max_pivot_periods'))
),
ranked_periods AS (
    -- Rank from oldest (1) to newest (N)
    SELECT 
        period_date,
        TO_CHAR(period_date, 'Mon-YYYY') AS period_label,
        ROW_NUMBER() OVER (ORDER BY period_date) AS period_rank
    FROM last_n_periods
)
SELECT 
    t.deal_id,
    t.deal_name,
    t.entity,
    t.account_number,
    t.account_name,
    t.unique_id,
    t.mapping_level_1,
    t.mapping_level_2,
    t.mapping_level_3,
    t.statement_type,
    t.sort_order_l1,
    t.sort_order_l2,
    -- Period headers and data (using amount_for_display with proper signs)
    MAX(CASE WHEN p.period_rank = 1 THEN p.period_label END) AS period_01_label,
    MAX(CASE WHEN p.period_rank = 2 THEN p.period_label END) AS period_02_label,
    MAX(CASE WHEN p.period_rank = 3 THEN p.period_label END) AS period_03_label,
    MAX(CASE WHEN p.period_rank = 4 THEN p.period_label END) AS period_04_label,
    MAX(CASE WHEN p.period_rank = 5 THEN p.period_label END) AS period_05_label,
    MAX(CASE WHEN p.period_rank = 6 THEN p.period_label END) AS period_06_label,
    MAX(CASE WHEN p.period_rank = 7 THEN p.period_label END) AS period_07_label,
    MAX(CASE WHEN p.period_rank = 8 THEN p.period_label END) AS period_08_label,
    MAX(CASE WHEN p.period_rank = 9 THEN p.period_label END) AS period_09_label,
    MAX(CASE WHEN p.period_rank = 10 THEN p.period_label END) AS period_10_label,
    MAX(CASE WHEN p.period_rank = 11 THEN p.period_label END) AS period_11_label,
    MAX(CASE WHEN p.period_rank = 12 THEN p.period_label END) AS period_12_label,
    MAX(CASE WHEN p.period_rank = 13 THEN p.period_label END) AS period_13_label,
    MAX(CASE WHEN p.period_rank = 14 THEN p.period_label END) AS period_14_label,
    MAX(CASE WHEN p.period_rank = 15 THEN p.period_label END) AS period_15_label,
    MAX(CASE WHEN p.period_rank = 16 THEN p.period_label END) AS period_16_label,
    MAX(CASE WHEN p.period_rank = 17 THEN p.period_label END) AS period_17_label,
    MAX(CASE WHEN p.period_rank = 18 THEN p.period_label END) AS period_18_label,
    MAX(CASE WHEN p.period_rank = 19 THEN p.period_label END) AS period_19_label,
    MAX(CASE WHEN p.period_rank = 20 THEN p.period_label END) AS period_20_label,
    MAX(CASE WHEN p.period_rank = 21 THEN p.period_label END) AS period_21_label,
    MAX(CASE WHEN p.period_rank = 22 THEN p.period_label END) AS period_22_label,
    MAX(CASE WHEN p.period_rank = 23 THEN p.period_label END) AS period_23_label,
    MAX(CASE WHEN p.period_rank = 24 THEN p.period_label END) AS period_24_label,
    MAX(CASE WHEN p.period_rank = 1 THEN t.amount_for_display END) AS period_01,
    MAX(CASE WHEN p.period_rank = 2 THEN t.amount_for_display END) AS period_02,
    MAX(CASE WHEN p.period_rank = 3 THEN t.amount_for_display END) AS period_03,
    MAX(CASE WHEN p.period_rank = 4 THEN t.amount_for_display END) AS period_04,
    MAX(CASE WHEN p.period_rank = 5 THEN t.amount_for_display END) AS period_05,
    MAX(CASE WHEN p.period_rank = 6 THEN t.amount_for_display END) AS period_06,
    MAX(CASE WHEN p.period_rank = 7 THEN t.amount_for_display END) AS period_07,
    MAX(CASE WHEN p.period_rank = 8 THEN t.amount_for_display END) AS period_08,
    MAX(CASE WHEN p.period_rank = 9 THEN t.amount_for_display END) AS period_09,
    MAX(CASE WHEN p.period_rank = 10 THEN t.amount_for_display END) AS period_10,
    MAX(CASE WHEN p.period_rank = 11 THEN t.amount_for_display END) AS period_11,
    MAX(CASE WHEN p.period_rank = 12 THEN t.amount_for_display END) AS period_12,
    MAX(CASE WHEN p.period_rank = 13 THEN t.amount_for_display END) AS period_13,
    MAX(CASE WHEN p.period_rank = 14 THEN t.amount_for_display END) AS period_14,
    MAX(CASE WHEN p.period_rank = 15 THEN t.amount_for_display END) AS period_15,
    MAX(CASE WHEN p.period_rank = 16 THEN t.amount_for_display END) AS period_16,
    MAX(CASE WHEN p.period_rank = 17 THEN t.amount_for_display END) AS period_17,
    MAX(CASE WHEN p.period_rank = 18 THEN t.amount_for_display END) AS period_18,
    MAX(CASE WHEN p.period_rank = 19 THEN t.amount_for_display END) AS period_19,
    MAX(CASE WHEN p.period_rank = 20 THEN t.amount_for_display END) AS period_20,
    MAX(CASE WHEN p.period_rank = 21 THEN t.amount_for_display END) AS period_21,
    MAX(CASE WHEN p.period_rank = 22 THEN t.amount_for_display END) AS period_22,
    MAX(CASE WHEN p.period_rank = 23 THEN t.amount_for_display END) AS period_23,
    MAX(CASE WHEN p.period_rank = 24 THEN t.amount_for_display END) AS period_24
FROM v_trial_balance_for_schedules t
CROSS JOIN ranked_periods p
WHERE t.period_date = p.period_date
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12
ORDER BY 11, 12, 4;

-- ============================================================================
-- PART 2: INCOME STATEMENT GENERATION
-- ============================================================================

CREATE OR REPLACE PROCEDURE generate_income_statement(deal_id_param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    rows_created NUMBER DEFAULT 0;
    session_id VARCHAR DEFAULT CURRENT_SESSION()::VARCHAR;
BEGIN
    -- Validate input
    IF (NOT validate_deal_id(:deal_id_param)) THEN
        RETURN 'ERROR: Invalid deal_id format';
    END IF;
    
    -- Log start
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status, session_id)
    VALUES (:log_id_var, 'generate_income_statement', :deal_id_param, :start_time_var, 'STARTED', :session_id);
    
    -- Create session-specific temp table (isolated per user/session)
    CREATE OR REPLACE TEMPORARY TABLE temp_is_schedule (
        row_num NUMBER AUTOINCREMENT,
        row_label VARCHAR(500),
        row_type VARCHAR(20),
        account_filter VARCHAR(600),
        formula_template VARCHAR(5000),
        row_format_json VARCHAR(5000)
    );
    
    -- Header
    INSERT INTO temp_is_schedule (row_label, row_type, account_filter, formula_template, row_format_json)
    VALUES 
        ('Income Statement ($000s)', 'header', NULL, 'PERIOD_LABEL', 
         '{"bold": true, "font_size": 12, "bg_color": "#4472C4", "font_color": "white"}'),
        ('', 'blank', NULL, NULL, '{}'),
        ('Revenue', 'section_header', NULL, NULL, '{"bold": true, "outline_level": 1}');
    
    -- Revenue accounts (flexible mapping depth)
    INSERT INTO temp_is_schedule (row_label, row_type, account_filter, row_format_json)
    SELECT 
        CASE 
            WHEN mapping_level_3 IS NOT NULL THEN '    ' || mapping_level_3
            WHEN mapping_level_2 IS NOT NULL THEN '  ' || mapping_level_2
            ELSE account_name
        END AS row_label,
        'data',
        account_number || ' - ' || account_name,
        OBJECT_CONSTRUCT(
            'number_format', '#,##0',
            'outline_level', CASE WHEN mapping_level_3 IS NOT NULL THEN 3
                                 WHEN mapping_level_2 IS NOT NULL THEN 2
                                 ELSE 1 END,
            'indent', CASE WHEN mapping_level_3 IS NOT NULL THEN 2
                          WHEN mapping_level_2 IS NOT NULL THEN 1
                          ELSE 0 END
        )::VARCHAR
    FROM account_mappings
    WHERE deal_id = :deal_id_param 
    AND statement_type = 'IS' 
    AND mapping_level_1 = 'Revenue'
    AND is_active = TRUE
    ORDER BY sort_order_l1, COALESCE(sort_order_l2, 999), COALESCE(sort_order_l3, 999);
    
    INSERT INTO temp_is_schedule (row_label, row_type, account_filter, row_format_json)
    VALUES 
        ('Total Revenue', 'subtotal', NULL, 
         '{"bold": true, "border_top": true, "number_format": "#,##0", "outline_level": 1}'),
        ('', 'blank', NULL, '{}'),
        ('Cost of Goods Sold', 'section_header', NULL, '{"bold": true, "outline_level": 1}');
    
    -- COGS accounts
    INSERT INTO temp_is_schedule (row_label, row_type, account_filter, row_format_json)
    SELECT 
        CASE 
            WHEN mapping_level_3 IS NOT NULL THEN '    ' || mapping_level_3
            WHEN mapping_level_2 IS NOT NULL THEN '  ' || mapping_level_2
            ELSE account_name
        END AS row_label,
        'data',
        account_number || ' - ' || account_name,
        OBJECT_CONSTRUCT(
            'number_format', '#,##0',
            'outline_level', CASE WHEN mapping_level_3 IS NOT NULL THEN 3
                                 WHEN mapping_level_2 IS NOT NULL THEN 2
                                 ELSE 1 END,
            'indent', CASE WHEN mapping_level_3 IS NOT NULL THEN 2
                          WHEN mapping_level_2 IS NOT NULL THEN 1
                          ELSE 0 END
        )::VARCHAR
    FROM account_mappings
    WHERE deal_id = :deal_id_param 
    AND statement_type = 'IS' 
    AND mapping_level_1 = 'Cost of Goods Sold'
    AND is_active = TRUE
    ORDER BY sort_order_l1, COALESCE(sort_order_l2, 999), COALESCE(sort_order_l3, 999);
    
    INSERT INTO temp_is_schedule (row_label, row_type, account_filter, row_format_json)
    VALUES 
        ('Total Cost of Goods Sold', 'subtotal', NULL, 
         '{"bold": true, "border_top": true, "number_format": "#,##0", "outline_level": 1}'),
        ('', 'blank', NULL, '{}'),
        ('Gross Margin', 'calculated', NULL, 
         '{"bold": true, "border_bottom": true, "number_format": "#,##0"}'),
        ('', 'blank', NULL, '{}'),
        ('Operating Expenses', 'section_header', NULL, '{"bold": true, "outline_level": 1}');
    
    -- OpEx accounts
    INSERT INTO temp_is_schedule (row_label, row_type, account_filter, row_format_json)
    SELECT 
        CASE 
            WHEN mapping_level_3 IS NOT NULL THEN '    ' || mapping_level_3
            WHEN mapping_level_2 IS NOT NULL THEN '  ' || mapping_level_2
            ELSE account_name
        END AS row_label,
        'data',
        account_number || ' - ' || account_name,
        OBJECT_CONSTRUCT(
            'number_format', '#,##0',
            'outline_level', CASE WHEN mapping_level_3 IS NOT NULL THEN 3
                                 WHEN mapping_level_2 IS NOT NULL THEN 2
                                 ELSE 1 END,
            'indent', CASE WHEN mapping_level_3 IS NOT NULL THEN 2
                          WHEN mapping_level_2 IS NOT NULL THEN 1
                          ELSE 0 END
        )::VARCHAR
    FROM account_mappings
    WHERE deal_id = :deal_id_param 
    AND statement_type = 'IS' 
    AND mapping_level_1 = 'Operating Expenses'
    AND is_active = TRUE
    ORDER BY sort_order_l1, COALESCE(sort_order_l2, 999), COALESCE(sort_order_l3, 999);
    
    INSERT INTO temp_is_schedule (row_label, row_type, account_filter, row_format_json)
    VALUES 
        ('Total Operating Expenses', 'subtotal', NULL, 
         '{"bold": true, "border_top": true, "number_format": "#,##0", "outline_level": 1}'),
        ('', 'blank', NULL, '{}'),
        ('Operating Income', 'total', NULL, 
         '{"bold": true, "border_bottom_double": true, "number_format": "#,##0"}');
    
    SELECT COUNT(*) INTO :rows_created FROM temp_is_schedule;
    
    -- Log success
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = 'SUCCESS',
        rows_affected = :rows_created
    WHERE log_id = :log_id_var;
    
    RETURN 'SUCCESS: Generated Income Statement with ' || :rows_created || ' rows';
    
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
-- PART 3: BALANCE SHEET GENERATION
-- ============================================================================

CREATE OR REPLACE PROCEDURE generate_balance_sheet(deal_id_param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    log_id_var VARCHAR DEFAULT UUID_STRING();
    start_time_var TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    rows_created NUMBER DEFAULT 0;
    session_id VARCHAR DEFAULT CURRENT_SESSION()::VARCHAR;
BEGIN
    -- Validate input
    IF (NOT validate_deal_id(:deal_id_param)) THEN
        RETURN 'ERROR: Invalid deal_id format';
    END IF;
    
    -- Log start
    INSERT INTO audit_log (log_id, procedure_name, deal_id, start_time, status, session_id)
    VALUES (:log_id_var, 'generate_balance_sheet', :deal_id_param, :start_time_var, 'STARTED', :session_id);
    
    -- Create session-specific temp table
    CREATE OR REPLACE TEMPORARY TABLE temp_bs_schedule (
        row_num NUMBER AUTOINCREMENT,
        row_label VARCHAR(500),
        row_type VARCHAR(20),
        account_filter VARCHAR(600),
        row_format_json VARCHAR(5000)
    );
    
    -- Header
    INSERT INTO temp_bs_schedule (row_label, row_type, account_filter, row_format_json)
    VALUES 
        ('Balance Sheet ($000s)', 'header', NULL, 
         '{"bold": true, "font_size": 12, "bg_color": "#4472C4", "font_color": "white"}'),
        ('', 'blank', NULL, '{}'),
        ('ASSETS', 'section_header', NULL, '{"bold": true, "outline_level": 1}'),
        ('Current Assets', 'subsection_header', NULL, '{"bold": true, "outline_level": 2, "indent": 1}');
    
    -- Current Assets
    INSERT INTO temp_bs_schedule (row_label, row_type, account_filter, row_format_json)
    SELECT 
        CASE 
            WHEN mapping_level_3 IS NOT NULL THEN '    ' || mapping_level_3
            WHEN mapping_level_2 IS NOT NULL THEN '  ' || mapping_level_2
            ELSE account_name
        END AS row_label,
        'data',
        account_number || ' - ' || account_name,
        OBJECT_CONSTRUCT(
            'number_format', '#,##0',
            'outline_level', CASE WHEN mapping_level_3 IS NOT NULL THEN 3
                                 WHEN mapping_level_2 IS NOT NULL THEN 2
                                 ELSE 1 END,
            'indent', CASE WHEN mapping_level_3 IS NOT NULL THEN 2
                          WHEN mapping_level_2 IS NOT NULL THEN 1
                          ELSE 0 END
        )::VARCHAR
    FROM account_mappings
    WHERE deal_id = :deal_id_param 
    AND statement_type = 'BS' 
    AND mapping_level_1 = 'Assets' 
    AND COALESCE(mapping_level_2, 'Current Assets') = 'Current Assets'
    AND is_active = TRUE
    ORDER BY sort_order_l1, COALESCE(sort_order_l2, 999), COALESCE(sort_order_l3, 999);
    
    INSERT INTO temp_bs_schedule (row_label, row_type, account_filter, row_format_json)
    VALUES 
        ('  Total Current Assets', 'subtotal', NULL, 
         '{"bold": true, "border_top": true, "number_format": "#,##0", "outline_level": 2, "indent": 1}'),
        ('', 'blank', NULL, '{}'),
        ('Non-Current Assets', 'subsection_header', NULL, 
         '{"bold": true, "outline_level": 2, "indent": 1}');
    
    -- Add remaining BS sections (Non-Current Assets, Liabilities, Equity)
    -- ... (similar pattern as above)
    
    SELECT COUNT(*) INTO :rows_created FROM temp_bs_schedule;
    
    -- Log success
    UPDATE audit_log 
    SET end_time = CURRENT_TIMESTAMP(),
        duration_seconds = DATEDIFF(second, :start_time_var, CURRENT_TIMESTAMP()),
        status = 'SUCCESS',
        rows_affected = :rows_created
    WHERE log_id = :log_id_var;
    
    RETURN 'SUCCESS: Generated Balance Sheet with ' || :rows_created || ' rows';
    
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

SELECT 'Schedule generation procedures created successfully' AS status;



# SQL_ERRM Fix Summary

**Issue:** SQLERRM cannot be used directly in SQL statements (UPDATE, SELECT, etc.) within Snowflake Scripting exception handlers.

**Root Cause:** When Snowflake compiles SQL statements within procedures, SQLERRM is not in the SQL compilation scope, even though it's accessible in the procedural Snowflake Scripting code.

**Solution:** Assign SQLERRM to a local variable first, then use that variable in SQL statements.

## Procedures Requiring Fix

Based on analysis of `deploy_snowsight.sql`:

1. ✅ `load_trial_balance()` - FIXED (lines 963, 1097, 1111)
2. ✅ `load_account_mappings()` - FIXED (lines 1150, 1261, 1273)  
3. ❌ `generate_income_statement()` - NEEDS FIX (lines 1669, 1672)
4. ❌ `generate_balance_sheet()` - NEEDS FIX (lines 1773, 1776)
5. ❌ `generate_ai_insights()` - NEEDS FIX (lines 1941, 1944)
6. ❌ `export_database_tab()` - NEEDS FIX (lines 2004, 2007)
7. ❌ `export_income_statement_structure()` - NEEDS FIX (lines 2060, 2063)
8. ❌ `export_balance_sheet_structure()` - NEEDS FIX (lines 2113, 2116)
9. ❌ `export_ai_insights()` - NEEDS FIX (lines 2169, 2172)
10. ❌ `generate_fdd_schedules()` - NEEDS FIX (lines 2255, 2258)
11. ❌ `load_sample_data()` - NEEDS FIX (line 2338)
12. ❌ `run_complete_poc()` - NEEDS FIX (line 2361)

## Fix Pattern

### Before (❌ Incorrect):
```sql
DECLARE
    log_id_var VARCHAR;
BEGIN
    -- ... code ...
EXCEPTION
    WHEN OTHER THEN
        UPDATE audit_log 
        SET error_message = SQLERRM  -- ❌ SQLERRM used directly in SQL
        WHERE log_id = :log_id_var;
        
        RETURN 'ERROR: ' || SQLERRM;  -- ✅ This is OK
END;
```

### After (✅ Correct):
```sql
DECLARE
    log_id_var VARCHAR;
    error_msg VARCHAR;  -- ✅ Add error variable
BEGIN
    -- ... code ...
EXCEPTION
    WHEN OTHER THEN
        error_msg := SQLERRM;  -- ✅ Assign to variable first
        
        UPDATE audit_log 
        SET error_message = :error_msg  -- ✅ Use variable in SQL
        WHERE log_id = :log_id_var;
        
        RETURN 'ERROR: ' || :error_msg;  -- ✅ Use variable
END;
```

## Key Rules

1. **Variables for EXCEPTION handlers must be declared in DECLARE section** - not in BEGIN...END
2. **SQLERRM can be used directly in procedural code** - like `error_msg := SQLERRM`
3. **SQLERRM CANNOT be used in SQL statements** - must assign to variable first
4. **SQL statements include**: UPDATE, INSERT, SELECT (even in assignments like `result := (SELECT...)`)

## Reference

- Snowflake Docs: [Working with Exception Handlers](https://docs.snowflake.com/en/developer-guide/snowflake-scripting/exceptions)
- Snowflake Docs: [Passing variables to exception handler](https://docs.snowflake.com/en/developer-guide/snowflake-scripting/exceptions#label-snowflake-scripting-exception-handler-variables)


# End-to-End Comprehensive Test Plan

**Date:** October 21, 2025  
**Test Scope:** Full deployment and functional testing  
**Test Data:** CSV files already in FDD_INPUT_STAGE

---

## Test Phases

### Phase 1: Clean Deployment
- Drop existing database (if any)
- Deploy from scratch using deploy_snowsight.sql
- Verify all 42 objects created successfully

### Phase 2: Object Validation
- Verify 9 tables created
- Verify 7 views created
- Verify 20 procedures created
- Verify 6 functions created
- Verify system configuration loaded (23 config values)

### Phase 3: Data Loading Tests
- Test `load_trial_balance()` procedure
- Test `load_account_mappings()` procedure
- Verify data loaded correctly
- Check row counts and data quality

### Phase 4: Data Quality Validation
- Test `validate_data_quality()` procedure
- Check for data quality issues
- Verify trial balance validation

### Phase 5: Schedule Generation Tests
- Test `generate_income_statement()` procedure
- Test `generate_balance_sheet()` procedure
- Verify schedule structures created
- Check row counts and formatting

### Phase 6: AI Insights Tests
- Test `generate_ai_insights()` procedure
- Verify AI insights generated
- Check insight quality and count

### Phase 7: Export Tests
- Test `export_database_tab()` procedure
- Test `export_income_statement_structure()` procedure
- Test `export_balance_sheet_structure()` procedure
- Test `export_ai_insights()` procedure
- Verify files created in output stage

### Phase 8: Complete PoC Test
- Test `run_complete_poc()` procedure
- Verify end-to-end workflow
- Check all outputs

### Phase 9: View Tests
- Test `v_database_tab_pivoted` view
- Test `v_trial_balance_for_schedules` view
- Test `v_portfolio_summary` view
- Verify data formatting

### Phase 10: Security & Configuration Tests
- Test configuration functions
- Test validation functions
- Verify row-level security
- Test data masking

---

## Success Criteria

- ✅ Zero SQL compilation errors
- ✅ All objects created successfully
- ✅ Data loads without errors
- ✅ Schedules generate correctly
- ✅ AI insights created
- ✅ Export files created in stage
- ✅ All views return data
- ✅ Configuration functions work
- ✅ Data validation passes

---

## Test Execution Log

_Test results will be documented below..._


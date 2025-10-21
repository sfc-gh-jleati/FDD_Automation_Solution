# ✅ FINAL FIX - Deploy Updated load_account_mappings Procedure

## 🎯 Current Status

**Working Now (Temporary):**
- ✅ Account mappings manually set to `is_active = TRUE`
- ✅ All 4 CSV files are generating (including database_tab!)
- ✅ database_tab_DEAL_HL_001.csv = 20.3 KB with 29 accounts

**Issue:**
When you run `run_complete_poc()` again, it will reload the account_mappings and set `is_active = NULL` again, breaking the database_tab export.

**Permanent Fix:**
Deploy the updated `load_account_mappings` procedure that automatically sets `is_active = TRUE` after loading.

---

## 🚀 Deploy the Fix (5 minutes)

### Step 1: Open Snowsight
Navigate to: https://app.snowflake.com/

### Step 2: Create New Worksheet
Click: **+ Worksheet** (or **Projects** → **Worksheets** → **+**)

### Step 3: Set Context
Paste and run these lines first:
```sql
USE DATABASE HL_FDD_POC;
USE SCHEMA TRIAL_BALANCE;
```

### Step 4: Copy the Fixed Procedure
Open this file on your computer:
```
production/sql/03_data_procedures.sql
```

**Copy lines 186-322** (the entire `CREATE OR REPLACE PROCEDURE load_account_mappings` block)

OR use this command to see it:
```bash
cd "/Users/jleati/Cursor Projects/HL FDD MVP V2/production"
sed -n '186,322p' sql/03_data_procedures.sql
```

### Step 5: Paste and Execute in Snowsight
Paste the procedure definition into the Snowsight worksheet and click **Run** (or press Cmd+Enter)

You should see:
```
Statement executed successfully.
```

---

## ✅ Test the Fix

After deploying the procedure, test that everything works end-to-end:

```sql
USE DATABASE HL_FDD_POC;
USE SCHEMA TRIAL_BALANCE;

-- Clean up and start fresh
TRUNCATE TABLE account_mappings;
TRUNCATE TABLE income_statement_structure;
TRUNCATE TABLE balance_sheet_structure;
TRUNCATE TABLE ai_insights;
REMOVE @fdd_output_stage PATTERN='.*DEAL_HL_001.*';

-- Run the complete PoC
CALL run_complete_poc();

-- Verify all 4 files were created
LIST @fdd_output_stage;
```

**Expected Output:**
```
fdd_output_stage/database_tab_DEAL_HL_001.csv      | 20288 | ... ✅
fdd_output_stage/income_statement_DEAL_HL_001.csv | 1232  | ... ✅
fdd_output_stage/balance_sheet_DEAL_HL_001.csv    | 704   | ... ✅
fdd_output_stage/ai_insights_DEAL_HL_001.csv      | 11760 | ... ✅
```

---

## 📋 What the Fix Does

**The Problem:**
```sql
-- Original load_account_mappings procedure:
COPY INTO account_mappings (...columns...) FROM @stage...
-- is_active column not included, defaults to NULL
```

**The Fix:**
```sql
-- Updated procedure adds this after COPY:
UPDATE account_mappings SET is_active = TRUE WHERE is_active IS NULL;
-- Now all mappings have is_active = TRUE
-- View filter "WHERE m.is_active = TRUE" includes all rows ✅
```

---

## 🆘 Alternative: Full Redeployment

If you prefer to redeploy everything (takes 2-3 minutes):

1. Open Snowsight
2. Create new worksheet
3. Copy **entire contents** of `production/sql/deploy_snowsight.sql`
4. Paste into worksheet
5. Execute all

This will recreate all objects with the latest code, including the fixed procedure.

---

## ✅ Success Criteria

After deploying and testing, you should have:

- ✅ `run_complete_poc()` completes without errors
- ✅ All 4 CSV files in `@fdd_output_stage`
- ✅ `database_tab_DEAL_HL_001.csv` is 20KB+ with actual data
- ✅ Audit log shows `load_account_mappings` with SUCCESS status
- ✅ `SELECT COUNT(*) FROM account_mappings WHERE is_active = TRUE` returns 29

---

## 📥 Download and Use in Excel

Once all 4 files are verified:

1. **Download database_tab_DEAL_HL_001.csv** from Snowsight Stages UI
2. Open your Excel FDD template
3. Go to **Database** tab
4. Import the CSV (Data → From Text/CSV)
5. Your Excel SUMIF formulas will now populate with data! 🎉

---

## 📝 Summary of Root Cause

| Component | Issue | Fix |
|-----------|-------|-----|
| CSV File | Doesn't include `is_active` column | N/A - by design |
| Table Column | `is_active` defaults to NULL when not provided | Added `DEFAULT TRUE` doesn't help with COPY |
| Load Procedure | COPY doesn't set `is_active` | ✅ Added UPDATE after COPY |
| View Filter | `WHERE m.is_active = TRUE` excludes NULL | Correct - security feature |
| Result | View returns 0 rows → database_tab CSV empty | ✅ Fixed with UPDATE statement |

---

**Once deployed, this fix is permanent** - every future `run_complete_poc()` call will work correctly! 🚀


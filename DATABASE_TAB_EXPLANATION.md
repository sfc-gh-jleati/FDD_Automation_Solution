# Database Tab CSV - Critical File for Excel SUMIF Formulas

## 🎯 What is the Database Tab CSV?

The **Database Tab CSV** (`database_tab_DEAL_HL_001.csv`) is the **most important output file** for the Excel integration. It contains all trial balance data in a **pivoted wide format** that Excel can use as a lookup table for SUMIF formulas.

### Original Excel Workflow:
1. **Database Tab** (imported from CSV) = Source data table
2. **Income Statement Tab** = Uses SUMIF to pull from Database Tab
3. **Balance Sheet Tab** = Uses SUMIF to pull from Database Tab
4. **AI Insights Tab** = Imported separately

---

## 📊 File Structure

### Expected Columns:

**Metadata Columns (12):**
1. `DEAL_ID` - Deal identifier
2. `DEAL_NAME` - Deal name
3. `ENTITY` - Entity name
4. `ACCOUNT_NUMBER` - Account number
5. `ACCOUNT_NAME` - Account name
6. `UNIQUE_ID` - Unique identifier
7. `MAPPING_LEVEL_1` - Top-level mapping (e.g., "Revenue", "COGS")
8. `MAPPING_LEVEL_2` - Second-level mapping
9. `MAPPING_LEVEL_3` - Third-level mapping
10. `STATEMENT_TYPE` - "income_statement" or "balance_sheet"
11. `SORT_ORDER_L1` - Sort order for level 1
12. `SORT_ORDER_L2` - Sort order for level 2

**Period Label Columns (24):**
- `PERIOD_01_LABEL` = "Jan-2023"
- `PERIOD_02_LABEL` = "Feb-2023"
- ...
- `PERIOD_24_LABEL` = "Dec-2024"

**Period Value Columns (24):**
- `PERIOD_01` = Numeric value for Jan-2023
- `PERIOD_02` = Numeric value for Feb-2023
- ...
- `PERIOD_24` = Numeric value for Dec-2024

**Total Columns:** 60 (12 metadata + 24 labels + 24 values)

### Expected Rows:
- **One row per account** (typically 29 accounts for the sample data)
- Each row contains all 24 months of data for that account

---

## 🔍 Sample Data

```csv
DEAL_ID,DEAL_NAME,ENTITY,ACCOUNT_NUMBER,ACCOUNT_NAME,MAPPING_LEVEL_1,MAPPING_LEVEL_2,PERIOD_01_LABEL,PERIOD_01,PERIOD_02_LABEL,PERIOD_02,...
DEAL_HL_001,Houlihan Lokey,ABC Corp,1000,Cash - Operating,Assets,Current Assets,Jan-2023,161563.29,Feb-2023,174839.41,...
DEAL_HL_001,Houlihan Lokey,ABC Corp,1020,Accounts Receivable,Assets,Current Assets,Jan-2023,272265.17,Feb-2023,289453.38,...
DEAL_HL_001,Houlihan Lokey,ABC Corp,1050,Inventory,Assets,Current Assets,Jan-2023,200239.49,Feb-2023,213045.27,...
...
```

---

## 📝 Excel SUMIF Formula Example

In the **Income Statement** tab, a typical formula would look like:

```excel
=SUMIF(Database!$E:$E, "Net Sales", Database!N:N)
```

This sums all values in column N (e.g., `PERIOD_01`) where the account name in column E matches "Net Sales".

The **Database Tab** provides the lookup range for these formulas.

---

## ⚙️ How It's Generated

### 1. View: `v_database_tab_pivoted`
Creates the wide-format table by:
- Joining `v_trial_balance_for_schedules` with period ranks
- Using CASE statements to pivot 24 periods into 24 columns
- Including all metadata for SUMIF lookups

```sql
SELECT 
    deal_id, account_number, account_name, mapping_level_1, ...,
    MAX(CASE WHEN p.period_rank = 1 THEN p.period_label END) AS period_01_label,
    MAX(CASE WHEN p.period_rank = 1 THEN t.amount_for_display END) AS period_01,
    MAX(CASE WHEN p.period_rank = 2 THEN p.period_label END) AS period_02_label,
    MAX(CASE WHEN p.period_rank = 2 THEN t.amount_for_display END) AS period_02,
    ...
FROM v_trial_balance_for_schedules t
CROSS JOIN ranked_periods p
GROUP BY deal_id, account_number, account_name, ...
```

### 2. Procedure: `export_database_tab()`
Exports the view to CSV:

```sql
COPY INTO @fdd_output_stage/database_tab_DEAL_HL_001.csv
FROM (SELECT * FROM v_database_tab_pivoted WHERE deal_id = 'DEAL_HL_001')
FILE_FORMAT = (FORMAT_NAME = 'csv_format' COMPRESSION = NONE)
HEADER = TRUE
OVERWRITE = TRUE
SINGLE = TRUE;
```

### 3. Called by: `generate_fdd_schedules()`
The procedure is called on line 2260:

```sql
CALL export_database_tab(:safe_deal_id);
```

---

## 🚨 Issue: File May Not Be Generated

### Problem:
In our previous verification, we only saw 3 output files:
- ✅ `income_statement_DEAL_HL_001.csv`
- ✅ `balance_sheet_DEAL_HL_001.csv`
- ✅ `ai_insights_DEAL_HL_001.csv`

**Missing:** `database_tab_DEAL_HL_001.csv` ❌

### Potential Causes:
1. **Silent failure** - Procedure failed but didn't throw error
2. **View returned 0 rows** - No data in `v_database_tab_pivoted`
3. **Export procedure not called** - Skipped due to error in previous step
4. **File created but not listed** - Stage listing issue

---

## ✅ Verification Steps

### Step 1: Run the Verification Script
```sql
-- In Snowsight, run:
@verify_database_tab.sql
```

This script will:
1. ✅ Check if `v_database_tab_pivoted` has data
2. ✅ Show sample rows from the view
3. ✅ Check audit log for `export_database_tab` calls
4. ✅ List all files in the output stage
5. ✅ Manually call `export_database_tab()` to test
6. ✅ Verify the file was created

### Step 2: Check Audit Log
```sql
SELECT 
    procedure_name,
    deal_id,
    status,
    error_message
FROM audit_log
WHERE procedure_name = 'export_database_tab'
ORDER BY start_time DESC
LIMIT 5;
```

**Expected:** Status = 'SUCCESS'  
**If Error:** Check `error_message` column

### Step 3: List Output Files
```sql
LIST @fdd_output_stage;
```

**Expected Output:**
```
fdd_output_stage/database_tab_DEAL_HL_001.csv    | 15000  | ...
fdd_output_stage/income_statement_DEAL_HL_001.csv | 1200   | ...
fdd_output_stage/balance_sheet_DEAL_HL_001.csv   | 689    | ...
fdd_output_stage/ai_insights_DEAL_HL_001.csv     | 11500  | ...
```

### Step 4: Download and Verify
1. In Snowsight: Data → Stages → FDD_OUTPUT_STAGE
2. Download `database_tab_DEAL_HL_001.csv`
3. Open in Excel or text editor
4. Verify:
   - ✅ Header row has 60 columns
   - ✅ 29 data rows (one per account)
   - ✅ Period labels are "Jan-2023" through "Dec-2024"
   - ✅ Period values are numeric

---

## 🔧 Troubleshooting

### Problem 1: File Not Created

**Diagnosis:**
```sql
SELECT * FROM audit_log 
WHERE procedure_name = 'export_database_tab' 
ORDER BY start_time DESC LIMIT 1;
```

**Solution A:** If status = 'ERROR', check `error_message`  
**Solution B:** If no rows, procedure was never called (check parent procedure error)  
**Solution C:** If status = 'SUCCESS' but file missing, check stage permissions

### Problem 2: File is Empty or Has Wrong Structure

**Diagnosis:**
```sql
SELECT COUNT(*), MIN(deal_id), COUNT(DISTINCT account_number)
FROM v_database_tab_pivoted
WHERE deal_id = 'DEAL_HL_001';
```

**Expected:** 29 rows, deal_id = 'DEAL_HL_001', 29 unique accounts

**Solution:** If 0 rows, check:
- Trial balance data was loaded: `SELECT COUNT(*) FROM trial_balance_raw WHERE deal_id = 'DEAL_HL_001';`
- Account mappings exist: `SELECT COUNT(*) FROM account_mappings WHERE is_active = TRUE;`

### Problem 3: Procedure Fails Silently

**Diagnosis:**
```sql
-- Manually call the procedure
CALL export_database_tab('DEAL_HL_001');
```

Watch for error message in result.

**Common Errors:**
- `Invalid deal_id format` - Deal ID validation failed
- `SQL compilation error` - View or table doesn't exist
- `Stage not found` - Output stage missing
- `Insufficient privileges` - Role lacks permissions

---

## 🎯 Expected Behavior

When `run_complete_poc()` completes successfully:

1. **4 CSV files** should be created in `@fdd_output_stage`:
   - ✅ `database_tab_DEAL_HL_001.csv` (15 KB) - **CRITICAL FOR EXCEL**
   - ✅ `income_statement_DEAL_HL_001.csv` (1.2 KB)
   - ✅ `balance_sheet_DEAL_HL_001.csv` (689 B)
   - ✅ `ai_insights_DEAL_HL_001.csv` (11.5 KB)

2. **All files are uncompressed** (plain CSV, not .csv.gz)

3. **Database tab** contains:
   - 29 rows (one per account)
   - 60 columns (metadata + 48 period columns)
   - Proper headers
   - Numeric values for all periods

---

## 📥 Excel Import Instructions

Once the `database_tab_DEAL_HL_001.csv` is verified:

### Step 1: Download the File
```sql
-- Via Snowsight UI: Data → Stages → FDD_OUTPUT_STAGE → Download
-- OR via SnowSQL:
GET @fdd_output_stage/database_tab_DEAL_HL_001.csv file:///tmp/;
```

### Step 2: Import into Excel
1. Open your FDD Excel template
2. Go to **Database** tab
3. Delete existing data (if any)
4. Click: Data → From Text/CSV
5. Select `database_tab_DEAL_HL_001.csv`
6. Import with these settings:
   - Delimiter: Comma
   - Data type detection: Automatic
   - Text qualifier: Double quote

### Step 3: Verify SUMIF Formulas Work
1. Go to **Income Statement** tab
2. Check that SUMIF formulas populate with values
3. Example: Revenue row should show values for all 24 periods

---

## 🆘 Support

If the database tab CSV is still missing after running `verify_database_tab.sql`:

1. **Share the output** of the verification script
2. **Check audit log** for any error messages
3. **Manually test** the `export_database_tab()` procedure
4. **Verify view** has data: `SELECT COUNT(*) FROM v_database_tab_pivoted;`

---

## ✅ Success Criteria

The database tab CSV is working correctly when:

- ✅ File `database_tab_DEAL_HL_001.csv` exists in `@fdd_output_stage`
- ✅ File is uncompressed (plain CSV, not .gz)
- ✅ File has 30 rows (1 header + 29 accounts)
- ✅ File has 60 columns
- ✅ All 24 periods have labels and values
- ✅ Values match the source trial balance data
- ✅ Excel SUMIF formulas work when using this as lookup table

---

**Next Step:** Run `verify_database_tab.sql` in Snowsight and share the results!


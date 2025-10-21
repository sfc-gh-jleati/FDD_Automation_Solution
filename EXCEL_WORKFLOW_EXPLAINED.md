# Excel Integration Workflow - Complete Guide

## 🔄 The Complete Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     1️⃣ SNOWFLAKE (SQL)                          │
│                                                                  │
│  ┌──────────────┐                                               │
│  │ Trial Balance│──┐                                            │
│  │ Raw Data     │  │                                            │
│  └──────────────┘  │                                            │
│                    ▼                                            │
│  ┌─────────────────────────────┐                                │
│  │ v_database_tab_pivoted VIEW │                                │
│  │ (29 rows x 60 columns)      │                                │
│  │ - Account metadata          │                                │
│  │ - 24 period labels          │                                │
│  │ - 24 period values          │                                │
│  └─────────────────────────────┘                                │
│                    ▼                                            │
│  ┌─────────────────────────────┐                                │
│  │ export_database_tab()       │                                │
│  │ PROCEDURE                   │                                │
│  └─────────────────────────────┘                                │
│                    ▼                                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ @fdd_output_stage/database_tab_DEAL_HL_001.csv         │   │
│  │ - Uncompressed CSV file                                 │   │
│  │ - Ready for Excel import                                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              │ DOWNLOAD
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   2️⃣ LOCAL MACHINE                              │
│                                                                  │
│  📥 database_tab_DEAL_HL_001.csv (15 KB)                        │
│  📥 income_statement_DEAL_HL_001.csv (1.2 KB)                   │
│  📥 balance_sheet_DEAL_HL_001.csv (689 B)                       │
│  📥 ai_insights_DEAL_HL_001.csv (11.5 KB)                       │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              │ IMPORT
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  3️⃣ EXCEL (FDD Template)                        │
│                                                                  │
│  ┌──────────────────────┐                                       │
│  │ Database Tab         │ ← Import database_tab CSV             │
│  │ (Lookup Table)       │                                       │
│  └──────────────────────┘                                       │
│            ▲         ▲                                           │
│            │         │                                           │
│    SUMIF   │         │   SUMIF                                  │
│  references│         │ references                                │
│            │         │                                           │
│  ┌─────────┴─────┐   └──────────┬────────┐                     │
│  │ Income        │              │Balance  │                     │
│  │ Statement Tab │              │Sheet Tab│                     │
│  │               │              │         │                     │
│  │ =SUMIF(       │              │=SUMIF(  │                     │
│  │  Database!$E, │              │Database!│                     │
│  │  "Net Sales", │              │$E,      │                     │
│  │  Database!N)  │              │"Cash",  │                     │
│  │               │              │Database!│                     │
│  └───────────────┘              │N)       │                     │
│                                 └─────────┘                     │
│                                                                  │
│  ┌──────────────────────┐                                       │
│  │ AI Insights Tab      │ ← Import ai_insights CSV              │
│  └──────────────────────┘                                       │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Step-by-Step Instructions

### **STEP 1: Run in Snowsight** (SQL Queries)

```sql
USE ROLE fdd_admin_role;
USE DATABASE hl_fdd_poc;
USE SCHEMA fdd_schema;
USE WAREHOUSE fdd_wh;

-- Generate all outputs
CALL run_complete_poc();

-- Verify files were created
LIST @fdd_output_stage;
```

**Expected Output:**
```
fdd_output_stage/database_tab_DEAL_HL_001.csv      | 15000 | Oct 21 2025
fdd_output_stage/income_statement_DEAL_HL_001.csv | 1200  | Oct 21 2025
fdd_output_stage/balance_sheet_DEAL_HL_001.csv    | 689   | Oct 21 2025
fdd_output_stage/ai_insights_DEAL_HL_001.csv      | 11500 | Oct 21 2025
```

---

### **STEP 2: Download Files from Snowsight** (UI Navigation)

1. In Snowsight, navigate to:
   ```
   Data → Databases → HL_FDD_POC → FDD_SCHEMA → Stages → FDD_OUTPUT_STAGE
   ```

2. Click on each file and download:
   - ✅ `database_tab_DEAL_HL_001.csv`
   - ✅ `income_statement_DEAL_HL_001.csv`
   - ✅ `balance_sheet_DEAL_HL_001.csv`
   - ✅ `ai_insights_DEAL_HL_001.csv`

3. Save files to your computer (e.g., `Downloads/` folder)

---

### **STEP 3: Import into Excel** (Excel Application)

#### A. Import Database Tab (MOST CRITICAL)

1. Open your FDD Excel template: `FDD_PoC_Template_PRODUCTION_FINAL.xlsm`

2. Go to the **Database** tab

3. **Delete existing data** (if any):
   - Select all data rows
   - Press Delete

4. **Import CSV**:
   - Click: **Data → From Text/CSV**
   - Select: `database_tab_DEAL_HL_001.csv`
   - Click: **Import**
   
5. **Import Settings**:
   - File Origin: UTF-8
   - Delimiter: Comma
   - Data Type Detection: Based on entire dataset
   - Click: **Load**

6. **Verify Import**:
   - You should see **29 rows** of data (one per account)
   - You should see **60 columns**:
     - Columns A-L: Metadata (deal_id, account_number, account_name, etc.)
     - Columns M-AJ: Period labels (PERIOD_01_LABEL through PERIOD_24_LABEL)
     - Columns AK-BH: Period values (PERIOD_01 through PERIOD_24)

#### B. Import Income Statement Structure

1. Go to the **Income Statement** tab
2. Import `income_statement_DEAL_HL_001.csv` into the structure section
3. This file has the row labels and formatting JSON

#### C. Import Balance Sheet Structure

1. Go to the **Balance Sheet** tab
2. Import `balance_sheet_DEAL_HL_001.csv` into the structure section
3. This file has the row labels and formatting JSON

#### D. Import AI Insights

1. Go to the **AI Insights** tab
2. Import `ai_insights_DEAL_HL_001.csv`
3. This file has the variance analysis and insights

---

### **STEP 4: Verify Excel Formulas Work** (Excel)

#### Income Statement Tab:

The Income Statement should have formulas like:

```excel
=SUMIF(Database!$E:$E, "Net Sales", Database!N:N)
```

**Translation:**
- `Database!$E:$E` = Look in column E (ACCOUNT_NAME) of Database tab
- `"Net Sales"` = Find rows where account name equals "Net Sales"
- `Database!N:N` = Sum the values in column N (PERIOD_01)

**Verify:**
1. Click on a cell in the Income Statement that should show revenue
2. Check the formula bar - you should see a SUMIF formula
3. The cell should now display a **number** (not #REF! or #N/A)
4. If you see a value, the import worked! ✅

#### Balance Sheet Tab:

Similar formulas like:

```excel
=SUMIF(Database!$E:$E, "Cash - Operating", Database!N:N)
```

**Verify:**
1. Click on a cell showing Cash
2. Formula bar should show SUMIF referencing Database tab
3. Cell should display a numeric value ✅

---

## 🔍 Understanding the Database Tab Structure

### Column Layout (60 columns total):

**Columns A-L: Metadata (12 columns)**
```
A: DEAL_ID              = "DEAL_HL_001"
B: DEAL_NAME            = "Houlihan Lokey"  
C: ENTITY               = "ABC Corp"
D: ACCOUNT_NUMBER       = "1000"
E: ACCOUNT_NAME         = "Cash - Operating"  ← SUMIF looks here
F: UNIQUE_ID            = "DEAL_HL_001_ABC_1000"
G: MAPPING_LEVEL_1      = "Assets"
H: MAPPING_LEVEL_2      = "Current Assets"
I: MAPPING_LEVEL_3      = NULL
J: STATEMENT_TYPE       = "balance_sheet"
K: SORT_ORDER_L1        = 1
L: SORT_ORDER_L2        = 1
```

**Columns M-AJ: Period Labels (24 columns)**
```
M: PERIOD_01_LABEL      = "Jan-2023"
N: PERIOD_02_LABEL      = "Feb-2023"
...
AJ: PERIOD_24_LABEL     = "Dec-2024"
```

**Columns AK-BH: Period Values (24 columns)**
```
AK: PERIOD_01           = 161563.29  ← SUMIF sums this
AL: PERIOD_02           = 174839.41
...
BH: PERIOD_24           = 298475.12
```

---

## 🎯 Example: How SUMIF Works

### Excel Formula in Income Statement:
```excel
=SUMIF(Database!$E:$E, "Net Sales", Database!AK:AK)
```

### What This Does:
1. **Search Range**: `Database!$E:$E` (Column E = ACCOUNT_NAME)
2. **Search Criteria**: `"Net Sales"`
3. **Sum Range**: `Database!AK:AK` (Column AK = PERIOD_01 values)

### Result:
- Finds all rows in Database tab where ACCOUNT_NAME = "Net Sales"
- Sums the corresponding PERIOD_01 values
- Returns the total Net Sales for January 2023

---

## 🚨 Common Issues

### Issue 1: #REF! Error in Excel

**Cause:** Database tab is empty or not imported

**Solution:**
1. Verify `database_tab_DEAL_HL_001.csv` exists in Snowflake stage
2. Download and import it into Excel Database tab
3. Ensure data starts at row 2 (row 1 is headers)

---

### Issue 2: #N/A Error in Excel

**Cause:** Account name mismatch in SUMIF formula

**Solution:**
1. Check the exact account name in Database tab column E
2. Ensure formula uses the exact same spelling/capitalization
3. Example: "Net Sales" ≠ "net sales" ≠ "Net sales"

---

### Issue 3: All Values Show 0

**Cause:** SUMIF range is referencing wrong column

**Solution:**
1. Verify the sum range points to a value column (AK:BH)
2. Don't reference label columns (M:AJ)
3. Example: `Database!AK:AK` is correct, `Database!M:M` is wrong

---

### Issue 4: Database Tab CSV Missing in Snowflake

**Cause:** Export procedure failed or wasn't called

**Solution:**
Run this in Snowsight:
```sql
-- Check if view has data
SELECT COUNT(*) FROM v_database_tab_pivoted WHERE deal_id = 'DEAL_HL_001';
-- Should return 29

-- Check audit log for errors
SELECT * FROM audit_log 
WHERE procedure_name = 'export_database_tab' 
ORDER BY start_time DESC LIMIT 1;

-- Manually export
CALL export_database_tab('DEAL_HL_001');

-- Verify file created
LIST @fdd_output_stage;
```

---

## ✅ Success Checklist

### In Snowsight (SQL):
- [x] `CALL run_complete_poc()` returns SUCCESS
- [x] `LIST @fdd_output_stage` shows 4 CSV files
- [x] `database_tab_DEAL_HL_001.csv` exists (most critical!)
- [x] All files are uncompressed (.csv not .csv.gz)

### In Excel:
- [x] Database tab has 29 rows of data
- [x] Database tab has 60 columns
- [x] Column E shows account names
- [x] Columns AK-BH show numeric values
- [x] Income Statement formulas show numbers (not errors)
- [x] Balance Sheet formulas show numbers (not errors)
- [x] Values match the source trial balance data

---

## 🎓 Key Takeaway

**Two Separate Systems:**

1. **Snowflake** (SQL) = Data preparation and export
   - Runs: `CALL run_complete_poc()`
   - Outputs: 4 CSV files

2. **Excel** (Formulas) = Data consumption and analysis
   - Imports: 4 CSV files
   - Uses: SUMIF formulas to reference imported data

**The SUMIF formula never runs in Snowflake - it only runs in Excel after you import the CSV files!**

---

## 📞 Next Steps

1. **Run this in Snowsight** to verify all files exist:
   ```
   @verify_output_files_simple.sql
   ```

2. **If database_tab CSV is missing**, let me know the error message from the audit log

3. **If all files exist**, download them and import into Excel

4. **If Excel formulas don't work**, share a screenshot of the Database tab

---

**Remember:** Snowflake creates the data → Excel consumes the data → Excel formulas work! 🚀


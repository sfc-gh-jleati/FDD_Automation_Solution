# Quick Start Guide - FDD Automation

**Get up and running in 15 minutes**

---

## ⚡ Rapid Deployment

### Step 1: Deploy Core Solution (5 min)

1. Open [Snowsight](https://app.snowflake.com/)
2. Create new worksheet
3. Copy entire contents of: `sql/deploy_snowsight.sql`
4. Paste and click **"Run All"**
5. Wait ~2 minutes

✅ **Expected:** "✓ DEPLOYMENT SUCCESSFUL"

### Step 2: Upload Sample Data (2 min)

**Via Snowsight UI:**
1. Navigate to: Data → HL_FDD_POC → TRIAL_BALANCE → Stages → FDD_INPUT_STAGE
2. Click "+ Files"
3. Upload both files from `examples/` folder

**Via SnowSQL:**
```bash
PUT file:///path/to/01_sample_trial_balance_24mo.csv @fdd_input_stage;
PUT file:///path/to/02_sample_account_mappings_24mo.csv @fdd_input_stage;
```

### Step 3: Run & Verify (1 min)

```sql
USE DATABASE HL_FDD_POC;
USE SCHEMA TRIAL_BALANCE;

CALL run_complete_poc();
LIST @fdd_output_stage;
```

✅ **Expected:** 4 CSV files created:
- `database_tab_DEAL_HL_001.csv` - Pivoted data for Excel SUMIF formulas
- `income_statement_DEAL_HL_001.csv` - IS structure
- `balance_sheet_DEAL_HL_001.csv` - BS structure  
- `ai_insights_DEAL_HL_001.csv` - **AI-generated variance analysis** 🆕

---

## 📥 Excel Integration (5 min)

1. **Download** files from Snowsight:
   - Navigate to: Data → HL_FDD_POC → TRIAL_BALANCE → Stages → FDD_OUTPUT_STAGE
   - Download: `database_tab_DEAL_HL_001.csv`
   - Download: `income_statement_DEAL_HL_001.csv`
   - Download: `balance_sheet_DEAL_HL_001.csv`
   - Download: `ai_insights_DEAL_HL_001.csv` 🆕

2. **Import into Excel:**
   - Open your FDD Excel template
   - Database tab: Import `database_tab_DEAL_HL_001.csv`
   - Income Statement: Import `income_statement_DEAL_HL_001.csv`
   - Balance Sheet: Import `balance_sheet_DEAL_HL_001.csv`
   - **AI Insights tab:** Import `ai_insights_DEAL_HL_001.csv` (review variance explanations) 🆕

3. **Verify:**
   - Excel SUMIF formulas should populate with data ✅

---

## 🎨 Optional: Admin Dashboard (10 min)

### Deploy Streamlit Dashboard

1. Upload files to @streamlit_stage via Snowsight UI
2. Run: `streamlit/deploy_streamlit.sql`
3. Access: Projects → Streamlit → FDD Automation Admin Dashboard

**See:** `streamlit/SNOWSIGHT_DEPLOYMENT_GUIDE.md` for detailed steps

---

## ✅ Success Checklist

After deployment, verify:
- [ ] 41 database objects created (14 tables, 5 views, 16 procedures, 6 functions)
- [ ] Sample data loaded (696 TB rows, 29 mappings)
- [ ] **4 CSV files generated** in @fdd_output_stage 🆕
- [ ] database_tab CSV is 20 KB with 60 columns
- [ ] **ai_insights CSV contains 15+ AI-generated variance explanations** 🆕
- [ ] Excel import works and SUMIF formulas populate

---

## 📚 Next Steps

- **Learn More:** See `README.md` for complete overview
- **Deployment Details:** See `docs/DEPLOYMENT_GUIDE.md`
- **Daily Operations:** See `docs/OPERATIONS_MANUAL.md`
- **Technical Details:** See `HANDOFF.md`

---

## 🆘 Troubleshooting

**Problem:** database_tab CSV is empty  
**Solution:**
```sql
SELECT COUNT(*) FROM account_mappings WHERE is_active = TRUE;
-- Should return 29
-- If 0: CALL load_account_mappings();
```

**Problem:** No CSV files generated  
**Solution:** Check audit log for errors
```sql
SELECT * FROM audit_log WHERE status = 'ERROR' ORDER BY start_time DESC LIMIT 5;
```

---

**For complete documentation, see `README.md`** 🚀


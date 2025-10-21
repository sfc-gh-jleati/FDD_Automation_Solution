"""
Houlihan Lokey FDD Automation - Admin Dashboard
=================================================
Comprehensive admin interface for monitoring, configuration, and management
of the FDD automation solution.

Features:
- Real-time monitoring and observability
- Configuration management
- AI threshold tuning
- Data quality monitoring
- Stage file management
- Performance analytics
- Audit log viewer
- Error diagnostics
"""

import streamlit as st
import pandas as pd
from datetime import datetime, timedelta
import plotly.express as px
import plotly.graph_objects as go

# Initialize Snowflake session
session = st.connection('snowflake').session()

# Page configuration
st.set_page_config(
    page_title="FDD Automation Admin",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for professional styling
st.markdown("""
<style>
    .main-header {
        font-size: 2.5rem;
        font-weight: 700;
        color: #1f77b4;
        margin-bottom: 0.5rem;
    }
    .section-header {
        font-size: 1.5rem;
        font-weight: 600;
        color: #2c3e50;
        margin-top: 1.5rem;
        margin-bottom: 1rem;
        border-bottom: 2px solid #3498db;
        padding-bottom: 0.5rem;
    }
    .metric-card {
        background-color: #f8f9fa;
        border-radius: 8px;
        padding: 1rem;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .success-badge {
        background-color: #28a745;
        color: white;
        padding: 0.25rem 0.75rem;
        border-radius: 4px;
        font-weight: 600;
    }
    .error-badge {
        background-color: #dc3545;
        color: white;
        padding: 0.25rem 0.75rem;
        border-radius: 4px;
        font-weight: 600;
    }
    .warning-badge {
        background-color: #ffc107;
        color: black;
        padding: 0.25rem 0.75rem;
        border-radius: 4px;
        font-weight: 600;
    }
</style>
""", unsafe_allow_html=True)

# =====================================================
# SIDEBAR NAVIGATION
# =====================================================

st.sidebar.markdown("# 🏢 FDD Admin Dashboard")
st.sidebar.markdown("---")

page = st.sidebar.radio(
    "Navigation",
    [
        "🏠 Overview",
        "📊 Monitoring & Performance",
        "⚙️ Configuration Management",
        "🎯 AI Threshold Tuning",
        "✅ Data Quality Dashboard",
        "📁 Stage File Management",
        "📜 Audit Log Viewer",
        "🚨 Error Diagnostics",
        "🧪 System Health Check"
    ]
)

st.sidebar.markdown("---")
st.sidebar.markdown("### Quick Actions")

if st.sidebar.button("🔄 Refresh Data", use_container_width=True):
    st.cache_data.clear()
    st.rerun()

if st.sidebar.button("📊 Run Health Check", use_container_width=True):
    st.session_state['run_health_check'] = True

st.sidebar.markdown("---")
st.sidebar.info("**Version:** 1.0.0  \n**Database:** HL_FDD_POC  \n**Schema:** TRIAL_BALANCE")

# =====================================================
# PAGE: OVERVIEW
# =====================================================

if page == "🏠 Overview":
    st.markdown('<p class="main-header">📊 FDD Automation Admin Dashboard</p>', unsafe_allow_html=True)
    st.markdown("Welcome to the Houlihan Lokey Financial Due Diligence Automation Admin Portal")
    
    # Key Metrics Row
    col1, col2, col3, col4 = st.columns(4)
    
    # Get quick stats
    total_deals = session.sql("SELECT COUNT(DISTINCT deal_id) FROM trial_balance_raw").collect()[0][0]
    total_tb_rows = session.sql("SELECT COUNT(*) FROM trial_balance_raw").collect()[0][0]
    total_insights = session.sql("SELECT COUNT(*) FROM ai_insights").collect()[0][0]
    
    recent_errors = session.sql("""
        SELECT COUNT(*) 
        FROM audit_log 
        WHERE status = 'ERROR' 
        AND start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
    """).collect()[0][0]
    
    with col1:
        st.metric("Total Deals", total_deals, delta=None)
    with col2:
        st.metric("Trial Balance Rows", f"{total_tb_rows:,}", delta=None)
    with col3:
        st.metric("AI Insights Generated", total_insights, delta=None)
    with col4:
        st.metric("Errors (7 days)", recent_errors, delta=None, delta_color="inverse")
    
    st.markdown("---")
    
    # Recent Activity
    st.markdown('<p class="section-header">Recent Activity (Last 24 Hours)</p>', unsafe_allow_html=True)
    
    recent_activity = session.sql("""
        SELECT 
            TO_CHAR(start_time, 'HH24:MI:SS') AS time,
            procedure_name,
            deal_id,
            status,
            duration_seconds,
            rows_affected,
            SUBSTRING(message, 1, 100) AS message
        FROM audit_log
        WHERE start_time > DATEADD(hour, -24, CURRENT_TIMESTAMP())
        ORDER BY start_time DESC
        LIMIT 20
    """).to_pandas()
    
    if not recent_activity.empty:
        st.dataframe(recent_activity, use_container_width=True, hide_index=True)
    else:
        st.info("No activity in the last 24 hours")
    
    # System Health Summary
    st.markdown('<p class="section-header">System Health Summary</p>', unsafe_allow_html=True)
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("**📈 Performance Metrics**")
        avg_duration = session.sql("""
            SELECT AVG(duration_seconds) 
            FROM audit_log 
            WHERE procedure_name = 'generate_fdd_schedules'
            AND start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
        """).collect()[0][0]
        
        if avg_duration:
            st.metric("Avg Schedule Generation Time", f"{avg_duration:.1f}s")
        else:
            st.info("No recent schedule generations")
    
    with col2:
        st.markdown("**✅ Data Quality**")
        failed_checks = session.sql("""
            SELECT COUNT(*) 
            FROM data_quality_checks 
            WHERE passed = FALSE 
            AND created_at > DATEADD(day, -7, CURRENT_TIMESTAMP())
        """).collect()[0][0]
        
        st.metric("Failed Quality Checks (7 days)", failed_checks, delta=None, delta_color="inverse")

# =====================================================
# PAGE: MONITORING & PERFORMANCE
# =====================================================

elif page == "📊 Monitoring & Performance":
    st.markdown('<p class="main-header">📊 Monitoring & Performance</p>', unsafe_allow_html=True)
    
    # Time range selector
    time_range = st.selectbox("Time Range", ["Last Hour", "Last 24 Hours", "Last 7 Days", "Last 30 Days", "All Time"])
    
    hours_map = {
        "Last Hour": 1,
        "Last 24 Hours": 24,
        "Last 7 Days": 168,
        "Last 30 Days": 720,
        "All Time": 999999
    }
    
    hours = hours_map[time_range]
    
    # Procedure execution stats
    st.markdown('<p class="section-header">Procedure Execution Statistics</p>', unsafe_allow_html=True)
    
    proc_stats = session.sql(f"""
        SELECT 
            procedure_name,
            COUNT(*) AS total_executions,
            SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) AS successful,
            SUM(CASE WHEN status = 'ERROR' THEN 1 ELSE 0 END) AS failed,
            ROUND(AVG(duration_seconds), 2) AS avg_duration_sec,
            ROUND(MAX(duration_seconds), 2) AS max_duration_sec,
            SUM(COALESCE(rows_affected, 0)) AS total_rows_affected
        FROM audit_log
        WHERE start_time > DATEADD(hour, -{hours}, CURRENT_TIMESTAMP())
        GROUP BY procedure_name
        ORDER BY total_executions DESC
    """).to_pandas()
    
    if not proc_stats.empty:
        st.dataframe(proc_stats, use_container_width=True, hide_index=True)
        
        # Success rate chart
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown("**Success Rate by Procedure**")
            proc_stats['success_rate'] = (proc_stats['SUCCESSFUL'] / proc_stats['TOTAL_EXECUTIONS'] * 100).round(1)
            fig = px.bar(proc_stats, x='PROCEDURE_NAME', y='success_rate', 
                        title='Success Rate (%)',
                        labels={'success_rate': 'Success Rate (%)', 'PROCEDURE_NAME': 'Procedure'},
                        color='success_rate',
                        color_continuous_scale=['red', 'yellow', 'green'])
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            st.markdown("**Average Execution Time**")
            fig = px.bar(proc_stats, x='PROCEDURE_NAME', y='AVG_DURATION_SEC',
                        title='Average Duration (seconds)',
                        labels={'AVG_DURATION_SEC': 'Duration (s)', 'PROCEDURE_NAME': 'Procedure'},
                        color='AVG_DURATION_SEC',
                        color_continuous_scale='Blues')
            st.plotly_chart(fig, use_container_width=True)
    else:
        st.info(f"No procedure executions in the {time_range.lower()}")
    
    # Performance trend over time
    st.markdown('<p class="section-header">Performance Trend</p>', unsafe_allow_html=True)
    
    trend_data = session.sql(f"""
        SELECT 
            DATE_TRUNC('hour', start_time) AS hour,
            procedure_name,
            AVG(duration_seconds) AS avg_duration
        FROM audit_log
        WHERE start_time > DATEADD(hour, -{hours}, CURRENT_TIMESTAMP())
        AND procedure_name IN ('generate_fdd_schedules', 'run_complete_poc', 'load_trial_balance')
        GROUP BY 1, 2
        ORDER BY 1, 2
    """).to_pandas()
    
    if not trend_data.empty:
        fig = px.line(trend_data, x='HOUR', y='AVG_DURATION', color='PROCEDURE_NAME',
                     title='Execution Time Trend',
                     labels={'AVG_DURATION': 'Duration (seconds)', 'HOUR': 'Time'})
        st.plotly_chart(fig, use_container_width=True)

# =====================================================
# PAGE: CONFIGURATION MANAGEMENT
# =====================================================

elif page == "⚙️ Configuration Management":
    st.markdown('<p class="main-header">⚙️ Configuration Management</p>', unsafe_allow_html=True)
    
    # Load current configuration
    config_df = session.sql("""
        SELECT 
            config_key,
            config_value::VARCHAR AS config_value,
            description,
            is_sensitive,
            updated_at
        FROM system_config
        ORDER BY config_key
    """).to_pandas()
    
    # Configuration categories
    st.markdown('<p class="section-header">System Configuration</p>', unsafe_allow_html=True)
    
    category = st.selectbox("Filter by Category", [
        "All",
        "Data Validation",
        "AI Settings",
        "Warehouse Settings",
        "File Settings",
        "Retention Policies",
        "Other"
    ])
    
    # Filter configurations by category
    if category != "All":
        category_keywords = {
            "Data Validation": ["tolerance", "threshold", "variance", "error_rate"],
            "AI Settings": ["ai_", "max_ai"],
            "Warehouse Settings": ["warehouse", "suspend"],
            "File Settings": ["stage", "file_format"],
            "Retention Policies": ["retention"],
        }
        keywords = category_keywords.get(category, [])
        if keywords:
            mask = config_df['CONFIG_KEY'].str.contains('|'.join(keywords), case=False)
            filtered_df = config_df[mask]
        else:
            filtered_df = config_df
    else:
        filtered_df = config_df
    
    # Display configuration table
    st.dataframe(filtered_df, use_container_width=True, hide_index=True)
    
    # Configuration Editor
    st.markdown('<p class="section-header">Update Configuration</p>', unsafe_allow_html=True)
    
    col1, col2 = st.columns([2, 1])
    
    with col1:
        selected_config = st.selectbox(
            "Select Configuration to Update",
            options=config_df['CONFIG_KEY'].tolist()
        )
        
        # Get current value and description
        current_row = config_df[config_df['CONFIG_KEY'] == selected_config].iloc[0]
        current_value = current_row['CONFIG_VALUE']
        description = current_row['DESCRIPTION']
        
        st.info(f"**Description:** {description}")
        st.markdown(f"**Current Value:** `{current_value}`")
        
        new_value = st.text_input("New Value", value=current_value)
        
        if st.button("💾 Update Configuration", type="primary"):
            try:
                # Determine the data type and convert appropriately
                if selected_config in ['enable_row_level_security']:
                    # Boolean
                    value_sql = f"TO_VARIANT({new_value.lower()})"
                elif selected_config in ['ai_model_variance', 'ai_model_trends', 'warehouse_size_default', 
                                        'input_stage_name', 'output_stage_name', 'default_file_format',
                                        'deal_id_validation_regex', 'environment', 'schema_version']:
                    # String
                    value_sql = f"TO_VARIANT('{new_value}')"
                else:
                    # Number
                    value_sql = f"TO_VARIANT({new_value})"
                
                update_sql = f"""
                    UPDATE system_config
                    SET config_value = {value_sql},
                        updated_at = CURRENT_TIMESTAMP()
                    WHERE config_key = '{selected_config}'
                """
                session.sql(update_sql).collect()
                st.success(f"✅ Configuration '{selected_config}' updated to: {new_value}")
                st.cache_data.clear()
                st.rerun()
            except Exception as e:
                st.error(f"❌ Error updating configuration: {str(e)}")
    
    with col2:
        st.markdown("### Quick Presets")
        
        if st.button("🔧 Development Settings"):
            st.info("Apply development-friendly settings (lower thresholds, more logging)")
        
        if st.button("🚀 Production Settings"):
            st.info("Apply production-optimized settings")
        
        if st.button("🔄 Reset to Defaults"):
            st.warning("This will reset all configuration to default values")

# =====================================================
# PAGE: AI THRESHOLD TUNING
# =====================================================

elif page == "🎯 AI Threshold Tuning":
    st.markdown('<p class="main-header">🎯 AI Variance Threshold Tuning</p>', unsafe_allow_html=True)
    
    st.markdown("""
    Fine-tune AI insight generation thresholds to optimize the relevance and volume of insights generated.
    Adjusting these parameters affects which variances trigger AI analysis.
    """)
    
    # Load current AI settings
    ai_config = session.sql("""
        SELECT config_key, config_value::VARCHAR AS value, description
        FROM system_config
        WHERE config_key LIKE 'ai_%' OR config_key LIKE '%variance%' OR config_key LIKE '%threshold%'
        ORDER BY config_key
    """).to_pandas()
    
    # Current Settings Display
    st.markdown('<p class="section-header">Current AI Settings</p>', unsafe_allow_html=True)
    st.dataframe(ai_config, use_container_width=True, hide_index=True)
    
    # Threshold Tuner
    st.markdown('<p class="section-header">Threshold Configuration</p>', unsafe_allow_html=True)
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("### Variance Detection")
        
        current_threshold = float(session.sql(
            "SELECT config_value::FLOAT FROM system_config WHERE config_key = 'variance_threshold_pct'"
        ).collect()[0][0])
        
        new_threshold = st.slider(
            "Variance Threshold (%)",
            min_value=0.05,
            max_value=1.00,
            value=current_threshold,
            step=0.05,
            help="Minimum percentage change to flag as variance. Lower = more insights"
        )
        
        current_min_amount = float(session.sql(
            "SELECT config_value::FLOAT FROM system_config WHERE config_key = 'min_variance_amount'"
        ).collect()[0][0])
        
        new_min_amount = st.number_input(
            "Minimum Variance Amount ($)",
            min_value=0.0,
            max_value=100000.0,
            value=current_min_amount,
            step=1000.0,
            help="Minimum dollar amount to trigger variance analysis"
        )
        
        if st.button("💾 Save Variance Settings", type="primary"):
            try:
                session.sql(f"""
                    UPDATE system_config
                    SET config_value = TO_VARIANT({new_threshold}),
                        updated_at = CURRENT_TIMESTAMP()
                    WHERE config_key = 'variance_threshold_pct'
                """).collect()
                
                session.sql(f"""
                    UPDATE system_config
                    SET config_value = TO_VARIANT({new_min_amount}),
                        updated_at = CURRENT_TIMESTAMP()
                    WHERE config_key = 'min_variance_amount'
                """).collect()
                
                st.success(f"✅ Thresholds updated! Variance: {new_threshold*100:.0f}%, Min Amount: ${new_min_amount:,.2f}")
                st.cache_data.clear()
            except Exception as e:
                st.error(f"❌ Error: {str(e)}")
    
    with col2:
        st.markdown("### AI Model Configuration")
        
        current_model = session.sql(
            "SELECT config_value::VARCHAR FROM system_config WHERE config_key = 'ai_model_variance'"
        ).collect()[0][0].strip('"')
        
        new_model = st.selectbox(
            "AI Model for Variance Analysis",
            ["claude-4-sonnet", "claude-3.5-sonnet", "mistral-large", "llama3-70b"],
            index=["claude-4-sonnet", "claude-3.5-sonnet", "mistral-large", "llama3-70b"].index(current_model) if current_model in ["claude-4-sonnet", "claude-3.5-sonnet", "mistral-large", "llama3-70b"] else 0,
            help="Select the Snowflake Cortex model for AI insights"
        )
        
        current_max_insights = int(session.sql(
            "SELECT config_value::INT FROM system_config WHERE config_key = 'max_ai_insights'"
        ).collect()[0][0])
        
        new_max_insights = st.number_input(
            "Maximum AI Insights per Deal",
            min_value=5,
            max_value=50,
            value=current_max_insights,
            step=5,
            help="Limit the number of AI insights to control costs"
        )
        
        if st.button("💾 Save AI Model Settings", type="primary"):
            try:
                session.sql(f"""
                    UPDATE system_config
                    SET config_value = TO_VARIANT('"{new_model}"'),
                        updated_at = CURRENT_TIMESTAMP()
                    WHERE config_key = 'ai_model_variance'
                """).collect()
                
                session.sql(f"""
                    UPDATE system_config
                    SET config_value = TO_VARIANT({new_max_insights}),
                        updated_at = CURRENT_TIMESTAMP()
                    WHERE config_key = 'max_ai_insights'
                """).collect()
                
                st.success(f"✅ AI settings updated! Model: {new_model}, Max Insights: {new_max_insights}")
                st.cache_data.clear()
            except Exception as e:
                st.error(f"❌ Error: {str(e)}")
    
    # Impact Analysis
    st.markdown('<p class="section-header">Threshold Impact Analysis</p>', unsafe_allow_html=True)
    
    st.info("""
    **Preview how changing thresholds would affect insight generation:**
    - Lower thresholds = More insights (higher cost, more detail)
    - Higher thresholds = Fewer insights (lower cost, high-impact only)
    """)
    
    test_threshold = st.slider("Test Threshold (%)", 0.05, 1.0, new_threshold, 0.05)
    test_min_amount = st.number_input("Test Min Amount ($)", 0.0, 100000.0, new_min_amount, 1000.0)
    
    if st.button("📊 Preview Impact"):
        impact_query = f"""
            WITH variances AS (
                SELECT 
                    t1.account_name,
                    t1.period_date,
                    t1.amount_for_display AS current_amount,
                    LAG(t1.amount_for_display) OVER (PARTITION BY t1.account_number ORDER BY t1.period_date) AS prior_amount,
                    ABS(t1.amount_for_display - prior_amount) AS variance_amount,
                    CASE 
                        WHEN prior_amount = 0 THEN NULL
                        ELSE ABS((t1.amount_for_display - prior_amount) / NULLIF(prior_amount, 0))
                    END AS variance_pct
                FROM v_trial_balance_for_schedules t1
            )
            SELECT 
                COUNT(*) AS total_variances,
                COUNT(CASE WHEN ABS(variance_pct) >= {test_threshold} AND ABS(variance_amount) >= {test_min_amount} THEN 1 END) AS insights_that_would_generate,
                ROUND(COUNT(CASE WHEN ABS(variance_pct) >= {test_threshold} AND ABS(variance_amount) >= {test_min_amount} THEN 1 END) * 100.0 / COUNT(*), 2) AS pct_of_total
            FROM variances
            WHERE variance_pct IS NOT NULL
        """
        
        impact_result = session.sql(impact_query).to_pandas()
        
        col1, col2, col3 = st.columns(3)
        with col1:
            st.metric("Total Variances", f"{impact_result['TOTAL_VARIANCES'][0]:,}")
        with col2:
            st.metric("Insights Generated", f"{impact_result['INSIGHTS_THAT_WOULD_GENERATE'][0]:,}")
        with col3:
            st.metric("% of Total", f"{impact_result['PCT_OF_TOTAL'][0]:.1f}%")

# =====================================================
# PAGE: DATA QUALITY DASHBOARD
# =====================================================

elif page == "✅ Data Quality Dashboard":
    st.markdown('<p class="main-header">✅ Data Quality Dashboard</p>', unsafe_allow_html=True)
    
    # Quality Overview
    st.markdown('<p class="section-header">Quality Check Summary</p>', unsafe_allow_html=True)
    
    quality_summary = session.sql("""
        SELECT 
            check_type,
            COUNT(*) AS total_checks,
            SUM(CASE WHEN passed = TRUE THEN 1 ELSE 0 END) AS passed,
            SUM(CASE WHEN passed = FALSE THEN 1 ELSE 0 END) AS failed,
            ROUND(SUM(CASE WHEN passed = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS pass_rate
        FROM data_quality_checks
        GROUP BY check_type
        ORDER BY check_type
    """).to_pandas()
    
    if not quality_summary.empty:
        col1, col2, col3 = st.columns(3)
        
        total_checks = quality_summary['TOTAL_CHECKS'].sum()
        total_passed = quality_summary['PASSED'].sum()
        total_failed = quality_summary['FAILED'].sum()
        
        with col1:
            st.metric("Total Quality Checks", total_checks)
        with col2:
            st.metric("Passed", total_passed, delta=None)
        with col3:
            st.metric("Failed", total_failed, delta=None, delta_color="inverse")
        
        st.dataframe(quality_summary, use_container_width=True, hide_index=True)
        
        # Quality by severity
        severity_data = session.sql("""
            SELECT 
                severity,
                COUNT(*) AS count
            FROM data_quality_checks
            WHERE passed = FALSE
            GROUP BY severity
            ORDER BY CASE severity WHEN 'ERROR' THEN 1 WHEN 'WARNING' THEN 2 ELSE 3 END
        """).to_pandas()
        
        if not severity_data.empty:
            fig = px.pie(severity_data, values='COUNT', names='SEVERITY',
                        title='Failed Checks by Severity',
                        color='SEVERITY',
                        color_discrete_map={'ERROR': 'red', 'WARNING': 'orange', 'INFO': 'blue'})
            st.plotly_chart(fig, use_container_width=True)
    
    # Recent Failed Checks
    st.markdown('<p class="section-header">Recent Failed Checks</p>', unsafe_allow_html=True)
    
    failed_checks = session.sql("""
        SELECT 
            deal_id,
            check_name,
            check_type,
            severity,
            message,
            TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI:SS') AS checked_at
        FROM data_quality_checks
        WHERE passed = FALSE
        ORDER BY created_at DESC
        LIMIT 50
    """).to_pandas()
    
    if not failed_checks.empty:
        st.dataframe(failed_checks, use_container_width=True, hide_index=True)
    else:
        st.success("✅ No failed quality checks! All validations passing.")

# =====================================================
# PAGE: STAGE FILE MANAGEMENT
# =====================================================

elif page == "📁 Stage File Management":
    st.markdown('<p class="main-header">📁 Stage File Management</p>', unsafe_allow_html=True)
    
    # Stage selector
    stage_name = st.selectbox("Select Stage", ["fdd_input_stage", "fdd_output_stage"])
    
    # List files in stage
    st.markdown(f'<p class="section-header">Files in @{stage_name}</p>', unsafe_allow_html=True)
    
    try:
        files_query = f"LIST @{stage_name}"
        files_df = session.sql(files_query).to_pandas()
        
        if not files_df.empty:
            # Format file sizes
            files_df['size_kb'] = (files_df['size'] / 1024).round(2)
            files_df['size_mb'] = (files_df['size'] / 1024 / 1024).round(2)
            
            # Display file list
            st.dataframe(files_df[['name', 'size', 'size_kb', 'last_modified']], 
                        use_container_width=True, hide_index=True)
            
            # Statistics
            col1, col2, col3 = st.columns(3)
            with col1:
                st.metric("Total Files", len(files_df))
            with col2:
                st.metric("Total Size (MB)", f"{files_df['size_mb'].sum():.2f}")
            with col3:
                st.metric("Avg File Size (KB)", f"{files_df['size_kb'].mean():.2f}")
            
            # File Management Actions
            st.markdown('<p class="section-header">File Management</p>', unsafe_allow_html=True)
            
            col1, col2 = st.columns([2, 1])
            
            with col1:
                file_to_remove = st.selectbox("Select File to Remove", files_df['name'].tolist())
            
            with col2:
                st.markdown("##")  # Spacing
                if st.button("🗑️ Remove File", type="secondary"):
                    try:
                        session.sql(f"REMOVE @{stage_name} PATTERN='{file_to_remove.split('/')[-1]}'").collect()
                        st.success(f"✅ File removed: {file_to_remove}")
                        st.cache_data.clear()
                        st.rerun()
                    except Exception as e:
                        st.error(f"❌ Error: {str(e)}")
            
            # Bulk cleanup
            st.markdown("### Bulk Cleanup")
            
            days_old = st.number_input("Remove files older than (days)", min_value=1, max_value=365, value=30)
            
            if st.button("🗑️ Remove Old Files", type="secondary"):
                st.warning(f"This will remove all files in @{stage_name} older than {days_old} days")
                if st.button("⚠️ Confirm Deletion"):
                    try:
                        # Note: Snowflake doesn't support time-based REMOVE, so we'd need to query and remove individually
                        st.info("Bulk cleanup would be implemented here with file iteration")
                    except Exception as e:
                        st.error(f"❌ Error: {str(e)}")
        
        else:
            st.info(f"No files found in @{stage_name}")
    
    except Exception as e:
        st.error(f"❌ Error listing files: {str(e)}")

# =====================================================
# PAGE: AUDIT LOG VIEWER
# =====================================================

elif page == "📜 Audit Log Viewer":
    st.markdown('<p class="main-header">📜 Audit Log Viewer</p>', unsafe_allow_html=True)
    
    # Filters
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        time_filter = st.selectbox("Time Range", ["Last Hour", "Last 24 Hours", "Last 7 Days", "Last 30 Days", "All"])
    
    with col2:
        status_filter = st.selectbox("Status", ["All", "SUCCESS", "ERROR", "WARNING", "STARTED"])
    
    with col3:
        # Get unique procedures
        procedures = session.sql("SELECT DISTINCT procedure_name FROM audit_log ORDER BY 1").to_pandas()
        procedure_filter = st.selectbox("Procedure", ["All"] + procedures['PROCEDURE_NAME'].tolist())
    
    with col4:
        # Get unique deal_ids
        deals = session.sql("SELECT DISTINCT deal_id FROM audit_log WHERE deal_id IS NOT NULL ORDER BY 1").to_pandas()
        deal_filter = st.selectbox("Deal ID", ["All"] + deals['DEAL_ID'].tolist())
    
    # Build query
    where_clauses = []
    
    if time_filter != "All":
        hours_map = {"Last Hour": 1, "Last 24 Hours": 24, "Last 7 Days": 168, "Last 30 Days": 720}
        hours = hours_map[time_filter]
        where_clauses.append(f"start_time > DATEADD(hour, -{hours}, CURRENT_TIMESTAMP())")
    
    if status_filter != "All":
        where_clauses.append(f"status = '{status_filter}'")
    
    if procedure_filter != "All":
        where_clauses.append(f"procedure_name = '{procedure_filter}'")
    
    if deal_filter != "All":
        where_clauses.append(f"deal_id = '{deal_filter}'")
    
    where_clause = " AND ".join(where_clauses) if where_clauses else "1=1"
    
    # Load audit logs
    audit_query = f"""
        SELECT 
            TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
            procedure_name,
            deal_id,
            status,
            duration_seconds,
            rows_affected,
            SUBSTRING(message, 1, 100) AS message,
            SUBSTRING(error_message, 1, 100) AS error_message
        FROM audit_log
        WHERE {where_clause}
        ORDER BY start_time DESC
        LIMIT 1000
    """
    
    audit_df = session.sql(audit_query).to_pandas()
    
    if not audit_df.empty:
        st.markdown(f"**{len(audit_df)} log entries found**")
        st.dataframe(audit_df, use_container_width=True, hide_index=True)
        
        # Export option
        if st.button("📥 Export to CSV"):
            csv = audit_df.to_csv(index=False)
            st.download_button(
                label="Download CSV",
                data=csv,
                file_name=f"audit_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
                mime="text/csv"
            )
    else:
        st.info("No audit log entries match the selected filters")

# =====================================================
# PAGE: ERROR DIAGNOSTICS
# =====================================================

elif page == "🚨 Error Diagnostics":
    st.markdown('<p class="main-header">🚨 Error Diagnostics</p>', unsafe_allow_html=True)
    
    # Error Summary
    st.markdown('<p class="section-header">Error Summary (Last 7 Days)</p>', unsafe_allow_html=True)
    
    error_summary = session.sql("""
        SELECT 
            procedure_name,
            COUNT(*) AS error_count,
            COUNT(DISTINCT deal_id) AS affected_deals,
            MAX(start_time) AS last_error_time
        FROM audit_log
        WHERE status = 'ERROR'
        AND start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
        GROUP BY procedure_name
        ORDER BY error_count DESC
    """).to_pandas()
    
    if not error_summary.empty:
        st.dataframe(error_summary, use_container_width=True, hide_index=True)
        
        # Error trend
        error_trend = session.sql("""
            SELECT 
                DATE_TRUNC('hour', start_time) AS hour,
                COUNT(*) AS error_count
            FROM audit_log
            WHERE status = 'ERROR'
            AND start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
            GROUP BY 1
            ORDER BY 1
        """).to_pandas()
        
        if not error_trend.empty:
            fig = px.line(error_trend, x='HOUR', y='ERROR_COUNT',
                         title='Error Trend (Last 7 Days)',
                         labels={'ERROR_COUNT': 'Errors', 'HOUR': 'Time'})
            st.plotly_chart(fig, use_container_width=True)
    else:
        st.success("✅ No errors in the last 7 days!")
    
    # Recent Errors Detail
    st.markdown('<p class="section-header">Recent Errors (Details)</p>', unsafe_allow_html=True)
    
    recent_errors = session.sql("""
        SELECT 
            TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS error_time,
            procedure_name,
            deal_id,
            error_message,
            duration_seconds
        FROM audit_log
        WHERE status = 'ERROR'
        ORDER BY start_time DESC
        LIMIT 50
    """).to_pandas()
    
    if not recent_errors.empty:
        st.dataframe(recent_errors, use_container_width=True, hide_index=True)
    else:
        st.success("✅ No errors found!")
    
    # Load Errors
    st.markdown('<p class="section-header">Data Load Errors</p>', unsafe_allow_html=True)
    
    load_errors = session.sql("""
        SELECT 
            deal_id,
            file_name,
            error_type,
            error_message,
            line_content,
            TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI:SS') AS error_time
        FROM load_errors
        ORDER BY created_at DESC
        LIMIT 100
    """).to_pandas()
    
    if not load_errors.empty:
        st.dataframe(load_errors, use_container_width=True, hide_index=True)
    else:
        st.success("✅ No load errors!")

# =====================================================
# PAGE: SYSTEM HEALTH CHECK
# =====================================================

elif page == "🧪 System Health Check":
    st.markdown('<p class="main-header">🧪 System Health Check</p>', unsafe_allow_html=True)
    
    if st.button("▶️ Run Complete Health Check", type="primary"):
        with st.spinner("Running health check..."):
            
            # Check 1: Database Objects
            st.markdown("### 1️⃣ Database Objects")
            
            tables = session.sql("SHOW TABLES IN SCHEMA TRIAL_BALANCE").collect()
            views = session.sql("SHOW VIEWS IN SCHEMA TRIAL_BALANCE").collect()
            procedures = session.sql("SHOW PROCEDURES IN SCHEMA TRIAL_BALANCE").collect()
            
            col1, col2, col3 = st.columns(3)
            with col1:
                st.metric("Tables", len(tables), delta="✅" if len(tables) >= 14 else "❌")
            with col2:
                st.metric("Views", len(views), delta="✅" if len(views) >= 5 else "❌")
            with col3:
                st.metric("Procedures", len(procedures), delta="✅" if len(procedures) >= 16 else "❌")
            
            # Check 2: Data Integrity
            st.markdown("### 2️⃣ Data Integrity")
            
            tb_count = session.sql("SELECT COUNT(*) FROM trial_balance_raw").collect()[0][0]
            am_count = session.sql("SELECT COUNT(*) FROM account_mappings").collect()[0][0]
            am_active = session.sql("SELECT COUNT(*) FROM account_mappings WHERE is_active = TRUE").collect()[0][0]
            
            col1, col2, col3 = st.columns(3)
            with col1:
                st.metric("Trial Balance Rows", tb_count, delta="✅" if tb_count > 0 else "❌")
            with col2:
                st.metric("Account Mappings", am_count, delta="✅" if am_count > 0 else "❌")
            with col3:
                st.metric("Active Mappings", am_active, delta="✅" if am_active == am_count else "⚠️")
            
            # Check 3: View Health
            st.markdown("### 3️⃣ View Health")
            
            try:
                view1_count = session.sql("SELECT COUNT(*) FROM v_trial_balance_for_schedules").collect()[0][0]
                view2_count = session.sql("SELECT COUNT(*) FROM v_database_tab_pivoted").collect()[0][0]
                
                col1, col2 = st.columns(2)
                with col1:
                    st.metric("v_trial_balance_for_schedules", view1_count, delta="✅" if view1_count > 0 else "❌")
                with col2:
                    st.metric("v_database_tab_pivoted", view2_count, delta="✅" if view2_count > 0 else "❌")
            except Exception as e:
                st.error(f"❌ View health check failed: {str(e)}")
            
            # Check 4: Recent Execution Success
            st.markdown("### 4️⃣ Recent Execution Success")
            
            recent_success = session.sql("""
                SELECT 
                    procedure_name,
                    COUNT(*) AS executions,
                    SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) AS successful,
                    ROUND(SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS success_rate
                FROM audit_log
                WHERE start_time > DATEADD(hour, -24, CURRENT_TIMESTAMP())
                GROUP BY 1
                ORDER BY 1
            """).to_pandas()
            
            if not recent_success.empty:
                st.dataframe(recent_success, use_container_width=True, hide_index=True)
            
            # Overall Health Score
            st.markdown("### 🎯 Overall Health Score")
            
            health_checks = [
                len(tables) >= 14,
                len(views) >= 5,
                len(procedures) >= 16,
                tb_count > 0,
                am_active == am_count and am_count > 0,
                view1_count > 0 if 'view1_count' in locals() else False,
                view2_count > 0 if 'view2_count' in locals() else False,
                recent_errors == 0 if 'recent_errors' in locals() else True
            ]
            
            health_score = (sum(health_checks) / len(health_checks)) * 100
            
            if health_score >= 90:
                st.success(f"✅ **System Health: EXCELLENT** ({health_score:.0f}%)")
            elif health_score >= 70:
                st.warning(f"⚠️ **System Health: GOOD** ({health_score:.0f}%)")
            else:
                st.error(f"❌ **System Health: NEEDS ATTENTION** ({health_score:.0f}%)")
    
    # Quick Diagnostics
    st.markdown('<p class="section-header">Quick Diagnostics</p>', unsafe_allow_html=True)
    
    if st.button("🔍 Check if database_tab Will Generate"):
        view_count = session.sql("SELECT COUNT(*) FROM v_database_tab_pivoted").collect()[0][0]
        
        if view_count > 0:
            st.success(f"✅ v_database_tab_pivoted has {view_count} rows - database_tab CSV will generate!")
        else:
            st.error("❌ v_database_tab_pivoted is EMPTY - database_tab CSV will be empty!")
            st.markdown("**Troubleshooting Steps:**")
            st.code("""
1. Check account_mappings:
   SELECT COUNT(*) FROM account_mappings WHERE is_active = TRUE;

2. If 0, reload:
   CALL load_account_mappings();

3. Verify fix worked:
   SELECT COUNT(*) FROM v_database_tab_pivoted;
            """)

# =====================================================
# FOOTER
# =====================================================

st.markdown("---")
st.markdown("""
<div style='text-align: center; color: #7f8c8d; font-size: 0.9rem;'>
    <p><strong>Houlihan Lokey FDD Automation</strong> | Version 1.0.0 | Powered by Snowflake</p>
    <p>For support, refer to documentation or contact your Snowflake account team</p>
</div>
""", unsafe_allow_html=True)


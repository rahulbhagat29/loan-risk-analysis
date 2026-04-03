CREATE DATABASE loan_risk;

USE loan_risk;
SELECT COUNT(*) FROM loans_clean;

-- First SQL query — verify your key columns
SELECT 
    loan_amnt, annual_inc, dti, grade, 
    default_flag, loan_to_income, dti_bucket
FROM loans_clean
LIMIT 5;

-- Check your default rate by grade
SELECT 
    grade,
    COUNT(*) AS total_loans,
    SUM(default_flag) AS total_defaults,
    ROUND(SUM(default_flag) * 100.0 / COUNT(*), 2) AS default_rate_pct,
    ROUND(AVG(int_rate), 2) AS avg_interest_rate
FROM loans_clean
GROUP BY grade
ORDER BY grade;

-- Default rate by DTI bucket
SELECT 
    dti_bucket,
    COUNT(*) AS total_loans,
    SUM(default_flag) AS total_defaults,
    ROUND(SUM(default_flag) * 100.0 / COUNT(*), 2) AS default_rate_pct,
    ROUND(AVG(loan_to_income), 3) AS avg_loan_to_income
FROM loans_clean
GROUP BY dti_bucket
ORDER BY default_rate_pct;

-- Default rate by grade AND DTI bucket combined
SELECT 
    grade,
    dti_bucket,
    COUNT(*) AS total_loans,
    SUM(default_flag) AS total_defaults,
    ROUND(SUM(default_flag) * 100.0 / COUNT(*), 2) AS default_rate_pct,
    ROUND(AVG(int_rate), 2) AS avg_interest_rate
FROM loans_clean
WHERE dti_bucket IS NOT NULL
GROUP BY grade, dti_bucket
ORDER BY grade, default_rate_pct;

-- Calculate estimated profit per segment
SELECT 
    grade,
    dti_bucket,
    COUNT(*) AS total_loans,
    ROUND(AVG(loan_amnt), 2) AS avg_loan_amnt,
    ROUND(SUM(default_flag) * 100.0 / COUNT(*), 2) AS default_rate_pct,
    ROUND(SUM(loan_amnt * (int_rate/100)), 2) AS total_interest_earned,
    ROUND(SUM(loan_amnt * default_flag), 2) AS total_loss_from_defaults,
    ROUND(SUM(loan_amnt * (int_rate/100)) - SUM(loan_amnt * default_flag), 2) AS net_profit
FROM loans_clean
WHERE dti_bucket IS NOT NULL
GROUP BY grade, dti_bucket
ORDER BY net_profit DESC;

-- This is one query that combines everything
WITH segment_stats AS (
    SELECT 
        grade,
        dti_bucket,
        COUNT(*) AS total_loans,
        SUM(default_flag) AS total_defaults,
        ROUND(SUM(default_flag) * 100.0 / COUNT(*), 2) AS default_rate_pct,
        ROUND(AVG(int_rate), 2) AS avg_interest_rate,
        ROUND(AVG(loan_amnt), 2) AS avg_loan_amnt
    FROM loans_clean
    WHERE dti_bucket IS NOT NULL
    GROUP BY grade, dti_bucket
),
profit_calc AS (
    SELECT 
        s.*,
        ROUND(s.avg_loan_amnt * (s.avg_interest_rate/100) * s.total_loans, 2) AS total_interest_earned,
        ROUND(s.avg_loan_amnt * s.total_defaults, 2) AS total_loss,
        ROUND((s.avg_loan_amnt * (s.avg_interest_rate/100) * s.total_loans) - 
              (s.avg_loan_amnt * s.total_defaults), 2) AS net_profit
    FROM segment_stats s
),
segment_ranked AS (
    SELECT *,
        CASE 
            WHEN net_profit > 0 AND default_rate_pct < 15 THEN 'APPROVE'
            WHEN net_profit > 0 AND default_rate_pct BETWEEN 15 AND 25 THEN 'REVIEW'
            ELSE 'REJECT'
        END AS recommendation,
        RANK() OVER (ORDER BY net_profit DESC) AS profit_rank
    FROM profit_calc
)
SELECT * FROM segment_ranked
ORDER BY net_profit DESC;
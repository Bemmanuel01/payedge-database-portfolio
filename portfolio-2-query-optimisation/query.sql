-- Q1: Statement for one account (Adaeze's savings account, account_id = 1)

SELECT t.transaction_id, t.reference, t.transaction_type, t.amount, t.status,
       t.transaction_date, fa.account_number AS from_account, ta.account_number AS to_account
FROM transactions t
         LEFT JOIN accounts fa ON fa.account_id = t.from_account_id
         LEFT JOIN accounts ta ON ta.account_id = t.to_account_id
WHERE t.from_account_id = 1 OR t.to_account_id = 1
ORDER BY t.transaction_date DESC;

-- Q2: Failed transactions in the last 30 days, with affected customers

SELECT t.reference, t.amount, t.transaction_date, c.full_name, c.email
FROM transactions t
         JOIN accounts  a ON a.account_id  = t.from_account_id
         JOIN customers c ON c.customer_id = a.customer_id
WHERE t.status = 'FAILED'
  AND t.transaction_date >= NOW() - INTERVAL '30 days'
ORDER BY t.transaction_date DESC;

-- Q3: Monthly summary of successful transactions (CTE)

WITH monthly AS (
    SELECT DATE_TRUNC('month', transaction_date) AS month,
    transaction_type,
    COUNT(*)    AS txn_count,
    SUM(amount) AS total_amount
FROM transactions
WHERE status = 'SUCCESS'
GROUP BY 1, 2
    )
SELECT TO_CHAR(month, 'YYYY-MM') AS period, transaction_type, txn_count, total_amount
FROM monthly
ORDER BY month DESC, transaction_type;

-- Q4: Top 3 balances within each account type (window function)

SELECT *
FROM (
         SELECT c.full_name, a.account_number, a.account_type, a.balance,
                RANK() OVER (PARTITION BY a.account_type ORDER BY a.balance DESC) AS rank_in_type
         FROM accounts a
                  JOIN customers c ON c.customer_id = a.customer_id
         WHERE a.status = 'ACTIVE'
     ) ranked
WHERE rank_in_type <= 3
ORDER BY account_type, rank_in_type;

-- Q5: Accounts greater than the average balance (sub-query)

SELECT a.account_number, a.account_type, a.balance
FROM accounts a
WHERE a.balance > (SELECT AVG(balance) FROM accounts WHERE status = 'ACTIVE')
ORDER BY a.balance DESC
    LIMIT 10;
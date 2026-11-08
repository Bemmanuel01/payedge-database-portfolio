-- ============================================================
-- PAYEDGE DIGITAL BANK: Volume Seed Data
-- Portfolio 2: Query Processing and Optimisation
--
-- PURPOSE: Generates test volume so that indexes and execution
--          plans can be measured meaningfully.
--          (customers: 5,000 | accounts: 5,000 | transactions: 500,000)
--
-- PREREQUISITES: Run the schema.sql and data.sql.
--                Expected starting counts: customers 5, accounts 7, transactions 10.
--
-- ============================================================


-- ------------------------------------------------------------
-- 1a. 5,000 customers
--     Customers emails and phones uses real Nigerian network prefixes
--     with scattered (non-sequential) suffixes, BVNs start with  22 for all customers.
-- ------------------------------------------------------------
WITH base AS (
    SELECT g,
           (ARRAY['Chinedu','Amina','Tunde','Blessing','Ibrahim','Funke','Obinna','Zainab',
            'Kelechi','Halima','Segun','Chiamaka','Musa','Folake','Uche','Aisha',
            'Babatunde','Ifeoma','Yusuf','Temitope'])[1 + g % 20]        AS fn,
    (ARRAY['Adeyemi','Okonkwo','Bello','Eze','Ogunleye','Abubakar','Nwosu','Balogun',
    'Udoh','Lawal','Ibrahim','Okoye','Adewale','Suleiman','Obi','Onyeka',
    'Ajayi','Danjuma','Okafor','Akinola'])[1 + (g / 20) % 20]    AS ln
FROM generate_series(1, 5000) g
    )
INSERT INTO customers (full_name, email, phone, bvn, date_of_birth, kyc_status)
SELECT
    fn || ' ' || ln,
    lower(fn || '.' || ln) || g || '@gmail.com',
    (ARRAY['0802','0803','0806','0810','0813','0814','0816',
     '0903','0906','0701','0708','0809'])[1 + (g * 7) % 12]
        || lpad(((g::bigint * 7368787 + 2468013) % 10000000)::text, 7, '0'),
    '22' || lpad(((g::bigint * 483711653 + 123456789) % 1000000000)::text, 9, '0'),
    DATE '1966-01-01' + ((g * 37) % 13000),
    (ARRAY['PENDING','VERIFIED','VERIFIED','VERIFIED'])[1 + g % 4]
FROM base;


-- ------------------------------------------------------------
-- 1b. One account for each seeded customer
--     Customer's account number is the same as the customer's phone number but without the leading 0.
-- ------------------------------------------------------------
INSERT INTO accounts (customer_id, account_number, account_type, balance, opened_date)
SELECT c.customer_id,
       substring(c.phone FROM 2),
       (ARRAY['SAVINGS','CURRENT','FIXED'])[1 + c.customer_id % 3],
       (random() * 1000000)::numeric(15,2),
       DATE '2024-01-01' + (c.customer_id % 600)
FROM customers c
WHERE c.customer_id > 5;


-- ------------------------------------------------------------
-- 1c. 500,000 transactions
--     Account IDs are taken from the accounts table so the foreign
--     keys always resolve. Sender and receiver always differ.
--     Status mix: about 80% SUCCESS, 10% PENDING, 10% FAILED.
-- ------------------------------------------------------------
WITH ids AS (
    SELECT array_agg(account_id ORDER BY account_id) AS arr, COUNT(*) AS n
    FROM accounts
),
     pairs AS (
         SELECT g,
                1 + floor(random() * ids.n)::int       AS i,
             1 + floor(random() * (ids.n - 1))::int AS off
         FROM ids, generate_series(1, 500000) g
     )
INSERT INTO transactions
    (from_account_id, to_account_id, transaction_type, amount, status, reference, narration, transaction_date)
SELECT ids.arr[p.i],
       ids.arr[1 + ((p.i - 1 + p.off) % ids.n)],
    'TRANSFER',
    (100 + random() * 99900)::numeric(15,2),
    (ARRAY['SUCCESS','SUCCESS','SUCCESS','SUCCESS','SUCCESS',
    'SUCCESS','SUCCESS','SUCCESS','PENDING','FAILED'])[1 + floor(random() * 10)::int],
    'SEED-' || p.g,
    'Seeded transaction',
    NOW() - random() * INTERVAL '365 days'
FROM pairs p, ids;


-- ------------------------------------------------------------
-- Refresh planner statistics (required before taking execution plans)
-- ------------------------------------------------------------
ANALYZE;


-- ------------------------------------------------------------
-- Verification (expected: 5005 | 5007 | 500010)
-- ------------------------------------------------------------
SELECT (SELECT COUNT(*) FROM customers)    AS customers,
       (SELECT COUNT(*) FROM accounts)     AS accounts,
       (SELECT COUNT(*) FROM transactions) AS transactions;



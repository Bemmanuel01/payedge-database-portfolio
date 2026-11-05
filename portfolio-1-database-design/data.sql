-- Customer table data
INSERT INTO customers
(full_name, email, phone, bvn, date_of_birth, address, kyc_status)
VALUES
    ('Adaeze Nwachukwu', 'adaeze@gmail.com',  '08077345338', '22235289041', '1990-05-15', '12 Marina Street, Lagos',        'VERIFIED'),
    ('Emeka Okafor',     'emeka@gmail.com',   '09123456789', '22206319012', '1985-08-22', '45 Wuse Zone 4, Abuja',          'VERIFIED'),
    ('Fatima Bello',     'fatima@gmail.com',  '07034567890', '22264790113', '1995-03-10', '7 Ahmadu Bello Way, Kaduna',     'PENDING'),
    ('Chidi Eze',        'chidi@gmail.com',   '08155678901', '22271901299', '1988-11-30', '22 Forces Avenue, Enugu',        'VERIFIED'),
    ('Ngozi Obi',        'ngozi@gmail.com',   '08056789012', '22208401315', '1992-07-18', '3 Aba Road, Port Harcourt',      'VERIFIED');

BEGIN;

UPDATE customers SET phone = '08077343538', bvn = '22235289041', updated_at = CURRENT_TIMESTAMP
WHERE email = 'adaeze@gmail.com';

UPDATE customers SET phone = '09144577709', bvn = '22206319012', updated_at = CURRENT_TIMESTAMP
WHERE email = 'emeka@gmail.com';

UPDATE customers SET phone = '07034567890', bvn = '22264790113', updated_at = CURRENT_TIMESTAMP
WHERE email = 'fatima@gmail.com';

UPDATE customers SET phone = '08155609905', bvn = '22271901299', updated_at = CURRENT_TIMESTAMP
WHERE email = 'chidi@gmail.com';

UPDATE customers SET phone = '08055788012', bvn = '22208401315', updated_at = CURRENT_TIMESTAMP
WHERE email = 'ngozi@gmail.com';

COMMIT;

-- Account Data
INSERT INTO accounts
(customer_id, account_number, account_type, balance, currency, status, opened_date)
VALUES
    (1, '8077343538', 'SAVINGS',   250000.00, 'NGN', 'ACTIVE', '2024-01-15'),
    (1, '0077343538', 'CURRENT',  1500000.00, 'NGN', 'ACTIVE', '2024-01-15'),
    (2, '9144577709', 'SAVINGS',    75000.00, 'NGN', 'ACTIVE', '2024-02-20'),
    (3, '7034567890', 'SAVINGS',    12000.00, 'NGN', 'ACTIVE', '2024-03-10'),
    (4, '8155609905', 'CURRENT',   890000.00, 'NGN', 'ACTIVE', '2024-01-05'),
    (5, '8055788012', 'SAVINGS',   340000.00, 'NGN', 'ACTIVE', '2024-04-18'),
    (5, '0055788012', 'FIXED',    2000000.00, 'NGN', 'ACTIVE', '2024-04-18')
;

-- Transaction Data
INSERT INTO transactions
(from_account_id, to_account_id, transaction_type, amount, status, reference, narration)
VALUES
    (1,    3,    'TRANSFER',    50000.00, 'SUCCESS',  'TXN-20261001-001', 'Rent payment'),
    (2,    5,    'TRANSFER',   200000.00, 'SUCCESS',  'TXN-20261001-002', 'Loan repayment'),
    (NULL, 1,    'DEPOSIT',    100000.00, 'SUCCESS',  'TXN-20261002-001', 'Nil'),
    (3,    NULL, 'WITHDRAWAL',  20000.00, 'SUCCESS',  'TXN-20261002-002', 'Nil'),
    (4,    6,    'TRANSFER',    15000.00, 'FAILED',   'TXN-20261003-001', 'Snacks Purchase'),
    (1,    6,    'TRANSFER',    30000.00, 'SUCCESS',  'TXN-20261003-002', 'School fees'),
    (2,    NULL, 'WITHDRAWAL', 500000.00, 'SUCCESS',  'TXN-20261004-001', 'Client Onus'),
    (5,    3,    'TRANSFER',    75000.00, 'FAILED',   'TXN-20261004-002', 'Electricity bill'),
    (NULL, 4,    'DEPOSIT',    250000.00, 'SUCCESS',  'TXN-20261005-001', 'Client fee'),
    (6,    1,    'TRANSFER',    10000.00, 'REVERSED', 'TXN-20261005-002', 'Nil')
;

-- Beneficiaries Data
INSERT INTO beneficiaries
(customer_id, beneficiary_name, account_number, bank_name)
VALUES
    (1, 'Emeka Okafor',      '9144577709', 'PayEdge'),
    (1, 'Ahmed Musa',        '2034567890', 'GTBank'),
    (2, 'Chidi Eze',         '8155609905', 'PayEdge'),
    (5, 'Starfield College', '3045678912', 'Access Bank')
;

-- Loan Applications Data
INSERT INTO loan_applications
(customer_id, account_id, loan_amount, interest_rate, tenure_months, status, applied_date, approved_date)
VALUES
    (4, 5,  500000.00, 15.50, 12, 'APPROVED',  '2026-09-20 10:15:00', '2026-09-22 14:30:00'),
    (3, 4,  100000.00, 18.00,  6, 'PENDING',   '2026-10-28 09:05:00', NULL),
    (5, 6, 1000000.00, 14.00, 24, 'DISBURSED', '2026-08-10 11:40:00', '2026-08-12 16:00:00')
;

-- Audit Logs Data
INSERT INTO audit_logs
(user_id, action, table_affected, record_id, old_value, new_value, log_timestamp)
VALUES
    (9001, 'KYC_STATUS_UPDATE','customers',1,'{"kyc_status": "PENDING"}','{"kyc_status": "VERIFIED"}','2026-10-01 09:10:00'),
    (9001, 'EMAIL_UPDATE','customers',1,'{"email": "adaeze@email.com"}','{"email": "adaeze@gmail.com"}','2026-11-05 10:20:00'),
    (9002, 'TRANSACTION_FAILED','transactions',5,NULL,'{"status": "FAILED", "reference": "TXN-20261003-001"}','2026-10-03 12:45:00'),
    (9002, 'TRANSACTION_REVERSED', 'transactions',10,'{"status": "SUCCESS"}','{"status": "REVERSED", "reference": "TXN-20261005-002"}','2026-10-05 15:30:00'),
    (9003, 'LOAN_APPROVED','loan_applications', 1,'{"status": "PENDING"}','{"status": "APPROVED", "loan_amount": 500000.00}','2026-09-22 14:30:00')
;

-- Staff Data
INSERT INTO staff (staff_id, full_name, email, role)
VALUES
    (9001, 'Immanuel Benjamine','immanuel.benjamine@payedge.ng','COMPLIANCE_OFFICER'),
    (9002, 'Emmanuel Benjamin', 'emmanuel.benjamin@payedge.ng','ADMIN'),
    (9003, 'Ifeanyi Benjamin','ifeanyi.benjamin@payedge.ng','LOAN_OFFICER')
;

SELECT setval('staff_staff_id_seq', (SELECT MAX(staff_id) FROM staff));
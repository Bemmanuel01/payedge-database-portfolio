-- Customer table data
INSERT INTO customers
(full_name, email, phone, bvn, date_of_birth, address, kyc_status)
VALUES
    ('Adaeze Nwachukwu', 'adaeze@email.com',  '08077345338', '22235289041', '1990-05-15', '12 Marina Street, Lagos',        'VERIFIED'),
    ('Emeka Okafor',     'emeka@email.com',   '09123456789', '22206319012', '1985-08-22', '45 Wuse Zone 4, Abuja',          'VERIFIED'),
    ('Fatima Bello',     'fatima@email.com',  '07034567890', '22264790113', '1995-03-10', '7 Ahmadu Bello Way, Kaduna',     'PENDING'),
    ('Chidi Eze',        'chidi@email.com',   '08155678901', '22271901299', '1988-11-30', '22 Forces Avenue, Enugu',        'VERIFIED'),
    ('Ngozi Obi',        'ngozi@email.com',   '08056789012', '22208401315', '1992-07-18', '3 Aba Road, Port Harcourt',      'VERIFIED');

BEGIN;

UPDATE customers SET phone = '08077343538', bvn = '22235289041', updated_at = CURRENT_TIMESTAMP
WHERE email = 'adaeze@email.com';

UPDATE customers SET phone = '09144577709', bvn = '22206319012', updated_at = CURRENT_TIMESTAMP
WHERE email = 'emeka@email.com';

UPDATE customers SET phone = '07034567890', bvn = '22264790113', updated_at = CURRENT_TIMESTAMP
WHERE email = 'fatima@email.com';

UPDATE customers SET phone = '08155609905', bvn = '22271901299', updated_at = CURRENT_TIMESTAMP
WHERE email = 'chidi@email.com';

UPDATE customers SET phone = '08055788012', bvn = '22208401315', updated_at = CURRENT_TIMESTAMP
WHERE email = 'ngozi@email.com';

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
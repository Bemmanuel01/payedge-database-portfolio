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


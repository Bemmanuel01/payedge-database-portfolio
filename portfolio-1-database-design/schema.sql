-- ============================================================
-- PAYEDGE DIGITAL BANK: PostgreSQL Database Schema
-- Portfolio 1: Database Design and Modelling
-- ============================================================

CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    phone VARCHAR(15) UNIQUE NOT NULL,
    bvn CHAR(11) UNIQUE NOT NULL,
    date_of_birth DATE NOT NULL,
    address TEXT,
    kyc_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_kyc_status
        CHECK (kyc_status IN ('PENDING', 'VERIFIED', 'REJECTED'))
);

CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    account_number CHAR(10) UNIQUE NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    balance NUMERIC(15,2) NOT NULL DEFAULT 0.00,
    currency CHAR(3) NOT NULL DEFAULT 'NGN',
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    opened_date DATE NOT NULL DEFAULT CURRENT_DATE,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_accounts_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
            ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_account_type
        CHECK (account_type IN ('SAVINGS', 'CURRENT', 'FIXED')),
    CONSTRAINT chk_account_status
        CHECK (status IN ('ACTIVE', 'DORMANT', 'CLOSED')),
    CONSTRAINT chk_balance
        CHECK (balance >= 0)
);

CREATE TABLE transactions (
    transaction_id SERIAL PRIMARY KEY,
    from_account_id INT,
    to_account_id INT,
    transaction_type VARCHAR(20) NOT NULL,
    amount NUMERIC(15,2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    reference VARCHAR(50) UNIQUE NOT NULL,
    narration VARCHAR(255),
    transaction_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_txn_from_account
        FOREIGN KEY (from_account_id) REFERENCES accounts (account_id),
    CONSTRAINT fk_txn_to_account
        FOREIGN KEY (to_account_id) REFERENCES accounts (account_id),
    CONSTRAINT chk_txn_type
        CHECK (transaction_type IN ('TRANSFER', 'DEPOSIT', 'WITHDRAWAL', 'REVERSAL')),
    CONSTRAINT chk_txn_status
        CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED', 'REVERSED')),
    CONSTRAINT chk_txn_amount
        CHECK (amount > 0),
    CONSTRAINT chk_txn_has_account
        CHECK (from_account_id IS NOT NULL OR to_account_id IS NOT NULL)
);

CREATE TABLE beneficiaries (
    beneficiary_id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    beneficiary_name VARCHAR(100) NOT NULL,
    account_number CHAR(10) NOT NULL,
    bank_name VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_beneficiary_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
            ON DELETE CASCADE
);

CREATE TABLE loan_applications (
    loan_id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    account_id INT NOT NULL,
    loan_amount NUMERIC(15,2) NOT NULL,
    interest_rate NUMERIC(5,2) NOT NULL,
    tenure_months INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    applied_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    approved_date TIMESTAMP,
    CONSTRAINT fk_loan_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id),
    CONSTRAINT fk_loan_account
        FOREIGN KEY (account_id) REFERENCES accounts (account_id),
    CONSTRAINT chk_loan_status
        CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'DISBURSED', 'CLOSED')),
    CONSTRAINT chk_loan_amount
        CHECK (loan_amount > 0),
    CONSTRAINT chk_loan_interest
        CHECK (interest_rate > 0),
    CONSTRAINT chk_loan_tenure
        CHECK (tenure_months > 0)
);

CREATE TABLE audit_logs (
    log_id SERIAL PRIMARY KEY,
    user_id INT,
    action VARCHAR(100) NOT NULL,
    table_affected VARCHAR(50),
    record_id INT,
    old_value JSONB,
    new_value JSONB,
    log_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);







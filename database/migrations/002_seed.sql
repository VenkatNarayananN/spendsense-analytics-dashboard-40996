BEGIN;

-- ---------------------------------------------------------------------------
-- Demo Users (deterministic UUIDs)
-- ---------------------------------------------------------------------------
INSERT INTO public.users (id, email, is_active, role, full_name, avatar_url)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'ava.brooks@spendsense.demo', true, 'admin', 'Ava Brooks', 'https://example.com/avatars/ava.png'),
  ('22222222-2222-2222-2222-222222222222', 'liam.chen@spendsense.demo', true, 'user', 'Liam Chen', 'https://example.com/avatars/liam.png'),
  ('33333333-3333-3333-3333-333333333333', 'sophia.patel@spendsense.demo', true, 'user', 'Sophia Patel', 'https://example.com/avatars/sophia.png')
ON CONFLICT (email) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Global Categories (user_id NULL) + one user's custom categories
-- Deterministic IDs so later seed statements can reference them.
-- ---------------------------------------------------------------------------
-- Expense (global)
INSERT INTO public.categories (id, user_id, name, type, color)
VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', NULL, 'Groceries', 'expense', '#34D399'),
  ('aaaaaaaa-0000-0000-0000-000000000002', NULL, 'Dining', 'expense', '#F59E0B'),
  ('aaaaaaaa-0000-0000-0000-000000000003', NULL, 'Rent', 'expense', '#60A5FA'),
  ('aaaaaaaa-0000-0000-0000-000000000004', NULL, 'Utilities', 'expense', '#A78BFA'),
  ('aaaaaaaa-0000-0000-0000-000000000005', NULL, 'Transport', 'expense', '#FB7185'),
  ('aaaaaaaa-0000-0000-0000-000000000006', NULL, 'Entertainment', 'expense', '#F472B6'),
  ('aaaaaaaa-0000-0000-0000-000000000007', NULL, 'Health', 'expense', '#22C55E')
ON CONFLICT DO NOTHING;

-- Income (global)
INSERT INTO public.categories (id, user_id, name, type, color)
VALUES
  ('bbbbbbbb-0000-0000-0000-000000000001', NULL, 'Salary', 'income', '#10B981'),
  ('bbbbbbbb-0000-0000-0000-000000000002', NULL, 'Bonus', 'income', '#84CC16')
ON CONFLICT DO NOTHING;

-- Custom categories for users[0] (Ava)
INSERT INTO public.categories (id, user_id, name, type, color)
VALUES
  ('cccccccc-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Coffee', 'expense', '#C084FC'),
  ('cccccccc-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Subscriptions', 'expense', '#F97316')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Budgets for users[0] - current month
-- ---------------------------------------------------------------------------
INSERT INTO public.budgets (id, user_id, name, limit_amount, period, currency, category_id, start_date, end_date)
VALUES
  ('dddddddd-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Groceries Budget', 400.00, 'monthly', 'USD', 'aaaaaaaa-0000-0000-0000-000000000001', date_trunc('month', current_date)::date, (date_trunc('month', current_date) + interval '1 month - 1 day')::date),
  ('dddddddd-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Dining Budget', 250.00, 'monthly', 'USD', 'aaaaaaaa-0000-0000-0000-000000000002', date_trunc('month', current_date)::date, (date_trunc('month', current_date) + interval '1 month - 1 day')::date),
  ('dddddddd-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'Transport Budget', 150.00, 'monthly', 'USD', 'aaaaaaaa-0000-0000-0000-000000000005', date_trunc('month', current_date)::date, (date_trunc('month', current_date) + interval '1 month - 1 day')::date),
  ('dddddddd-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'Entertainment Budget', 120.00, 'monthly', 'USD', 'aaaaaaaa-0000-0000-0000-000000000006', date_trunc('month', current_date)::date, (date_trunc('month', current_date) + interval '1 month - 1 day')::date)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Transactions (~120) over last 90 days for users[0]
-- Notes:
-- - Uses generate_series to create realistic distribution across categories/vendors.
-- - Deterministic IDs derived from md5 to keep migration repeatable.
-- ---------------------------------------------------------------------------
WITH
series AS (
  SELECT
    gs::int AS n,
    (now() - (random() * interval '90 days')) AS occurred_at
  FROM generate_series(1, 120) gs
),
picked AS (
  SELECT
    n,
    occurred_at,
    -- Category selection biased towards groceries/dining/transport/entertainment/utilities/health/coffee/subscriptions
    CASE
      WHEN n % 10 IN (0,1,2) THEN 'aaaaaaaa-0000-0000-0000-000000000001'::uuid -- Groceries
      WHEN n % 10 IN (3,4) THEN 'aaaaaaaa-0000-0000-0000-000000000002'::uuid -- Dining
      WHEN n % 10 = 5 THEN 'aaaaaaaa-0000-0000-0000-000000000005'::uuid -- Transport
      WHEN n % 10 = 6 THEN 'aaaaaaaa-0000-0000-0000-000000000006'::uuid -- Entertainment
      WHEN n % 10 = 7 THEN 'aaaaaaaa-0000-0000-0000-000000000004'::uuid -- Utilities
      WHEN n % 10 = 8 THEN 'aaaaaaaa-0000-0000-0000-000000000007'::uuid -- Health
      ELSE 'cccccccc-0000-0000-0000-000000000001'::uuid -- Coffee (custom)
    END AS category_id,
    CASE
      WHEN n % 10 IN (0,1,2) THEN 'dddddddd-0000-0000-0000-000000000001'::uuid -- Groceries budget
      WHEN n % 10 IN (3,4) THEN 'dddddddd-0000-0000-0000-000000000002'::uuid -- Dining budget
      WHEN n % 10 = 5 THEN 'dddddddd-0000-0000-0000-000000000003'::uuid -- Transport budget
      WHEN n % 10 = 6 THEN 'dddddddd-0000-0000-0000-000000000004'::uuid -- Entertainment budget
      ELSE NULL::uuid
    END AS budget_id,
    CASE
      WHEN n % 20 = 0 THEN 'pending'
      WHEN n % 7 = 0 THEN 'reconciled'
      ELSE 'posted'
    END AS status,
    CASE
      WHEN n % 10 IN (0,1,2) THEN (10 + random() * 140)::numeric(12,2)        -- groceries
      WHEN n % 10 IN (3,4) THEN (6 + random() * 70)::numeric(12,2)           -- dining
      WHEN n % 10 = 5 THEN (8 + random() * 55)::numeric(12,2)                -- transport
      WHEN n % 10 = 6 THEN (9 + random() * 65)::numeric(12,2)                -- entertainment
      WHEN n % 10 = 7 THEN (40 + random() * 130)::numeric(12,2)              -- utilities
      WHEN n % 10 = 8 THEN (15 + random() * 120)::numeric(12,2)              -- health
      ELSE (3 + random() * 12)::numeric(12,2)                                -- coffee
    END AS amount,
    CASE
      WHEN n % 12 = 0 THEN 'Netflix'
      WHEN n % 12 = 1 THEN 'Starbucks'
      WHEN n % 12 = 2 THEN 'Whole Foods'
      WHEN n % 12 = 3 THEN 'Trader Joe''s'
      WHEN n % 12 = 4 THEN 'Lyft'
      WHEN n % 12 = 5 THEN 'Uber'
      WHEN n % 12 = 6 THEN 'City Transit'
      WHEN n % 12 = 7 THEN 'Utility Co.'
      WHEN n % 12 = 8 THEN 'Pharmacy Plus'
      WHEN n % 12 = 9 THEN 'CinemaPlex'
      WHEN n % 12 = 10 THEN 'Chipotle'
      ELSE 'Local Market'
    END AS vendor
  FROM series
),
expense_rows AS (
  SELECT
    -- stable UUID from md5 (version 4-ish format)
    (
      substring(md5('txn-expense-' || n::text) from 1 for 8) || '-' ||
      substring(md5('txn-expense-' || n::text) from 9 for 4) || '-' ||
      substring(md5('txn-expense-' || n::text) from 13 for 4) || '-' ||
      substring(md5('txn-expense-' || n::text) from 17 for 4) || '-' ||
      substring(md5('txn-expense-' || n::text) from 21 for 12)
    )::uuid AS id,
    '11111111-1111-1111-1111-111111111111'::uuid AS user_id,
    (amount * -1)::numeric(12,2) AS amount,
    'USD'::char(3) AS currency,
    occurred_at AS occurred_at,
    (vendor || ' purchase')::text AS description,
    category_id,
    budget_id,
    status
  FROM picked
),
income_seed AS (
  SELECT
    -- Salary (2 pay cycles) and one bonus
    1 AS n, (date_trunc('day', now() - interval '60 days') + interval '09:00')::timestamptz AS occurred_at, 3200.00::numeric(12,2) AS amount, 'Monthly Salary'::text AS description, 'bbbbbbbb-0000-0000-0000-000000000001'::uuid AS category_id
  UNION ALL
  SELECT
    2 AS n, (date_trunc('day', now() - interval '30 days') + interval '09:00')::timestamptz AS occurred_at, 3200.00::numeric(12,2) AS amount, 'Monthly Salary'::text AS description, 'bbbbbbbb-0000-0000-0000-000000000001'::uuid AS category_id
  UNION ALL
  SELECT
    3 AS n, (date_trunc('day', now() - interval '15 days') + interval '12:00')::timestamptz AS occurred_at, 750.00::numeric(12,2) AS amount, 'Performance Bonus'::text AS description, 'bbbbbbbb-0000-0000-0000-000000000002'::uuid AS category_id
),
income_rows AS (
  SELECT
    (
      substring(md5('txn-income-' || n::text) from 1 for 8) || '-' ||
      substring(md5('txn-income-' || n::text) from 9 for 4) || '-' ||
      substring(md5('txn-income-' || n::text) from 13 for 4) || '-' ||
      substring(md5('txn-income-' || n::text) from 17 for 4) || '-' ||
      substring(md5('txn-income-' || n::text) from 21 for 12)
    )::uuid AS id,
    '11111111-1111-1111-1111-111111111111'::uuid AS user_id,
    amount::numeric(12,2) AS amount,
    'USD'::char(3) AS currency,
    occurred_at,
    description,
    category_id,
    NULL::uuid AS budget_id,
    'posted'::text AS status
  FROM income_seed
)
INSERT INTO public.transactions (id, user_id, amount, currency, occurred_at, description, category_id, budget_id, status)
SELECT id, user_id, amount, currency, occurred_at, description, category_id, budget_id, status
FROM expense_rows
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.transactions (id, user_id, amount, currency, occurred_at, description, category_id, budget_id, status)
SELECT id, user_id, amount, currency, occurred_at, description, category_id, budget_id, status
FROM income_rows
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Alerts for users[0]
-- ---------------------------------------------------------------------------
INSERT INTO public.alerts (id, user_id, type, threshold, notified_at, is_active, related_transaction_id)
VALUES
  ('eeeeeeee-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'budget_exceeded', 250.00, now() - interval '5 days', true, NULL),
  ('eeeeeeee-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'budget_exceeded', 250.00, now() - interval '2 days', true, NULL),
  ('eeeeeeee-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'new_transaction', NULL, now() - interval '1 day', true,
    (
      SELECT t.id
      FROM public.transactions t
      WHERE t.user_id = '11111111-1111-1111-1111-111111111111'::uuid
      ORDER BY t.occurred_at DESC
      LIMIT 1
    )
  ),
  ('eeeeeeee-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'new_transaction', NULL, now() - interval '12 hours', true,
    (
      SELECT t.id
      FROM public.transactions t
      WHERE t.user_id = '11111111-1111-1111-1111-111111111111'::uuid
      ORDER BY t.occurred_at DESC
      OFFSET 3 LIMIT 1
    )
  ),
  ('eeeeeeee-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', 'custom', 100.00, NULL, true, NULL)
ON CONFLICT (id) DO NOTHING;

COMMIT;

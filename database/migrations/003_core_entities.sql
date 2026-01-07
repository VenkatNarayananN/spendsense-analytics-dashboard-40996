BEGIN;

-- ---------------------------------------------------------------------------
-- 003_core_entities.sql
-- Core entities for SpendSense analytics dashboard (PostgreSQL / Supabase compatible)
--
-- Creates/updates:
--  - public.users
--  - public.transactions
--  - public.alerts
--
-- Notes:
-- - Uses UUID primary keys with gen_random_uuid() (pgcrypto).
-- - Uses citext for case-insensitive email uniqueness (preferred on Supabase).
-- - Adds updated_at triggers using public.set_updated_at() (created in 001_init.sql).
-- - Does NOT seed data.
-- ---------------------------------------------------------------------------

-- Required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

-- ---------------------------------------------------------------------------
-- 1) users
-- Requirements: id, email, name, avatar_url, created_at (+ updated_at)
-- ---------------------------------------------------------------------------

-- Ensure email is case-insensitive (citext) while preserving existing data.
-- This is idempotent: it will only alter type if column exists and isn't already citext.
ALTER TABLE IF EXISTS public.users
  ALTER COLUMN email TYPE citext
  USING email::citext;

-- Add "name" column (requested core field). Existing schema uses full_name; keep it for
-- backward compatibility and add a new "name" column.
ALTER TABLE IF EXISTS public.users
  ADD COLUMN IF NOT EXISTS name text NULL;

-- Ensure core columns exist (safely, without removing existing columns).
ALTER TABLE IF EXISTS public.users
  ADD COLUMN IF NOT EXISTS avatar_url text NULL,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- Ensure NOT NULL where appropriate.
ALTER TABLE IF EXISTS public.users
  ALTER COLUMN email SET NOT NULL;

-- Ensure case-insensitive uniqueness on email.
-- If a prior UNIQUE(email) constraint exists, it remains valid with citext.
-- Add a named constraint if missing.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'users_email_unique'
      AND conrelid = 'public.users'::regclass
  ) THEN
    ALTER TABLE public.users
      ADD CONSTRAINT users_email_unique UNIQUE (email);
  END IF;
END
$$;

-- Comments to aid future documentation.
COMMENT ON TABLE public.users IS 'Application users (profile data).';
COMMENT ON COLUMN public.users.id IS 'Primary key (UUID).';
COMMENT ON COLUMN public.users.email IS 'User email address (case-insensitive via citext).';
COMMENT ON COLUMN public.users.name IS 'Display name for the user.';
COMMENT ON COLUMN public.users.avatar_url IS 'Optional avatar image URL.';
COMMENT ON COLUMN public.users.created_at IS 'Row creation timestamp (UTC).';
COMMENT ON COLUMN public.users.updated_at IS 'Row last update timestamp (UTC), maintained by trigger.';

-- updated_at trigger (reuse existing function created in 001_init.sql).
DROP TRIGGER IF EXISTS trg_users_set_updated_at ON public.users;
CREATE TRIGGER trg_users_set_updated_at
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2) transactions
-- Requirements: id, user_id, amount, currency, category, merchant,
--               transaction_date, notes (+ created_at, updated_at)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  amount numeric(12,2) NOT NULL,
  currency char(3) NOT NULL,
  category text NULL,
  merchant text NULL,
  transaction_date timestamptz NOT NULL,
  notes text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT transactions_user_fk
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE
);

-- Comments
COMMENT ON TABLE public.transactions IS 'Financial transactions imported/entered for a user.';
COMMENT ON COLUMN public.transactions.id IS 'Primary key (UUID).';
COMMENT ON COLUMN public.transactions.user_id IS 'Owning user id (FK to users).';
COMMENT ON COLUMN public.transactions.amount IS 'Transaction amount (signed).';
COMMENT ON COLUMN public.transactions.currency IS 'ISO-4217 currency code (e.g., USD).';
COMMENT ON COLUMN public.transactions.category IS 'Freeform category label for analytics.';
COMMENT ON COLUMN public.transactions.merchant IS 'Merchant/payee name.';
COMMENT ON COLUMN public.transactions.transaction_date IS 'When the transaction occurred (timestamp with timezone).';
COMMENT ON COLUMN public.transactions.notes IS 'Optional user notes.';
COMMENT ON COLUMN public.transactions.created_at IS 'Row creation timestamp (UTC).';
COMMENT ON COLUMN public.transactions.updated_at IS 'Row last update timestamp (UTC), maintained by trigger.';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_transactions_user_id
  ON public.transactions (user_id);

CREATE INDEX IF NOT EXISTS idx_transactions_transaction_date_desc
  ON public.transactions (transaction_date DESC);

CREATE INDEX IF NOT EXISTS idx_transactions_category
  ON public.transactions (category);

CREATE INDEX IF NOT EXISTS idx_transactions_merchant
  ON public.transactions (merchant);

-- updated_at trigger
DROP TRIGGER IF EXISTS trg_transactions_set_updated_at ON public.transactions;
CREATE TRIGGER trg_transactions_set_updated_at
BEFORE UPDATE ON public.transactions
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 3) alerts
-- Requirements: id, user_id, type, severity, message, status, created_at
--               (+ updated_at)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  type text NOT NULL,
  severity text NOT NULL DEFAULT 'info',
  message text NOT NULL,
  status text NOT NULL DEFAULT 'unread',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT alerts_user_fk
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
  CONSTRAINT alerts_severity_check
    CHECK (severity IN ('info', 'warning', 'critical')),
  CONSTRAINT alerts_status_check
    CHECK (status IN ('unread', 'read', 'archived'))
);

-- Comments
COMMENT ON TABLE public.alerts IS 'User-facing alerts generated by rules, anomalies, or system events.';
COMMENT ON COLUMN public.alerts.id IS 'Primary key (UUID).';
COMMENT ON COLUMN public.alerts.user_id IS 'Owning user id (FK to users).';
COMMENT ON COLUMN public.alerts.type IS 'Alert type identifier (e.g., anomaly, budget, system).';
COMMENT ON COLUMN public.alerts.severity IS 'Alert severity level (info, warning, critical).';
COMMENT ON COLUMN public.alerts.message IS 'Human-readable alert message.';
COMMENT ON COLUMN public.alerts.status IS 'Alert lifecycle status (unread, read, archived).';
COMMENT ON COLUMN public.alerts.created_at IS 'Row creation timestamp (UTC).';
COMMENT ON COLUMN public.alerts.updated_at IS 'Row last update timestamp (UTC), maintained by trigger.';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_alerts_user_id
  ON public.alerts (user_id);

CREATE INDEX IF NOT EXISTS idx_alerts_created_at_desc
  ON public.alerts (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_alerts_status
  ON public.alerts (status);

-- updated_at trigger
DROP TRIGGER IF EXISTS trg_alerts_set_updated_at ON public.alerts;
CREATE TRIGGER trg_alerts_set_updated_at
BEFORE UPDATE ON public.alerts
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

COMMIT;

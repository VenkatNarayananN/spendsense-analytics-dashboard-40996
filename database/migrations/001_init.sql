BEGIN;

-- SpendSense schema (PostgreSQL / Supabase compatible)
-- Uses pgcrypto for gen_random_uuid()

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- Helper: updated_at trigger function
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- 1) users
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id uuid NULL,
  email text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  role text NOT NULL DEFAULT 'user',
  full_name text NULL,
  avatar_url text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT users_email_unique UNIQUE (email),
  CONSTRAINT users_role_check CHECK (role IN ('admin', 'user'))
);

-- Optional Supabase Auth linkage (nullable)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.schemata
    WHERE schema_name = 'auth'
  ) THEN
    BEGIN
      ALTER TABLE public.users
        ADD CONSTRAINT users_auth_user_id_fk
        FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
    EXCEPTION
      WHEN duplicate_object THEN
        -- constraint already exists
        NULL;
    END;
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_users_is_active ON public.users (is_active);
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users (role);

DROP TRIGGER IF EXISTS trg_users_set_updated_at ON public.users;
CREATE TRIGGER trg_users_set_updated_at
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2) categories
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NULL,
  name text NOT NULL,
  type text NOT NULL,
  color text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT categories_type_check CHECK (type IN ('expense', 'income')),
  CONSTRAINT categories_user_fk FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE
);

-- Unique constraint on (coalesce(user_id, zero_uuid), name, type)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'categories_unique_user_or_global_name_type'
  ) THEN
    ALTER TABLE public.categories
      ADD CONSTRAINT categories_unique_user_or_global_name_type
      UNIQUE (
        (COALESCE(user_id, '00000000-0000-0000-0000-000000000000'::uuid)),
        name,
        type
      );
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_categories_user_id ON public.categories (user_id);
CREATE INDEX IF NOT EXISTS idx_categories_type ON public.categories (type);

DROP TRIGGER IF EXISTS trg_categories_set_updated_at ON public.categories;
CREATE TRIGGER trg_categories_set_updated_at
BEFORE UPDATE ON public.categories
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 3) budgets
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.budgets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  name text NOT NULL,
  limit_amount numeric(12,2) NOT NULL,
  period text NOT NULL,
  currency char(3) NOT NULL DEFAULT 'USD',
  category_id uuid NULL,
  start_date date NOT NULL,
  end_date date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT budgets_user_fk FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
  CONSTRAINT budgets_category_fk FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE SET NULL,
  CONSTRAINT budgets_period_check CHECK (period IN ('weekly', 'monthly', 'quarterly', 'yearly')),
  CONSTRAINT budgets_date_range_check CHECK (end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS idx_budgets_user_id ON public.budgets (user_id);
CREATE INDEX IF NOT EXISTS idx_budgets_user_period ON public.budgets (user_id, period);
CREATE INDEX IF NOT EXISTS idx_budgets_user_category ON public.budgets (user_id, category_id);

DROP TRIGGER IF EXISTS trg_budgets_set_updated_at ON public.budgets;
CREATE TRIGGER trg_budgets_set_updated_at
BEFORE UPDATE ON public.budgets
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 4) transactions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  amount numeric(12,2) NOT NULL,
  currency char(3) NOT NULL DEFAULT 'USD',
  occurred_at timestamptz NOT NULL,
  description text NULL,
  category_id uuid NULL,
  budget_id uuid NULL,
  status text NOT NULL DEFAULT 'posted',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT transactions_user_fk FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
  CONSTRAINT transactions_category_fk FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE SET NULL,
  CONSTRAINT transactions_budget_fk FOREIGN KEY (budget_id) REFERENCES public.budgets(id) ON DELETE SET NULL,
  CONSTRAINT transactions_status_check CHECK (status IN ('pending', 'posted', 'reconciled'))
);

CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions (user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_occurred_at ON public.transactions (occurred_at);
CREATE INDEX IF NOT EXISTS idx_transactions_category_id ON public.transactions (category_id);
CREATE INDEX IF NOT EXISTS idx_transactions_budget_id ON public.transactions (budget_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user_occurred_at_desc ON public.transactions (user_id, occurred_at DESC);

DROP TRIGGER IF EXISTS trg_transactions_set_updated_at ON public.transactions;
CREATE TRIGGER trg_transactions_set_updated_at
BEFORE UPDATE ON public.transactions
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 5) alerts
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  type text NOT NULL,
  threshold numeric(12,2) NULL,
  notified_at timestamptz NULL,
  is_active boolean NOT NULL DEFAULT true,
  related_transaction_id uuid NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT alerts_user_fk FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
  CONSTRAINT alerts_related_transaction_fk FOREIGN KEY (related_transaction_id) REFERENCES public.transactions(id) ON DELETE SET NULL,
  CONSTRAINT alerts_type_check CHECK (type IN ('budget_exceeded', 'new_transaction', 'custom'))
);

CREATE INDEX IF NOT EXISTS idx_alerts_user_id ON public.alerts (user_id);
CREATE INDEX IF NOT EXISTS idx_alerts_type ON public.alerts (type);
CREATE INDEX IF NOT EXISTS idx_alerts_is_active ON public.alerts (is_active);

DROP TRIGGER IF EXISTS trg_alerts_set_updated_at ON public.alerts;
CREATE TRIGGER trg_alerts_set_updated_at
BEFORE UPDATE ON public.alerts
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 6) audit_log
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_log (
  id bigserial PRIMARY KEY,
  table_name text NOT NULL,
  record_id uuid NULL,
  operation text NOT NULL,
  changed_at timestamptz NOT NULL DEFAULT now(),
  user_id uuid NULL,
  previous_data jsonb NULL,
  new_data jsonb NULL,
  CONSTRAINT audit_log_operation_check CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
  CONSTRAINT audit_log_user_fk FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_audit_log_table_name ON public.audit_log (table_name);
CREATE INDEX IF NOT EXISTS idx_audit_log_operation ON public.audit_log (operation);
CREATE INDEX IF NOT EXISTS idx_audit_log_changed_at_desc ON public.audit_log (changed_at DESC);

-- ---------------------------------------------------------------------------
-- Row Level Security placeholders (Supabase)
-- NOTE: Disabled by default. Uncomment and tailor for your project.
-- ---------------------------------------------------------------------------
-- -- Enable RLS:
-- ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.alerts ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
--
-- -- Example policy: users can read/update their own rows (requires auth_user_id to be set)
-- CREATE POLICY "Users can read own profile"
--   ON public.users
--   FOR SELECT
--   USING (auth.uid() = auth_user_id);
--
-- CREATE POLICY "Users can update own profile"
--   ON public.users
--   FOR UPDATE
--   USING (auth.uid() = auth_user_id)
--   WITH CHECK (auth.uid() = auth_user_id);
--
-- -- Example policy: users can manage their own transactions
-- CREATE POLICY "Users can manage own transactions"
--   ON public.transactions
--   FOR ALL
--   USING (EXISTS (SELECT 1 FROM public.users u WHERE u.id = transactions.user_id AND u.auth_user_id = auth.uid()))
--   WITH CHECK (EXISTS (SELECT 1 FROM public.users u WHERE u.id = transactions.user_id AND u.auth_user_id = auth.uid()));

COMMIT;

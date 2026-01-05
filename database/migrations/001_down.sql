BEGIN;

-- Drop in reverse dependency order
DROP TABLE IF EXISTS public.audit_log;
DROP TABLE IF EXISTS public.alerts;
DROP TABLE IF EXISTS public.transactions;
DROP TABLE IF EXISTS public.budgets;
DROP TABLE IF EXISTS public.categories;
DROP TABLE IF EXISTS public.users;

-- Triggers are dropped automatically with tables; drop function explicitly.
DROP FUNCTION IF EXISTS public.set_updated_at();

-- Extension optional to keep (commonly shared). Uncomment if you want to remove it.
-- DROP EXTENSION IF EXISTS pgcrypto;

COMMIT;

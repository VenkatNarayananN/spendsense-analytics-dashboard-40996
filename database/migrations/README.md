# Database Migrations (PostgreSQL / Supabase compatible)

This folder contains SQL migrations for the SpendSense database container.

## Files

- `001_init.sql`  
  Creates extensions, tables, constraints, indexes, and `updated_at` triggers. Includes commented Row Level Security (RLS) policy examples for Supabase (disabled by default).

- `002_seed.sql`  
  Inserts demo users, global & user categories, budgets, ~120 transactions for the first demo user over the last 90 days, and several alerts.

- `001_down.sql`  
  Drops schema objects in reverse order (use with care).

## Apply migrations (this environment)

This repo’s database container includes `db_connection.txt` with a ready-to-use `psql postgresql://...` connection string.

From the `database/` directory:

```bash
# connect string reference
cat db_connection.txt

# apply schema
psql "$(cat db_connection.txt)" -v ON_ERROR_STOP=1 -f migrations/001_init.sql

# apply seed data
psql "$(cat db_connection.txt)" -v ON_ERROR_STOP=1 -f migrations/002_seed.sql
```

## Rollback (drops tables)

```bash
psql "$(cat db_connection.txt)" -v ON_ERROR_STOP=1 -f migrations/001_down.sql
```

## Notes for Supabase

- `gen_random_uuid()` requires `pgcrypto` (enabled in `001_init.sql`).
- RLS is **not enabled** by default in these migrations. If you deploy to Supabase and want client-side access, you typically enable RLS and add policies (examples are included as comments in `001_init.sql`).
- `users.auth_user_id` is an optional link to `auth.users(id)` on Supabase. The FK constraint is added only if the `auth` schema exists.

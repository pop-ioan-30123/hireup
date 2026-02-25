# HireUp Database (PostgreSQL)

Acest folder conține schema inițială pentru autentificare/înregistrare, audit și securitate.

## Migrations

Rulare în ordine:

1. `db/migrations/001_extensions.sql`
2. `db/migrations/002_schema_core.sql`
3. `db/migrations/003_audit_security.sql`
4. `db/migrations/004_profile_visibility_and_avatar.sql`
5. `db/migrations/005_two_factor_auth.sql`
6. `db/migrations/006_two_factor_backup_codes.sql`
7. `db/migrations/007_account_gender_birth_date.sql` *(deprecated, no-op)*
8. `db/migrations/008_profile_visibility_gender_birth_job_title.sql` *(deprecated, no-op)*
9. `db/migrations/009_reconcile_consolidated_profile_columns.sql` *(compatibility for older DBs)*

Exemplu:

```bash
psql "$DATABASE_URL" -f db/migrations/001_extensions.sql
psql "$DATABASE_URL" -f db/migrations/002_schema_core.sql
psql "$DATABASE_URL" -f db/migrations/003_audit_security.sql
psql "$DATABASE_URL" -f db/migrations/004_profile_visibility_and_avatar.sql
psql "$DATABASE_URL" -f db/migrations/005_two_factor_auth.sql
psql "$DATABASE_URL" -f db/migrations/006_two_factor_backup_codes.sql
psql "$DATABASE_URL" -f db/migrations/007_account_gender_birth_date.sql
psql "$DATABASE_URL" -f db/migrations/008_profile_visibility_gender_birth_job_title.sql
psql "$DATABASE_URL" -f db/migrations/009_reconcile_consolidated_profile_columns.sql
```

## Ce acoperă schema

- Conturi (`app_user`) pentru User și Company.
- Date profil user (`user_profile`) și contact HR pentru companie (`company_hr_contact`).
- Atașamente (`file_attachment`) pentru ID/CV (doar metadata + checksum + storage key).
- Consimțăminte GDPR/Terms/Privacy (`user_consent`) cu versiune și timestamp.
- Sesiuni autentificare (`auth_session`) cu refresh token hash.
- Audit complet `INSERT/UPDATE/DELETE` prin trigger generic (`audit_log`).
- Evenimente de securitate aplicație (`security_event_log`).

## Măsuri de securitate recomandate (obligatorii în backend)

1. **Parole:** stochează doar hash Argon2id (niciodată plaintext).
2. **Token-uri:** salvează doar hash pentru refresh token în `auth_session`.
3. **Fișiere:** stochează fișiere în object storage criptat; în DB doar metadata.
4. **Criptare transport:** conexiune DB doar cu TLS.
5. **Criptare at-rest:** activează la nivel de disc/volum + KMS pentru chei.
6. **Least privilege:** user aplicație fără permisiuni DDL și fără `UPDATE/DELETE` pe audit log.
7. **Audit context:** la fiecare request setează în sesiunea SQL:
   - `app.current_user_id`
   - `app.current_user_email`
   - `app.current_ip`
   - `app.current_user_agent`
   - `app.request_id`

## Exemplu setare context audit pe request

```sql
SELECT set_config('app.current_user_id', '00000000-0000-0000-0000-000000000000', true);
SELECT set_config('app.current_user_email', 'user@example.com', true);
SELECT set_config('app.current_ip', '203.0.113.20', true);
SELECT set_config('app.current_user_agent', 'HireUpApi/1.0', true);
SELECT set_config('app.request_id', '11111111-1111-1111-1111-111111111111', true);
```

## Retenție loguri (recomandare)

- `audit_log`: 12–24 luni (în funcție de conformitate).
- `security_event_log`: 24 luni pentru evenimente severe.
- Arhivează periodic în storage WORM sau bucket imutabil.

## Notă importantă

Acest repo este frontend Flutter. Pentru protecție reală, trebuie un backend API care:

- validează inputul server-side,
- aplică rate-limiting și lockout,
- aplică RBAC,
- scrie explicit în `security_event_log` la tentative suspecte.

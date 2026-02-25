# HireUp Backend (NestJS)

Backend API for authentication and registration, integrated with the PostgreSQL schema in `../db/migrations`.

## 1) Install

```bash
cd backend
npm install
```

## 2) Configure env

```bash
cp .env.example .env
```

Required variables:

- `DATABASE_URL`
- `JWT_ACCESS_SECRET`
- `JWT_ACCESS_EXPIRES_IN`
- `REFRESH_TOKEN_DAYS`
- `PORT`

Optional variables:

- `FOUNDER_BADGE_EMAILS` (comma-separated e-mails that receive the `Founder` badge)
- `EMAIL_VERIFICATION_BASE_URL` (base URL used for verification links)
- `EMAIL_VERIFICATION_TTL_HOURS` (verification token validity)
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_SECURE`
- `SMTP_USER`
- `SMTP_PASS`
- `SMTP_FROM`
- `EMAIL_VERIFICATION_BASE_URL` (base URL used in verification links, e.g. `http://localhost:4000`)
- `EMAIL_VERIFICATION_TTL_HOURS` (default `24`)
- `SMTP_HOST`
- `SMTP_PORT` (default `587`)
- `SMTP_SECURE` (`true`/`false`)
- `SMTP_USER`
- `SMTP_PASS`
- `SMTP_FROM`

## 3) Run DB migrations

```bash
npm run db:migrate
```

## 4) Start API

```bash
npm run start:dev
```

Health endpoint:

- `GET /health`

## Auth endpoints

- `POST /auth/register-user`
- `POST /auth/register-company`
- `POST /auth/login`
- `GET /auth/verify-email?token=...`
- `POST /auth/verification/resend` (authenticated; available after 3 days if account is still unverified)

## Security notes

- Uses Argon2id for password hashing.
- Stores refresh tokens only as SHA-256 hash in DB.
- Captures request context (`requestId`, `ipAddress`, `userAgent`) and forwards it to PostgreSQL session settings for audit triggers.
- Writes explicit login/registration events to `security_event_log`.
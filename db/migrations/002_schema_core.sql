-- Core schema for HireUp registration/auth domain.

CREATE TYPE account_type AS ENUM ('user', 'company');
CREATE TYPE account_status AS ENUM ('pending_verification', 'active', 'suspended', 'deleted');
CREATE TYPE attachment_type AS ENUM ('id_document', 'cv');
CREATE TYPE consent_type AS ENUM ('gdpr_registration', 'terms_of_service', 'privacy_policy');

CREATE TABLE app_user (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_type account_type NOT NULL,
    status account_status NOT NULL DEFAULT 'pending_verification',
    email CITEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    first_name TEXT,
    last_name TEXT,
    phone_e164 TEXT,
    gender TEXT CHECK (gender IS NULL OR gender IN ('male', 'female')),
    birth_date DATE,
    is_email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    failed_login_attempts INTEGER NOT NULL DEFAULT 0,
    last_failed_login_at TIMESTAMPTZ,
    locked_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE company (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_user_id UUID NOT NULL UNIQUE REFERENCES app_user(id) ON DELETE CASCADE,
    legal_name TEXT NOT NULL,
    country_code CHAR(2) NOT NULL DEFAULT 'RO',
    county TEXT,
    city TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_profile (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES app_user(id) ON DELETE CASCADE,
    job_title TEXT NOT NULL,
    years_experience SMALLINT NOT NULL CHECK (years_experience >= 0 AND years_experience <= 80),
    education_level TEXT NOT NULL,
    education_institution TEXT NOT NULL,
    country TEXT NOT NULL,
    county TEXT NOT NULL,
    city TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE company_hr_contact (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES company(id) ON DELETE CASCADE,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email CITEXT NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(company_id, email)
);

CREATE TABLE file_attachment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES app_user(id) ON DELETE CASCADE,
    company_id UUID REFERENCES company(id) ON DELETE CASCADE,
    attachment_type attachment_type NOT NULL,
    original_file_name TEXT NOT NULL,
    mime_type TEXT,
    file_size_bytes BIGINT NOT NULL CHECK (file_size_bytes > 0),
    storage_key TEXT NOT NULL UNIQUE,
    sha256_checksum CHAR(64) NOT NULL,
    uploaded_by UUID NOT NULL REFERENCES app_user(id) ON DELETE RESTRICT,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    encrypted_at_rest BOOLEAN NOT NULL DEFAULT TRUE,
    CHECK (
      (user_id IS NOT NULL AND company_id IS NULL) OR
      (user_id IS NULL AND company_id IS NOT NULL)
    )
);

CREATE TABLE user_consent (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    consent_type consent_type NOT NULL,
    accepted BOOLEAN NOT NULL,
    consent_version TEXT NOT NULL,
    locale TEXT NOT NULL,
    ip_address INET,
    user_agent TEXT,
    accepted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, consent_type, consent_version)
);

CREATE TABLE auth_session (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    refresh_token_hash TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    revoked_reason TEXT,
    ip_address INET,
    user_agent TEXT
);

CREATE INDEX idx_app_user_email ON app_user(email);
CREATE INDEX idx_app_user_status ON app_user(status);
CREATE INDEX idx_user_profile_location ON user_profile(country, county, city);
CREATE INDEX idx_company_hr_contact_company ON company_hr_contact(company_id);
CREATE INDEX idx_file_attachment_user ON file_attachment(user_id);
CREATE INDEX idx_file_attachment_company ON file_attachment(company_id);
CREATE INDEX idx_user_consent_user ON user_consent(user_id);
CREATE INDEX idx_auth_session_user ON auth_session(user_id);
CREATE INDEX idx_auth_session_active ON auth_session(user_id, expires_at) WHERE revoked_at IS NULL;

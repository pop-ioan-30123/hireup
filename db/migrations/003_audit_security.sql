-- Audit and security-focused structures and triggers.

CREATE TABLE audit_log (
    id BIGSERIAL PRIMARY KEY,
    event_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actor_user_id UUID,
    actor_email TEXT,
    action TEXT NOT NULL,
    table_name TEXT NOT NULL,
    record_pk TEXT,
    old_data JSONB,
    new_data JSONB,
    ip_address INET,
    user_agent TEXT,
    request_id UUID
);

CREATE INDEX idx_audit_log_event_ts ON audit_log(event_ts DESC);
CREATE INDEX idx_audit_log_actor_user ON audit_log(actor_user_id);
CREATE INDEX idx_audit_log_table_action ON audit_log(table_name, action);

CREATE TABLE security_event_log (
    id BIGSERIAL PRIMARY KEY,
    event_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    user_id UUID REFERENCES app_user(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    request_id UUID
);

CREATE INDEX idx_security_event_log_ts ON security_event_log(event_ts DESC);
CREATE INDEX idx_security_event_log_type ON security_event_log(event_type);
CREATE INDEX idx_security_event_log_user ON security_event_log(user_id);

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_app_user_updated_at
BEFORE UPDATE ON app_user
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_company_updated_at
BEFORE UPDATE ON company
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_user_profile_updated_at
BEFORE UPDATE ON user_profile
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_company_hr_contact_updated_at
BEFORE UPDATE ON company_hr_contact
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE FUNCTION write_audit_log()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_actor_user_id UUID;
  v_actor_email TEXT;
  v_ip INET;
  v_user_agent TEXT;
  v_request_id UUID;
  v_record_pk TEXT;
BEGIN
  BEGIN
    v_actor_user_id := NULLIF(current_setting('app.current_user_id', true), '')::UUID;
  EXCEPTION WHEN others THEN
    v_actor_user_id := NULL;
  END;

  v_actor_email := NULLIF(current_setting('app.current_user_email', true), '');

  BEGIN
    v_ip := NULLIF(current_setting('app.current_ip', true), '')::INET;
  EXCEPTION WHEN others THEN
    v_ip := NULL;
  END;

  v_user_agent := NULLIF(current_setting('app.current_user_agent', true), '');

  BEGIN
    v_request_id := NULLIF(current_setting('app.request_id', true), '')::UUID;
  EXCEPTION WHEN others THEN
    v_request_id := NULL;
  END;

  IF TG_OP = 'DELETE' THEN
    v_record_pk := COALESCE(OLD.id::TEXT, NULL);
  ELSE
    v_record_pk := COALESCE(NEW.id::TEXT, NULL);
  END IF;

  INSERT INTO audit_log (
    actor_user_id,
    actor_email,
    action,
    table_name,
    record_pk,
    old_data,
    new_data,
    ip_address,
    user_agent,
    request_id
  )
  VALUES (
    v_actor_user_id,
    v_actor_email,
    TG_OP,
    TG_TABLE_NAME,
    v_record_pk,
    CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END,
    v_ip,
    v_user_agent,
    v_request_id
  );

  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

CREATE TRIGGER trg_audit_app_user
AFTER INSERT OR UPDATE OR DELETE ON app_user
FOR EACH ROW EXECUTE FUNCTION write_audit_log();

CREATE TRIGGER trg_audit_company
AFTER INSERT OR UPDATE OR DELETE ON company
FOR EACH ROW EXECUTE FUNCTION write_audit_log();

CREATE TRIGGER trg_audit_user_profile
AFTER INSERT OR UPDATE OR DELETE ON user_profile
FOR EACH ROW EXECUTE FUNCTION write_audit_log();

CREATE TRIGGER trg_audit_company_hr_contact
AFTER INSERT OR UPDATE OR DELETE ON company_hr_contact
FOR EACH ROW EXECUTE FUNCTION write_audit_log();

CREATE TRIGGER trg_audit_file_attachment
AFTER INSERT OR UPDATE OR DELETE ON file_attachment
FOR EACH ROW EXECUTE FUNCTION write_audit_log();

CREATE TRIGGER trg_audit_user_consent
AFTER INSERT OR UPDATE OR DELETE ON user_consent
FOR EACH ROW EXECUTE FUNCTION write_audit_log();

CREATE TRIGGER trg_audit_auth_session
AFTER INSERT OR UPDATE OR DELETE ON auth_session
FOR EACH ROW EXECUTE FUNCTION write_audit_log();

-- Keep audit logs append-only for non-admin application roles.
REVOKE UPDATE, DELETE ON audit_log FROM PUBLIC;
REVOKE UPDATE, DELETE ON security_event_log FROM PUBLIC;

-- Fix audit trigger function to resolve record primary key dynamically per table.

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
  v_row_data JSONB;
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

  v_row_data := CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;

  SELECT string_agg(
           format('%s=%s', a.attname, COALESCE(v_row_data ->> a.attname, 'NULL')),
           ', ' ORDER BY ord.ordinality
         )
    INTO v_record_pk
  FROM pg_index i
  JOIN unnest(i.indkey) WITH ORDINALITY AS ord(attnum, ordinality) ON TRUE
  JOIN pg_attribute a
    ON a.attrelid = i.indrelid
   AND a.attnum = ord.attnum
  WHERE i.indrelid = TG_RELID
    AND i.indisprimary;

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
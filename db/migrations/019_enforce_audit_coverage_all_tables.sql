-- Enforce audit/update trigger coverage for all application tables.

CREATE OR REPLACE FUNCTION ensure_audit_trigger_for_table(p_table regclass)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_trigger_name TEXT;
BEGIN
  v_trigger_name := format(
    'trg_audit_%s',
    replace(replace(p_table::text, '.', '_'), '"', '')
  );

  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgrelid = p_table
      AND tgname = v_trigger_name
      AND NOT tgisinternal
  ) THEN
    EXECUTE format(
      'CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE ON %s FOR EACH ROW EXECUTE FUNCTION write_audit_log()',
      v_trigger_name,
      p_table
    );
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION ensure_updated_at_trigger_for_table(p_table regclass)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_schema TEXT;
  v_table TEXT;
  v_trigger_name TEXT;
BEGIN
  v_schema := split_part(p_table::text, '.', 1);
  v_table := split_part(p_table::text, '.', 2);

  IF v_table = '' THEN
    v_table := v_schema;
    v_schema := 'public';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns c
    WHERE c.table_schema = replace(v_schema, '"', '')
      AND c.table_name = replace(v_table, '"', '')
      AND c.column_name = 'updated_at'
  ) THEN
    RETURN;
  END IF;

  v_trigger_name := format(
    'trg_%s_updated_at',
    replace(replace(p_table::text, '.', '_'), '"', '')
  );

  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgrelid = p_table
      AND tgname = v_trigger_name
      AND NOT tgisinternal
  ) THEN
    EXECUTE format(
      'CREATE TRIGGER %I BEFORE UPDATE ON %s FOR EACH ROW EXECUTE FUNCTION set_updated_at()',
      v_trigger_name,
      p_table
    );
  END IF;
END;
$$;

DO $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT c.oid::regclass AS table_ref
    FROM pg_class c
    INNER JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r'
      AND n.nspname = 'public'
      AND c.relname NOT IN ('audit_log', 'security_event_log')
  LOOP
    PERFORM ensure_audit_trigger_for_table(rec.table_ref);
    PERFORM ensure_updated_at_trigger_for_table(rec.table_ref);
  END LOOP;
END;
$$;

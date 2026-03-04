-- Re-enable all user-defined triggers in public schema tables.

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
  LOOP
    EXECUTE format('ALTER TABLE %s ENABLE TRIGGER USER', rec.table_ref);
  END LOOP;
END;
$$;
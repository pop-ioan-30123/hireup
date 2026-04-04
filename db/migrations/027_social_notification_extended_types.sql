-- Migration 027: extend social notification types for actor + recipient events.

DO $$
DECLARE
  notification_constraint_name text;
BEGIN
  SELECT conname
    INTO notification_constraint_name
  FROM pg_constraint
  WHERE conrelid = 'social_notification'::regclass
    AND contype = 'c'
    AND pg_get_constraintdef(oid) ILIKE '%notification_type%'
  LIMIT 1;

  IF notification_constraint_name IS NOT NULL THEN
    EXECUTE format(
      'ALTER TABLE social_notification DROP CONSTRAINT IF EXISTS %I',
      notification_constraint_name
    );
  END IF;
END $$;

ALTER TABLE social_notification
  ADD CONSTRAINT chk_social_notification_notification_type
  CHECK (
    notification_type IN (
      'follow',
      'unfollow',
      'contact',
      'follow_received',
      'follow_sent',
      'unfollow_received',
      'unfollow_sent',
      'contact_created',
      'contact_removed'
    )
  );

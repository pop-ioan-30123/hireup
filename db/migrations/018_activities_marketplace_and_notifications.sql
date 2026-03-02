-- Activities marketplace domain + notifications for no-provider deadlines.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'activity_status') THEN
    CREATE TYPE activity_status AS ENUM ('open', 'assigned', 'closed', 'cancelled');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS activity (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  provider_user_id UUID REFERENCES app_user(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  amount_ron NUMERIC(12, 2) NOT NULL CHECK (amount_ron > 0),
  country TEXT NOT NULL,
  county TEXT NOT NULL,
  city TEXT NOT NULL,
  duration_hours INTEGER NOT NULL CHECK (duration_hours > 0),
  start_at TIMESTAMPTZ NOT NULL,
  is_recurring BOOLEAN NOT NULL DEFAULT FALSE,
  recurrence_pattern TEXT,
  recurrence_days SMALLINT[] NOT NULL DEFAULT '{}',
  recurrence_label TEXT,
  meal_included BOOLEAN NOT NULL DEFAULT FALSE,
  status activity_status NOT NULL DEFAULT 'open',
  close_reason TEXT,
  warning_sent_at TIMESTAMPTZ,
  provider_assigned_at TIMESTAMPTZ,
  closed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_activity_recurrence_days_valid CHECK (
    recurrence_days <@ ARRAY[1,2,3,4,5,6,7]::SMALLINT[]
  ),
  CONSTRAINT chk_activity_meal_duration CHECK (
    meal_included = FALSE OR duration_hours > 4
  )
);

CREATE TABLE IF NOT EXISTS activity_notification (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  activity_id UUID REFERENCES activity(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL,
  notification_type TEXT NOT NULL,
  icon_key TEXT NOT NULL,
  sent_date DATE NOT NULL,
  sent_time TIME NOT NULL,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_activity_notification_once_per_type
  ON activity_notification(activity_id, user_id, notification_type)
  WHERE activity_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_activity_owner ON activity(owner_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_provider ON activity(provider_user_id, start_at ASC);
CREATE INDEX IF NOT EXISTS idx_activity_marketplace ON activity(status, start_at ASC)
  WHERE provider_user_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_activity_notification_user ON activity_notification(user_id, sent_at DESC);

DROP TRIGGER IF EXISTS trg_activity_updated_at ON activity;
CREATE TRIGGER trg_activity_updated_at
BEFORE UPDATE ON activity
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- Add service categorization fields for marketplace activities.

ALTER TABLE activity
  ADD COLUMN IF NOT EXISTS section TEXT NOT NULL DEFAULT 'services',
  ADD COLUMN IF NOT EXISTS category_key TEXT NOT NULL DEFAULT 'other_services',
  ADD COLUMN IF NOT EXISTS subcategory_key TEXT;

UPDATE activity
SET section = COALESCE(NULLIF(BTRIM(section), ''), 'services'),
    category_key = COALESCE(NULLIF(BTRIM(category_key), ''), 'other_services')
WHERE section IS NULL
   OR BTRIM(section) = ''
   OR category_key IS NULL
   OR BTRIM(category_key) = '';

ALTER TABLE activity
  DROP CONSTRAINT IF EXISTS chk_activity_section;

ALTER TABLE activity
  ADD CONSTRAINT chk_activity_section
  CHECK (section = 'services');

CREATE INDEX IF NOT EXISTS idx_activity_category_key
  ON activity(category_key);

CREATE INDEX IF NOT EXISTS idx_activity_location_category
  ON activity(county, city, category_key);
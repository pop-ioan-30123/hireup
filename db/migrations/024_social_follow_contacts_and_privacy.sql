-- Migration 024: Follow system, contacts system, privacy settings, and message requests

-- ============================================================
-- 1. Follow system
-- ============================================================
CREATE TABLE IF NOT EXISTS user_follow (
  follower_user_id  UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  following_user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (follower_user_id, following_user_id),
  CHECK (follower_user_id <> following_user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_follow_follower  ON user_follow(follower_user_id);
CREATE INDEX IF NOT EXISTS idx_user_follow_following ON user_follow(following_user_id);

-- ============================================================
-- 2. Contacts system
-- ============================================================
CREATE TABLE IF NOT EXISTS user_contact (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_user_id UUID        NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  target_user_id    UUID        NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  status            TEXT        NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (requester_user_id, target_user_id),
  CHECK (requester_user_id <> target_user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_contact_requester ON user_contact(requester_user_id);
CREATE INDEX IF NOT EXISTS idx_user_contact_target    ON user_contact(target_user_id);

-- ============================================================
-- 3. Privacy settings per user
-- ============================================================
CREATE TABLE IF NOT EXISTS user_privacy_settings (
  user_id              UUID    PRIMARY KEY REFERENCES app_user(id) ON DELETE CASCADE,
  messages_privacy     TEXT    NOT NULL DEFAULT 'everyone'
                       CHECK (messages_privacy IN ('everyone', 'contacts', 'contacts_and_followers')),
  show_follower_count  BOOLEAN NOT NULL DEFAULT TRUE,
  show_contact_count   BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 4. Message conversations: add request_status for message requests
-- ============================================================
ALTER TABLE message_conversation_member
  ADD COLUMN IF NOT EXISTS request_status TEXT NOT NULL DEFAULT 'active'
  CHECK (request_status IN ('active', 'request'));

CREATE INDEX IF NOT EXISTS idx_mcm_request_status
  ON message_conversation_member(request_status)
  WHERE request_status = 'request';

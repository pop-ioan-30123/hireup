-- Messaging domain: direct messages + groups + encrypted message payload storage.

CREATE TABLE IF NOT EXISTS message_conversation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_type TEXT NOT NULL CHECK (conversation_type IN ('dm', 'group')),
  title TEXT,
  created_by_user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE RESTRICT,
  dm_user_low UUID REFERENCES app_user(id) ON DELETE CASCADE,
  dm_user_high UUID REFERENCES app_user(id) ON DELETE CASCADE,
  last_message_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_message_conversation_dm_shape CHECK (
    (
      conversation_type = 'dm' AND
      title IS NULL AND
      dm_user_low IS NOT NULL AND
      dm_user_high IS NOT NULL AND
      dm_user_low <> dm_user_high
    )
    OR
    (
      conversation_type = 'group' AND
      dm_user_low IS NULL AND
      dm_user_high IS NULL
    )
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_message_conversation_dm_pair
  ON message_conversation(dm_user_low, dm_user_high)
  WHERE conversation_type = 'dm';

CREATE INDEX IF NOT EXISTS idx_message_conversation_last_message
  ON message_conversation(last_message_at DESC NULLS LAST, created_at DESC);

CREATE TABLE IF NOT EXISTS message_conversation_member (
  conversation_id UUID NOT NULL REFERENCES message_conversation(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_read_at TIMESTAMPTZ,
  last_read_message_id UUID,
  removed_at TIMESTAMPTZ,
  PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_message_member_user_active
  ON message_conversation_member(user_id, joined_at DESC)
  WHERE removed_at IS NULL;

CREATE TABLE IF NOT EXISTS message_entry (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES message_conversation(id) ON DELETE CASCADE,
  sender_user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE RESTRICT,
  message_kind TEXT NOT NULL DEFAULT 'text' CHECK (message_kind IN ('text', 'system')),
  ciphertext TEXT NOT NULL,
  algorithm TEXT NOT NULL DEFAULT 'xchacha20poly1305',
  nonce TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  edited_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_message_entry_conversation_created
  ON message_entry(conversation_id, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_message_entry_sender_created
  ON message_entry(sender_user_id, created_at DESC);

ALTER TABLE message_conversation_member
  ADD CONSTRAINT fk_message_member_last_read
  FOREIGN KEY (last_read_message_id)
  REFERENCES message_entry(id)
  ON DELETE SET NULL;

DROP TRIGGER IF EXISTS trg_message_conversation_updated_at ON message_conversation;
CREATE TRIGGER trg_message_conversation_updated_at
BEFORE UPDATE ON message_conversation
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
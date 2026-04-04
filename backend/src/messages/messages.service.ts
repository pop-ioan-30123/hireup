import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PoolClient } from 'pg';
import { DatabaseService } from '../database/database.service';
import {
  applyAuditSqlContext,
  AuditSqlContext,
} from '../database/audit-sql-context';
import { SocialService } from '../social/social.service';
import { CreateDmConversationDto } from './dto/create-dm-conversation.dto';
import { CreateGroupConversationDto } from './dto/create-group-conversation.dto';
import { ListMessagesQueryDto } from './dto/list-messages-query.dto';
import { PostMessageDto } from './dto/post-message.dto';
import { SetMessageReactionDto } from './dto/set-message-reaction.dto';
import { UpdateMessageDto } from './dto/update-message.dto';

type ConversationRow = {
  id: string;
  conversation_type: 'dm' | 'group';
  title: string | null;
  created_by_user_id: string;
  created_at: string;
  updated_at: string;
  last_message_at: string | null;
  last_message_preview: string | null;
  last_message_sender_user_id: string | null;
  role: 'owner' | 'admin' | 'member';
  unread_count: number;
  request_status: 'active' | 'request';
};

type ParticipantRow = {
  conversation_id: string;
  user_id: string;
  first_name: string | null;
  last_name: string | null;
  email: string;
  role: 'owner' | 'admin' | 'member';
  joined_at: string;
};

type MessageRow = {
  id: string;
  conversation_id: string;
  sender_user_id: string;
  message_kind: 'text' | 'system';
  ciphertext: string;
  algorithm: string;
  nonce: string | null;
  metadata: unknown;
  created_at: string;
  edited_at: string | null;
  deleted_at: string | null;
  delivered_at: string | null;
  read_at: string | null;
};

@Injectable()
export class MessagesService {
  private requestStatusSchemaEnsured = false;

  constructor(
    private readonly db: DatabaseService,
    private readonly socialService: SocialService,
  ) {}

  async listConversations(currentUserId: string, auditContext?: AuditSqlContext) {
    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        currentUserId,
        ...auditContext,
      });
      await this.ensureRequestStatusSchema(client);

      const conversationsRes = await client.query<ConversationRow>(
        `
          SELECT
            c.id,
            c.conversation_type,
            c.title,
            c.created_by_user_id,
            c.created_at::text,
            c.updated_at::text,
            c.last_message_at::text,
            (
              SELECT me.ciphertext
              FROM message_entry me
              WHERE me.conversation_id = c.id
                AND me.deleted_at IS NULL
                AND NOT (COALESCE(me.metadata -> 'hiddenForUserIds', '[]'::jsonb) ? ($2::text))
              ORDER BY me.created_at DESC
              LIMIT 1
            ) AS last_message_preview,
            (
              SELECT me.sender_user_id::text
              FROM message_entry me
              WHERE me.conversation_id = c.id
                AND me.deleted_at IS NULL
                AND NOT (COALESCE(me.metadata -> 'hiddenForUserIds', '[]'::jsonb) ? ($2::text))
              ORDER BY me.created_at DESC
              LIMIT 1
            ) AS last_message_sender_user_id,
            m.role,
              m.request_status,
            (
              SELECT COUNT(*)::int
              FROM message_entry me
              WHERE me.conversation_id = c.id
                AND me.deleted_at IS NULL
                AND me.created_at > COALESCE(m.last_read_at, to_timestamp(0))
                AND me.sender_user_id <> $1
            ) AS unread_count
          FROM message_conversation c
          INNER JOIN message_conversation_member m
            ON m.conversation_id = c.id
          WHERE m.user_id = $1
            AND m.removed_at IS NULL
          ORDER BY COALESCE(c.last_message_at, c.created_at) DESC
        `,
        [currentUserId, currentUserId],
      );

      const conversationIds = conversationsRes.rows.map((row) => row.id);
      const participantsByConversation = await this.loadParticipantsByConversation(
        client,
        conversationIds,
      );

        return {
          items: conversationsRes.rows.map((row) => ({
            id: row.id,
            type: row.conversation_type,
            title: row.title,
            createdByUserId: row.created_by_user_id,
            role: row.role,
            unreadCount: row.unread_count,
            requestStatus: row.request_status,
            createdAt: row.created_at,
            updatedAt: row.updated_at,
            lastMessageAt: row.last_message_at,
            lastMessagePreview: row.last_message_preview,
            lastMessageSenderUserId: row.last_message_sender_user_id,
            participants: participantsByConversation.get(row.id) ?? [],
          })),
        };
    });
  }

  async createDirectConversation(
    currentUserId: string,
    payload: CreateDmConversationDto,
    auditContext?: AuditSqlContext,
  ) {
    const otherUserId = payload.otherUserId;
    if (otherUserId === currentUserId) {
      throw new BadRequestException('Cannot create a DM with yourself');
    }

    const [dmUserLow, dmUserHigh] =
      currentUserId < otherUserId
        ? [currentUserId, otherUserId]
        : [otherUserId, currentUserId];

    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        currentUserId,
        ...auditContext,
      });
      await this.ensureRequestStatusSchema(client);

      await this.assertUsersExist(client, [otherUserId]);

      const existingRes = await client.query<{ id: string }>(
        `
          SELECT id
          FROM message_conversation
          WHERE conversation_type = 'dm'
            AND dm_user_low = $1
            AND dm_user_high = $2
          LIMIT 1
        `,
        [dmUserLow, dmUserHigh],
      );

      const existingId = existingRes.rows[0]?.id;
      if (existingId) {
        return this.getConversationForUser(client, currentUserId, existingId);
      }

      const conversationRes = await client.query<{ id: string }>(
        `
          INSERT INTO message_conversation(
            conversation_type,
            title,
            created_by_user_id,
            dm_user_low,
            dm_user_high
          )
          VALUES('dm', NULL, $1, $2, $3)
          RETURNING id
        `,
        [currentUserId, dmUserLow, dmUserHigh],
      );

      const conversationId = conversationRes.rows[0]?.id;
      if (!conversationId) {
        throw new ConflictException('Failed to create DM conversation');
      }

        const requestStatus = await this.socialService.canSendDirectMessage(
          currentUserId,
          otherUserId,
        );

        await client.query(
          `
            INSERT INTO message_conversation_member(conversation_id, user_id, role, request_status)
            VALUES
              ($1, $2, 'member', 'active'),
              ($1, $3, 'member', $4)
          `,
          [conversationId, currentUserId, otherUserId, requestStatus],
        );

      return this.getConversationForUser(client, currentUserId, conversationId);
    });
  }

  async createGroupConversation(
    currentUserId: string,
    payload: CreateGroupConversationDto,
    auditContext?: AuditSqlContext,
  ) {
    const title = payload.title.trim();
    if (title.length < 2) {
      throw new BadRequestException('Group title is too short');
    }

    const dedupedMemberIds = Array.from(new Set(payload.memberIds ?? []));
    const filteredMemberIds = dedupedMemberIds.filter((id) => id !== currentUserId);

    const totalMembers = filteredMemberIds.length + 1;
    if (totalMembers > 300) {
      throw new BadRequestException('Group cannot have more than 300 members');
    }

    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        currentUserId,
        ...auditContext,
      });

      await this.assertUsersExist(client, filteredMemberIds);

      const conversationRes = await client.query<{ id: string }>(
        `
          INSERT INTO message_conversation(
            conversation_type,
            title,
            created_by_user_id
          )
          VALUES('group', $1, $2)
          RETURNING id
        `,
        [title, currentUserId],
      );

      const conversationId = conversationRes.rows[0]?.id;
      if (!conversationId) {
        throw new ConflictException('Failed to create group conversation');
      }

      await client.query(
        `
          INSERT INTO message_conversation_member(conversation_id, user_id, role)
          VALUES($1, $2, 'owner')
        `,
        [conversationId, currentUserId],
      );

      if (filteredMemberIds.length > 0) {
        const valuesSql = filteredMemberIds
          .map((_, index) => `($1, $${index + 2}, 'member')`)
          .join(', ');

        await client.query(
          `
            INSERT INTO message_conversation_member(conversation_id, user_id, role)
            VALUES ${valuesSql}
          `,
          [conversationId, ...filteredMemberIds],
        );
      }

      return this.getConversationForUser(client, currentUserId, conversationId);
    });
  }

  async listMessages(
    currentUserId: string,
    conversationId: string,
    query: ListMessagesQueryDto,
    auditContext?: AuditSqlContext,
  ) {
    const limit = query.limit ?? 50;
      const before = query.before ? new Date(query.before) : null;
      if (before != null && Number.isNaN(before.getTime())) {
        throw new BadRequestException('Invalid "before" timestamp');
      }

    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        currentUserId,
        ...auditContext,
      });

      await this.assertConversationMembership(client, currentUserId, conversationId);

      const rowsRes = await client.query<MessageRow>(
        `
          SELECT
            id,
            conversation_id,
            sender_user_id,
            message_kind,
            ciphertext,
            algorithm,
            nonce,
            metadata,
            created_at::text,
            edited_at::text,
            deleted_at::text,
            created_at::text AS delivered_at,
            CASE
              WHEN (
                SELECT COUNT(*)
                FROM message_conversation_member recipient
                WHERE recipient.conversation_id = message_entry.conversation_id
                  AND recipient.user_id <> message_entry.sender_user_id
                  AND recipient.removed_at IS NULL
              ) = 0 THEN NULL
              WHEN (
                SELECT COUNT(*)
                FROM message_conversation_member recipient
                WHERE recipient.conversation_id = message_entry.conversation_id
                  AND recipient.user_id <> message_entry.sender_user_id
                  AND recipient.removed_at IS NULL
                  AND recipient.last_read_at >= message_entry.created_at
              ) = (
                SELECT COUNT(*)
                FROM message_conversation_member recipient
                WHERE recipient.conversation_id = message_entry.conversation_id
                  AND recipient.user_id <> message_entry.sender_user_id
                  AND recipient.removed_at IS NULL
              )
              THEN (
                SELECT MIN(recipient.last_read_at)::text
                FROM message_conversation_member recipient
                WHERE recipient.conversation_id = message_entry.conversation_id
                  AND recipient.user_id <> message_entry.sender_user_id
                  AND recipient.removed_at IS NULL
                  AND recipient.last_read_at >= message_entry.created_at
              )
              ELSE NULL
            END AS read_at
          FROM message_entry
          WHERE conversation_id = $1
            AND deleted_at IS NULL
            AND NOT (COALESCE(metadata -> 'hiddenForUserIds', '[]'::jsonb) ? $4)
            AND ($2::timestamptz IS NULL OR created_at < $2)
          ORDER BY created_at DESC
          LIMIT $3
        `,
        [conversationId, before?.toISOString() ?? null, limit, currentUserId],
      );

      const newestFirst = rowsRes.rows;
      const items = [...newestFirst].reverse().map((row) => this.mapMessage(row));

      const newestMessage = newestFirst[0];
      if (newestMessage) {
        await client.query(
          `
            UPDATE message_conversation_member
            SET
              last_read_at = GREATEST(COALESCE(last_read_at, to_timestamp(0)), $1::timestamptz),
              last_read_message_id = $2
            WHERE conversation_id = $3
              AND user_id = $4
              AND removed_at IS NULL
          `,
          [newestMessage.created_at, newestMessage.id, conversationId, currentUserId],
        );
      }

      const oldestMessage = newestFirst[newestFirst.length - 1];

      return {
        items,
        nextBefore: oldestMessage?.created_at ?? null,
        hasMore: newestFirst.length >= limit,
      };
    });
  }

  async postMessage(
    currentUserId: string,
    conversationId: string,
    payload: PostMessageDto,
    auditContext?: AuditSqlContext,
  ) {
    const ciphertext = payload.ciphertext.trim();
    if (!ciphertext) {
      throw new BadRequestException('Message ciphertext cannot be empty');
    }

    const messageKind = payload.messageKind ?? 'text';
    const algorithm = payload.algorithm?.trim() || 'xchacha20poly1305';
    const nonce = payload.nonce?.trim() || null;

    let metadataJson = '{}';
    if (payload.metadata) {
      try {
        const parsed = JSON.parse(payload.metadata);
        metadataJson = JSON.stringify(parsed);
      } catch (_) {
        throw new BadRequestException('Invalid metadata JSON');
      }
    }

    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        currentUserId,
        ...auditContext,
      });
      await this.ensureRequestStatusSchema(client);

      await this.assertConversationMembership(client, currentUserId, conversationId);

      const memberStateRes = await client.query<{
        request_status: 'active' | 'request';
      }>(
        `
          SELECT request_status
          FROM message_conversation_member
          WHERE conversation_id = $1
            AND user_id = $2
            AND removed_at IS NULL
          LIMIT 1
        `,
        [conversationId, currentUserId],
      );

      const currentMemberState = memberStateRes.rows[0];
      if (currentMemberState?.request_status === 'request') {
        await client.query(
          `
            UPDATE message_conversation_member
            SET request_status = 'active'
            WHERE conversation_id = $1
              AND removed_at IS NULL
          `,
          [conversationId],
        );
      }

      const messageRes = await client.query<MessageRow>(
        `
          INSERT INTO message_entry(
            conversation_id,
            sender_user_id,
            message_kind,
            ciphertext,
            algorithm,
            nonce,
            metadata
          )
          VALUES($1, $2, $3, $4, $5, $6, $7::jsonb)
          RETURNING
            id,
            conversation_id,
            sender_user_id,
            message_kind,
            ciphertext,
            algorithm,
            nonce,
            metadata,
            created_at::text,
            edited_at::text,
            deleted_at::text
        `,
        [
          conversationId,
          currentUserId,
          messageKind,
          ciphertext,
          algorithm,
          nonce,
          metadataJson,
        ],
      );

      const createdMessage = messageRes.rows[0];
      if (!createdMessage) {
        throw new ConflictException('Failed to create message');
      }

      await client.query(
        `
          UPDATE message_conversation
          SET last_message_at = $1::timestamptz,
              updated_at = $1::timestamptz
          WHERE id = $2
        `,
        [createdMessage.created_at, conversationId],
      );

      await client.query(
        `
          UPDATE message_conversation_member
          SET
            last_read_at = $1::timestamptz,
            last_read_message_id = $2
          WHERE conversation_id = $3
            AND user_id = $4
            AND removed_at IS NULL
        `,
        [createdMessage.created_at, createdMessage.id, conversationId, currentUserId],
      );

      return this.mapMessage(createdMessage);
    });
  }

  async updateMessage(
    currentUserId: string,
    conversationId: string,
    messageId: string,
    payload: UpdateMessageDto,
    auditContext?: AuditSqlContext,
  ) {
    const ciphertext = payload.ciphertext.trim();
    if (!ciphertext) {
      throw new BadRequestException('Message ciphertext cannot be empty');
    }

    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        currentUserId,
        ...auditContext,
      });

      await this.assertConversationMembership(client, currentUserId, conversationId);

      const message = await this.getMessageForConversation(client, conversationId, messageId);
      if (message.sender_user_id !== currentUserId) {
        throw new ForbiddenException('Only the sender can edit this message');
      }
      if (message.deleted_at != null) {
        throw new BadRequestException('Message was deleted');
      }

      const createdAt = new Date(message.created_at);
      const now = new Date();
      if (now.getTime() - createdAt.getTime() > 30 * 60 * 1000) {
        throw new BadRequestException('Message can only be edited within 30 minutes');
      }

      const updatedRes = await client.query<MessageRow>(
        `
          UPDATE message_entry
          SET ciphertext = $1,
              edited_at = NOW()
          WHERE id = $2
            AND conversation_id = $3
          RETURNING
            id,
            conversation_id,
            sender_user_id,
            message_kind,
            ciphertext,
            algorithm,
            nonce,
            metadata,
            created_at::text,
            edited_at::text,
            deleted_at::text,
            created_at::text AS delivered_at,
            NULL::text AS read_at
        `,
        [ciphertext, messageId, conversationId],
      );

      return this.mapMessage(updatedRes.rows[0]);
    });
  }

  async setMessageReaction(
    currentUserId: string,
    conversationId: string,
    messageId: string,
    payload: SetMessageReactionDto,
    auditContext?: AuditSqlContext,
  ) {
    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        currentUserId,
        ...auditContext,
      });

      await this.assertConversationMembership(client, currentUserId, conversationId);

      const message = await this.getMessageForConversation(client, conversationId, messageId);
      if (message.deleted_at != null) {
        throw new BadRequestException('Message was deleted');
      }

      const emoji = payload.emoji.trim();
      const metadata = this.normalizeMessageMetadata(message.metadata);
      if (emoji.length === 0) {
        delete metadata.reactions[currentUserId];
      } else {
        metadata.reactions[currentUserId] = emoji;
      }

      const updatedRes = await client.query<MessageRow>(
        `
          UPDATE message_entry
          SET metadata = $1::jsonb
          WHERE id = $2
            AND conversation_id = $3
          RETURNING
            id,
            conversation_id,
            sender_user_id,
            message_kind,
            ciphertext,
            algorithm,
            nonce,
            metadata,
            created_at::text,
            edited_at::text,
            deleted_at::text,
            created_at::text AS delivered_at,
            NULL::text AS read_at
        `,
        [JSON.stringify(metadata), messageId, conversationId],
      );

      return this.mapMessage(updatedRes.rows[0]);
    });
  }

  async deleteMessage(
    currentUserId: string,
    conversationId: string,
    messageId: string,
    scope: string | undefined,
    auditContext?: AuditSqlContext,
  ) {
    const normalizedScope = scope === 'everyone' ? 'everyone' : 'me';

    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        currentUserId,
        ...auditContext,
      });

      await this.assertConversationMembership(client, currentUserId, conversationId);
      const message = await this.getMessageForConversation(client, conversationId, messageId);

      if (normalizedScope == 'everyone') {
        if (message.sender_user_id !== currentUserId) {
          throw new ForbiddenException('Only the sender can delete for everyone');
        }

        await client.query(
          `
            UPDATE message_entry
            SET deleted_at = NOW()
            WHERE id = $1
              AND conversation_id = $2
          `,
          [messageId, conversationId],
        );

        return { ok: true, scope: normalizedScope };
      }

      const metadata = this.normalizeMessageMetadata(message.metadata);
      const hidden = new Set<string>([
        ...metadata.hiddenForUserIds,
        currentUserId,
      ]);
      metadata.hiddenForUserIds = [...hidden];

      await client.query(
        `
          UPDATE message_entry
          SET metadata = $1::jsonb
          WHERE id = $2
            AND conversation_id = $3
        `,
        [JSON.stringify(metadata), messageId, conversationId],
      );

      return { ok: true, scope: normalizedScope };
    });
  }

  async markConversationRead(
    currentUserId: string,
    conversationId: string,
    auditContext?: AuditSqlContext,
  ) {
    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        currentUserId,
        ...auditContext,
      });

      await this.assertConversationMembership(client, currentUserId, conversationId);

      const latestMessageRes = await client.query<{ id: string; created_at: string }>(
        `
          SELECT id, created_at::text
          FROM message_entry
          WHERE conversation_id = $1
            AND deleted_at IS NULL
          ORDER BY created_at DESC
          LIMIT 1
        `,
        [conversationId],
      );

      const latestMessage = latestMessageRes.rows[0];
      await client.query(
        `
          UPDATE message_conversation_member
          SET
            last_read_at = COALESCE($1::timestamptz, NOW()),
            last_read_message_id = $2
          WHERE conversation_id = $3
            AND user_id = $4
            AND removed_at IS NULL
        `,
        [latestMessage?.created_at ?? null, latestMessage?.id ?? null, conversationId, currentUserId],
      );

      return { ok: true };
    });
  }

  private async assertUsersExist(client: PoolClient, userIds: string[]): Promise<void> {
    if (userIds.length === 0) return;

    const res = await client.query<{ id: string }>(
      `
        SELECT id
        FROM app_user
        WHERE id = ANY($1::uuid[])
          AND deleted_at IS NULL
      `,
      [userIds],
    );

    if (res.rows.length !== userIds.length) {
      throw new NotFoundException('One or more users were not found');
    }
  }

  private async assertConversationMembership(
    client: PoolClient,
    currentUserId: string,
    conversationId: string,
  ): Promise<void> {
    const res = await client.query<{ role: 'owner' | 'admin' | 'member' }>(
      `
        SELECT role
        FROM message_conversation_member
        WHERE conversation_id = $1
          AND user_id = $2
          AND removed_at IS NULL
        LIMIT 1
      `,
      [conversationId, currentUserId],
    );

    if (!res.rows[0]) {
      throw new ForbiddenException('Not a conversation member');
    }
  }

  private async getConversationForUser(
    client: PoolClient,
    currentUserId: string,
    conversationId: string,
  ) {
    await this.ensureRequestStatusSchema(client);

    const conversationRes = await client.query<ConversationRow>(
      `
        SELECT
          c.id,
          c.conversation_type,
          c.title,
          c.created_by_user_id,
          c.created_at::text,
          c.updated_at::text,
          c.last_message_at::text,
          (
            SELECT me.ciphertext
            FROM message_entry me
            WHERE me.conversation_id = c.id
              AND me.deleted_at IS NULL
              AND NOT (COALESCE(me.metadata -> 'hiddenForUserIds', '[]'::jsonb) ? ($3::text))
            ORDER BY me.created_at DESC
            LIMIT 1
          ) AS last_message_preview,
          (
            SELECT me.sender_user_id::text
            FROM message_entry me
            WHERE me.conversation_id = c.id
              AND me.deleted_at IS NULL
              AND NOT (COALESCE(me.metadata -> 'hiddenForUserIds', '[]'::jsonb) ? ($3::text))
            ORDER BY me.created_at DESC
            LIMIT 1
          ) AS last_message_sender_user_id,
          m.role,
          m.request_status,
          (
            SELECT COUNT(*)::int
            FROM message_entry me
            WHERE me.conversation_id = c.id
              AND me.deleted_at IS NULL
              AND me.created_at > COALESCE(m.last_read_at, to_timestamp(0))
              AND me.sender_user_id <> $1
          ) AS unread_count
        FROM message_conversation c
        INNER JOIN message_conversation_member m
          ON m.conversation_id = c.id
        WHERE c.id = $2
          AND m.user_id = $1
          AND m.removed_at IS NULL
        LIMIT 1
      `,
      [currentUserId, conversationId, currentUserId],
    );

    const row = conversationRes.rows[0];
    if (!row) {
      throw new NotFoundException('Conversation not found');
    }

    const participantsByConversation = await this.loadParticipantsByConversation(client, [
      conversationId,
    ]);

    return {
      id: row.id,
      type: row.conversation_type,
      title: row.title,
      createdByUserId: row.created_by_user_id,
      role: row.role,
      unreadCount: row.unread_count,
          requestStatus: row.request_status,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      lastMessageAt: row.last_message_at,
          lastMessagePreview: row.last_message_preview,
          lastMessageSenderUserId: row.last_message_sender_user_id,
      participants: participantsByConversation.get(row.id) ?? [],
    };
  }

  private async ensureRequestStatusSchema(client: PoolClient): Promise<void> {
    if (this.requestStatusSchemaEnsured) {
      return;
    }

    await client.query(
      `
        ALTER TABLE message_conversation_member
        ADD COLUMN IF NOT EXISTS request_status TEXT NOT NULL DEFAULT 'active'
        CHECK (request_status IN ('active', 'request'))
      `,
    );

    await client.query(
      `
        CREATE INDEX IF NOT EXISTS idx_mcm_request_status
          ON message_conversation_member(request_status)
          WHERE request_status = 'request'
      `,
    );

    this.requestStatusSchemaEnsured = true;
  }

  private async loadParticipantsByConversation(
    client: PoolClient,
    conversationIds: string[],
  ): Promise<Map<string, Array<Record<string, unknown>>>> {
    const grouped = new Map<string, Array<Record<string, unknown>>>();

    if (conversationIds.length === 0) {
      return grouped;
    }

    const participantsRes = await client.query<ParticipantRow>(
      `
        SELECT
          m.conversation_id,
          m.user_id,
          m.role,
          m.joined_at::text,
          u.first_name,
          u.last_name,
          u.email::text
        FROM message_conversation_member m
        INNER JOIN app_user u
          ON u.id = m.user_id
        WHERE m.conversation_id = ANY($1::uuid[])
          AND m.removed_at IS NULL
          AND u.deleted_at IS NULL
        ORDER BY m.joined_at ASC
      `,
      [conversationIds],
    );

    for (const row of participantsRes.rows) {
      const firstName = (row.first_name ?? '').trim();
      const lastName = (row.last_name ?? '').trim();
      const fullName = [firstName, lastName].filter((value) => value.length > 0).join(' ');

      const participant = {
        userId: row.user_id,
        role: row.role,
        joinedAt: row.joined_at,
        firstName: row.first_name,
        lastName: row.last_name,
        fullName: fullName || row.email,
        email: row.email,
      };

      const existing = grouped.get(row.conversation_id);
      if (existing) {
        existing.push(participant);
      } else {
        grouped.set(row.conversation_id, [participant]);
      }
    }

    return grouped;
  }

  private mapMessage(row: MessageRow) {
    return {
      id: row.id,
      conversationId: row.conversation_id,
      senderUserId: row.sender_user_id,
      messageKind: row.message_kind,
      ciphertext: row.ciphertext,
      algorithm: row.algorithm,
      nonce: row.nonce,
      metadata:
        row.metadata && typeof row.metadata === 'object' ? row.metadata : ({} as Record<string, unknown>),
      createdAt: row.created_at,
      deliveredAt: row.delivered_at,
      readAt: row.read_at,
      editedAt: row.edited_at,
      deletedAt: row.deleted_at,
    };
  }

  private async getMessageForConversation(
    client: PoolClient,
    conversationId: string,
    messageId: string,
  ) {
    const res = await client.query<MessageRow>(
      `
        SELECT
          id,
          conversation_id,
          sender_user_id,
          message_kind,
          ciphertext,
          algorithm,
          nonce,
          metadata,
          created_at::text,
          edited_at::text,
          deleted_at::text,
          created_at::text AS delivered_at,
          NULL::text AS read_at
        FROM message_entry
        WHERE id = $1
          AND conversation_id = $2
        LIMIT 1
      `,
      [messageId, conversationId],
    );

    const row = res.rows[0];
    if (!row) {
      throw new NotFoundException('Message not found');
    }
    return row;
  }

  private normalizeMessageMetadata(metadata: unknown) {
    const raw =
      metadata && typeof metadata === 'object'
        ? (metadata as Record<string, unknown>)
        : {};

    const rawReactions = raw['reactions'];
    const reactions: Record<string, string> = {};
    if (rawReactions && typeof rawReactions === 'object' && !Array.isArray(rawReactions)) {
      for (const [key, value] of Object.entries(rawReactions as Record<string, unknown>)) {
        if (key.trim().length > 0 && typeof value === 'string') {
          reactions[key] = value;
        }
      }
    }

    const rawHidden = raw['hiddenForUserIds'];
    const hiddenForUserIds = new Set<string>();
    if (Array.isArray(rawHidden)) {
      for (const value of rawHidden) {
        if (typeof value === 'string' && value.trim().length > 0) {
          hiddenForUserIds.add(value);
        }
      }
    }

    return {
      ...raw,
      'reactions': reactions,
      'hiddenForUserIds': [...hiddenForUserIds],
    };
  }
}

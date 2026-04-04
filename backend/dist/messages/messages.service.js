"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MessagesService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../database/database.service");
const audit_sql_context_1 = require("../database/audit-sql-context");
const social_service_1 = require("../social/social.service");
let MessagesService = class MessagesService {
    constructor(db, socialService) {
        this.db = db;
        this.socialService = socialService;
        this.requestStatusSchemaEnsured = false;
    }
    async listConversations(currentUserId, auditContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId,
                ...auditContext,
            });
            await this.ensureRequestStatusSchema(client);
            const conversationsRes = await client.query(`
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
        `, [currentUserId, currentUserId]);
            const conversationIds = conversationsRes.rows.map((row) => row.id);
            const participantsByConversation = await this.loadParticipantsByConversation(client, conversationIds);
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
    async createDirectConversation(currentUserId, payload, auditContext) {
        const otherUserId = payload.otherUserId;
        if (otherUserId === currentUserId) {
            throw new common_1.BadRequestException('Cannot create a DM with yourself');
        }
        const [dmUserLow, dmUserHigh] = currentUserId < otherUserId
            ? [currentUserId, otherUserId]
            : [otherUserId, currentUserId];
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId,
                ...auditContext,
            });
            await this.ensureRequestStatusSchema(client);
            await this.assertUsersExist(client, [otherUserId]);
            const existingRes = await client.query(`
          SELECT id
          FROM message_conversation
          WHERE conversation_type = 'dm'
            AND dm_user_low = $1
            AND dm_user_high = $2
          LIMIT 1
        `, [dmUserLow, dmUserHigh]);
            const existingId = existingRes.rows[0]?.id;
            if (existingId) {
                return this.getConversationForUser(client, currentUserId, existingId);
            }
            const conversationRes = await client.query(`
          INSERT INTO message_conversation(
            conversation_type,
            title,
            created_by_user_id,
            dm_user_low,
            dm_user_high
          )
          VALUES('dm', NULL, $1, $2, $3)
          RETURNING id
        `, [currentUserId, dmUserLow, dmUserHigh]);
            const conversationId = conversationRes.rows[0]?.id;
            if (!conversationId) {
                throw new common_1.ConflictException('Failed to create DM conversation');
            }
            const requestStatus = await this.socialService.canSendDirectMessage(currentUserId, otherUserId);
            await client.query(`
            INSERT INTO message_conversation_member(conversation_id, user_id, role, request_status)
            VALUES
              ($1, $2, 'member', 'active'),
              ($1, $3, 'member', $4)
          `, [conversationId, currentUserId, otherUserId, requestStatus]);
            return this.getConversationForUser(client, currentUserId, conversationId);
        });
    }
    async createGroupConversation(currentUserId, payload, auditContext) {
        const title = payload.title.trim();
        if (title.length < 2) {
            throw new common_1.BadRequestException('Group title is too short');
        }
        const dedupedMemberIds = Array.from(new Set(payload.memberIds ?? []));
        const filteredMemberIds = dedupedMemberIds.filter((id) => id !== currentUserId);
        const totalMembers = filteredMemberIds.length + 1;
        if (totalMembers > 300) {
            throw new common_1.BadRequestException('Group cannot have more than 300 members');
        }
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId,
                ...auditContext,
            });
            await this.assertUsersExist(client, filteredMemberIds);
            const conversationRes = await client.query(`
          INSERT INTO message_conversation(
            conversation_type,
            title,
            created_by_user_id
          )
          VALUES('group', $1, $2)
          RETURNING id
        `, [title, currentUserId]);
            const conversationId = conversationRes.rows[0]?.id;
            if (!conversationId) {
                throw new common_1.ConflictException('Failed to create group conversation');
            }
            await client.query(`
          INSERT INTO message_conversation_member(conversation_id, user_id, role)
          VALUES($1, $2, 'owner')
        `, [conversationId, currentUserId]);
            if (filteredMemberIds.length > 0) {
                const valuesSql = filteredMemberIds
                    .map((_, index) => `($1, $${index + 2}, 'member')`)
                    .join(', ');
                await client.query(`
            INSERT INTO message_conversation_member(conversation_id, user_id, role)
            VALUES ${valuesSql}
          `, [conversationId, ...filteredMemberIds]);
            }
            return this.getConversationForUser(client, currentUserId, conversationId);
        });
    }
    async listMessages(currentUserId, conversationId, query, auditContext) {
        const limit = query.limit ?? 50;
        const before = query.before ? new Date(query.before) : null;
        if (before != null && Number.isNaN(before.getTime())) {
            throw new common_1.BadRequestException('Invalid "before" timestamp');
        }
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId,
                ...auditContext,
            });
            await this.assertConversationMembership(client, currentUserId, conversationId);
            const rowsRes = await client.query(`
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
        `, [conversationId, before?.toISOString() ?? null, limit, currentUserId]);
            const newestFirst = rowsRes.rows;
            const items = [...newestFirst].reverse().map((row) => this.mapMessage(row));
            const newestMessage = newestFirst[0];
            if (newestMessage) {
                await client.query(`
            UPDATE message_conversation_member
            SET
              last_read_at = GREATEST(COALESCE(last_read_at, to_timestamp(0)), $1::timestamptz),
              last_read_message_id = $2
            WHERE conversation_id = $3
              AND user_id = $4
              AND removed_at IS NULL
          `, [newestMessage.created_at, newestMessage.id, conversationId, currentUserId]);
            }
            const oldestMessage = newestFirst[newestFirst.length - 1];
            return {
                items,
                nextBefore: oldestMessage?.created_at ?? null,
                hasMore: newestFirst.length >= limit,
            };
        });
    }
    async postMessage(currentUserId, conversationId, payload, auditContext) {
        const ciphertext = payload.ciphertext.trim();
        if (!ciphertext) {
            throw new common_1.BadRequestException('Message ciphertext cannot be empty');
        }
        const messageKind = payload.messageKind ?? 'text';
        const algorithm = payload.algorithm?.trim() || 'xchacha20poly1305';
        const nonce = payload.nonce?.trim() || null;
        let metadataJson = '{}';
        if (payload.metadata) {
            try {
                const parsed = JSON.parse(payload.metadata);
                metadataJson = JSON.stringify(parsed);
            }
            catch (_) {
                throw new common_1.BadRequestException('Invalid metadata JSON');
            }
        }
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId,
                ...auditContext,
            });
            await this.ensureRequestStatusSchema(client);
            await this.assertConversationMembership(client, currentUserId, conversationId);
            const memberStateRes = await client.query(`
          SELECT request_status
          FROM message_conversation_member
          WHERE conversation_id = $1
            AND user_id = $2
            AND removed_at IS NULL
          LIMIT 1
        `, [conversationId, currentUserId]);
            const currentMemberState = memberStateRes.rows[0];
            if (currentMemberState?.request_status === 'request') {
                await client.query(`
            UPDATE message_conversation_member
            SET request_status = 'active'
            WHERE conversation_id = $1
              AND removed_at IS NULL
          `, [conversationId]);
            }
            const messageRes = await client.query(`
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
        `, [
                conversationId,
                currentUserId,
                messageKind,
                ciphertext,
                algorithm,
                nonce,
                metadataJson,
            ]);
            const createdMessage = messageRes.rows[0];
            if (!createdMessage) {
                throw new common_1.ConflictException('Failed to create message');
            }
            await client.query(`
          UPDATE message_conversation
          SET last_message_at = $1::timestamptz,
              updated_at = $1::timestamptz
          WHERE id = $2
        `, [createdMessage.created_at, conversationId]);
            await client.query(`
          UPDATE message_conversation_member
          SET
            last_read_at = $1::timestamptz,
            last_read_message_id = $2
          WHERE conversation_id = $3
            AND user_id = $4
            AND removed_at IS NULL
        `, [createdMessage.created_at, createdMessage.id, conversationId, currentUserId]);
            return this.mapMessage(createdMessage);
        });
    }
    async updateMessage(currentUserId, conversationId, messageId, payload, auditContext) {
        const ciphertext = payload.ciphertext.trim();
        if (!ciphertext) {
            throw new common_1.BadRequestException('Message ciphertext cannot be empty');
        }
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId,
                ...auditContext,
            });
            await this.assertConversationMembership(client, currentUserId, conversationId);
            const message = await this.getMessageForConversation(client, conversationId, messageId);
            if (message.sender_user_id !== currentUserId) {
                throw new common_1.ForbiddenException('Only the sender can edit this message');
            }
            if (message.deleted_at != null) {
                throw new common_1.BadRequestException('Message was deleted');
            }
            const createdAt = new Date(message.created_at);
            const now = new Date();
            if (now.getTime() - createdAt.getTime() > 30 * 60 * 1000) {
                throw new common_1.BadRequestException('Message can only be edited within 30 minutes');
            }
            const updatedRes = await client.query(`
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
        `, [ciphertext, messageId, conversationId]);
            return this.mapMessage(updatedRes.rows[0]);
        });
    }
    async setMessageReaction(currentUserId, conversationId, messageId, payload, auditContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId,
                ...auditContext,
            });
            await this.assertConversationMembership(client, currentUserId, conversationId);
            const message = await this.getMessageForConversation(client, conversationId, messageId);
            if (message.deleted_at != null) {
                throw new common_1.BadRequestException('Message was deleted');
            }
            const emoji = payload.emoji.trim();
            const metadata = this.normalizeMessageMetadata(message.metadata);
            if (emoji.length === 0) {
                delete metadata.reactions[currentUserId];
            }
            else {
                metadata.reactions[currentUserId] = emoji;
            }
            const updatedRes = await client.query(`
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
        `, [JSON.stringify(metadata), messageId, conversationId]);
            return this.mapMessage(updatedRes.rows[0]);
        });
    }
    async deleteMessage(currentUserId, conversationId, messageId, scope, auditContext) {
        const normalizedScope = scope === 'everyone' ? 'everyone' : 'me';
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId,
                ...auditContext,
            });
            await this.assertConversationMembership(client, currentUserId, conversationId);
            const message = await this.getMessageForConversation(client, conversationId, messageId);
            if (normalizedScope == 'everyone') {
                if (message.sender_user_id !== currentUserId) {
                    throw new common_1.ForbiddenException('Only the sender can delete for everyone');
                }
                await client.query(`
            UPDATE message_entry
            SET deleted_at = NOW()
            WHERE id = $1
              AND conversation_id = $2
          `, [messageId, conversationId]);
                return { ok: true, scope: normalizedScope };
            }
            const metadata = this.normalizeMessageMetadata(message.metadata);
            const hidden = new Set([
                ...metadata.hiddenForUserIds,
                currentUserId,
            ]);
            metadata.hiddenForUserIds = [...hidden];
            await client.query(`
          UPDATE message_entry
          SET metadata = $1::jsonb
          WHERE id = $2
            AND conversation_id = $3
        `, [JSON.stringify(metadata), messageId, conversationId]);
            return { ok: true, scope: normalizedScope };
        });
    }
    async markConversationRead(currentUserId, conversationId, auditContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId,
                ...auditContext,
            });
            await this.assertConversationMembership(client, currentUserId, conversationId);
            const latestMessageRes = await client.query(`
          SELECT id, created_at::text
          FROM message_entry
          WHERE conversation_id = $1
            AND deleted_at IS NULL
          ORDER BY created_at DESC
          LIMIT 1
        `, [conversationId]);
            const latestMessage = latestMessageRes.rows[0];
            await client.query(`
          UPDATE message_conversation_member
          SET
            last_read_at = COALESCE($1::timestamptz, NOW()),
            last_read_message_id = $2
          WHERE conversation_id = $3
            AND user_id = $4
            AND removed_at IS NULL
        `, [latestMessage?.created_at ?? null, latestMessage?.id ?? null, conversationId, currentUserId]);
            return { ok: true };
        });
    }
    async assertUsersExist(client, userIds) {
        if (userIds.length === 0)
            return;
        const res = await client.query(`
        SELECT id
        FROM app_user
        WHERE id = ANY($1::uuid[])
          AND deleted_at IS NULL
      `, [userIds]);
        if (res.rows.length !== userIds.length) {
            throw new common_1.NotFoundException('One or more users were not found');
        }
    }
    async assertConversationMembership(client, currentUserId, conversationId) {
        const res = await client.query(`
        SELECT role
        FROM message_conversation_member
        WHERE conversation_id = $1
          AND user_id = $2
          AND removed_at IS NULL
        LIMIT 1
      `, [conversationId, currentUserId]);
        if (!res.rows[0]) {
            throw new common_1.ForbiddenException('Not a conversation member');
        }
    }
    async getConversationForUser(client, currentUserId, conversationId) {
        await this.ensureRequestStatusSchema(client);
        const conversationRes = await client.query(`
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
      `, [currentUserId, conversationId, currentUserId]);
        const row = conversationRes.rows[0];
        if (!row) {
            throw new common_1.NotFoundException('Conversation not found');
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
    async ensureRequestStatusSchema(client) {
        if (this.requestStatusSchemaEnsured) {
            return;
        }
        await client.query(`
        ALTER TABLE message_conversation_member
        ADD COLUMN IF NOT EXISTS request_status TEXT NOT NULL DEFAULT 'active'
        CHECK (request_status IN ('active', 'request'))
      `);
        await client.query(`
        CREATE INDEX IF NOT EXISTS idx_mcm_request_status
          ON message_conversation_member(request_status)
          WHERE request_status = 'request'
      `);
        this.requestStatusSchemaEnsured = true;
    }
    async loadParticipantsByConversation(client, conversationIds) {
        const grouped = new Map();
        if (conversationIds.length === 0) {
            return grouped;
        }
        const participantsRes = await client.query(`
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
      `, [conversationIds]);
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
            }
            else {
                grouped.set(row.conversation_id, [participant]);
            }
        }
        return grouped;
    }
    mapMessage(row) {
        return {
            id: row.id,
            conversationId: row.conversation_id,
            senderUserId: row.sender_user_id,
            messageKind: row.message_kind,
            ciphertext: row.ciphertext,
            algorithm: row.algorithm,
            nonce: row.nonce,
            metadata: row.metadata && typeof row.metadata === 'object' ? row.metadata : {},
            createdAt: row.created_at,
            deliveredAt: row.delivered_at,
            readAt: row.read_at,
            editedAt: row.edited_at,
            deletedAt: row.deleted_at,
        };
    }
    async getMessageForConversation(client, conversationId, messageId) {
        const res = await client.query(`
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
      `, [messageId, conversationId]);
        const row = res.rows[0];
        if (!row) {
            throw new common_1.NotFoundException('Message not found');
        }
        return row;
    }
    normalizeMessageMetadata(metadata) {
        const raw = metadata && typeof metadata === 'object'
            ? metadata
            : {};
        const rawReactions = raw['reactions'];
        const reactions = {};
        if (rawReactions && typeof rawReactions === 'object' && !Array.isArray(rawReactions)) {
            for (const [key, value] of Object.entries(rawReactions)) {
                if (key.trim().length > 0 && typeof value === 'string') {
                    reactions[key] = value;
                }
            }
        }
        const rawHidden = raw['hiddenForUserIds'];
        const hiddenForUserIds = new Set();
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
};
exports.MessagesService = MessagesService;
exports.MessagesService = MessagesService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        social_service_1.SocialService])
], MessagesService);
//# sourceMappingURL=messages.service.js.map
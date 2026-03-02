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
exports.ActivitiesService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../database/database.service");
const audit_sql_context_1 = require("../database/audit-sql-context");
let ActivitiesService = class ActivitiesService {
    constructor(db) {
        this.db = db;
        this.baseSelectSql = `
    SELECT
      a.id,
      a.owner_user_id,
      owner.first_name AS owner_first_name,
      owner.last_name AS owner_last_name,
      a.provider_user_id,
      provider.first_name AS provider_first_name,
      provider.last_name AS provider_last_name,
      a.title,
      a.description,
      a.amount_ron,
      a.country,
      a.county,
      a.city,
      a.duration_hours,
      a.start_at,
      a.is_recurring,
      a.recurrence_pattern,
      a.recurrence_days,
      a.recurrence_label,
      a.meal_included,
      a.status,
      a.close_reason,
      a.warning_sent_at,
      a.created_at,
      a.updated_at
    FROM activity a
    INNER JOIN app_user owner ON owner.id = a.owner_user_id
    LEFT JOIN app_user provider ON provider.id = a.provider_user_id
  `;
    }
    normalizeText(value) {
        return value?.trim() ?? '';
    }
    fullName(firstName, lastName) {
        const first = firstName?.trim() ?? '';
        const last = lastName?.trim() ?? '';
        const merged = [first, last].filter((value) => value.length > 0).join(' ').trim();
        return merged.length > 0 ? merged : 'User';
    }
    recurrenceLabel(payload) {
        if (!payload.isRecurring)
            return null;
        const direct = this.normalizeText(payload.recurrenceLabel);
        if (direct.length > 0)
            return direct;
        if (payload.recurrencePattern === 'byDays' && (payload.recurrenceDays?.length ?? 0) > 0) {
            const labels = payload.recurrenceDays.map((day) => {
                switch (day) {
                    case 1:
                        return 'Mon';
                    case 2:
                        return 'Tue';
                    case 3:
                        return 'Wed';
                    case 4:
                        return 'Thu';
                    case 5:
                        return 'Fri';
                    case 6:
                        return 'Sat';
                    default:
                        return 'Sun';
                }
            });
            return labels.join(', ');
        }
        switch (payload.recurrencePattern) {
            case 'daily':
                return 'Daily';
            case 'weekly':
                return 'Weekly';
            case 'biWeekly':
                return 'Every 2 weeks';
            case 'monthly':
                return 'Monthly';
            default:
                return 'Recurring';
        }
    }
    validatePayload(payload) {
        const title = this.normalizeText(payload.title);
        const description = this.normalizeText(payload.description);
        const country = this.normalizeText(payload.country);
        const county = this.normalizeText(payload.county);
        const city = this.normalizeText(payload.city);
        if (!title || !description || !country || !county || !city) {
            throw new common_1.BadRequestException('Missing required activity fields');
        }
        const amountRon = Number(payload.amountRon);
        if (!Number.isFinite(amountRon) || amountRon <= 0) {
            throw new common_1.BadRequestException('Invalid amountRon');
        }
        const durationHours = Number(payload.durationHours);
        if (!Number.isInteger(durationHours) || durationHours <= 0) {
            throw new common_1.BadRequestException('Invalid durationHours');
        }
        const startAt = new Date(payload.startAt ?? '');
        if (Number.isNaN(startAt.getTime())) {
            throw new common_1.BadRequestException('Invalid startAt');
        }
        if (startAt.getTime() < Date.now()) {
            throw new common_1.BadRequestException('Activity start cannot be in the past');
        }
        const isRecurring = Boolean(payload.isRecurring);
        const recurrencePattern = isRecurring
            ? payload.recurrencePattern ?? 'weekly'
            : null;
        const recurrenceDays = (payload.recurrenceDays ?? [])
            .map((value) => Number(value))
            .filter((value) => Number.isInteger(value) && value >= 1 && value <= 7);
        const mealIncluded = Boolean(payload.mealIncluded) && durationHours > 4;
        return {
            title,
            description,
            amountRon,
            durationHours,
            country,
            county,
            city,
            startAt,
            isRecurring,
            recurrencePattern,
            recurrenceDays,
            mealIncluded,
        };
    }
    async processAutoCloseRules(client) {
        const nowIso = new Date().toISOString();
        await client.query(`
      UPDATE activity
      SET status = 'closed',
          close_reason = 'no_provider_by_deadline',
          closed_at = NOW(),
          updated_at = NOW()
      WHERE provider_user_id IS NULL
        AND status IN ('open', 'assigned')
        AND start_at <= $1::timestamptz
      `, [nowIso]);
        const warningRows = await client.query(`
      SELECT id, owner_user_id, title, start_at
      FROM activity
      WHERE provider_user_id IS NULL
        AND status = 'open'
        AND start_at > NOW()
        AND start_at <= NOW() + INTERVAL '6 hours'
      `);
        for (const row of warningRows.rows) {
            const start = new Date(row.start_at);
            const hh = start.getUTCHours().toString().padStart(2, '0');
            const mm = start.getUTCMinutes().toString().padStart(2, '0');
            const description = `Activity "${row.title}" has no provider and will close in up to 6 hours (start: ${start.toISOString().slice(0, 10)} ${hh}:${mm} UTC).`;
            await client.query(`
        INSERT INTO activity_notification (
          user_id,
          activity_id,
          title,
          description,
          category,
          notification_type,
          icon_key,
          sent_date,
          sent_time,
          sent_at
        )
        VALUES (
          $1, $2,
          'Activity closing soon',
          $3,
          'activity',
          'closing_soon_6h',
          'warning',
          CURRENT_DATE,
          CURRENT_TIME,
          NOW()
        )
        ON CONFLICT DO NOTHING
        `, [row.owner_user_id, row.id, description]);
            await client.query(`
        UPDATE activity
        SET warning_sent_at = COALESCE(warning_sent_at, NOW())
        WHERE id = $1
        `, [row.id]);
        }
    }
    buildSortSql(sort) {
        switch (sort) {
            case 'postedAsc':
                return 'a.created_at ASC';
            case 'dueAsc':
                return 'a.start_at ASC';
            case 'dueDesc':
                return 'a.start_at DESC';
            case 'postedDesc':
            default:
                return 'a.created_at DESC';
        }
    }
    mapActivityRow(row, currentUserId) {
        const now = new Date();
        const startAt = new Date(row.start_at);
        const isWarningWindowNoProvider = row.provider_user_id == null &&
            row.status === 'open' &&
            startAt.getTime() > now.getTime() &&
            startAt.getTime() <= now.getTime() + 6 * 60 * 60 * 1000;
        const isClosedNoProvider = row.provider_user_id == null &&
            (row.status === 'closed' || startAt.getTime() <= now.getTime()) &&
            row.close_reason === 'no_provider_by_deadline';
        return {
            id: row.id,
            title: row.title,
            description: row.description,
            amountRon: Number(row.amount_ron),
            durationHours: row.duration_hours,
            country: row.country,
            county: row.county,
            city: row.city,
            startAt: row.start_at,
            dueAt: row.start_at,
            isRecurring: row.is_recurring,
            recurrencePattern: row.recurrence_pattern,
            recurrenceDays: row.recurrence_days ?? [],
            recurrenceLabel: row.recurrence_label,
            mealIncluded: row.meal_included,
            status: row.status,
            closeReason: row.close_reason,
            isPostedByCurrentUser: row.owner_user_id === currentUserId,
            owner: {
                id: row.owner_user_id,
                fullName: this.fullName(row.owner_first_name, row.owner_last_name),
                rating: 5,
                reviewCount: 0,
            },
            provider: row.provider_user_id
                ? {
                    id: row.provider_user_id,
                    fullName: this.fullName(row.provider_first_name, row.provider_last_name),
                    rating: 5,
                    reviewCount: 0,
                }
                : null,
            createdAt: row.created_at,
            updatedAt: row.updated_at,
            isUpcomingForCurrentUser: row.provider_user_id === currentUserId,
            isWarningWindowNoProvider,
            isClosedNoProvider,
            canEdit: row.owner_user_id === currentUserId &&
                row.provider_user_id == null &&
                !isClosedNoProvider,
        };
    }
    async listWithSql(client, sql, params, currentUserId) {
        const res = await client.query(sql, params);
        return res.rows.map((row) => this.mapActivityRow(row, currentUserId));
    }
    async listMarketplace(userId, query, auditContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId: userId,
                ...auditContext,
            });
            await this.processAutoCloseRules(client);
            const filters = [
                `a.status = 'open'`,
                'a.provider_user_id IS NULL',
                `a.start_at > NOW() + INTERVAL '6 hours'`,
            ];
            const params = [];
            if (query.filter === 'recurring') {
                filters.push('a.is_recurring = TRUE');
            }
            if (query.filter === 'oneTime') {
                filters.push('a.is_recurring = FALSE');
            }
            const sql = `
        ${this.baseSelectSql}
        WHERE ${filters.join(' AND ')}
        ORDER BY ${this.buildSortSql(query.sort)}
      `;
            const items = await this.listWithSql(client, sql, params, userId);
            return { items };
        });
    }
    async listMine(userId, auditContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId: userId,
                ...auditContext,
            });
            await this.processAutoCloseRules(client);
            const sql = `
        ${this.baseSelectSql}
        WHERE a.owner_user_id = $1
        ORDER BY a.created_at DESC
      `;
            const items = await this.listWithSql(client, sql, [userId], userId);
            return { items };
        });
    }
    async listUpcoming(userId, auditContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId: userId,
                ...auditContext,
            });
            await this.processAutoCloseRules(client);
            const sql = `
        ${this.baseSelectSql}
        WHERE a.provider_user_id = $1
          AND a.status = 'assigned'
          AND a.start_at > NOW()
        ORDER BY a.start_at ASC
      `;
            const items = await this.listWithSql(client, sql, [userId], userId);
            return { items };
        });
    }
    async listNotifications(userId, auditContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId: userId,
                ...auditContext,
            });
            await this.processAutoCloseRules(client);
            const res = await client.query(`
        SELECT
          id,
          title,
          description,
          category,
          notification_type,
          icon_key,
          sent_date,
          sent_time,
          sent_at,
          activity_id
        FROM activity_notification
        WHERE user_id = $1
        ORDER BY sent_at DESC
        LIMIT 100
        `, [userId]);
            return {
                items: res.rows.map((row) => ({
                    id: row.id,
                    title: row.title,
                    description: row.description,
                    category: row.category,
                    type: row.notification_type,
                    iconKey: row.icon_key,
                    sentDate: row.sent_date,
                    sentTime: row.sent_time,
                    sentAt: row.sent_at,
                    activityId: row.activity_id,
                })),
            };
        });
    }
    async create(userId, payload, auditContext) {
        const parsed = this.validatePayload(payload);
        const recurrenceLabel = this.recurrenceLabel(payload);
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId: userId,
                ...auditContext,
            });
            const insertRes = await client.query(`
        INSERT INTO activity (
          owner_user_id,
          title,
          description,
          amount_ron,
          country,
          county,
          city,
          duration_hours,
          start_at,
          is_recurring,
          recurrence_pattern,
          recurrence_days,
          recurrence_label,
          meal_included,
          status
        )
        VALUES (
          $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12::smallint[],$13,$14,'open'
        )
        RETURNING id
        `, [
                userId,
                parsed.title,
                parsed.description,
                parsed.amountRon,
                parsed.country,
                parsed.county,
                parsed.city,
                parsed.durationHours,
                parsed.startAt.toISOString(),
                parsed.isRecurring,
                parsed.recurrencePattern,
                parsed.recurrenceDays,
                recurrenceLabel,
                parsed.mealIncluded,
            ]);
            const createdId = insertRes.rows[0]?.id;
            if (!createdId) {
                throw new common_1.BadRequestException('Could not create activity');
            }
            await this.processAutoCloseRules(client);
            return this.getByIdForUser(client, createdId, userId);
        });
    }
    async getByIdForUser(client, activityId, userId) {
        const res = await client.query(`
      ${this.baseSelectSql}
      WHERE a.id = $1
      LIMIT 1
      `, [activityId]);
        const row = res.rows[0];
        if (!row) {
            throw new common_1.NotFoundException('Activity not found');
        }
        return { item: this.mapActivityRow(row, userId) };
    }
    async update(userId, activityId, payload, auditContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId: userId,
                ...auditContext,
            });
            const existingRes = await client.query(`
        SELECT id, owner_user_id, provider_user_id
        FROM activity
        WHERE id = $1
        FOR UPDATE
        `, [activityId]);
            const existing = existingRes.rows[0];
            if (!existing) {
                throw new common_1.NotFoundException('Activity not found');
            }
            if (existing.owner_user_id !== userId) {
                throw new common_1.ConflictException('You can only edit your own activity');
            }
            if (existing.provider_user_id) {
                throw new common_1.ConflictException('Cannot edit an activity that already has a provider');
            }
            const snapshot = await this.getByIdForUser(client, activityId, userId);
            const current = snapshot.item;
            const validated = this.validatePayload({
                title: (payload.title ?? current['title']),
                description: (payload.description ?? current['description']),
                amountRon: Number(payload.amountRon ?? current['amountRon']),
                durationHours: Number(payload.durationHours ?? current['durationHours']),
                country: (payload.country ?? current['country']),
                county: (payload.county ?? current['county']),
                city: (payload.city ?? current['city']),
                startAt: (payload.startAt ?? current['startAt']),
                isRecurring: (payload.isRecurring ?? current['isRecurring']),
                recurrencePattern: (payload.recurrencePattern ?? current['recurrencePattern']),
                recurrenceDays: (payload.recurrenceDays ?? current['recurrenceDays']),
                mealIncluded: (payload.mealIncluded ?? current['mealIncluded']),
            });
            const recurrenceLabel = this.recurrenceLabel({
                isRecurring: validated.isRecurring,
                recurrencePattern: validated.recurrencePattern ?? undefined,
                recurrenceDays: validated.recurrenceDays,
                recurrenceLabel: payload.recurrenceLabel,
            });
            await client.query(`
        UPDATE activity
        SET
          title = $2,
          description = $3,
          amount_ron = $4,
          country = $5,
          county = $6,
          city = $7,
          duration_hours = $8,
          start_at = $9,
          is_recurring = $10,
          recurrence_pattern = $11,
          recurrence_days = $12::smallint[],
          recurrence_label = $13,
          meal_included = $14,
          status = CASE
            WHEN status = 'closed' AND close_reason = 'no_provider_by_deadline' AND $9::timestamptz > NOW()
              THEN 'open'
            ELSE status
          END,
          close_reason = CASE
            WHEN status = 'closed' AND close_reason = 'no_provider_by_deadline' AND $9::timestamptz > NOW()
              THEN NULL
            ELSE close_reason
          END,
          closed_at = CASE
            WHEN status = 'closed' AND close_reason = 'no_provider_by_deadline' AND $9::timestamptz > NOW()
              THEN NULL
            ELSE closed_at
          END,
          warning_sent_at = CASE
            WHEN $9::timestamptz > NOW() + INTERVAL '6 hours'
              THEN NULL
            ELSE warning_sent_at
          END
        WHERE id = $1
        `, [
                activityId,
                validated.title,
                validated.description,
                validated.amountRon,
                validated.country,
                validated.county,
                validated.city,
                validated.durationHours,
                validated.startAt.toISOString(),
                validated.isRecurring,
                validated.recurrencePattern,
                validated.recurrenceDays,
                recurrenceLabel,
                validated.mealIncluded,
            ]);
            await this.processAutoCloseRules(client);
            return this.getByIdForUser(client, activityId, userId);
        });
    }
    async remove(userId, activityId, auditContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId: userId,
                ...auditContext,
            });
            const deleted = await client.query(`
        DELETE FROM activity
        WHERE id = $1
          AND owner_user_id = $2
        RETURNING id
        `, [activityId, userId]);
            if ((deleted.rowCount ?? 0) === 0) {
                throw new common_1.NotFoundException('Activity not found');
            }
            return { deleted: true };
        });
    }
    async ensureNoOverlapForProvider(client, userId, activityStartAt, activityDurationHours, excludingActivityId) {
        const overlap = await client.query(`
      SELECT id
      FROM activity
      WHERE provider_user_id = $1
        AND status = 'assigned'
        AND id <> $2
        AND tstzrange(start_at, start_at + (duration_hours || ' hours')::interval, '[)')
            && tstzrange($3::timestamptz, $3::timestamptz + ($4 || ' hours')::interval, '[)')
      LIMIT 1
      `, [userId, excludingActivityId, activityStartAt, activityDurationHours]);
        if ((overlap.rowCount ?? 0) > 0) {
            throw new common_1.ConflictException('Cannot accept overlapping activities, even by 1 minute');
        }
    }
    async accept(userId, activityId, auditContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId: userId,
                ...auditContext,
            });
            await this.processAutoCloseRules(client);
            const targetRes = await client.query(`
        SELECT id, owner_user_id, provider_user_id, start_at, duration_hours, status
        FROM activity
        WHERE id = $1
        FOR UPDATE
        `, [activityId]);
            const target = targetRes.rows[0];
            if (!target) {
                throw new common_1.NotFoundException('Activity not found');
            }
            if (target.owner_user_id === userId) {
                throw new common_1.ConflictException('You cannot accept your own activity');
            }
            if (target.provider_user_id) {
                throw new common_1.ConflictException('Activity already has a provider');
            }
            if (target.status !== 'open') {
                throw new common_1.ConflictException('Activity is not open');
            }
            const start = new Date(target.start_at);
            if (start.getTime() <= Date.now()) {
                throw new common_1.ConflictException('Activity already reached its deadline');
            }
            await this.ensureNoOverlapForProvider(client, userId, target.start_at, target.duration_hours, target.id);
            await client.query(`
        UPDATE activity
        SET provider_user_id = $2,
            provider_assigned_at = NOW(),
            status = 'assigned',
            warning_sent_at = NULL,
            close_reason = NULL,
            closed_at = NULL
        WHERE id = $1
        `, [activityId, userId]);
            return this.getByIdForUser(client, activityId, userId);
        });
    }
    async removeProvider(userId, activityId, auditContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId: userId,
                ...auditContext,
            });
            const targetRes = await client.query(`
        SELECT id, owner_user_id, provider_user_id, start_at
        FROM activity
        WHERE id = $1
        FOR UPDATE
        `, [activityId]);
            const target = targetRes.rows[0];
            if (!target) {
                throw new common_1.NotFoundException('Activity not found');
            }
            if (target.owner_user_id !== userId) {
                throw new common_1.ConflictException('Only owner can remove provider');
            }
            await client.query(`
        UPDATE activity
        SET provider_user_id = NULL,
            provider_assigned_at = NULL,
            status = (
              CASE
              WHEN start_at > NOW() THEN 'open'
              ELSE 'closed'
              END
            )::activity_status,
            close_reason = CASE
              WHEN start_at > NOW() THEN NULL
              ELSE 'no_provider_by_deadline'
            END,
            closed_at = CASE
              WHEN start_at > NOW() THEN NULL
              ELSE NOW()
            END
        WHERE id = $1
        `, [activityId]);
            await this.processAutoCloseRules(client);
            return this.getByIdForUser(client, activityId, userId);
        });
    }
};
exports.ActivitiesService = ActivitiesService;
exports.ActivitiesService = ActivitiesService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], ActivitiesService);
//# sourceMappingURL=activities.service.js.map
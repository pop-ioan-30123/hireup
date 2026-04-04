import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PoolClient } from 'pg';
import { DatabaseService } from '../database/database.service';
import {
  AuditSqlContext,
  applyAuditSqlContext,
} from '../database/audit-sql-context';
import { CreateActivityDto } from './dto/create-activity.dto';
import { UpdateActivityDto } from './dto/update-activity.dto';
import { ListMarketplaceQueryDto } from './dto/list-marketplace-query.dto';

type SqlClient = {
  query: <T = Record<string, unknown>>(
    sql: string,
    params?: unknown[],
  ) => Promise<{ rows: T[]; rowCount?: number | null }>;
};

type ActivityRow = {
  id: string;
  owner_user_id: string;
  owner_first_name: string | null;
  owner_last_name: string | null;
  provider_user_id: string | null;
  provider_first_name: string | null;
  provider_last_name: string | null;
  title: string;
  description: string;
  amount_ron: string;
  country: string;
  county: string;
  city: string;
  section: string;
  category_key: string;
  subcategory_key: string | null;
  duration_hours: number;
  start_at: string;
  is_recurring: boolean;
  recurrence_pattern: string | null;
  recurrence_days: number[];
  recurrence_label: string | null;
  meal_included: boolean;
  status: 'open' | 'assigned' | 'closed' | 'cancelled';
  close_reason: string | null;
  warning_sent_at: string | null;
  created_at: string;
  updated_at: string;
};

@Injectable()
export class ActivitiesService {
  constructor(private readonly db: DatabaseService) {}

  private isMissingRelationError(error: unknown, relationName: string): boolean {
    if (!error || typeof error != 'object') return false;

    const code = (error as { code?: unknown }).code;
    const message = (error as { message?: unknown }).message;

    return (
      code === '42P01' &&
      typeof message === 'string' &&
      message.toLowerCase().includes(relationName.toLowerCase())
    );
  }

  private normalizeText(value?: string): string {
    return value?.trim() ?? '';
  }

  private fullName(firstName: string | null, lastName: string | null): string {
    const first = firstName?.trim() ?? '';
    const last = lastName?.trim() ?? '';
    const merged = [first, last].filter((value) => value.length > 0).join(' ').trim();
    return merged.length > 0 ? merged : 'User';
  }

  private recurrenceLabel(payload: {
    isRecurring: boolean;
    recurrenceLabel?: string;
    recurrencePattern?: string;
    recurrenceDays?: number[];
  }): string | null {
    if (!payload.isRecurring) return null;

    const direct = this.normalizeText(payload.recurrenceLabel);
    if (direct.length > 0) return direct;

    if (payload.recurrencePattern === 'byDays' && (payload.recurrenceDays?.length ?? 0) > 0) {
      const labels = payload.recurrenceDays!.map((day) => {
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

  private validatePayload(payload: {
    section?: string;
    categoryKey?: string;
    subcategoryKey?: string;
    title?: string;
    description?: string;
    amountRon?: number;
    durationHours?: number;
    country?: string;
    county?: string;
    city?: string;
    startAt?: string;
    isRecurring?: boolean;
    recurrencePattern?: string;
    recurrenceDays?: number[];
    mealIncluded?: boolean;
  }): {
    section: 'services';
    categoryKey: string;
    subcategoryKey: string | null;
    title: string;
    description: string;
    amountRon: number;
    durationHours: number;
    country: string;
    county: string;
    city: string;
    startAt: Date;
    isRecurring: boolean;
    recurrencePattern: string | null;
    recurrenceDays: number[];
    mealIncluded: boolean;
  } {
    const section = this.normalizeText(payload.section || 'services');
    if (section !== 'services') {
      throw new BadRequestException('Invalid section');
    }

    const categoryKey = this.normalizeText(payload.categoryKey);
    if (!categoryKey) {
      throw new BadRequestException('Missing categoryKey');
    }

    const subcategoryRaw = this.normalizeText(payload.subcategoryKey);
    const subcategoryKey = subcategoryRaw.length > 0 ? subcategoryRaw : null;

    const title = this.normalizeText(payload.title);
    const description = this.normalizeText(payload.description);
    const country = this.normalizeText(payload.country);
    const county = this.normalizeText(payload.county);
    const city = this.normalizeText(payload.city);

    if (!title || !description || !country || !county || !city) {
      throw new BadRequestException('Missing required activity fields');
    }

    const amountRon = Number(payload.amountRon);
    if (!Number.isFinite(amountRon) || amountRon <= 0) {
      throw new BadRequestException('Invalid amountRon');
    }

    const durationHours = Number(payload.durationHours);
    if (!Number.isInteger(durationHours) || durationHours <= 0) {
      throw new BadRequestException('Invalid durationHours');
    }

    const startAt = new Date(payload.startAt ?? '');
    if (Number.isNaN(startAt.getTime())) {
      throw new BadRequestException('Invalid startAt');
    }

    if (startAt.getTime() < Date.now()) {
      throw new BadRequestException('Activity start cannot be in the past');
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
      section: 'services',
      categoryKey,
      subcategoryKey,
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

  private async processAutoCloseRules(client: SqlClient): Promise<void> {
    const nowIso = new Date().toISOString();

    await client.query(
      `
      UPDATE activity
      SET status = 'closed',
          close_reason = 'no_provider_by_deadline',
          closed_at = NOW(),
          updated_at = NOW()
      WHERE provider_user_id IS NULL
        AND status IN ('open', 'assigned')
        AND start_at <= $1::timestamptz
      `,
      [nowIso],
    );

    const warningRows = await client.query<{
      id: string;
      owner_user_id: string;
      title: string;
      start_at: string;
    }>(
      `
      SELECT id, owner_user_id, title, start_at
      FROM activity
      WHERE provider_user_id IS NULL
        AND status = 'open'
        AND start_at > NOW()
        AND start_at <= NOW() + INTERVAL '6 hours'
      `,
    );

    for (const row of warningRows.rows) {
      const start = new Date(row.start_at);
      const hh = start.getUTCHours().toString().padStart(2, '0');
      const mm = start.getUTCMinutes().toString().padStart(2, '0');
      const description = `Activity "${row.title}" has no provider and will close in up to 6 hours (start: ${start.toISOString().slice(0, 10)} ${hh}:${mm} UTC).`;

      try {
        await client.query(
          `
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
          `,
          [row.owner_user_id, row.id, description],
        );
      } catch (error) {
        if (!this.isMissingRelationError(error, 'activity_notification')) {
          throw error;
        }
      }

      await client.query(
        `
        UPDATE activity
        SET warning_sent_at = COALESCE(warning_sent_at, NOW())
        WHERE id = $1
        `,
        [row.id],
      );
    }
  }

  private buildSortSql(sort?: string): string {
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

  private mapActivityRow(row: ActivityRow, currentUserId: string) {
    const now = new Date();
    const startAt = new Date(row.start_at);
    const isWarningWindowNoProvider =
      row.provider_user_id == null &&
      row.status === 'open' &&
      startAt.getTime() > now.getTime() &&
      startAt.getTime() <= now.getTime() + 6 * 60 * 60 * 1000;

    const isClosedNoProvider =
      row.provider_user_id == null &&
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
      section: row.section,
      categoryKey: row.category_key,
      subcategoryKey: row.subcategory_key,
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
      canEdit:
        row.owner_user_id === currentUserId &&
        row.provider_user_id == null &&
        !isClosedNoProvider,
    };
  }

  private async listWithSql(
    client: SqlClient,
    sql: string,
    params: unknown[],
    currentUserId: string,
  ): Promise<Array<Record<string, unknown>>> {
    const res = await client.query<ActivityRow>(sql, params);
    return res.rows.map((row) => this.mapActivityRow(row, currentUserId));
  }

  private baseSelectSql = `
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
      a.section,
      a.category_key,
      a.subcategory_key,
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

  async listMarketplace(
    userId: string,
    query: ListMarketplaceQueryDto,
    auditContext?: AuditSqlContext,
  ) {
    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        currentUserId: userId,
        ...auditContext,
      });
      await this.processAutoCloseRules(client);

      const filters: string[] = [
        `a.status = 'open'`,
        'a.provider_user_id IS NULL',
        `a.start_at > NOW() + INTERVAL '6 hours'`,
      ];
      const params: unknown[] = [];

      if (query.filter === 'recurring') {
        filters.push('a.is_recurring = TRUE');
      }
      if (query.filter === 'oneTime') {
        filters.push('a.is_recurring = FALSE');
      }
      if (this.normalizeText(query.section || 'services') === 'services') {
        filters.push(`a.section = 'services'`);
      }
      if (this.normalizeText(query.county)) {
        params.push(this.normalizeText(query.county));
        filters.push(`LOWER(a.county) = LOWER($${params.length})`);
      }
      if (this.normalizeText(query.city)) {
        params.push(this.normalizeText(query.city));
        filters.push(`LOWER(a.city) = LOWER($${params.length})`);
      }
      if (this.normalizeText(query.categoryKey)) {
        params.push(this.normalizeText(query.categoryKey));
        filters.push(`a.category_key = $${params.length}`);
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

  async listMine(userId: string, auditContext?: AuditSqlContext) {
    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
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

  async listUpcoming(userId: string, auditContext?: AuditSqlContext) {
    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
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

  async listNotifications(userId: string, auditContext?: AuditSqlContext) {
    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        currentUserId: userId,
        ...auditContext,
      });
      await this.processAutoCloseRules(client);

      try {
        const res = await client.query<{
          id: string;
          title: string;
          description: string;
          category: string;
          notification_type: string;
          icon_key: string;
          sent_date: string;
          sent_time: string;
          sent_at: string;
          is_read: boolean;
          read_at: string | null;
          activity_id: string | null;
        }>(
          `
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
            is_read,
            read_at,
            activity_id
          FROM activity_notification
          WHERE user_id = $1
          ORDER BY sent_at DESC
          LIMIT 100
          `,
          [userId],
        );

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
            isRead: row.is_read,
            readAt: row.read_at,
            activityId: row.activity_id,
          })),
        };
      } catch (error) {
        if (this.isMissingRelationError(error, 'activity_notification')) {
          return { items: [] };
        }
        throw error;
      }
    });
  }

  async markNotificationsRead(userId: string, auditContext?: AuditSqlContext) {
    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        currentUserId: userId,
        ...auditContext,
      });

      try {
        await client.query(
          `
          UPDATE activity_notification
          SET is_read = TRUE,
              read_at = COALESCE(read_at, NOW())
          WHERE user_id = $1
            AND is_read = FALSE
          `,
          [userId],
        );
      } catch (error) {
        if (this.isMissingRelationError(error, 'activity_notification')) {
          return { ok: true };
        }
        throw error;
      }

      return { ok: true };
    });
  }

  async create(
    userId: string,
    payload: CreateActivityDto,
    auditContext?: AuditSqlContext,
  ) {
    const parsed = this.validatePayload(payload);
    const recurrenceLabel = this.recurrenceLabel(payload);

    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        currentUserId: userId,
        ...auditContext,
      });

      const insertRes = await client.query<{ id: string }>(
        `
        INSERT INTO activity (
          owner_user_id,
          section,
          category_key,
          subcategory_key,
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
          $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14::smallint[],$15,$16,'open'
        )
        RETURNING id
        `,
        [
          userId,
          parsed.section,
          parsed.categoryKey,
          parsed.subcategoryKey,
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
        ],
      );

      const createdId = insertRes.rows[0]?.id;
      if (!createdId) {
        throw new BadRequestException('Could not create activity');
      }

      await this.processAutoCloseRules(client);
      return this.getByIdForUser(client, createdId, userId);
    });
  }

  private async getByIdForUser(client: SqlClient, activityId: string, userId: string) {
    const res = await client.query<ActivityRow>(
      `
      ${this.baseSelectSql}
      WHERE a.id = $1
      LIMIT 1
      `,
      [activityId],
    );

    const row = res.rows[0];
    if (!row) {
      throw new NotFoundException('Activity not found');
    }

    return { item: this.mapActivityRow(row, userId) };
  }

  async update(
    userId: string,
    activityId: string,
    payload: UpdateActivityDto,
    auditContext?: AuditSqlContext,
  ) {
    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        currentUserId: userId,
        ...auditContext,
      });

      const existingRes = await client.query<{
        id: string;
        owner_user_id: string;
        provider_user_id: string | null;
      }>(
        `
        SELECT id, owner_user_id, provider_user_id
        FROM activity
        WHERE id = $1
        FOR UPDATE
        `,
        [activityId],
      );

      const existing = existingRes.rows[0];
      if (!existing) {
        throw new NotFoundException('Activity not found');
      }
      if (existing.owner_user_id !== userId) {
        throw new ConflictException('You can only edit your own activity');
      }
      if (existing.provider_user_id) {
        throw new ConflictException('Cannot edit an activity that already has a provider');
      }

      const snapshot = await this.getByIdForUser(client, activityId, userId);
      const current = snapshot.item as Record<string, unknown>;

      const validated = this.validatePayload({
        section: (payload.section ?? current['section']) as string,
        categoryKey: (payload.categoryKey ?? current['categoryKey']) as string,
        subcategoryKey: (payload.subcategoryKey ?? current['subcategoryKey']) as
          | string
          | undefined,
        title: (payload.title ?? current['title']) as string,
        description: (payload.description ?? current['description']) as string,
        amountRon: Number(payload.amountRon ?? current['amountRon']),
        durationHours: Number(payload.durationHours ?? current['durationHours']),
        country: (payload.country ?? current['country']) as string,
        county: (payload.county ?? current['county']) as string,
        city: (payload.city ?? current['city']) as string,
        startAt: (payload.startAt ?? current['startAt']) as string,
        isRecurring: (payload.isRecurring ?? current['isRecurring']) as boolean,
        recurrencePattern: (payload.recurrencePattern ?? current['recurrencePattern']) as string | undefined,
        recurrenceDays: (payload.recurrenceDays ?? current['recurrenceDays']) as number[] | undefined,
        mealIncluded: (payload.mealIncluded ?? current['mealIncluded']) as boolean,
      });

      const recurrenceLabel = this.recurrenceLabel({
        isRecurring: validated.isRecurring,
        recurrencePattern: validated.recurrencePattern ?? undefined,
        recurrenceDays: validated.recurrenceDays,
        recurrenceLabel: payload.recurrenceLabel,
      });

      await client.query(
        `
        UPDATE activity
        SET
          section = $2,
          category_key = $3,
          subcategory_key = $4,
          title = $5,
          description = $6,
          amount_ron = $7,
          country = $8,
          county = $9,
          city = $10,
          duration_hours = $11,
          start_at = $12,
          is_recurring = $13,
          recurrence_pattern = $14,
          recurrence_days = $15::smallint[],
          recurrence_label = $16,
          meal_included = $17,
          status = CASE
            WHEN status = 'closed' AND close_reason = 'no_provider_by_deadline' AND $12::timestamptz > NOW()
              THEN 'open'
            ELSE status
          END,
          close_reason = CASE
            WHEN status = 'closed' AND close_reason = 'no_provider_by_deadline' AND $12::timestamptz > NOW()
              THEN NULL
            ELSE close_reason
          END,
          closed_at = CASE
            WHEN status = 'closed' AND close_reason = 'no_provider_by_deadline' AND $12::timestamptz > NOW()
              THEN NULL
            ELSE closed_at
          END,
          warning_sent_at = CASE
            WHEN $12::timestamptz > NOW() + INTERVAL '6 hours'
              THEN NULL
            ELSE warning_sent_at
          END
        WHERE id = $1
        `,
        [
          activityId,
          validated.section,
          validated.categoryKey,
          validated.subcategoryKey,
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
        ],
      );

      await this.processAutoCloseRules(client);
      return this.getByIdForUser(client, activityId, userId);
    });
  }

  async remove(userId: string, activityId: string, auditContext?: AuditSqlContext) {
    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        currentUserId: userId,
        ...auditContext,
      });

      const deleted = await client.query<{ id: string }>(
        `
        DELETE FROM activity
        WHERE id = $1
          AND owner_user_id = $2
        RETURNING id
        `,
        [activityId, userId],
      );

      if ((deleted.rowCount ?? 0) === 0) {
        throw new NotFoundException('Activity not found');
      }

      return { deleted: true };
    });
  }

  private async ensureNoOverlapForProvider(
    client: SqlClient,
    userId: string,
    activityStartAt: string,
    activityDurationHours: number,
    excludingActivityId: string,
  ): Promise<void> {
    const overlap = await client.query<{ id: string }>(
      `
      SELECT id
      FROM activity
      WHERE provider_user_id = $1
        AND status = 'assigned'
        AND id <> $2
        AND tstzrange(start_at, start_at + (duration_hours || ' hours')::interval, '[)')
            && tstzrange($3::timestamptz, $3::timestamptz + ($4 || ' hours')::interval, '[)')
      LIMIT 1
      `,
      [userId, excludingActivityId, activityStartAt, activityDurationHours],
    );

    if ((overlap.rowCount ?? 0) > 0) {
      throw new ConflictException('Cannot accept overlapping activities, even by 1 minute');
    }
  }

  async accept(userId: string, activityId: string, auditContext?: AuditSqlContext) {
    return this.db.withTransaction(async (client: PoolClient) => {
      await applyAuditSqlContext(client, {
        currentUserId: userId,
        ...auditContext,
      });
      await this.processAutoCloseRules(client);

      const targetRes = await client.query<{
        id: string;
        owner_user_id: string;
        provider_user_id: string | null;
        start_at: string;
        duration_hours: number;
        status: string;
      }>(
        `
        SELECT id, owner_user_id, provider_user_id, start_at, duration_hours, status
        FROM activity
        WHERE id = $1
        FOR UPDATE
        `,
        [activityId],
      );

      const target = targetRes.rows[0];
      if (!target) {
        throw new NotFoundException('Activity not found');
      }

      if (target.owner_user_id === userId) {
        throw new ConflictException('You cannot accept your own activity');
      }
      if (target.provider_user_id) {
        throw new ConflictException('Activity already has a provider');
      }
      if (target.status !== 'open') {
        throw new ConflictException('Activity is not open');
      }

      const start = new Date(target.start_at);
      if (start.getTime() <= Date.now()) {
        throw new ConflictException('Activity already reached its deadline');
      }

      await this.ensureNoOverlapForProvider(
        client,
        userId,
        target.start_at,
        target.duration_hours,
        target.id,
      );

      await client.query(
        `
        UPDATE activity
        SET provider_user_id = $2,
            provider_assigned_at = NOW(),
            status = 'assigned',
            warning_sent_at = NULL,
            close_reason = NULL,
            closed_at = NULL
        WHERE id = $1
        `,
        [activityId, userId],
      );

      return this.getByIdForUser(client, activityId, userId);
    });
  }

  async removeProvider(userId: string, activityId: string, auditContext?: AuditSqlContext) {
    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        currentUserId: userId,
        ...auditContext,
      });

      const targetRes = await client.query<{
        id: string;
        owner_user_id: string;
        provider_user_id: string | null;
        start_at: string;
      }>(
        `
        SELECT id, owner_user_id, provider_user_id, start_at
        FROM activity
        WHERE id = $1
        FOR UPDATE
        `,
        [activityId],
      );

      const target = targetRes.rows[0];
      if (!target) {
        throw new NotFoundException('Activity not found');
      }
      if (target.owner_user_id !== userId) {
        throw new ConflictException('Only owner can remove provider');
      }

      await client.query(
        `
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
        `,
        [activityId],
      );

      await this.processAutoCloseRules(client);
      return this.getByIdForUser(client, activityId, userId);
    });
  }
}

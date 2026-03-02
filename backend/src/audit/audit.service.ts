import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { AuditSqlContext, applyAuditSqlContext } from '../database/audit-sql-context';
import { ListAuditLogsQueryDto } from './dto/list-audit-logs-query.dto';
import { ListSecurityEventsQueryDto } from './dto/list-security-events-query.dto';

@Injectable()
export class AuditService {
  constructor(private readonly db: DatabaseService) {}

  async listAuditLogs(
    userId: string,
    query: ListAuditLogsQueryDto,
    requestContext?: AuditSqlContext,
  ) {
    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        currentUserId: userId,
        ...requestContext,
      });

      const page = Math.max(1, Number(query.page ?? 1));
      const limit = Math.max(1, Math.min(200, Number(query.limit ?? 50)));
      const offset = (page - 1) * limit;

      const whereParts: string[] = ['actor_user_id = $1'];
      const params: unknown[] = [userId];

      if (query.from) {
        params.push(query.from);
        whereParts.push(`event_ts >= $${params.length}::timestamptz`);
      }
      if (query.to) {
        params.push(query.to);
        whereParts.push(`event_ts <= $${params.length}::timestamptz`);
      }
      if (query.tableName) {
        params.push(query.tableName.trim());
        whereParts.push(`table_name = $${params.length}`);
      }
      if (query.action) {
        params.push(query.action);
        whereParts.push(`action = $${params.length}`);
      }
      if (query.actorUserId) {
        params.push(query.actorUserId);
        whereParts.push(`actor_user_id = $${params.length}::uuid`);
      }

      const whereSql = whereParts.join(' AND ');

      const countRes = await client.query<{ total: string }>(
        `SELECT COUNT(*)::text AS total FROM audit_log WHERE ${whereSql}`,
        params,
      );

      const paginatedParams = [...params, limit, offset];
      const rowsRes = await client.query<{
        id: string;
        event_ts: string;
        actor_user_id: string | null;
        actor_email: string | null;
        action: string;
        table_name: string;
        record_pk: string | null;
        old_data: Record<string, unknown> | null;
        new_data: Record<string, unknown> | null;
        ip_address: string | null;
        user_agent: string | null;
        request_id: string | null;
      }>(
        `
        SELECT
          id,
          event_ts,
          actor_user_id,
          actor_email,
          action,
          table_name,
          record_pk,
          old_data,
          new_data,
          ip_address,
          user_agent,
          request_id
        FROM audit_log
        WHERE ${whereSql}
        ORDER BY event_ts DESC, id DESC
        LIMIT $${paginatedParams.length - 1}
        OFFSET $${paginatedParams.length}
        `,
        paginatedParams,
      );

      const total = Number(countRes.rows[0]?.total ?? '0');

      return {
        page,
        limit,
        total,
        items: rowsRes.rows.map((row) => ({
          id: Number(row.id),
          eventTs: row.event_ts,
          actorUserId: row.actor_user_id,
          actorEmail: row.actor_email,
          action: row.action,
          tableName: row.table_name,
          recordPk: row.record_pk,
          oldData: row.old_data,
          newData: row.new_data,
          ipAddress: row.ip_address,
          userAgent: row.user_agent,
          requestId: row.request_id,
        })),
      };
    });
  }

  async listSecurityEvents(
    userId: string,
    query: ListSecurityEventsQueryDto,
    requestContext?: AuditSqlContext,
  ) {
    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        currentUserId: userId,
        ...requestContext,
      });

      const page = Math.max(1, Number(query.page ?? 1));
      const limit = Math.max(1, Math.min(200, Number(query.limit ?? 50)));
      const offset = (page - 1) * limit;

      const whereParts: string[] = ['user_id = $1'];
      const params: unknown[] = [userId];

      if (query.from) {
        params.push(query.from);
        whereParts.push(`event_ts >= $${params.length}::timestamptz`);
      }
      if (query.to) {
        params.push(query.to);
        whereParts.push(`event_ts <= $${params.length}::timestamptz`);
      }
      if (query.eventType) {
        params.push(query.eventType.trim());
        whereParts.push(`event_type = $${params.length}`);
      }
      if (query.severity) {
        params.push(query.severity);
        whereParts.push(`severity = $${params.length}`);
      }

      const whereSql = whereParts.join(' AND ');

      const countRes = await client.query<{ total: string }>(
        `SELECT COUNT(*)::text AS total FROM security_event_log WHERE ${whereSql}`,
        params,
      );

      const paginatedParams = [...params, limit, offset];
      const rowsRes = await client.query<{
        id: string;
        event_ts: string;
        user_id: string | null;
        event_type: string;
        severity: string;
        details: Record<string, unknown> | null;
        ip_address: string | null;
        user_agent: string | null;
        request_id: string | null;
      }>(
        `
        SELECT
          id,
          event_ts,
          user_id,
          event_type,
          severity,
          details,
          ip_address,
          user_agent,
          request_id
        FROM security_event_log
        WHERE ${whereSql}
        ORDER BY event_ts DESC, id DESC
        LIMIT $${paginatedParams.length - 1}
        OFFSET $${paginatedParams.length}
        `,
        paginatedParams,
      );

      const total = Number(countRes.rows[0]?.total ?? '0');

      return {
        page,
        limit,
        total,
        items: rowsRes.rows.map((row) => ({
          id: Number(row.id),
          eventTs: row.event_ts,
          userId: row.user_id,
          eventType: row.event_type,
          severity: row.severity,
          details: row.details,
          ipAddress: row.ip_address,
          userAgent: row.user_agent,
          requestId: row.request_id,
        })),
      };
    });
  }
}

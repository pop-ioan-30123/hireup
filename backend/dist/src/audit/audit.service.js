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
exports.AuditService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../database/database.service");
const audit_sql_context_1 = require("../database/audit-sql-context");
let AuditService = class AuditService {
    constructor(db) {
        this.db = db;
    }
    async listAuditLogs(userId, query, requestContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId: userId,
                ...requestContext,
            });
            const page = Math.max(1, Number(query.page ?? 1));
            const limit = Math.max(1, Math.min(200, Number(query.limit ?? 50)));
            const offset = (page - 1) * limit;
            const whereParts = ['actor_user_id = $1'];
            const params = [userId];
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
            const countRes = await client.query(`SELECT COUNT(*)::text AS total FROM audit_log WHERE ${whereSql}`, params);
            const paginatedParams = [...params, limit, offset];
            const rowsRes = await client.query(`
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
        `, paginatedParams);
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
    async listSecurityEvents(userId, query, requestContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                currentUserId: userId,
                ...requestContext,
            });
            const page = Math.max(1, Number(query.page ?? 1));
            const limit = Math.max(1, Math.min(200, Number(query.limit ?? 50)));
            const offset = (page - 1) * limit;
            const whereParts = ['user_id = $1'];
            const params = [userId];
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
            const countRes = await client.query(`SELECT COUNT(*)::text AS total FROM security_event_log WHERE ${whereSql}`, params);
            const paginatedParams = [...params, limit, offset];
            const rowsRes = await client.query(`
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
        `, paginatedParams);
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
};
exports.AuditService = AuditService;
exports.AuditService = AuditService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], AuditService);
//# sourceMappingURL=audit.service.js.map
import { DatabaseService } from '../database/database.service';
import { AuditSqlContext } from '../database/audit-sql-context';
import { ListAuditLogsQueryDto } from './dto/list-audit-logs-query.dto';
import { ListSecurityEventsQueryDto } from './dto/list-security-events-query.dto';
export declare class AuditService {
    private readonly db;
    constructor(db: DatabaseService);
    listAuditLogs(userId: string, query: ListAuditLogsQueryDto, requestContext?: AuditSqlContext): Promise<{
        page: number;
        limit: number;
        total: number;
        items: {
            id: number;
            eventTs: string;
            actorUserId: string | null;
            actorEmail: string | null;
            action: string;
            tableName: string;
            recordPk: string | null;
            oldData: Record<string, unknown> | null;
            newData: Record<string, unknown> | null;
            ipAddress: string | null;
            userAgent: string | null;
            requestId: string | null;
        }[];
    }>;
    listSecurityEvents(userId: string, query: ListSecurityEventsQueryDto, requestContext?: AuditSqlContext): Promise<{
        page: number;
        limit: number;
        total: number;
        items: {
            id: number;
            eventTs: string;
            userId: string | null;
            eventType: string;
            severity: string;
            details: Record<string, unknown> | null;
            ipAddress: string | null;
            userAgent: string | null;
            requestId: string | null;
        }[];
    }>;
}

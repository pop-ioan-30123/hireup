import { AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { AuditService } from './audit.service';
import { ListAuditLogsQueryDto } from './dto/list-audit-logs-query.dto';
import { ListSecurityEventsQueryDto } from './dto/list-security-events-query.dto';
export declare class AuditController {
    private readonly auditService;
    constructor(auditService: AuditService);
    listAuditLogs(req: AuthenticatedRequest, query: ListAuditLogsQueryDto): Promise<{
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
    listSecurityEvents(req: AuthenticatedRequest, query: ListSecurityEventsQueryDto): Promise<{
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

import { PoolClient } from 'pg';
export interface AuditSqlContext {
    currentUserId?: string | null;
    currentUserEmail?: string | null;
    ipAddress?: string | null;
    userAgent?: string | null;
    requestId?: string | null;
}
export declare function applyAuditSqlContext(client: PoolClient, context: AuditSqlContext): Promise<void>;

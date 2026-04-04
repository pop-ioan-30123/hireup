export declare class ListAuditLogsQueryDto {
    from?: string;
    to?: string;
    tableName?: string;
    action?: 'INSERT' | 'UPDATE' | 'DELETE';
    actorUserId?: string;
    page?: number;
    limit?: number;
}

export declare class ListSecurityEventsQueryDto {
    from?: string;
    to?: string;
    eventType?: string;
    severity?: 'low' | 'medium' | 'high' | 'critical';
    page?: number;
    limit?: number;
}

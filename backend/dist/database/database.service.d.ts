import { OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PoolClient, QueryResult, QueryResultRow } from 'pg';
export declare class DatabaseService implements OnModuleDestroy {
    private readonly configService;
    private readonly pool;
    constructor(configService: ConfigService);
    query<T extends QueryResultRow = QueryResultRow>(text: string, params?: unknown[]): Promise<QueryResult<T>>;
    withTransaction<T>(handler: (client: PoolClient) => Promise<T>): Promise<T>;
    onModuleDestroy(): Promise<void>;
}

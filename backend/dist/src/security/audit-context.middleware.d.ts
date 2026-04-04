import { NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';
declare module 'express-serve-static-core' {
    interface Request {
        auditContext?: {
            requestId: string;
            ipAddress: string | null;
            userAgent: string | null;
        };
    }
}
export declare class AuditContextMiddleware implements NestMiddleware {
    use(req: Request, res: Response, next: NextFunction): void;
}

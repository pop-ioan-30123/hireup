import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';
import { v4 as uuidv4 } from 'uuid';

declare module 'express-serve-static-core' {
  interface Request {
    auditContext?: {
      requestId: string;
      ipAddress: string | null;
      userAgent: string | null;
    };
  }
}

@Injectable()
export class AuditContextMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction): void {
    const requestId = req.header('x-request-id') ?? uuidv4();
    const ipAddress = req.ip ?? null;
    const userAgent = req.header('user-agent') ?? null;

    req.auditContext = {
      requestId,
      ipAddress,
      userAgent,
    };

    res.setHeader('x-request-id', requestId);
    next();
  }
}
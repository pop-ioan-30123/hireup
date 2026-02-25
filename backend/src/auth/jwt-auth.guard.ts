import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as jwt from 'jsonwebtoken';
import { Request } from 'express';

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
  };
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly configService: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const authHeader = request.headers['authorization'];

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing bearer token');
    }

    const token = authHeader.substring('Bearer '.length).trim();
    const secret = this.configService.get<string>('JWT_ACCESS_SECRET');

    if (!secret) {
      throw new UnauthorizedException('Missing JWT secret');
    }

    try {
      const payload = jwt.verify(token, secret) as { sub?: string; email?: string };
      if (!payload?.sub || !payload?.email) {
        throw new UnauthorizedException('Invalid token');
      }

      request.user = {
        id: payload.sub,
        email: payload.email,
      };

      return true;
    } catch (_) {
      throw new UnauthorizedException('Invalid token');
    }
  }
}

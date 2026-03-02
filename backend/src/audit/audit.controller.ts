import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard, AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { AuditService } from './audit.service';
import { ListAuditLogsQueryDto } from './dto/list-audit-logs-query.dto';
import { ListSecurityEventsQueryDto } from './dto/list-security-events-query.dto';

@Controller('audit')
@UseGuards(JwtAuthGuard)
export class AuditController {
  constructor(private readonly auditService: AuditService) {}

  @Get('logs')
  async listAuditLogs(
    @Req() req: AuthenticatedRequest,
    @Query() query: ListAuditLogsQueryDto,
  ) {
    return this.auditService.listAuditLogs(req.user!.id, query, req.auditContext);
  }

  @Get('security-events')
  async listSecurityEvents(
    @Req() req: AuthenticatedRequest,
    @Query() query: ListSecurityEventsQueryDto,
  ) {
    return this.auditService.listSecurityEvents(req.user!.id, query, req.auditContext);
  }
}

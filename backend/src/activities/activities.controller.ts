import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard, AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { ActivitiesService } from './activities.service';
import { CreateActivityDto } from './dto/create-activity.dto';
import { UpdateActivityDto } from './dto/update-activity.dto';
import { ListMarketplaceQueryDto } from './dto/list-marketplace-query.dto';

@Controller('activities')
@UseGuards(JwtAuthGuard)
export class ActivitiesController {
  constructor(private readonly activitiesService: ActivitiesService) {}

  @Get()
  async listMarketplace(
    @Req() req: AuthenticatedRequest,
    @Query() query: ListMarketplaceQueryDto,
  ) {
    return this.activitiesService.listMarketplace(req.user!.id, query, req.auditContext);
  }

  @Get('mine')
  async listMine(@Req() req: AuthenticatedRequest) {
    return this.activitiesService.listMine(req.user!.id, req.auditContext);
  }

  @Get('upcoming')
  async listUpcoming(@Req() req: AuthenticatedRequest) {
    return this.activitiesService.listUpcoming(req.user!.id, req.auditContext);
  }

  @Get('notifications')
  async listNotifications(@Req() req: AuthenticatedRequest) {
    return this.activitiesService.listNotifications(req.user!.id, req.auditContext);
  }

  @Post('notifications/read')
  async markNotificationsRead(@Req() req: AuthenticatedRequest) {
    return this.activitiesService.markNotificationsRead(req.user!.id, req.auditContext);
  }

  @Post()
  async create(
    @Req() req: AuthenticatedRequest,
    @Body() payload: CreateActivityDto,
  ) {
    return this.activitiesService.create(req.user!.id, payload, req.auditContext);
  }

  @Patch(':activityId')
  async update(
    @Req() req: AuthenticatedRequest,
    @Param('activityId', new ParseUUIDPipe()) activityId: string,
    @Body() payload: UpdateActivityDto,
  ) {
    return this.activitiesService.update(req.user!.id, activityId, payload, req.auditContext);
  }

  @Delete(':activityId')
  async remove(
    @Req() req: AuthenticatedRequest,
    @Param('activityId', new ParseUUIDPipe()) activityId: string,
  ) {
    return this.activitiesService.remove(req.user!.id, activityId, req.auditContext);
  }

  @Post(':activityId/accept')
  async accept(
    @Req() req: AuthenticatedRequest,
    @Param('activityId', new ParseUUIDPipe()) activityId: string,
  ) {
    return this.activitiesService.accept(req.user!.id, activityId, req.auditContext);
  }

  @Post(':activityId/remove-provider')
  async removeProvider(
    @Req() req: AuthenticatedRequest,
    @Param('activityId', new ParseUUIDPipe()) activityId: string,
  ) {
    return this.activitiesService.removeProvider(req.user!.id, activityId, req.auditContext);
  }
}

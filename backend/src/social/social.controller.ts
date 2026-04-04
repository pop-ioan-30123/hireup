import {
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Body,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AuthenticatedRequest, JwtAuthGuard } from '../auth/jwt-auth.guard';
import { UpdatePrivacySettingsDto } from './dto/update-privacy-settings.dto';
import { SocialService } from './social.service';

@Controller('social')
@UseGuards(JwtAuthGuard)
export class SocialController {
  constructor(private readonly socialService: SocialService) {}

  // ── Follow ──────────────────────────────────
  @Post('follow/:userId')
  follow(
    @Req() req: AuthenticatedRequest,
    @Param('userId', ParseUUIDPipe) userId: string,
  ) {
    return this.socialService.followUser(req.user!.id, userId);
  }

  @Delete('follow/:userId')
  unfollow(
    @Req() req: AuthenticatedRequest,
    @Param('userId', ParseUUIDPipe) userId: string,
  ) {
    return this.socialService.unfollowUser(req.user!.id, userId);
  }

  @Get('followers')
  listMyFollowers(@Req() req: AuthenticatedRequest) {
    return this.socialService.listFollowers(req.user!.id);
  }

  @Get('following')
  listMyFollowing(@Req() req: AuthenticatedRequest) {
    return this.socialService.listFollowing(req.user!.id);
  }

  @Get('users/:userId/followers')
  listUserFollowers(
    @Req() req: AuthenticatedRequest,
    @Param('userId', ParseUUIDPipe) userId: string,
  ) {
    return this.socialService.listFollowers(userId, req.user!.id);
  }

  @Get('users/:userId/following')
  listUserFollowing(@Param('userId', ParseUUIDPipe) userId: string) {
    return this.socialService.listFollowing(userId);
  }

  @Get('users/:userId/contacts')
  listUserContacts(
    @Req() req: AuthenticatedRequest,
    @Param('userId', ParseUUIDPipe) userId: string,
  ) {
    return this.socialService.listContacts(userId, req.user!.id);
  }

  // ── Contacts ────────────────────────────────
  @Post('contacts/request/:userId')
  sendContactRequest(
    @Req() req: AuthenticatedRequest,
    @Param('userId', ParseUUIDPipe) userId: string,
  ) {
    return this.socialService.sendContactRequest(req.user!.id, userId);
  }

  @Post('contacts/accept/:userId')
  acceptContactRequest(
    @Req() req: AuthenticatedRequest,
    @Param('userId', ParseUUIDPipe) userId: string,
  ) {
    return this.socialService.acceptContactRequest(req.user!.id, userId);
  }

  @Post('contacts/reject/:userId')
  rejectContactRequest(
    @Req() req: AuthenticatedRequest,
    @Param('userId', ParseUUIDPipe) userId: string,
  ) {
    return this.socialService.rejectContactRequest(req.user!.id, userId);
  }

  @Delete('contacts/:userId')
  removeContact(
    @Req() req: AuthenticatedRequest,
    @Param('userId', ParseUUIDPipe) userId: string,
  ) {
    return this.socialService.removeContact(req.user!.id, userId);
  }

  @Get('contacts')
  listContacts(@Req() req: AuthenticatedRequest) {
    return this.socialService.listContacts(req.user!.id);
  }

  @Get('notifications')
  listNotifications(@Req() req: AuthenticatedRequest) {
    return this.socialService.listSocialNotifications(req.user!.id);
  }

  @Post('notifications/read')
  markNotificationsRead(@Req() req: AuthenticatedRequest) {
    return this.socialService.markNotificationsRead(req.user!.id);
  }

  @Get('contacts/requests')
  listContactRequests(@Req() req: AuthenticatedRequest) {
    return this.socialService.listPendingContactRequests(req.user!.id);
  }

  // ── Social summary for a profile ──────────────
  @Get('users/:userId/summary')
  getSocialSummary(
    @Req() req: AuthenticatedRequest,
    @Param('userId', ParseUUIDPipe) userId: string,
  ) {
    return this.socialService.getSocialSummary(req.user!.id, userId);
  }

  // ── Privacy settings ────────────────────────
  @Get('privacy')
  getPrivacy(@Req() req: AuthenticatedRequest) {
    return this.socialService.getPrivacySettings(req.user!.id);
  }

  @Patch('privacy')
  updatePrivacy(
    @Req() req: AuthenticatedRequest,
    @Body() dto: UpdatePrivacySettingsDto,
  ) {
    return this.socialService.updatePrivacySettings(req.user!.id, dto);
  }
}

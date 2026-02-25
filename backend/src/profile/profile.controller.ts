import { Body, Controller, Get, NotFoundException, Patch, Req, StreamableFile, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { JwtAuthGuard, AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { UpdateCompanyProfileDto } from './dto/update-company-profile.dto';
import { UpdateProfileVisibilityDto } from './dto/update-profile-visibility.dto';
import { UpdateThemePreferenceDto } from './dto/update-theme-preference.dto';
import { UpdateUserProfileDto } from './dto/update-user-profile.dto';
import { ProfileService } from './profile.service';

@Controller('profile')
export class ProfileController {
  constructor(private readonly profileService: ProfileService) {}

  @UseGuards(JwtAuthGuard)
  @Get('me')
  async getProfile(@Req() req: AuthenticatedRequest) {
    return this.profileService.getProfile(req.user!.id);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('user')
  async updateUserProfile(
    @Req() req: AuthenticatedRequest,
    @Body() payload: UpdateUserProfileDto,
  ) {
    return this.profileService.updateUserProfile(req.user!.id, payload, req.auditContext);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('company')
  async updateCompanyProfile(
    @Req() req: AuthenticatedRequest,
    @Body() payload: UpdateCompanyProfileDto,
  ) {
    return this.profileService.updateCompanyProfile(req.user!.id, payload, req.auditContext);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('visibility')
  async updateVisibility(
    @Req() req: AuthenticatedRequest,
    @Body() payload: UpdateProfileVisibilityDto,
  ) {
    return this.profileService.updateVisibility(req.user!.id, payload, req.auditContext);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('theme')
  async updateThemePreference(
    @Req() req: AuthenticatedRequest,
    @Body() payload: UpdateThemePreferenceDto,
  ) {
    return this.profileService.updateThemePreference(req.user!.id, payload, req.auditContext);
  }

  @UseGuards(JwtAuthGuard)
  @Get('avatar')
  async getAvatar(@Req() req: AuthenticatedRequest): Promise<StreamableFile> {
    const avatar = await this.profileService.getAvatar(req.user!.id);
    if (!avatar) {
      throw new NotFoundException('Avatar not found');
    }

    return new StreamableFile(avatar.buffer, {
      type: avatar.mimeType ?? 'application/octet-stream',
      length: avatar.size,
      disposition: 'inline',
    });
  }
}

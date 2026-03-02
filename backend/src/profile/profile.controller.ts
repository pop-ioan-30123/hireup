import {
  Body,
  Controller,
  DefaultValuePipe,
  Delete,
  Get,
  NotFoundException,
  Param,
  ParseIntPipe,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Query,
  Req,
  StreamableFile,
  UseGuards,
} from '@nestjs/common';
import { Response } from 'express';
import { JwtAuthGuard, AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { CreateActivityPostDto } from './dto/create-activity-post.dto';
import { CreateActivityCommentDto } from './dto/create-activity-comment.dto';
import { SetUserEducationsDto } from './dto/set-user-educations.dto';
import { SetUserExperiencesDto } from './dto/set-user-experiences.dto';
import { SetUserProjectsDto } from './dto/set-user-projects.dto';
import { SetUserSkillsDto } from './dto/set-user-skills.dto';
import { UpdateCompanyProfileDto } from './dto/update-company-profile.dto';
import { UpdateActivityPostDto } from './dto/update-activity-post.dto';
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
  @Put('user/experiences')
  async setUserExperiences(
    @Req() req: AuthenticatedRequest,
    @Body() payload: SetUserExperiencesDto,
  ) {
    return this.profileService.setUserExperiences(req.user!.id, payload, req.auditContext);
  }

  @UseGuards(JwtAuthGuard)
  @Put('user/educations')
  async setUserEducations(
    @Req() req: AuthenticatedRequest,
    @Body() payload: SetUserEducationsDto,
  ) {
    return this.profileService.setUserEducations(req.user!.id, payload, req.auditContext);
  }

  @UseGuards(JwtAuthGuard)
  @Put('user/skills')
  async setUserSkills(
    @Req() req: AuthenticatedRequest,
    @Body() payload: SetUserSkillsDto,
  ) {
    return this.profileService.setUserSkills(req.user!.id, payload, req.auditContext);
  }

  @UseGuards(JwtAuthGuard)
  @Put('user/projects')
  async setUserProjects(
    @Req() req: AuthenticatedRequest,
    @Body() payload: SetUserProjectsDto,
  ) {
    return this.profileService.setUserProjects(req.user!.id, payload, req.auditContext);
  }

  @UseGuards(JwtAuthGuard)
  @Get('search/users')
  async searchUsers(
    @Req() req: AuthenticatedRequest,
    @Query('q', new DefaultValuePipe('')) query: string,
    @Query('field', new DefaultValuePipe('all')) field: string,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ) {
    return this.profileService.searchUsers(req.user!.id, query, field, page, limit);
  }

  @UseGuards(JwtAuthGuard)
  @Get('users/:userId')
  async getUserProfileById(
    @Req() req: AuthenticatedRequest,
    @Param('userId', new ParseUUIDPipe()) userId: string,
  ) {
    return this.profileService.getProfileForViewer(req.user!.id, userId);
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
  @Post('activity-posts')
  async createActivityPost(
    @Req() req: AuthenticatedRequest,
    @Body() payload: CreateActivityPostDto,
  ) {
    return this.profileService.createActivityPost(req.user!.id, payload, req.auditContext);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('activity-posts/:postId')
  async updateActivityPost(
    @Req() req: AuthenticatedRequest,
    @Param('postId', new ParseUUIDPipe()) postId: string,
    @Body() payload: UpdateActivityPostDto,
  ) {
    return this.profileService.updateActivityPost(req.user!.id, postId, payload, req.auditContext);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('activity-posts/:postId')
  async deleteActivityPost(
    @Req() req: AuthenticatedRequest,
    @Param('postId', new ParseUUIDPipe()) postId: string,
  ) {
    return this.profileService.deleteActivityPost(req.user!.id, postId, req.auditContext);
  }

  @UseGuards(JwtAuthGuard)
  @Post('activity-posts/:postId/comments')
  async createActivityComment(
    @Req() req: AuthenticatedRequest,
    @Param('postId', new ParseUUIDPipe()) postId: string,
    @Body() payload: CreateActivityCommentDto,
  ) {
    return this.profileService.createActivityComment(
      req.user!.id,
      postId,
      payload,
      req.auditContext,
    );
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

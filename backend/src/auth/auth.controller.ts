import { Body, Controller, Get, Post, Query, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';
import { AuthService } from './auth.service';
import { CheckEmailDto } from './dto/check-email.dto';
import { LoginDto } from './dto/login.dto';
import { RegisterCompanyDto } from './dto/register-company.dto';
import { RegisterUserDto } from './dto/register-user.dto';
import { TwoFactorCodeDto } from './dto/two-factor-code.dto';
import { AuthenticatedRequest, JwtAuthGuard } from './jwt-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register-user')
  registerUser(@Body() payload: RegisterUserDto, @Req() req: Request) {
    return this.authService.registerUser(payload, req.auditContext);
  }

  @Post('register-company')
  registerCompany(@Body() payload: RegisterCompanyDto, @Req() req: Request) {
    return this.authService.registerCompany(payload, req.auditContext);
  }

  @Post('login')
  login(@Body() payload: LoginDto, @Req() req: Request) {
    return this.authService.login(payload, req.auditContext);
  }

  @Post('check-email')
  checkEmail(@Body() payload: CheckEmailDto) {
    return this.authService.checkEmailAvailability(payload.email);
  }

  @UseGuards(JwtAuthGuard)
  @Post('2fa/setup')
  setupTwoFactor(@Req() req: AuthenticatedRequest) {
    return this.authService.setupTwoFactor(req.user!.id, req.user!.email, req.auditContext);
  }

  @UseGuards(JwtAuthGuard)
  @Post('2fa/setup/cancel')
  cancelTwoFactorSetup(@Req() req: AuthenticatedRequest) {
    return this.authService.cancelTwoFactorSetup(req.user!.id, req.auditContext);
  }

  @UseGuards(JwtAuthGuard)
  @Post('2fa/enable')
  enableTwoFactor(
    @Req() req: AuthenticatedRequest,
    @Body() payload: TwoFactorCodeDto,
  ) {
    return this.authService.enableTwoFactor(req.user!.id, payload.code, req.auditContext);
  }

  @UseGuards(JwtAuthGuard)
  @Post('2fa/disable')
  disableTwoFactor(
    @Req() req: AuthenticatedRequest,
    @Body() payload: TwoFactorCodeDto,
  ) {
    return this.authService.disableTwoFactor(req.user!.id, payload.code, req.auditContext);
  }

  @UseGuards(JwtAuthGuard)
  @Post('2fa/backup-codes/regenerate')
  regenerateBackupCodes(
    @Req() req: AuthenticatedRequest,
    @Body() payload: TwoFactorCodeDto,
  ) {
    return this.authService.regenerateTwoFactorBackupCodes(
      req.user!.id,
      payload.code,
      req.auditContext,
    );
  }

  @Get('verify-email')
  verifyEmail(@Query('token') token: string, @Req() req: Request) {
    return this.authService.verifyEmailToken(token, req.auditContext);
  }

  @UseGuards(JwtAuthGuard)
  @Post('verification/resend')
  resendVerificationEmail(@Req() req: AuthenticatedRequest) {
    return this.authService.resendEmailVerification(req.user!.id, req.auditContext);
  }
}
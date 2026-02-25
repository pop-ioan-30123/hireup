import { Request } from 'express';
import { AuthService } from './auth.service';
import { CheckEmailDto } from './dto/check-email.dto';
import { LoginDto } from './dto/login.dto';
import { RegisterCompanyDto } from './dto/register-company.dto';
import { RegisterUserDto } from './dto/register-user.dto';
import { TwoFactorCodeDto } from './dto/two-factor-code.dto';
import { AuthenticatedRequest } from './jwt-auth.guard';
export declare class AuthController {
    private readonly authService;
    constructor(authService: AuthService);
    registerUser(payload: RegisterUserDto, req: Request): Promise<{
        success: boolean;
        userId: string;
        verificationEmailSent: boolean;
    }>;
    registerCompany(payload: RegisterCompanyDto, req: Request): Promise<{
        success: boolean;
        userId: string;
        companyId: string;
        verificationEmailSent: boolean;
    }>;
    login(payload: LoginDto, req: Request): Promise<{
        accessToken: string;
        refreshToken: string;
        tokenType: string;
        expiresIn: string;
        user: {
            id: string;
            email: string;
            status: string;
            isEmailVerified: boolean;
        };
    }>;
    checkEmail(payload: CheckEmailDto): Promise<{
        available: boolean;
    }>;
    setupTwoFactor(req: AuthenticatedRequest): Promise<{
        qrCodeDataUrl: string;
        manualEntryKey: string;
        issuer: string;
        account: string;
    }>;
    cancelTwoFactorSetup(req: AuthenticatedRequest): Promise<{
        success: true;
    }>;
    enableTwoFactor(req: AuthenticatedRequest, payload: TwoFactorCodeDto): Promise<{
        success: true;
    }>;
    disableTwoFactor(req: AuthenticatedRequest, payload: TwoFactorCodeDto): Promise<{
        success: true;
    }>;
    regenerateBackupCodes(req: AuthenticatedRequest, payload: TwoFactorCodeDto): Promise<{
        backupCodes: string[];
    }>;
    verifyEmail(token: string, req: Request): Promise<{
        success: boolean;
        alreadyVerified: boolean;
    }>;
    resendVerificationEmail(req: AuthenticatedRequest): Promise<{
        success: boolean;
        alreadyVerified: boolean;
        verificationEmailSent: boolean;
    }>;
}

import { ConfigService } from '@nestjs/config';
import { DatabaseService } from '../database/database.service';
import { AuditSqlContext } from '../database/audit-sql-context';
import { LoginDto } from './dto/login.dto';
import { RegisterCompanyDto } from './dto/register-company.dto';
import { RegisterUserDto } from './dto/register-user.dto';
export declare class AuthService {
    private readonly db;
    private readonly configService;
    private readonly accessSecret;
    private readonly accessTtl;
    private readonly refreshDays;
    private readonly twoFactorIssuer;
    private readonly twoFactorEncryptionKey;
    private readonly emailVerifyTtlHours;
    private readonly verificationBaseUrl;
    private readonly mailFromAddress;
    private readonly smtpHost;
    private readonly smtpPort;
    private readonly smtpSecure;
    private readonly smtpUser;
    private readonly smtpPass;
    constructor(db: DatabaseService, configService: ConfigService);
    setupTwoFactor(userId: string, userEmail: string, requestContext?: AuditSqlContext): Promise<{
        qrCodeDataUrl: string;
        manualEntryKey: string;
        issuer: string;
        account: string;
    }>;
    cancelTwoFactorSetup(userId: string, requestContext?: AuditSqlContext): Promise<{
        success: true;
    }>;
    enableTwoFactor(userId: string, code: string, requestContext?: AuditSqlContext): Promise<{
        success: true;
    }>;
    disableTwoFactor(userId: string, code: string, requestContext?: AuditSqlContext): Promise<{
        success: true;
    }>;
    regenerateTwoFactorBackupCodes(userId: string, code: string, requestContext?: AuditSqlContext): Promise<{
        backupCodes: string[];
    }>;
    registerUser(payload: RegisterUserDto, requestContext?: AuditSqlContext): Promise<{
        success: boolean;
        userId: string;
        verificationEmailSent: boolean;
    }>;
    registerCompany(payload: RegisterCompanyDto, requestContext?: AuditSqlContext): Promise<{
        success: boolean;
        userId: string;
        companyId: string;
        verificationEmailSent: boolean;
    }>;
    login(payload: LoginDto, requestContext?: AuditSqlContext): Promise<{
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
    resendEmailVerification(userId: string, requestContext?: AuditSqlContext): Promise<{
        success: boolean;
        alreadyVerified: boolean;
        verificationEmailSent: boolean;
    }>;
    verifyEmailToken(token: string, requestContext?: AuditSqlContext): Promise<{
        success: boolean;
        alreadyVerified: boolean;
    }>;
    private ensureEmailVerificationTable;
    private hashEmailVerificationToken;
    private issueEmailVerificationToken;
    private get emailTransportConfigured();
    private resolveEmailLocale;
    private buildEmailSalutation;
    private sendEmailVerificationLink;
    checkEmailAvailability(email: string): Promise<{
        available: boolean;
    }>;
    private ensureEmailNotExists;
    private signAccessToken;
    private hashRefreshToken;
    private encryptTwoFactorSecret;
    private decryptTwoFactorSecret;
    private verifyTwoFactorCode;
    private generateTwoFactorBackupCodes;
    private hashBackupCode;
    private consumeBackupCode;
    private logSecurityEvent;
}

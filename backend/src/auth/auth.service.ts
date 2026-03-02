import { BadRequestException, ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as argon2 from 'argon2';
import * as crypto from 'crypto';
import * as jwt from 'jsonwebtoken';
import * as nodemailer from 'nodemailer';
import { authenticator } from 'otplib';
import { PoolClient } from 'pg';
import * as QRCode from 'qrcode';
import { DatabaseService } from '../database/database.service';
import { applyAuditSqlContext, AuditSqlContext } from '../database/audit-sql-context';
import { LoginDto } from './dto/login.dto';
import { RegisterCompanyDto } from './dto/register-company.dto';
import { RegisterUserDto } from './dto/register-user.dto';

interface UserRow {
  id: string;
  email: string;
  password_hash: string;
  status: string;
  is_email_verified: boolean;
  failed_login_attempts: number;
  locked_until: string | null;
  two_factor_enabled: boolean;
  two_factor_secret_enc: string | null;
  two_factor_backup_codes_hashes: string[];
}

@Injectable()
export class AuthService {
  private readonly accessSecret: string;
  private readonly accessTtl: jwt.SignOptions['expiresIn'];
  private readonly refreshDays: number;
  private readonly twoFactorIssuer: string;
  private readonly twoFactorEncryptionKey: Buffer;
  private readonly emailVerifyTtlHours: number;
  private readonly verificationBaseUrl: string;
  private readonly mailFromAddress: string;
  private readonly smtpHost: string;
  private readonly smtpPort: number;
  private readonly smtpSecure: boolean;
  private readonly smtpUser: string;
  private readonly smtpPass: string;

  constructor(
    private readonly db: DatabaseService,
    private readonly configService: ConfigService,
  ) {
    this.accessSecret = this.configService.get<string>('JWT_ACCESS_SECRET') ?? '';
    this.accessTtl = (this.configService.get<string>('JWT_ACCESS_EXPIRES_IN') ?? '15m') as jwt.SignOptions['expiresIn'];
    this.refreshDays = Number(this.configService.get<string>('REFRESH_TOKEN_DAYS') ?? '30');
    this.twoFactorIssuer = this.configService.get<string>('TWO_FACTOR_ISSUER') ?? 'CareerSuitUp';
    this.emailVerifyTtlHours = Number(
      this.configService.get<string>('EMAIL_VERIFICATION_TTL_HOURS') ?? '24',
    );
    this.verificationBaseUrl =
      this.configService.get<string>('EMAIL_VERIFICATION_BASE_URL') ??
      `http://localhost:${this.configService.get<string>('PORT') ?? '4000'}`;
    this.mailFromAddress =
      this.configService.get<string>('SMTP_FROM') ?? 'no-reply@careersuitup.local';
    this.smtpHost = this.configService.get<string>('SMTP_HOST') ?? '';
    this.smtpPort = Number(this.configService.get<string>('SMTP_PORT') ?? '587');
    this.smtpSecure =
      (this.configService.get<string>('SMTP_SECURE') ?? 'false').toLowerCase() ===
      'true';
    this.smtpUser = this.configService.get<string>('SMTP_USER') ?? '';
    this.smtpPass = this.configService.get<string>('SMTP_PASS') ?? '';

    if (!this.accessSecret) {
      throw new Error('JWT_ACCESS_SECRET is required');
    }

    const encryptionSeed =
      this.configService.get<string>('TWO_FACTOR_ENCRYPTION_KEY') ??
      this.accessSecret;
    this.twoFactorEncryptionKey = crypto
      .createHash('sha256')
      .update(encryptionSeed)
      .digest();

    authenticator.options = {
      step: 30,
      digits: 6,
      window: 1,
    };
  }

  async setupTwoFactor(
    userId: string,
    userEmail: string,
    requestContext?: AuditSqlContext,
  ): Promise<{
    qrCodeDataUrl: string;
    manualEntryKey: string;
    issuer: string;
    account: string;
  }> {
    const normalizedEmail = userEmail.toLowerCase().trim();
    const secret = authenticator.generateSecret();
    const encryptedSecret = this.encryptTwoFactorSecret(secret);
    const otpauthUrl = authenticator.keyuri(normalizedEmail, this.twoFactorIssuer, secret);
    const qrCodeDataUrl = await QRCode.toDataURL(otpauthUrl);

    await this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        ...requestContext,
        currentUserId: userId,
        currentUserEmail: normalizedEmail,
      });

      await client.query(
        `
          UPDATE app_user
          SET
            two_factor_enabled = false,
            two_factor_secret_enc = $2,
            two_factor_enabled_at = NULL
          WHERE id = $1
            AND deleted_at IS NULL
        `,
        [userId, encryptedSecret],
      );

      await this.logSecurityEvent(client, {
        userId,
        eventType: 'two_factor_setup_started',
        severity: 'low',
        details: {},
        requestContext,
      });
    });

    return {
      qrCodeDataUrl,
      manualEntryKey: secret,
      issuer: this.twoFactorIssuer,
      account: normalizedEmail,
    };
  }

  async cancelTwoFactorSetup(
    userId: string,
    requestContext?: AuditSqlContext,
  ): Promise<{ success: true }> {
    return this.db.withTransaction(async (client) => {
      const userRes = await client.query<{ email: string }>(
        `
          SELECT email
          FROM app_user
          WHERE id = $1
            AND deleted_at IS NULL
          LIMIT 1
        `,
        [userId],
      );

      const user = userRes.rows[0];
      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      await applyAuditSqlContext(client, {
        ...requestContext,
        currentUserId: userId,
        currentUserEmail: user.email,
      });

      await client.query(
        `
          UPDATE app_user
          SET
            two_factor_enabled = false,
            two_factor_secret_enc = NULL,
            two_factor_backup_codes_hashes = '{}',
            two_factor_backup_codes_generated_at = NULL,
            two_factor_enabled_at = NULL
          WHERE id = $1
        `,
        [userId],
      );

      await this.logSecurityEvent(client, {
        userId,
        eventType: 'two_factor_setup_cancelled',
        severity: 'low',
        details: {},
        requestContext,
      });

      return { success: true };
    });
  }

  async enableTwoFactor(
    userId: string,
    code: string,
    requestContext?: AuditSqlContext,
  ): Promise<{ success: true }> {
    return this.db.withTransaction(async (client) => {
      const userRes = await client.query<{
        email: string;
        two_factor_secret_enc: string | null;
      }>(
        `
          SELECT email, two_factor_secret_enc
          FROM app_user
          WHERE id = $1
            AND deleted_at IS NULL
          LIMIT 1
        `,
        [userId],
      );

      const user = userRes.rows[0];
      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      await applyAuditSqlContext(client, {
        ...requestContext,
        currentUserId: userId,
        currentUserEmail: user.email,
      });

      if (!user.two_factor_secret_enc) {
        throw new BadRequestException({
          code: 'TWO_FACTOR_SETUP_REQUIRED',
          message: 'Two-factor setup must be started before enabling.',
        });
      }

      const secret = this.decryptTwoFactorSecret(user.two_factor_secret_enc);
      const valid = this.verifyTwoFactorCode(secret, code);

      if (!valid) {
        await client.query(
          `
            UPDATE app_user
            SET
              two_factor_enabled = false,
              two_factor_secret_enc = NULL,
              two_factor_backup_codes_hashes = '{}',
              two_factor_backup_codes_generated_at = NULL,
              two_factor_enabled_at = NULL
            WHERE id = $1
          `,
          [userId],
        );

        await this.logSecurityEvent(client, {
          userId,
          eventType: 'two_factor_setup_cancelled_invalid_code',
          severity: 'medium',
          details: {},
          requestContext,
        });

        throw new UnauthorizedException({
          code: 'TWO_FACTOR_INVALID',
          message: 'Invalid two-factor authentication code.',
        });
      }

      await client.query(
        `
          UPDATE app_user
          SET
            two_factor_enabled = true,
            two_factor_enabled_at = NOW()
          WHERE id = $1
        `,
        [userId],
      );

      await this.logSecurityEvent(client, {
        userId,
        eventType: 'two_factor_enabled',
        severity: 'medium',
        details: {},
        requestContext,
      });

      return { success: true };
    });
  }

  async disableTwoFactor(
    userId: string,
    code: string,
    requestContext?: AuditSqlContext,
  ): Promise<{ success: true }> {
    return this.db.withTransaction(async (client) => {
      const userRes = await client.query<{
        email: string;
        two_factor_enabled: boolean;
        two_factor_secret_enc: string | null;
      }>(
        `
          SELECT email, two_factor_enabled, two_factor_secret_enc
          FROM app_user
          WHERE id = $1
            AND deleted_at IS NULL
          LIMIT 1
        `,
        [userId],
      );

      const user = userRes.rows[0];
      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      await applyAuditSqlContext(client, {
        ...requestContext,
        currentUserId: userId,
        currentUserEmail: user.email,
      });

      if (!user.two_factor_enabled || !user.two_factor_secret_enc) {
        return { success: true };
      }

      const secret = this.decryptTwoFactorSecret(user.two_factor_secret_enc);
      const valid = this.verifyTwoFactorCode(secret, code);

      if (!valid) {
        throw new UnauthorizedException({
          code: 'TWO_FACTOR_INVALID',
          message: 'Invalid two-factor authentication code.',
        });
      }

      await client.query(
        `
          UPDATE app_user
          SET
            two_factor_enabled = false,
            two_factor_secret_enc = NULL,
            two_factor_backup_codes_hashes = '{}',
            two_factor_backup_codes_generated_at = NULL,
            two_factor_enabled_at = NULL
          WHERE id = $1
        `,
        [userId],
      );

      await this.logSecurityEvent(client, {
        userId,
        eventType: 'two_factor_disabled',
        severity: 'medium',
        details: {},
        requestContext,
      });

      return { success: true };
    });
  }

  async regenerateTwoFactorBackupCodes(
    userId: string,
    code: string,
    requestContext?: AuditSqlContext,
  ): Promise<{ backupCodes: string[] }> {
    return this.db.withTransaction(async (client) => {
      const userRes = await client.query<{
        email: string;
        two_factor_enabled: boolean;
        two_factor_secret_enc: string | null;
      }>(
        `
          SELECT email, two_factor_enabled, two_factor_secret_enc
          FROM app_user
          WHERE id = $1
            AND deleted_at IS NULL
          LIMIT 1
        `,
        [userId],
      );

      const user = userRes.rows[0];
      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      await applyAuditSqlContext(client, {
        ...requestContext,
        currentUserId: userId,
        currentUserEmail: user.email,
      });

      if (!user.two_factor_enabled || !user.two_factor_secret_enc) {
        throw new BadRequestException({
          code: 'TWO_FACTOR_DISABLED',
          message: 'Two-factor authentication must be enabled first.',
        });
      }

      const secret = this.decryptTwoFactorSecret(user.two_factor_secret_enc);
      const valid = this.verifyTwoFactorCode(secret, code);

      if (!valid) {
        throw new UnauthorizedException({
          code: 'TWO_FACTOR_INVALID',
          message: 'Invalid two-factor authentication code.',
        });
      }

      const backupCodes = this.generateTwoFactorBackupCodes();
      const backupCodeHashes = backupCodes.map((value) => this.hashBackupCode(value));

      await client.query(
        `
          UPDATE app_user
          SET
            two_factor_backup_codes_hashes = $2,
            two_factor_backup_codes_generated_at = NOW()
          WHERE id = $1
        `,
        [userId, backupCodeHashes],
      );

      await this.logSecurityEvent(client, {
        userId,
        eventType: 'two_factor_backup_codes_regenerated',
        severity: 'medium',
        details: { count: backupCodes.length },
        requestContext,
      });

      return { backupCodes };
    });
  }

  async registerUser(payload: RegisterUserDto, requestContext?: AuditSqlContext) {
    const registration = await this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        ...requestContext,
        currentUserEmail: payload.email,
      });

      await this.ensureEmailVerificationTable(client);

      await this.ensureEmailNotExists(client, payload.email);

      const passwordHash = await argon2.hash(payload.password, { type: argon2.argon2id });

      const userInsert = await client.query<{ id: string }>(
        `
          INSERT INTO app_user (
            account_type,
            email,
            password_hash,
            first_name,
            last_name,
            gender,
            birth_date,
            phone_e164,
            status
          )
          VALUES ('user', $1, $2, $3, $4, $5, $6::date, $7, 'pending_verification')
          RETURNING id
        `,
        [
          payload.email.toLowerCase().trim(),
          passwordHash,
          payload.firstName.trim(),
          payload.lastName.trim(),
          payload.gender,
          payload.birthDate ?? null,
          payload.phone.trim(),
        ],
      );

      const userId = userInsert.rows[0].id;

      await applyAuditSqlContext(client, {
        ...requestContext,
        currentUserId: userId,
        currentUserEmail: payload.email,
      });

      await client.query(
        `
          INSERT INTO user_profile (
            user_id,
            job_title,
            years_experience,
            education_level,
            education_institution,
            specialization,
            country,
            county,
            city
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        `,
        [
          userId,
          payload.jobTitle.trim(),
          payload.yearsExperience ?? 0,
          payload.educationLevel?.trim() ?? '',
          payload.educationInstitution?.trim() ?? '',
          payload.specialization?.trim() ?? '',
          payload.country.trim(),
          payload.county.trim(),
          payload.city.trim(),
        ],
      );

      await client.query(
        `
          INSERT INTO profile_visibility (user_id)
          VALUES ($1)
          ON CONFLICT (user_id) DO NOTHING
        `,
        [userId],
      );

      await client.query(
        `
          INSERT INTO user_consent (
            user_id,
            consent_type,
            accepted,
            consent_version,
            locale,
            ip_address,
            user_agent
          )
          VALUES ($1, 'gdpr_registration', true, $2, $3, $4::inet, $5)
        `,
        [
          userId,
          payload.gdprVersion,
          payload.locale,
          payload.ipAddress ?? requestContext?.ipAddress ?? null,
          payload.userAgent ?? requestContext?.userAgent ?? null,
        ],
      );

      await this.logSecurityEvent(client, {
        userId,
        eventType: 'registration_user_success',
        severity: 'low',
        details: { email: payload.email.toLowerCase().trim() },
        requestContext,
      });

      const verificationToken = await this.issueEmailVerificationToken(client, userId);

      return {
        success: true,
        userId,
        email: payload.email.toLowerCase().trim(),
        verificationToken,
      };
    });

    const verificationSent = await this.sendEmailVerificationLink(
      registration.email,
      registration.verificationToken,
      payload.locale,
      payload.gender,
      payload.lastName,
    );

    return {
      success: true,
      userId: registration.userId,
      verificationEmailSent: verificationSent,
    };
  }

  async registerCompany(payload: RegisterCompanyDto, requestContext?: AuditSqlContext) {
    const registration = await this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        ...requestContext,
        currentUserEmail: payload.email,
      });

      await this.ensureEmailVerificationTable(client);

      await this.ensureEmailNotExists(client, payload.email);

      const passwordHash = await argon2.hash(payload.password, { type: argon2.argon2id });

      const userInsert = await client.query<{ id: string }>(
        `
          INSERT INTO app_user (
            account_type,
            email,
            password_hash,
            first_name,
            last_name,
            gender,
            birth_date,
            status
          )
          VALUES ('company', $1, $2, $3, $4, $5, $6::date, 'pending_verification')
          RETURNING id
        `,
        [
          payload.email.toLowerCase().trim(),
          passwordHash,
          payload.hrFirstName.trim(),
          payload.hrLastName.trim(),
          payload.gender,
          payload.birthDate ?? null,
        ],
      );

      const userId = userInsert.rows[0].id;

      await applyAuditSqlContext(client, {
        ...requestContext,
        currentUserId: userId,
        currentUserEmail: payload.email,
      });

      const companyInsert = await client.query<{ id: string }>(
        `
          INSERT INTO company (
            account_user_id,
            legal_name,
            country_code,
            county,
            city
          )
          VALUES ($1, $2, $3, $4, $5)
          RETURNING id
        `,
        [
          userId,
          payload.companyName.trim(),
          (payload.countryCode ?? 'RO').trim().toUpperCase(),
          payload.county?.trim() ?? null,
          payload.city?.trim() ?? null,
        ],
      );

      const companyId = companyInsert.rows[0].id;

      await client.query(
        `
          INSERT INTO profile_visibility (user_id)
          VALUES ($1)
          ON CONFLICT (user_id) DO NOTHING
        `,
        [userId],
      );

      await client.query(
        `
          INSERT INTO company_hr_contact (
            company_id,
            first_name,
            last_name,
            email,
            is_primary
          )
          VALUES ($1, $2, $3, $4, true)
        `,
        [
          companyId,
          payload.hrFirstName.trim(),
          payload.hrLastName.trim(),
          payload.hrEmail.toLowerCase().trim(),
        ],
      );

      await client.query(
        `
          INSERT INTO user_consent (
            user_id,
            consent_type,
            accepted,
            consent_version,
            locale,
            ip_address,
            user_agent
          )
          VALUES ($1, 'gdpr_registration', true, $2, $3, $4::inet, $5)
        `,
        [
          userId,
          payload.gdprVersion,
          payload.locale,
          payload.ipAddress ?? requestContext?.ipAddress ?? null,
          payload.userAgent ?? requestContext?.userAgent ?? null,
        ],
      );

      await this.logSecurityEvent(client, {
        userId,
        eventType: 'registration_company_success',
        severity: 'low',
        details: { email: payload.email.toLowerCase().trim(), companyId },
        requestContext,
      });

      const verificationToken = await this.issueEmailVerificationToken(client, userId);

      return {
        success: true,
        userId,
        companyId,
        email: payload.email.toLowerCase().trim(),
        verificationToken,
      };
    });

    const verificationSent = await this.sendEmailVerificationLink(
      registration.email,
      registration.verificationToken,
      payload.locale,
      payload.gender,
      payload.hrLastName,
    );

    return {
      success: true,
      userId: registration.userId,
      companyId: registration.companyId,
      verificationEmailSent: verificationSent,
    };
  }

  async login(payload: LoginDto, requestContext?: AuditSqlContext) {
    const normalizedEmail = payload.email.toLowerCase().trim();

    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        ...requestContext,
        currentUserEmail: normalizedEmail,
      });

      const userRes = await client.query<UserRow>(
        `
          SELECT id, email, password_hash, status, failed_login_attempts, locked_until, two_factor_enabled, two_factor_secret_enc, two_factor_backup_codes_hashes
                 , is_email_verified
          FROM app_user
          WHERE email = $1
            AND deleted_at IS NULL
          LIMIT 1
        `,
        [normalizedEmail],
      );

      if (userRes.rowCount === 0) {
        await this.logSecurityEvent(client, {
          userId: null,
          eventType: 'login_failed_user_not_found',
          severity: 'medium',
          details: { email: normalizedEmail },
          requestContext,
        });
        throw new UnauthorizedException({
          code: 'EMAIL_NOT_FOUND',
          message: 'No account exists for this email address.',
        });
      }

      const user = userRes.rows[0];

      await applyAuditSqlContext(client, {
        ...requestContext,
        currentUserId: user.id,
        currentUserEmail: user.email,
      });

      if (user.locked_until && new Date(user.locked_until) > new Date()) {
        const retryAfterSeconds = Math.max(
          1,
          Math.ceil((new Date(user.locked_until).getTime() - Date.now()) / 1000),
        );

        await this.logSecurityEvent(client, {
          userId: user.id,
          eventType: 'login_blocked_temporary_lock',
          severity: 'high',
          details: { lockedUntil: user.locked_until, retryAfterSeconds },
          requestContext,
        });
        throw new UnauthorizedException({
          code: 'WRONG_PASSWORD',
          message: 'The password entered is incorrect. Please retry later.',
          retryAfterSeconds,
        });
      }

      const validPassword = await argon2.verify(user.password_hash, payload.password);

      if (!validPassword) {
        const nextFailedAttempts = user.failed_login_attempts + 1;
        const retryAfterSeconds = 10;
        const lockUntil = new Date(Date.now() + retryAfterSeconds * 1000);

        await client.query(
          `
            UPDATE app_user
            SET
              failed_login_attempts = $2,
              last_failed_login_at = NOW(),
              locked_until = $3
            WHERE id = $1
          `,
          [user.id, nextFailedAttempts, lockUntil],
        );

        await this.logSecurityEvent(client, {
          userId: user.id,
          eventType: 'login_failed_invalid_password',
          severity: 'medium',
          details: {
            attempts: nextFailedAttempts,
            lockedUntil: lockUntil,
            retryAfterSeconds,
          },
          requestContext,
        });

        throw new UnauthorizedException({
          code: 'WRONG_PASSWORD',
          message: 'The password entered is incorrect. Please retry later.',
          retryAfterSeconds,
        });
      }

      if (user.two_factor_enabled) {
        if (!payload.twoFactorCode || payload.twoFactorCode.trim().length === 0) {
          await this.logSecurityEvent(client, {
            userId: user.id,
            eventType: 'login_failed_two_factor_missing',
            severity: 'medium',
            details: { email: user.email },
            requestContext,
          });

          throw new UnauthorizedException({
            code: 'TWO_FACTOR_REQUIRED',
            message: 'Two-factor authentication code is required.',
          });
        }

        if (!user.two_factor_secret_enc) {
          throw new UnauthorizedException({
            code: 'TWO_FACTOR_REQUIRED',
            message: 'Two-factor authentication setup is invalid.',
          });
        }

        const secret = this.decryptTwoFactorSecret(user.two_factor_secret_enc);
        const validTwoFactorCode = this.verifyTwoFactorCode(secret, payload.twoFactorCode);

        if (!validTwoFactorCode) {
          const backupCodeConsumed = await this.consumeBackupCode(
            client,
            user.id,
            payload.twoFactorCode,
          );

          if (backupCodeConsumed) {
            await this.logSecurityEvent(client, {
              userId: user.id,
              eventType: 'login_success_two_factor_backup_code',
              severity: 'medium',
              details: { email: user.email },
              requestContext,
            });
          } else {
            await this.logSecurityEvent(client, {
              userId: user.id,
              eventType: 'login_failed_two_factor_invalid',
              severity: 'medium',
              details: { email: user.email },
              requestContext,
            });

            throw new UnauthorizedException({
              code: 'TWO_FACTOR_INVALID',
              message: 'Invalid two-factor authentication code.',
            });
          }
        }

      }

      await client.query(
        `
          UPDATE app_user
          SET
            failed_login_attempts = 0,
            locked_until = NULL
          WHERE id = $1
        `,
        [user.id],
      );

      const accessToken = this.signAccessToken(user.id, user.email);
      const refreshToken = crypto.randomBytes(48).toString('base64url');
      const refreshTokenHash = this.hashRefreshToken(refreshToken);

      const expiresAt = new Date(Date.now() + this.refreshDays * 24 * 60 * 60 * 1000);

      await client.query(
        `
          INSERT INTO auth_session (
            user_id,
            refresh_token_hash,
            expires_at,
            ip_address,
            user_agent
          )
          VALUES ($1, $2, $3, $4::inet, $5)
        `,
        [
          user.id,
          refreshTokenHash,
          expiresAt,
          payload.ipAddress ?? requestContext?.ipAddress ?? null,
          payload.userAgent ?? requestContext?.userAgent ?? null,
        ],
      );

      await this.logSecurityEvent(client, {
        userId: user.id,
        eventType: 'login_success',
        severity: 'low',
        details: { email: user.email },
        requestContext,
      });

      return {
        accessToken,
        refreshToken,
        tokenType: 'Bearer',
        expiresIn: String(this.accessTtl),
        user: {
          id: user.id,
          email: user.email,
          status: user.status,
          isEmailVerified: user.is_email_verified,
        },
      };
    });
  }

  async resendEmailVerification(userId: string, requestContext?: AuditSqlContext) {
    return this.db.withTransaction(async (client) => {
      await this.ensureEmailVerificationTable(client);

      const userRes = await client.query<{
        email: string;
        is_email_verified: boolean;
        gender: 'male' | 'female' | null;
        last_name: string | null;
        locale: string | null;
        created_at: string;
      }>(
        `
          SELECT u.email,
                 u.is_email_verified,
                 u.gender,
                 u.last_name,
                 u.created_at,
                 (
                   SELECT uc.locale
                   FROM user_consent uc
                   WHERE uc.user_id = u.id
                   ORDER BY uc.accepted_at DESC
                   LIMIT 1
                 ) AS locale
          FROM app_user u
          WHERE u.id = $1
            AND deleted_at IS NULL
          LIMIT 1
        `,
        [userId],
      );

      const user = userRes.rows[0];
      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      await applyAuditSqlContext(client, {
        ...requestContext,
        currentUserId: userId,
        currentUserEmail: user.email,
      });

      if (user.is_email_verified) {
        return {
          success: true,
          alreadyVerified: true,
          verificationEmailSent: false,
        };
      }

      const resendAvailableAt =
          new Date(user.created_at).getTime() + 3 * 24 * 60 * 60 * 1000;
      if (Date.now() < resendAvailableAt) {
        const remainingHours = Math.max(
          1,
          Math.ceil((resendAvailableAt - Date.now()) / (60 * 60 * 1000)),
        );

        throw new BadRequestException({
          code: 'EMAIL_VERIFICATION_RESEND_NOT_AVAILABLE',
          message: `Verification email can be resent after ${remainingHours} hour(s).`,
        });
      }

      const verificationToken = await this.issueEmailVerificationToken(client, userId);
      const verificationSent = await this.sendEmailVerificationLink(
        user.email,
        verificationToken,
        user.locale ?? 'RO',
        user.gender,
        user.last_name,
      );

      await this.logSecurityEvent(client, {
        userId,
        eventType: 'email_verification_resent',
        severity: 'low',
        details: {},
        requestContext,
      });

      return {
        success: true,
        alreadyVerified: false,
        verificationEmailSent: verificationSent,
      };
    });
  }

  async verifyEmailToken(token: string, requestContext?: AuditSqlContext) {
    const normalizedToken = token.trim();
    if (!normalizedToken) {
      throw new BadRequestException('Verification token is required');
    }

    return this.db.withTransaction(async (client) => {
      await this.ensureEmailVerificationTable(client);

      const tokenHash = this.hashEmailVerificationToken(normalizedToken);
      const tokenRes = await client.query<{
        id: string;
        user_id: string;
        expires_at: string;
        used_at: string | null;
        email: string;
      }>(
        `
          SELECT t.id, t.user_id, t.expires_at, t.used_at, u.email
          FROM email_verification_token t
          JOIN app_user u ON u.id = t.user_id
          WHERE t.token_hash = $1
          LIMIT 1
        `,
        [tokenHash],
      );

      const row = tokenRes.rows[0];
      if (!row) {
        throw new BadRequestException('Invalid verification token');
      }

      if (row.used_at) {
        return { success: true, alreadyVerified: true };
      }

      if (new Date(row.expires_at).getTime() < Date.now()) {
        throw new BadRequestException('Verification token expired');
      }

      await applyAuditSqlContext(client, {
        ...requestContext,
        currentUserId: row.user_id,
        currentUserEmail: row.email,
      });

      await client.query(
        `
          UPDATE app_user
          SET is_email_verified = true,
              status = CASE WHEN status = 'pending_verification' THEN 'active' ELSE status END,
              updated_at = NOW()
          WHERE id = $1
        `,
        [row.user_id],
      );

      await client.query(
        `
          UPDATE email_verification_token
          SET used_at = NOW()
          WHERE id = $1
        `,
        [row.id],
      );

      await this.logSecurityEvent(client, {
        userId: row.user_id,
        eventType: 'email_verified',
        severity: 'low',
        details: {},
        requestContext,
      });

      return { success: true, alreadyVerified: false };
    });
  }

  private async ensureEmailVerificationTable(client: {
    query: (sql: string, params?: unknown[]) => Promise<unknown>;
  }): Promise<void> {
    await client.query(`
      CREATE TABLE IF NOT EXISTS email_verification_token (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
        token_hash CHAR(64) NOT NULL UNIQUE,
        expires_at TIMESTAMPTZ NOT NULL,
        used_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_email_verification_token_user_active
      ON email_verification_token (user_id, expires_at)
      WHERE used_at IS NULL
    `);

    await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_trigger
          WHERE tgname = 'trg_audit_email_verification_token'
            AND tgrelid = 'email_verification_token'::regclass
        ) THEN
          CREATE TRIGGER trg_audit_email_verification_token
          AFTER INSERT OR UPDATE OR DELETE ON email_verification_token
          FOR EACH ROW EXECUTE FUNCTION write_audit_log();
        END IF;
      END
      $$;
    `);
  }

  private hashEmailVerificationToken(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  private async issueEmailVerificationToken(
    client: PoolClient,
    userId: string,
  ): Promise<string> {
    const token = crypto.randomBytes(32).toString('base64url');
    const tokenHash = this.hashEmailVerificationToken(token);
    const expiresAt = new Date(Date.now() + this.emailVerifyTtlHours * 60 * 60 * 1000);

    await client.query(
      `
        UPDATE email_verification_token
        SET used_at = NOW()
        WHERE user_id = $1
          AND used_at IS NULL
      `,
      [userId],
    );

    await client.query(
      `
        INSERT INTO email_verification_token (user_id, token_hash, expires_at)
        VALUES ($1, $2, $3)
      `,
      [userId, tokenHash, expiresAt],
    );

    return token;
  }

  private get emailTransportConfigured(): boolean {
    return (
      this.smtpHost.trim().length > 0 &&
      this.smtpPort > 0 &&
      this.smtpUser.trim().length > 0 &&
      this.smtpPass.trim().length > 0
    );
  }

  private resolveEmailLocale(locale: string | null | undefined): 'RO' | 'EN' {
    return (locale ?? 'RO').toUpperCase() == 'EN' ? 'EN' : 'RO';
  }

  private buildEmailSalutation(
    locale: 'RO' | 'EN',
    gender: 'male' | 'female' | null | undefined,
    lastName: string | null | undefined,
  ): string {
    const cleanLastName = (lastName ?? '').trim();

    if (locale === 'RO') {
      if (gender === 'male') {
        return `Buna ziua domnule ${cleanLastName},`;
      }
      if (gender === 'female') {
        return `Buna ziua doamna ${cleanLastName},`;
      }
        return cleanLastName.length > 0
          ? `Buna ziua ${cleanLastName},`
          : 'Buna ziua,';
    }

    if (gender === 'male') {
        return cleanLastName.length > 0
          ? `Hello Mr. ${cleanLastName},`
          : 'Hello Mr.,';
    }

    if (gender === 'female') {
        return cleanLastName.length > 0
          ? `Hello Ms. ${cleanLastName},`
          : 'Hello Ms.,';
    }

    return cleanLastName.length > 0 ? `Hello ${cleanLastName},` : 'Hello,';
  }

  private async sendEmailVerificationLink(
    email: string,
    token: string,
    localeRaw: string,
    gender: 'male' | 'female' | null | undefined,
    lastName: string | null | undefined,
  ): Promise<boolean> {
    const verifyUrl = `${this.verificationBaseUrl.replace(/\/$/, '')}/auth/verify-email?token=${encodeURIComponent(token)}`;
    const locale = this.resolveEmailLocale(localeRaw);
    const salutation = this.buildEmailSalutation(locale, gender, lastName);
    const subject =
      locale === 'RO'
          ? 'Verificare cont CareerSuitUp'
          : 'CareerSuitUp account verification';
    const intro =
      locale === 'RO'
          ? 'Iti multumim pentru crearea contului. Pentru a valida contul, te rugam sa accesezi butonul de mai jos:'
          : 'Thank you for creating your account. To validate your account, please use the button below:';
    const buttonText = locale === 'RO' ? 'Verifica emailul' : 'Verify email';
    const fallbackText =
      locale === 'RO'
          ? 'Daca butonul nu functioneaza, foloseste acest link:'
          : 'If the button does not work, use this link:';
    const footerLine1 =
      locale === 'RO' ? 'Cu stima si respect,' : 'With respect,';
    const footerLine2 = 'Echipa CareerSuitUp';
    const plainText =
      `${salutation}\n\n${intro}\n${verifyUrl}\n\n${footerLine1}\n${footerLine2}`;
    const html = `
      <div style="font-family:Arial,Helvetica,sans-serif;max-width:600px;margin:0 auto;padding:20px;color:#1f2937;">
        <h2 style="margin:0 0 16px 0;color:#4c1d95;">CareerSuitUp</h2>
        <p style="margin:0 0 12px 0;">${salutation}</p>
        <p style="margin:0 0 18px 0;line-height:1.5;">${intro}</p>
        <p style="margin:0 0 20px 0;">
          <a href="${verifyUrl}" style="display:inline-block;background:#6d28d9;color:#ffffff;text-decoration:none;padding:12px 18px;border-radius:8px;font-weight:700;">
            ${buttonText}
          </a>
        </p>
        <p style="margin:0 0 8px 0;line-height:1.5;">${fallbackText}</p>
        <p style="margin:0 0 18px 0;word-break:break-all;"><a href="${verifyUrl}">${verifyUrl}</a></p>
        <p style="margin:0;line-height:1.5;">${footerLine1}<br/>${footerLine2}</p>
      </div>
    `;

    if (!this.emailTransportConfigured) {
      console.warn(
        `[email-verification] SMTP not configured. Verification link for ${email}: ${verifyUrl}`,
      );
      return false;
    }

    const transporter = nodemailer.createTransport({
      host: this.smtpHost,
      port: this.smtpPort,
      secure: this.smtpSecure,
      auth: {
        user: this.smtpUser,
        pass: this.smtpPass,
      },
    });

    await transporter.sendMail({
      from: `CareerSuitUp <${this.mailFromAddress}>`,
      to: email,
      subject,
      text: plainText,
      html,
    });

    return true;
  }

  async checkEmailAvailability(email: string): Promise<{ available: boolean }> {
    const normalizedEmail = email.toLowerCase().trim();

    const result = await this.db.query<{ id: string }>(
      `
        SELECT id
        FROM app_user
        WHERE email = $1
          AND deleted_at IS NULL
        LIMIT 1
      `,
      [normalizedEmail],
    );

    return {
      available: result.rowCount === 0,
    };
  }

  private async ensureEmailNotExists(client: PoolClient, email: string): Promise<void> {
    const exists = await client.query<{ id: string }>(
      `SELECT id FROM app_user WHERE email = $1 AND deleted_at IS NULL LIMIT 1`,
      [email.toLowerCase().trim()],
    );

    if (exists.rowCount && exists.rowCount > 0) {
      throw new ConflictException({
        code: 'EMAIL_ALREADY_EXISTS',
        message: 'An account is already associated with this email address.',
      });
    }
  }

  private signAccessToken(userId: string, email: string): string {
    return jwt.sign(
      {
        sub: userId,
        email,
      },
      this.accessSecret,
      { expiresIn: this.accessTtl },
    );
  }

  private hashRefreshToken(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  private encryptTwoFactorSecret(secret: string): string {
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv(
      'aes-256-gcm',
      this.twoFactorEncryptionKey,
      iv,
    );

    const encrypted = Buffer.concat([
      cipher.update(secret, 'utf8'),
      cipher.final(),
    ]);
    const tag = cipher.getAuthTag();

    return `${iv.toString('base64')}.${tag.toString('base64')}.${encrypted.toString('base64')}`;
  }

  private decryptTwoFactorSecret(encryptedPayload: string): string {
    const [ivEncoded, tagEncoded, dataEncoded] = encryptedPayload.split('.');

    if (!ivEncoded || !tagEncoded || !dataEncoded) {
      throw new UnauthorizedException({
        code: 'TWO_FACTOR_INVALID',
        message: 'Invalid two-factor authentication setup.',
      });
    }

    try {
      const iv = Buffer.from(ivEncoded, 'base64');
      const tag = Buffer.from(tagEncoded, 'base64');
      const encrypted = Buffer.from(dataEncoded, 'base64');
      const decipher = crypto.createDecipheriv(
        'aes-256-gcm',
        this.twoFactorEncryptionKey,
        iv,
      );

      decipher.setAuthTag(tag);

      const decrypted = Buffer.concat([
        decipher.update(encrypted),
        decipher.final(),
      ]);

      return decrypted.toString('utf8');
    } catch (_) {
      throw new UnauthorizedException({
        code: 'TWO_FACTOR_INVALID',
        message: 'Invalid two-factor authentication setup.',
      });
    }
  }

  private verifyTwoFactorCode(secret: string, code: string): boolean {
    const normalizedCode = code.replace(/\s+/g, '').trim();
    return authenticator.check(normalizedCode, secret);
  }

  private generateTwoFactorBackupCodes(count = 8): string[] {
    const codes = new Set<string>();

    while (codes.size < count) {
      const raw = crypto.randomBytes(4).toString('hex').toUpperCase();
      codes.add(`${raw.substring(0, 4)}-${raw.substring(4, 8)}`);
    }

    return Array.from(codes);
  }

  private hashBackupCode(code: string): string {
    const normalized = code.replace(/[^A-Za-z0-9]/g, '').toUpperCase();
    return crypto.createHash('sha256').update(normalized).digest('hex');
  }

  private async consumeBackupCode(
    client: PoolClient,
    userId: string,
    code: string,
  ): Promise<boolean> {
    const codeHash = this.hashBackupCode(code);

    const consumedRes = await client.query<{ id: string }>(
      `
        UPDATE app_user
        SET two_factor_backup_codes_hashes = array_remove(two_factor_backup_codes_hashes, $2)
        WHERE id = $1
          AND $2 = ANY(two_factor_backup_codes_hashes)
        RETURNING id
      `,
      [userId, codeHash],
    );

    return (consumedRes.rowCount ?? 0) > 0;
  }

  private async logSecurityEvent(
    client: PoolClient,
    params: {
      userId: string | null;
      eventType: string;
      severity: 'low' | 'medium' | 'high' | 'critical';
      details: Record<string, unknown>;
      requestContext?: AuditSqlContext;
    },
  ): Promise<void> {
    await client.query(
      `
        INSERT INTO security_event_log (
          user_id,
          event_type,
          severity,
          details,
          ip_address,
          user_agent,
          request_id
        )
        VALUES ($1, $2, $3, $4::jsonb, $5::inet, $6, $7::uuid)
      `,
      [
        params.userId,
        params.eventType,
        params.severity,
        JSON.stringify(params.details),
        params.requestContext?.ipAddress ?? null,
        params.requestContext?.userAgent ?? null,
        params.requestContext?.requestId ?? null,
      ],
    );
  }
}
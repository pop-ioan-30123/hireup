import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { promises as fs } from 'fs';
import * as path from 'path';
import { DatabaseService } from '../database/database.service';
import { applyAuditSqlContext, AuditSqlContext } from '../database/audit-sql-context';
import { UpdateCompanyProfileDto } from './dto/update-company-profile.dto';
import { UpdateProfileVisibilityDto } from './dto/update-profile-visibility.dto';
import { UpdateThemePreferenceDto } from './dto/update-theme-preference.dto';
import { UpdateUserProfileDto } from './dto/update-user-profile.dto';

interface AvatarPayload {
  buffer: Buffer;
  mimeType: string | null;
  size: number;
}

export interface ProfileBadge {
  key: 'founder' | 'two_factor';
  unlockedAt: string;
}

export interface ProfileBadgeCatalogEntry {
  key: 'founder' | 'two_factor';
  status: 'unlocked' | 'available' | 'unavailable';
  unlockedAt: string | null;
}

@Injectable()
export class ProfileService {
  constructor(private readonly db: DatabaseService) {}

  private async ensureThemePreferencesTable(client: {
    query: (sql: string, params?: unknown[]) => Promise<unknown>;
  }): Promise<void> {
    await client.query(`
      CREATE TABLE IF NOT EXISTS app_user_theme_preference (
        user_id UUID PRIMARY KEY REFERENCES app_user(id) ON DELETE CASCADE,
        default_theme TEXT NOT NULL CHECK (default_theme IN ('light', 'dark')),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
  }


  private getFounderEmails(): Set<string> {
    const raw = process.env.FOUNDER_BADGE_EMAILS ?? '';

    return new Set(
      raw
        .split(',')
        .map((value) => value.trim().toLowerCase())
        .filter((value) => value.length > 0),
    );
  }

  private computeBadgeData(user: {
    email: string;
    two_factor_enabled: boolean;
  }): {
    badges: ProfileBadge[];
    badgeCatalog: ProfileBadgeCatalogEntry[];
  } {
    const badges: ProfileBadge[] = [];
    const badgeCatalog: ProfileBadgeCatalogEntry[] = [];
    const now = new Date().toISOString();
    const founderEmails = this.getFounderEmails();
    const normalizedEmail = user.email.trim().toLowerCase();
    const founderEligible = founderEmails.has(normalizedEmail);

    if (founderEligible) {
      badges.push({
        key: 'founder',
        unlockedAt: now,
      });
    }

    badgeCatalog.push({
      key: 'founder',
      status: founderEligible ? 'unlocked' : 'unavailable',
      unlockedAt: founderEligible ? now : null,
    });

    if (user.two_factor_enabled) {
      badges.push({
        key: 'two_factor',
        unlockedAt: now,
      });
    }

    badgeCatalog.push({
      key: 'two_factor',
      status: user.two_factor_enabled ? 'unlocked' : 'available',
      unlockedAt: user.two_factor_enabled ? now : null,
    });

    return {
      badges,
      badgeCatalog,
    };
  }

  async getProfile(userId: string) {
    return this.db.withTransaction(async (client) => {
      await this.ensureThemePreferencesTable(client);

      const userRes = await client.query<{
        id: string;
        account_type: 'user' | 'company';
        email: string;
        is_email_verified: boolean;
        gender: 'male' | 'female' | null;
        birth_date: string | null;
        first_name: string | null;
        last_name: string | null;
        phone_e164: string | null;
        two_factor_enabled: boolean;
        two_factor_secret_enc: string | null;
        default_theme: 'light' | 'dark' | null;
      }>(
        `
          SELECT u.id,
                 u.account_type,
                 u.email,
               u.is_email_verified,
                 u.gender,
                 u.birth_date,
                 u.first_name,
                 u.last_name,
                 u.phone_e164,
                 u.two_factor_enabled,
                 u.two_factor_secret_enc,
                 p.default_theme
          FROM app_user u
          LEFT JOIN app_user_theme_preference p ON p.user_id = u.id
          WHERE u.id = $1
          LIMIT 1
        `,
        [userId],
      );

      const user = userRes.rows[0];
      if (!user) {
        throw new NotFoundException('User not found');
      }

      await client.query(
        `
          INSERT INTO profile_visibility (user_id)
          VALUES ($1)
          ON CONFLICT (user_id) DO NOTHING
        `,
        [userId],
      );

      const visibilityRes = await client.query<{
        show_gender: boolean;
        show_birth_date: boolean;
        show_job_title: boolean;
        show_phone: boolean;
        show_country: boolean;
        show_county: boolean;
        show_city: boolean;
        show_years_experience: boolean;
        show_education_level: boolean;
        show_education_institution: boolean;
        show_company_name: boolean;
        show_company_county: boolean;
        show_company_city: boolean;
        show_hr_first_name: boolean;
        show_hr_last_name: boolean;
        show_hr_email: boolean;
        show_cv: boolean;
      }>(
        `
          SELECT
            show_gender,
            show_birth_date,
            show_job_title,
            show_phone,
            show_country,
            show_county,
            show_city,
            show_years_experience,
            show_education_level,
            show_education_institution,
            show_company_name,
            show_company_county,
            show_company_city,
            show_hr_first_name,
            show_hr_last_name,
            show_hr_email,
            show_cv
          FROM profile_visibility
          WHERE user_id = $1
          LIMIT 1
        `,
        [userId],
      );

      const visibility = visibilityRes.rows[0];

      let userProfile: {
        jobTitle: string | null;
        yearsExperience: number | null;
        educationLevel: string | null;
        educationInstitution: string | null;
        country: string | null;
        county: string | null;
        city: string | null;
      } | null = null;

      let companyProfile: {
        companyName: string | null;
        countryCode: string | null;
        county: string | null;
        city: string | null;
        hrFirstName: string | null;
        hrLastName: string | null;
        hrEmail: string | null;
      } | null = null;

      if (user.account_type === 'user') {
        const profileRes = await client.query<{
          job_title: string;
          years_experience: number;
          education_level: string;
          education_institution: string;
          country: string;
          county: string;
          city: string;
        }>(
          `
            SELECT job_title, years_experience, education_level, education_institution, country, county, city
            FROM user_profile
            WHERE user_id = $1
            LIMIT 1
          `,
          [userId],
        );

        if (profileRes.rows[0]) {
          userProfile = {
            jobTitle: profileRes.rows[0].job_title,
            yearsExperience: profileRes.rows[0].years_experience,
            educationLevel: profileRes.rows[0].education_level,
            educationInstitution: profileRes.rows[0].education_institution,
            country: profileRes.rows[0].country,
            county: profileRes.rows[0].county,
            city: profileRes.rows[0].city,
          };
        }
      } else {
        const companyRes = await client.query<{
          company_name: string;
          country_code: string;
          county: string | null;
          city: string | null;
          hr_first_name: string | null;
          hr_last_name: string | null;
          hr_email: string | null;
        }>(
          `
            SELECT c.legal_name AS company_name,
                   c.country_code,
                   c.county,
                   c.city,
                   hr.first_name AS hr_first_name,
                   hr.last_name AS hr_last_name,
                   hr.email AS hr_email
            FROM company c
            LEFT JOIN company_hr_contact hr
              ON hr.company_id = c.id AND hr.is_primary = true
            WHERE c.account_user_id = $1
            LIMIT 1
          `,
          [userId],
        );

        if (companyRes.rows[0]) {
          companyProfile = {
            companyName: companyRes.rows[0].company_name,
            countryCode: companyRes.rows[0].country_code,
            county: companyRes.rows[0].county,
            city: companyRes.rows[0].city,
            hrFirstName: companyRes.rows[0].hr_first_name,
            hrLastName: companyRes.rows[0].hr_last_name,
            hrEmail: companyRes.rows[0].hr_email,
          };
        }
      }

      const avatarRes = await client.query<{ id: string }>(
        `
          SELECT id
          FROM file_attachment
          WHERE user_id = $1 AND attachment_type = 'avatar'
          ORDER BY uploaded_at DESC
          LIMIT 1
        `,
        [userId],
      );

      const cvRes = await client.query<{ id: string }>(
        `
          SELECT id
          FROM file_attachment
          WHERE user_id = $1 AND attachment_type = 'cv'
          ORDER BY uploaded_at DESC
          LIMIT 1
        `,
        [userId],
      );

      const badgeData = this.computeBadgeData({
        email: user.email,
        two_factor_enabled: user.two_factor_enabled,
      });

      return {
        accountType: user.account_type,
        user: {
          id: user.id,
          email: user.email,
          isEmailVerified: user.is_email_verified,
          gender: user.gender,
          birthDate: user.birth_date,
          firstName: user.first_name,
          lastName: user.last_name,
          phone: user.phone_e164,
          defaultTheme: user.default_theme ?? 'light',
          twoFactorEnabled: user.two_factor_enabled,
          twoFactorPending: !user.two_factor_enabled && Boolean(user.two_factor_secret_enc),
        },
        userProfile,
        companyProfile,
        visibility: {
          showGender: visibility?.show_gender ?? false,
          showBirthDate: visibility?.show_birth_date ?? false,
          showJobTitle: visibility?.show_job_title ?? false,
          showPhone: visibility?.show_phone ?? false,
          showCountry: visibility?.show_country ?? false,
          showCounty: visibility?.show_county ?? false,
          showCity: visibility?.show_city ?? false,
          showYearsExperience: visibility?.show_years_experience ?? false,
          showEducationLevel: visibility?.show_education_level ?? false,
          showEducationInstitution: visibility?.show_education_institution ?? false,
          showCompanyName: visibility?.show_company_name ?? false,
          showCompanyCounty: visibility?.show_company_county ?? false,
          showCompanyCity: visibility?.show_company_city ?? false,
          showHrFirstName: visibility?.show_hr_first_name ?? false,
          showHrLastName: visibility?.show_hr_last_name ?? false,
          showHrEmail: visibility?.show_hr_email ?? false,
          showCv: visibility?.show_cv ?? false,
        },
        hasAvatar: (avatarRes.rowCount ?? 0) > 0,
        hasCv: (cvRes.rowCount ?? 0) > 0,
        badges: badgeData.badges,
        badgeCatalog: badgeData.badgeCatalog,
      };
    });
  }

  async updateUserProfile(userId: string, payload: UpdateUserProfileDto, auditContext?: AuditSqlContext) {
    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        ...auditContext,
        currentUserId: userId,
      });
      const userRes = await client.query<{ account_type: 'user' | 'company' }>(
        'SELECT account_type FROM app_user WHERE id = $1',
        [userId],
      );

      if (userRes.rows[0]?.account_type !== 'user') {
        throw new BadRequestException('Only user accounts can update this profile');
      }

      await client.query(
        `
          UPDATE app_user
          SET phone_e164 = COALESCE($1, phone_e164),
              gender = COALESCE($2, gender),
              birth_date = COALESCE($3::date, birth_date),
              updated_at = NOW()
          WHERE id = $4
        `,
        [
          payload.phone?.trim(),
          payload.gender,
          payload.birthDate,
          userId,
        ],
      );

      await client.query(
        `
          UPDATE user_profile
          SET country = COALESCE($1, country),
              county = COALESCE($2, county),
              city = COALESCE($3, city),
              years_experience = COALESCE($4, years_experience),
              education_level = COALESCE($5, education_level),
              education_institution = COALESCE($6, education_institution),
              job_title = COALESCE($7, job_title),
              updated_at = NOW()
          WHERE user_id = $8
        `,
        [
          payload.country?.trim(),
          payload.county?.trim(),
          payload.city?.trim(),
          payload.yearsExperience,
          payload.educationLevel?.trim(),
          payload.educationInstitution?.trim(),
          payload.jobTitle?.trim(),
          userId,
        ],
      );

      return { success: true };
    });
  }

  async updateCompanyProfile(userId: string, payload: UpdateCompanyProfileDto, auditContext?: AuditSqlContext) {
    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        ...auditContext,
        currentUserId: userId,
      });
      const userRes = await client.query<{ account_type: 'user' | 'company' }>(
        'SELECT account_type FROM app_user WHERE id = $1',
        [userId],
      );

      if (userRes.rows[0]?.account_type !== 'company') {
        throw new BadRequestException('Only company accounts can update this profile');
      }

      await client.query(
        `
          UPDATE app_user
          SET gender = COALESCE($1, gender),
              birth_date = COALESCE($2::date, birth_date),
              updated_at = NOW()
          WHERE id = $3
        `,
        [
          payload.gender,
          payload.birthDate,
          userId,
        ],
      );

      await client.query(
        `
          UPDATE company
          SET legal_name = COALESCE($1, legal_name),
              country_code = COALESCE($2, country_code),
              county = COALESCE($3, county),
              city = COALESCE($4, city),
              updated_at = NOW()
          WHERE account_user_id = $5
        `,
        [
          payload.companyName?.trim(),
          payload.countryCode?.trim().toUpperCase(),
          payload.county?.trim(),
          payload.city?.trim(),
          userId,
        ],
      );

      return { success: true };
    });
  }

  async updateThemePreference(
    userId: string,
    payload: UpdateThemePreferenceDto,
    auditContext?: AuditSqlContext,
  ) {
    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        ...auditContext,
        currentUserId: userId,
      });

      await this.ensureThemePreferencesTable(client);

      await client.query(
        `
          INSERT INTO app_user_theme_preference (user_id, default_theme, updated_at)
          VALUES ($1, $2, NOW())
          ON CONFLICT (user_id)
          DO UPDATE SET
            default_theme = EXCLUDED.default_theme,
            updated_at = NOW()
        `,
        [userId, payload.defaultTheme],
      );

      return {
        success: true,
        defaultTheme: payload.defaultTheme,
      };
    });
  }

  async updateVisibility(userId: string, payload: UpdateProfileVisibilityDto, auditContext?: AuditSqlContext) {
    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        ...auditContext,
        currentUserId: userId,
      });

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
          UPDATE profile_visibility
          SET show_gender = COALESCE($1, show_gender),
              show_birth_date = COALESCE($2, show_birth_date),
              show_job_title = COALESCE($3, show_job_title),
              show_phone = COALESCE($4, show_phone),
              show_country = COALESCE($5, show_country),
              show_county = COALESCE($6, show_county),
              show_city = COALESCE($7, show_city),
              show_years_experience = COALESCE($8, show_years_experience),
              show_education_level = COALESCE($9, show_education_level),
              show_education_institution = COALESCE($10, show_education_institution),
              show_company_name = COALESCE($11, show_company_name),
              show_company_county = COALESCE($12, show_company_county),
              show_company_city = COALESCE($13, show_company_city),
              show_hr_first_name = COALESCE($14, show_hr_first_name),
              show_hr_last_name = COALESCE($15, show_hr_last_name),
              show_hr_email = COALESCE($16, show_hr_email),
              show_cv = COALESCE($17, show_cv),
              updated_at = NOW()
          WHERE user_id = $18
        `,
        [
          payload.showGender,
          payload.showBirthDate,
          payload.showJobTitle,
          payload.showPhone,
          payload.showCountry,
          payload.showCounty,
          payload.showCity,
          payload.showYearsExperience,
          payload.showEducationLevel,
          payload.showEducationInstitution,
          payload.showCompanyName,
          payload.showCompanyCounty,
          payload.showCompanyCity,
          payload.showHrFirstName,
          payload.showHrLastName,
          payload.showHrEmail,
          payload.showCv,
          userId,
        ],
      );

      return { success: true };
    });
  }

  async getAvatar(userId: string): Promise<AvatarPayload | null> {
    return this.db.withTransaction(async (client) => {
      const avatarRes = await client.query<{
        storage_key: string;
        mime_type: string | null;
        file_size_bytes: string;
      }>(
        `
          SELECT storage_key, mime_type, file_size_bytes
          FROM file_attachment
          WHERE user_id = $1 AND attachment_type = 'avatar'
          ORDER BY uploaded_at DESC
          LIMIT 1
        `,
        [userId],
      );

      if (avatarRes.rowCount === 0) {
        return null;
      }

      const avatar = avatarRes.rows[0];
      const storageRoot = path.resolve(__dirname, '../../uploads');
      const storagePath = path.join(storageRoot, avatar.storage_key);

      try {
        const buffer = await fs.readFile(storagePath);
        return {
          buffer,
          mimeType: avatar.mime_type,
          size: Number(avatar.file_size_bytes),
        };
      } catch (_) {
        throw new NotFoundException('Avatar not found on disk');
      }
    });
  }
}

"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ProfileService = void 0;
const common_1 = require("@nestjs/common");
const fs_1 = require("fs");
const path = __importStar(require("path"));
const database_service_1 = require("../database/database.service");
const audit_sql_context_1 = require("../database/audit-sql-context");
let ProfileService = class ProfileService {
    constructor(db) {
        this.db = db;
    }
    normalizeNullableText(value) {
        const trimmed = value?.trim() ?? '';
        return trimmed.length > 0 ? trimmed : null;
    }
    toActivityPostResponse(post, attachments, comments, viewerUserId) {
        return {
            id: post.id,
            content: post.content,
            sticker: post.sticker,
            createdAt: post.created_at,
            updatedAt: post.updated_at,
            canEdit: post.user_id === viewerUserId,
            attachments: attachments.map((attachment) => ({
                id: attachment.id,
                fileName: attachment.original_file_name,
                mimeType: attachment.mime_type,
                fileSizeBytes: Number(attachment.file_size_bytes),
            })),
            comments: comments.map((comment) => {
                const firstName = comment.first_name?.trim() ?? '';
                const lastName = comment.last_name?.trim() ?? '';
                const authorName = [firstName, lastName]
                    .filter((value) => value.length > 0)
                    .join(' ')
                    .trim();
                return {
                    id: comment.id,
                    userId: comment.user_id,
                    authorName: authorName.length === 0 ? 'User' : authorName,
                    content: comment.content,
                    createdAt: comment.created_at,
                    updatedAt: comment.updated_at,
                    isOwnComment: comment.user_id === viewerUserId,
                };
            }),
        };
    }
    async fetchActivityPosts(client, profileUserId, viewerUserId, limit = 20) {
        await this.ensureActivityCommentTable(client);
        const postsRes = await client.query(`
        SELECT id, user_id, content, sticker, created_at, updated_at
        FROM profile_activity_post
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT $2
      `, [profileUserId, limit]);
        if (postsRes.rows.length === 0) {
            return [];
        }
        const postIds = postsRes.rows.map((post) => post.id);
        const attachmentsRes = await client.query(`
        SELECT ppa.post_id,
               f.id,
               f.original_file_name,
               f.mime_type,
               f.file_size_bytes
        FROM profile_activity_post_attachment ppa
        INNER JOIN file_attachment f ON f.id = ppa.attachment_id
        WHERE ppa.post_id = ANY($1::uuid[])
        ORDER BY ppa.created_at ASC
      `, [postIds]);
        const commentsRes = await client.query(`
        SELECT c.post_id,
               c.id,
               c.user_id,
               c.content,
               c.created_at,
               c.updated_at,
               u.first_name,
               u.last_name
        FROM profile_activity_comment c
        INNER JOIN app_user u ON u.id = c.user_id
        WHERE c.post_id = ANY($1::uuid[])
        ORDER BY c.created_at ASC
      `, [postIds]);
        const attachmentsByPost = new Map();
        for (const attachment of attachmentsRes.rows) {
            const current = attachmentsByPost.get(attachment.post_id) ?? [];
            current.push({
                id: attachment.id,
                original_file_name: attachment.original_file_name,
                mime_type: attachment.mime_type,
                file_size_bytes: attachment.file_size_bytes,
            });
            attachmentsByPost.set(attachment.post_id, current);
        }
        const commentsByPost = new Map();
        for (const comment of commentsRes.rows) {
            const current = commentsByPost.get(comment.post_id) ?? [];
            current.push({
                id: comment.id,
                user_id: comment.user_id,
                content: comment.content,
                created_at: comment.created_at,
                updated_at: comment.updated_at,
                first_name: comment.first_name,
                last_name: comment.last_name,
            });
            commentsByPost.set(comment.post_id, current);
        }
        return postsRes.rows.map((post) => this.toActivityPostResponse(post, attachmentsByPost.get(post.id) ?? [], commentsByPost.get(post.id) ?? [], viewerUserId));
    }
    async ensureOwnedPostAttachments(client, userId, attachmentIds) {
        if (attachmentIds.length === 0)
            return;
        const attachmentsRes = await client.query(`
        SELECT id
        FROM file_attachment
        WHERE user_id = $1
          AND id = ANY($2::uuid[])
          AND attachment_type IN ('post_media', 'post_file')
      `, [userId, attachmentIds]);
        if ((attachmentsRes.rowCount ?? 0) !== attachmentIds.length) {
            throw new common_1.BadRequestException('One or more attachments are invalid for this user');
        }
    }
    assertExperienceRange(payload) {
        if (payload.isCurrent) {
            return;
        }
        if (payload.endMonth == null || payload.endYear == null) {
            throw new common_1.BadRequestException('End month and end year are required when the role is not current');
        }
        const startValue = payload.startYear * 12 + payload.startMonth;
        const endValue = payload.endYear * 12 + payload.endMonth;
        if (endValue < startValue) {
            throw new common_1.BadRequestException('Experience end date cannot be earlier than start date');
        }
    }
    assertEducationRange(payload) {
        if (payload.isCurrent) {
            return;
        }
        if (payload.endMonth == null || payload.endYear == null) {
            throw new common_1.BadRequestException('End month and end year are required when studies are not current');
        }
        const startValue = payload.startYear * 12 + payload.startMonth;
        const endValue = payload.endYear * 12 + payload.endMonth;
        if (endValue < startValue) {
            throw new common_1.BadRequestException('Education end date cannot be earlier than start date');
        }
    }
    async ensureThemePreferencesTable(client) {
        await client.query(`
      CREATE TABLE IF NOT EXISTS app_user_theme_preference (
        user_id UUID PRIMARY KEY REFERENCES app_user(id) ON DELETE CASCADE,
        default_theme TEXT NOT NULL CHECK (default_theme IN ('light', 'dark')),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
        await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_trigger
          WHERE tgname = 'trg_audit_app_user_theme_preference'
            AND tgrelid = 'app_user_theme_preference'::regclass
        ) THEN
          CREATE TRIGGER trg_audit_app_user_theme_preference
          AFTER INSERT OR UPDATE OR DELETE ON app_user_theme_preference
          FOR EACH ROW EXECUTE FUNCTION write_audit_log();
        END IF;
      END
      $$;
    `);
        await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_trigger
          WHERE tgname = 'trg_app_user_theme_preference_updated_at'
            AND tgrelid = 'app_user_theme_preference'::regclass
        ) THEN
          CREATE TRIGGER trg_app_user_theme_preference_updated_at
          BEFORE UPDATE ON app_user_theme_preference
          FOR EACH ROW EXECUTE FUNCTION set_updated_at();
        END IF;
      END
      $$;
    `);
    }
    async ensureUserSkillTable(client) {
        await client.query(`
      CREATE TABLE IF NOT EXISTS user_skill (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
        category TEXT NOT NULL CHECK (category IN ('language', 'soft', 'hard')),
        sort_order SMALLINT NOT NULL CHECK (sort_order >= 1 AND sort_order <= 30),
        name TEXT NOT NULL,
        score NUMERIC(4,2) NOT NULL CHECK (score >= 1 AND score <= 10),
        is_visible BOOLEAN NOT NULL DEFAULT TRUE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE (user_id, category, sort_order)
      )
    `);
        await client.query(`
      ALTER TABLE user_skill
      ALTER COLUMN score TYPE NUMERIC(4,2)
      USING score::NUMERIC(4,2)
    `);
        await client.query(`
      DO $$
      BEGIN
        IF EXISTS (
          SELECT 1
          FROM pg_constraint
          WHERE conname = 'user_skill_score_check'
        ) THEN
          ALTER TABLE user_skill DROP CONSTRAINT user_skill_score_check;
        END IF;
      END
      $$;
    `);
        await client.query(`
      ALTER TABLE user_skill
      ADD CONSTRAINT user_skill_score_check
      CHECK (score >= 1 AND score <= 10)
    `);
        await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_trigger
          WHERE tgname = 'trg_audit_user_skill'
            AND tgrelid = 'user_skill'::regclass
        ) THEN
          CREATE TRIGGER trg_audit_user_skill
          AFTER INSERT OR UPDATE OR DELETE ON user_skill
          FOR EACH ROW EXECUTE FUNCTION write_audit_log();
        END IF;
      END
      $$;
    `);
        await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_trigger
          WHERE tgname = 'trg_user_skill_updated_at'
            AND tgrelid = 'user_skill'::regclass
        ) THEN
          CREATE TRIGGER trg_user_skill_updated_at
          BEFORE UPDATE ON user_skill
          FOR EACH ROW EXECUTE FUNCTION set_updated_at();
        END IF;
      END
      $$;
    `);
    }
    async ensureUserProjectTable(client) {
        await client.query(`
      CREATE TABLE IF NOT EXISTS user_project (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
        sort_order SMALLINT NOT NULL CHECK (sort_order >= 1 AND sort_order <= 50),
        title TEXT NOT NULL,
        description TEXT,
        github_url TEXT,
        start_month SMALLINT NOT NULL CHECK (start_month BETWEEN 1 AND 12),
        start_year SMALLINT NOT NULL CHECK (start_year BETWEEN 1950 AND 2100),
        end_month SMALLINT,
        end_year SMALLINT,
        is_current BOOLEAN NOT NULL DEFAULT FALSE,
        show_on_profile BOOLEAN NOT NULL DEFAULT TRUE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE (user_id, sort_order)
      )
    `);
        await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_trigger
          WHERE tgname = 'trg_audit_user_project'
            AND tgrelid = 'user_project'::regclass
        ) THEN
          CREATE TRIGGER trg_audit_user_project
          AFTER INSERT OR UPDATE OR DELETE ON user_project
          FOR EACH ROW EXECUTE FUNCTION write_audit_log();
        END IF;
      END
      $$;
    `);
        await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_trigger
          WHERE tgname = 'trg_user_project_updated_at'
            AND tgrelid = 'user_project'::regclass
        ) THEN
          CREATE TRIGGER trg_user_project_updated_at
          BEFORE UPDATE ON user_project
          FOR EACH ROW EXECUTE FUNCTION set_updated_at();
        END IF;
      END
      $$;
    `);
    }
    async ensureProfileEntryVisibilityColumns(client) {
        await client.query(`
      ALTER TABLE user_experience
      ADD COLUMN IF NOT EXISTS show_on_profile BOOLEAN NOT NULL DEFAULT TRUE
    `);
        await client.query(`
      ALTER TABLE user_education
      ADD COLUMN IF NOT EXISTS show_on_profile BOOLEAN NOT NULL DEFAULT TRUE
    `);
    }
    async ensureActivityCommentTable(client) {
        await client.query(`
      CREATE TABLE IF NOT EXISTS profile_activity_comment (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        post_id UUID NOT NULL REFERENCES profile_activity_post(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
        content TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
        await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_trigger
          WHERE tgname = 'trg_audit_profile_activity_comment'
            AND tgrelid = 'profile_activity_comment'::regclass
        ) THEN
          CREATE TRIGGER trg_audit_profile_activity_comment
          AFTER INSERT OR UPDATE OR DELETE ON profile_activity_comment
          FOR EACH ROW EXECUTE FUNCTION write_audit_log();
        END IF;
      END
      $$;
    `);
        await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_trigger
          WHERE tgname = 'trg_profile_activity_comment_updated_at'
            AND tgrelid = 'profile_activity_comment'::regclass
        ) THEN
          CREATE TRIGGER trg_profile_activity_comment_updated_at
          BEFORE UPDATE ON profile_activity_comment
          FOR EACH ROW EXECUTE FUNCTION set_updated_at();
        END IF;
      END
      $$;
    `);
    }
    getFounderEmails() {
        const raw = process.env.FOUNDER_BADGE_EMAILS ?? '';
        return new Set(raw
            .split(',')
            .map((value) => value.trim().toLowerCase())
            .filter((value) => value.length > 0));
    }
    computeBadgeData(user) {
        const badges = [];
        const badgeCatalog = [];
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
    async getProfile(userId) {
        return this.db.withTransaction(async (client) => {
            await this.ensureThemePreferencesTable(client);
            await this.ensureUserSkillTable(client);
            await this.ensureUserProjectTable(client);
            await this.ensureProfileEntryVisibilityColumns(client);
            const userRes = await client.query(`
          SELECT u.id,
                 u.account_type,
                 u.email,
               u.is_email_verified,
                 u.created_at,
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
        `, [userId]);
            const user = userRes.rows[0];
            if (!user) {
                throw new common_1.NotFoundException('User not found');
            }
            await client.query(`
          INSERT INTO profile_visibility (user_id)
          VALUES ($1)
          ON CONFLICT (user_id) DO NOTHING
        `, [userId]);
            const visibilityRes = await client.query(`
          SELECT
            show_gender,
            show_birth_date,
            show_account_created_date,
            show_account_created_time,
            show_job_title,
            show_phone,
            show_country,
            show_county,
            show_city,
            show_years_experience,
            show_education_level,
            show_education_institution,
            show_specialization,
            show_company_name,
            show_company_county,
            show_company_city,
            show_hr_first_name,
            show_hr_last_name,
            show_hr_email,
            show_cv,
            show_profile_summary,
            show_professional_status,
            show_linkedin,
            show_github,
            show_youtube,
            show_instagram,
            show_tiktok
          FROM profile_visibility
          WHERE user_id = $1
          LIMIT 1
        `, [userId]);
            const visibility = visibilityRes.rows[0];
            let userProfile = null;
            let companyProfile = null;
            if (user.account_type === 'user') {
                const profileRes = await client.query(`
            SELECT job_title,
                   years_experience,
                   education_level,
                   education_institution,
                   specialization,
                   profile_summary,
                   professional_status,
                   linkedin_url,
                   github_url,
                   youtube_url,
                   instagram_url,
                   tiktok_url,
                   country,
                   county,
                   city
            FROM user_profile
            WHERE user_id = $1
            LIMIT 1
          `, [userId]);
                if (profileRes.rows[0]) {
                    userProfile = {
                        jobTitle: profileRes.rows[0].job_title,
                        yearsExperience: profileRes.rows[0].years_experience,
                        educationLevel: profileRes.rows[0].education_level,
                        educationInstitution: profileRes.rows[0].education_institution,
                        specialization: profileRes.rows[0].specialization,
                        profileSummary: profileRes.rows[0].profile_summary,
                        professionalStatus: profileRes.rows[0].professional_status,
                        linkedInUrl: profileRes.rows[0].linkedin_url,
                        githubUrl: profileRes.rows[0].github_url,
                        youtubeUrl: profileRes.rows[0].youtube_url,
                        instagramUrl: profileRes.rows[0].instagram_url,
                        tiktokUrl: profileRes.rows[0].tiktok_url,
                        country: profileRes.rows[0].country,
                        county: profileRes.rows[0].county,
                        city: profileRes.rows[0].city,
                    };
                }
            }
            else {
                const companyRes = await client.query(`
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
          `, [userId]);
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
            const userExperiencesRes = await client.query(`
          SELECT id,
                 company_name,
                 job_title,
                 description,
                 start_month,
                 start_year,
                 end_month,
                 end_year,
                   is_current,
                   show_on_profile
          FROM user_experience
          WHERE user_id = $1
          ORDER BY sort_order ASC
        `, [userId]);
            const userEducationsRes = await client.query(`
          SELECT id,
               education_level,
                 university,
                 specialization,
                 start_month,
                 start_year,
                 end_month,
                 end_year,
                   is_current,
                   show_on_profile
          FROM user_education
          WHERE user_id = $1
          ORDER BY sort_order ASC
        `, [userId]);
            const userSkillsRes = await client.query(`
          SELECT id,
                 category,
                 name,
               score::double precision AS score,
                 is_visible
          FROM user_skill
          WHERE user_id = $1
          ORDER BY category ASC, sort_order ASC
        `, [userId]);
            const userProjectsRes = await client.query(`
          SELECT id,
                 title,
                 description,
                 github_url,
                 start_month,
                 start_year,
                 end_month,
                 end_year,
                 is_current,
                 show_on_profile
          FROM user_project
          WHERE user_id = $1
          ORDER BY sort_order ASC
        `, [userId]);
            const activityPosts = await this.fetchActivityPosts(client, userId, userId);
            const avatarRes = await client.query(`
          SELECT id
          FROM file_attachment
          WHERE user_id = $1 AND attachment_type = 'avatar'
          ORDER BY uploaded_at DESC
          LIMIT 1
        `, [userId]);
            const cvRes = await client.query(`
          SELECT id
          FROM file_attachment
          WHERE user_id = $1 AND attachment_type = 'cv'
          ORDER BY uploaded_at DESC
          LIMIT 1
        `, [userId]);
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
                    createdAt: user.created_at,
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
                userExperiences: userExperiencesRes.rows.map((experience) => ({
                    id: experience.id,
                    companyName: experience.company_name,
                    jobTitle: experience.job_title,
                    description: experience.description,
                    startMonth: experience.start_month,
                    startYear: experience.start_year,
                    endMonth: experience.end_month,
                    endYear: experience.end_year,
                    isCurrent: experience.is_current,
                    showOnProfile: experience.show_on_profile,
                })),
                userEducations: userEducationsRes.rows.map((education) => ({
                    id: education.id,
                    educationLevel: education.education_level,
                    university: education.university,
                    specialization: education.specialization,
                    startMonth: education.start_month,
                    startYear: education.start_year,
                    endMonth: education.end_month,
                    endYear: education.end_year,
                    isCurrent: education.is_current,
                    showOnProfile: education.show_on_profile,
                })),
                userSkills: userSkillsRes.rows.map((skill) => ({
                    id: skill.id,
                    category: skill.category,
                    name: skill.name,
                    score: skill.score,
                    isVisible: skill.is_visible,
                })),
                userProjects: userProjectsRes.rows.map((project) => ({
                    id: project.id,
                    title: project.title,
                    description: project.description,
                    githubUrl: project.github_url,
                    startMonth: project.start_month,
                    startYear: project.start_year,
                    endMonth: project.end_month,
                    endYear: project.end_year,
                    isCurrent: project.is_current,
                    showOnProfile: project.show_on_profile,
                })),
                companyProfile,
                activityPosts,
                canPostActivity: true,
                canCommentActivity: true,
                visibility: {
                    showGender: visibility?.show_gender ?? false,
                    showBirthDate: visibility?.show_birth_date ?? false,
                    showAccountCreatedDate: visibility?.show_account_created_date ?? false,
                    showAccountCreatedTime: visibility?.show_account_created_time ?? false,
                    showJobTitle: visibility?.show_job_title ?? false,
                    showPhone: visibility?.show_phone ?? false,
                    showCountry: visibility?.show_country ?? false,
                    showCounty: visibility?.show_county ?? false,
                    showCity: visibility?.show_city ?? false,
                    showYearsExperience: visibility?.show_years_experience ?? false,
                    showEducationLevel: visibility?.show_education_level ?? false,
                    showEducationInstitution: visibility?.show_education_institution ?? false,
                    showSpecialization: visibility?.show_specialization ?? false,
                    showCompanyName: visibility?.show_company_name ?? false,
                    showCompanyCounty: visibility?.show_company_county ?? false,
                    showCompanyCity: visibility?.show_company_city ?? false,
                    showHrFirstName: visibility?.show_hr_first_name ?? false,
                    showHrLastName: visibility?.show_hr_last_name ?? false,
                    showHrEmail: visibility?.show_hr_email ?? false,
                    showCv: visibility?.show_cv ?? false,
                    showProfileSummary: visibility?.show_profile_summary ?? false,
                    showProfessionalStatus: visibility?.show_professional_status ?? false,
                    showLinkedIn: visibility?.show_linkedin ?? false,
                    showGithub: visibility?.show_github ?? false,
                    showYoutube: visibility?.show_youtube ?? false,
                    showInstagram: visibility?.show_instagram ?? false,
                    showTiktok: visibility?.show_tiktok ?? false,
                },
                hasAvatar: (avatarRes.rowCount ?? 0) > 0,
                hasCv: (cvRes.rowCount ?? 0) > 0,
                badges: badgeData.badges,
                badgeCatalog: badgeData.badgeCatalog,
            };
        });
    }
    async updateUserProfile(userId, payload, auditContext) {
        return this.db.withTransaction(async (client) => {
            await this.ensureProfileEntryVisibilityColumns(client);
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                ...auditContext,
                currentUserId: userId,
            });
            const userRes = await client.query('SELECT account_type FROM app_user WHERE id = $1', [userId]);
            if (userRes.rows[0]?.account_type !== 'user') {
                throw new common_1.BadRequestException('Only user accounts can update this profile');
            }
            await client.query(`
          UPDATE app_user
          SET phone_e164 = COALESCE($1, phone_e164),
              gender = COALESCE($2, gender),
              birth_date = COALESCE($3::date, birth_date),
              updated_at = NOW()
          WHERE id = $4
        `, [
                payload.phone?.trim(),
                payload.gender,
                payload.birthDate,
                userId,
            ]);
            await client.query(`
          UPDATE user_profile
          SET country = COALESCE($1, country),
              county = COALESCE($2, county),
              city = COALESCE($3, city),
              years_experience = COALESCE($4, years_experience),
              education_level = COALESCE($5, education_level),
              education_institution = COALESCE($6, education_institution),
              job_title = COALESCE($7, job_title),
              specialization = COALESCE($8, specialization),
              profile_summary = COALESCE($9, profile_summary),
                linkedin_url = COALESCE($10, linkedin_url),
                github_url = COALESCE($11, github_url),
                youtube_url = COALESCE($12, youtube_url),
                instagram_url = COALESCE($13, instagram_url),
                tiktok_url = COALESCE($14, tiktok_url),
                professional_status = COALESCE($15, professional_status),
              updated_at = NOW()
              WHERE user_id = $16
        `, [
                payload.country?.trim(),
                payload.county?.trim(),
                payload.city?.trim(),
                payload.yearsExperience,
                payload.educationLevel?.trim(),
                payload.educationInstitution?.trim(),
                payload.jobTitle?.trim(),
                payload.specialization?.trim(),
                payload.profileSummary?.trim(),
                payload.linkedInUrl?.trim(),
                payload.githubUrl?.trim(),
                payload.youtubeUrl?.trim(),
                payload.instagramUrl?.trim(),
                payload.tiktokUrl?.trim(),
                payload.professionalStatus,
                userId,
            ]);
            return { success: true };
        });
    }
    async updateCompanyProfile(userId, payload, auditContext) {
        return this.db.withTransaction(async (client) => {
            await this.ensureProfileEntryVisibilityColumns(client);
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                ...auditContext,
                currentUserId: userId,
            });
            const userRes = await client.query('SELECT account_type FROM app_user WHERE id = $1', [userId]);
            if (userRes.rows[0]?.account_type !== 'company') {
                throw new common_1.BadRequestException('Only company accounts can update this profile');
            }
            await client.query(`
          UPDATE app_user
          SET gender = COALESCE($1, gender),
              birth_date = COALESCE($2::date, birth_date),
              updated_at = NOW()
          WHERE id = $3
        `, [
                payload.gender,
                payload.birthDate,
                userId,
            ]);
            await client.query(`
          UPDATE company
          SET legal_name = COALESCE($1, legal_name),
              country_code = COALESCE($2, country_code),
              county = COALESCE($3, county),
              city = COALESCE($4, city),
              updated_at = NOW()
          WHERE account_user_id = $5
        `, [
                payload.companyName?.trim(),
                payload.countryCode?.trim().toUpperCase(),
                payload.county?.trim(),
                payload.city?.trim(),
                userId,
            ]);
            return { success: true };
        });
    }
    async updateThemePreference(userId, payload, auditContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                ...auditContext,
                currentUserId: userId,
            });
            await this.ensureThemePreferencesTable(client);
            await client.query(`
          INSERT INTO app_user_theme_preference (user_id, default_theme, updated_at)
          VALUES ($1, $2, NOW())
          ON CONFLICT (user_id)
          DO UPDATE SET
            default_theme = EXCLUDED.default_theme,
            updated_at = NOW()
        `, [userId, payload.defaultTheme]);
            return {
                success: true,
                defaultTheme: payload.defaultTheme,
            };
        });
    }
    async updateVisibility(userId, payload, auditContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                ...auditContext,
                currentUserId: userId,
            });
            await client.query(`
          INSERT INTO profile_visibility (user_id)
          VALUES ($1)
          ON CONFLICT (user_id) DO NOTHING
        `, [userId]);
            await client.query(`
          UPDATE profile_visibility
          SET show_gender = COALESCE($1, show_gender),
              show_birth_date = COALESCE($2, show_birth_date),
              show_account_created_date = COALESCE($3, show_account_created_date),
              show_account_created_time = COALESCE($4, show_account_created_time),
              show_job_title = COALESCE($5, show_job_title),
              show_phone = COALESCE($6, show_phone),
              show_country = COALESCE($7, show_country),
              show_county = COALESCE($8, show_county),
              show_city = COALESCE($9, show_city),
              show_years_experience = COALESCE($10, show_years_experience),
              show_education_level = COALESCE($11, show_education_level),
              show_education_institution = COALESCE($12, show_education_institution),
              show_specialization = COALESCE($13, show_specialization),
              show_company_name = COALESCE($14, show_company_name),
              show_company_county = COALESCE($15, show_company_county),
              show_company_city = COALESCE($16, show_company_city),
              show_hr_first_name = COALESCE($17, show_hr_first_name),
              show_hr_last_name = COALESCE($18, show_hr_last_name),
              show_hr_email = COALESCE($19, show_hr_email),
              show_cv = COALESCE($20, show_cv),
              show_profile_summary = COALESCE($21, show_profile_summary),
              show_professional_status = COALESCE($22, show_professional_status),
                show_linkedin = COALESCE($23, show_linkedin),
                show_github = COALESCE($24, show_github),
                show_youtube = COALESCE($25, show_youtube),
                show_instagram = COALESCE($26, show_instagram),
                show_tiktok = COALESCE($27, show_tiktok),
              updated_at = NOW()
              WHERE user_id = $28
        `, [
                payload.showGender,
                payload.showBirthDate,
                payload.showAccountCreatedDate,
                payload.showAccountCreatedTime,
                payload.showJobTitle,
                payload.showPhone,
                payload.showCountry,
                payload.showCounty,
                payload.showCity,
                payload.showYearsExperience,
                payload.showEducationLevel,
                payload.showEducationInstitution,
                payload.showSpecialization,
                payload.showCompanyName,
                payload.showCompanyCounty,
                payload.showCompanyCity,
                payload.showHrFirstName,
                payload.showHrLastName,
                payload.showHrEmail,
                payload.showCv,
                payload.showProfileSummary,
                payload.showProfessionalStatus,
                payload.showLinkedIn,
                payload.showGithub,
                payload.showYoutube,
                payload.showInstagram,
                payload.showTiktok,
                userId,
            ]);
            return { success: true };
        });
    }
    async setUserExperiences(userId, payload, auditContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                ...auditContext,
                currentUserId: userId,
            });
            const userRes = await client.query('SELECT account_type FROM app_user WHERE id = $1', [userId]);
            if (userRes.rows[0]?.account_type !== 'user') {
                throw new common_1.BadRequestException('Only user accounts can set experiences');
            }
            const experiences = payload.experiences ?? [];
            for (const experience of experiences) {
                this.assertExperienceRange(experience);
            }
            await client.query('DELETE FROM user_experience WHERE user_id = $1', [userId]);
            for (let index = 0; index < experiences.length; index += 1) {
                const experience = experiences[index];
                await client.query(`
            INSERT INTO user_experience (
              user_id,
              sort_order,
              company_name,
              job_title,
              description,
              start_month,
              start_year,
              end_month,
              end_year,
              is_current,
              show_on_profile,
              updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW())
          `, [
                    userId,
                    index + 1,
                    experience.companyName.trim(),
                    experience.jobTitle.trim(),
                    this.normalizeNullableText(experience.description),
                    experience.startMonth,
                    experience.startYear,
                    experience.isCurrent ? null : experience.endMonth,
                    experience.isCurrent ? null : experience.endYear,
                    experience.isCurrent,
                    experience.showOnProfile ?? true,
                ]);
            }
            return { success: true };
        });
    }
    async setUserEducations(userId, payload, auditContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                ...auditContext,
                currentUserId: userId,
            });
            const userRes = await client.query('SELECT account_type FROM app_user WHERE id = $1', [userId]);
            if (userRes.rows[0]?.account_type !== 'user') {
                throw new common_1.BadRequestException('Only user accounts can set educations');
            }
            const educations = payload.educations ?? [];
            for (const education of educations) {
                this.assertEducationRange(education);
            }
            await client.query('DELETE FROM user_education WHERE user_id = $1', [userId]);
            for (let index = 0; index < educations.length; index += 1) {
                const education = educations[index];
                await client.query(`
            INSERT INTO user_education (
              user_id,
              sort_order,
              education_level,
              university,
              specialization,
              start_month,
              start_year,
              end_month,
              end_year,
              is_current,
              show_on_profile,
              updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW())
          `, [
                    userId,
                    index + 1,
                    education.educationLevel.trim(),
                    education.university.trim(),
                    education.specialization?.trim() ?? '',
                    education.startMonth,
                    education.startYear,
                    education.isCurrent ? null : education.endMonth,
                    education.isCurrent ? null : education.endYear,
                    education.isCurrent,
                    education.showOnProfile ?? true,
                ]);
            }
            return { success: true };
        });
    }
    async setUserSkills(userId, payload, auditContext) {
        return this.db.withTransaction(async (client) => {
            await this.ensureUserSkillTable(client);
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                ...auditContext,
                currentUserId: userId,
            });
            const userRes = await client.query('SELECT account_type FROM app_user WHERE id = $1', [userId]);
            if (userRes.rows[0]?.account_type !== 'user') {
                throw new common_1.BadRequestException('Only user accounts can set skills');
            }
            const skills = payload.skills ?? [];
            const counters = {
                language: 0,
                soft: 0,
                hard: 0,
            };
            await client.query('DELETE FROM user_skill WHERE user_id = $1', [userId]);
            for (const skill of skills) {
                const trimmedName = skill.name.trim();
                if (trimmedName.length === 0) {
                    continue;
                }
                counters[skill.category] += 1;
                await client.query(`
            INSERT INTO user_skill (
              user_id,
              category,
              sort_order,
              name,
              score,
              is_visible,
              updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, NOW())
          `, [
                    userId,
                    skill.category,
                    counters[skill.category],
                    trimmedName,
                    skill.score,
                    skill.isVisible,
                ]);
            }
            return { success: true };
        });
    }
    async setUserProjects(userId, payload, auditContext) {
        return this.db.withTransaction(async (client) => {
            await this.ensureUserProjectTable(client);
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                ...auditContext,
                currentUserId: userId,
            });
            const userRes = await client.query('SELECT account_type FROM app_user WHERE id = $1', [userId]);
            if (userRes.rows[0]?.account_type !== 'user') {
                throw new common_1.BadRequestException('Only user accounts can set projects');
            }
            const projects = payload.projects ?? [];
            for (const project of projects) {
                this.assertExperienceRange({
                    startMonth: project.startMonth,
                    startYear: project.startYear,
                    isCurrent: project.isCurrent,
                    endMonth: project.endMonth,
                    endYear: project.endYear,
                });
            }
            await client.query('DELETE FROM user_project WHERE user_id = $1', [userId]);
            for (let index = 0; index < projects.length; index += 1) {
                const project = projects[index];
                const trimmedTitle = project.title.trim();
                if (trimmedTitle.length === 0) {
                    continue;
                }
                await client.query(`
            INSERT INTO user_project (
              user_id,
              sort_order,
              title,
              description,
              github_url,
              start_month,
              start_year,
              end_month,
              end_year,
              is_current,
              show_on_profile,
              updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW())
          `, [
                    userId,
                    index + 1,
                    trimmedTitle,
                    this.normalizeNullableText(project.description),
                    this.normalizeNullableText(project.githubUrl),
                    project.startMonth,
                    project.startYear,
                    project.isCurrent ? null : project.endMonth,
                    project.isCurrent ? null : project.endYear,
                    project.isCurrent,
                    project.showOnProfile ?? true,
                ]);
            }
            return { success: true };
        });
    }
    async searchUsers(viewerUserId, rawQuery, rawField = 'all', page = 1, limit = 20) {
        return this.db.withTransaction(async (client) => {
            const trimmedQuery = rawQuery.trim();
            const safePage = Number.isFinite(page) ? Math.max(1, page) : 1;
            const safeLimit = Number.isFinite(limit) ? Math.min(Math.max(limit, 1), 50) : 20;
            const offset = (safePage - 1) * safeLimit;
            const query = `%${trimmedQuery}%`;
            const safeField = ['all', 'name', 'email', 'jobTitle'].includes(rawField)
                ? rawField
                : 'all';
            const totalRes = await client.query(`
          SELECT COUNT(*)::int AS total
          FROM app_user u
          LEFT JOIN user_profile up ON up.user_id = u.id
          WHERE u.deleted_at IS NULL
            AND u.account_type = 'user'
            AND u.id <> $1
            AND (
              $2 = '%%'
              OR (
                $3 = 'all'
                AND (
                  u.email ILIKE $2
                  OR COALESCE(TRIM(CONCAT(u.first_name, ' ', u.last_name)), '') ILIKE $2
                  OR COALESCE(up.job_title, '') ILIKE $2
                )
              )
              OR (
                $3 = 'name'
                AND COALESCE(TRIM(CONCAT(u.first_name, ' ', u.last_name)), '') ILIKE $2
              )
              OR ($3 = 'email' AND u.email ILIKE $2)
              OR ($3 = 'jobTitle' AND COALESCE(up.job_title, '') ILIKE $2)
            )
        `, [viewerUserId, query, safeField]);
            const rowsRes = await client.query(`
          SELECT u.id AS user_id,
                 u.email,
                 u.first_name,
                 u.last_name,
                 up.city,
                 up.county,
                 up.country,
                 up.job_title,
                 up.years_experience,
                 up.professional_status,
                 COALESCE(v.show_city, false) AS show_city,
                 COALESCE(v.show_county, false) AS show_county,
                 COALESCE(v.show_country, false) AS show_country,
                 COALESCE(v.show_job_title, false) AS show_job_title,
                 COALESCE(v.show_years_experience, false) AS show_years_experience
          FROM app_user u
          LEFT JOIN user_profile up ON up.user_id = u.id
          LEFT JOIN profile_visibility v ON v.user_id = u.id
          WHERE u.deleted_at IS NULL
            AND u.account_type = 'user'
            AND u.id <> $1
            AND (
              $2 = '%%'
              OR (
                $3 = 'all'
                AND (
                  u.email ILIKE $2
                  OR COALESCE(TRIM(CONCAT(u.first_name, ' ', u.last_name)), '') ILIKE $2
                  OR COALESCE(up.job_title, '') ILIKE $2
                )
              )
              OR (
                $3 = 'name'
                AND COALESCE(TRIM(CONCAT(u.first_name, ' ', u.last_name)), '') ILIKE $2
              )
              OR ($3 = 'email' AND u.email ILIKE $2)
              OR ($3 = 'jobTitle' AND COALESCE(up.job_title, '') ILIKE $2)
            )
          ORDER BY u.created_at DESC
          LIMIT $4
          OFFSET $5
        `, [viewerUserId, query, safeField, safeLimit, offset]);
            return {
                page: safePage,
                limit: safeLimit,
                total: totalRes.rows[0]?.total ?? 0,
                items: rowsRes.rows.map((row) => ({
                    userId: row.user_id,
                    email: row.email,
                    firstName: row.first_name,
                    lastName: row.last_name,
                    jobTitle: row.show_job_title ? row.job_title : null,
                    yearsExperience: row.show_years_experience ? row.years_experience : null,
                    professionalStatus: row.professional_status,
                    city: row.show_city ? row.city : null,
                    county: row.show_county ? row.county : null,
                    country: row.show_country ? row.country : null,
                })),
            };
        });
    }
    async getProfileForViewer(viewerUserId, profileUserId) {
        if (viewerUserId === profileUserId) {
            return this.getProfile(profileUserId);
        }
        const profile = await this.getProfile(profileUserId);
        const visibility = profile.visibility ?? {};
        const user = profile.user ?? {};
        const userProfile = profile.userProfile ?? {};
        return {
            ...profile,
            user: {
                ...user,
                birthDate: visibility.showBirthDate ? user.birthDate : null,
                createdAt: visibility.showAccountCreatedDate || visibility.showAccountCreatedTime
                    ? user.createdAt
                    : null,
                phone: visibility.showPhone ? user.phone : null,
            },
            userProfile: {
                ...userProfile,
                jobTitle: visibility.showJobTitle ? userProfile.jobTitle : null,
                country: visibility.showCountry ? userProfile.country : null,
                county: visibility.showCounty ? userProfile.county : null,
                city: visibility.showCity ? userProfile.city : null,
                yearsExperience: visibility.showYearsExperience ? userProfile.yearsExperience : null,
                educationLevel: visibility.showEducationLevel ? userProfile.educationLevel : null,
                educationInstitution: visibility.showEducationInstitution ? userProfile.educationInstitution : null,
                specialization: visibility.showSpecialization ? userProfile.specialization : null,
                profileSummary: visibility.showProfileSummary ? userProfile.profileSummary : null,
                professionalStatus: visibility.showProfessionalStatus ? userProfile.professionalStatus : null,
                linkedInUrl: visibility.showLinkedIn ? userProfile.linkedInUrl : null,
                githubUrl: visibility.showGithub ? userProfile.githubUrl : null,
                youtubeUrl: visibility.showYoutube ? userProfile.youtubeUrl : null,
                instagramUrl: visibility.showInstagram ? userProfile.instagramUrl : null,
                tiktokUrl: visibility.showTiktok ? userProfile.tiktokUrl : null,
            },
            userExperiences: profile.userExperiences
                .filter((entry) => entry['showOnProfile'] !== false),
            userEducations: profile.userEducations
                .filter((entry) => entry['showOnProfile'] !== false),
            userSkills: profile.userSkills
                .filter((entry) => entry['isVisible'] === true),
            userProjects: profile.userProjects
                .filter((entry) => entry['showOnProfile'] !== false),
        };
    }
    async createActivityPost(userId, payload, auditContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                ...auditContext,
                currentUserId: userId,
            });
            const content = payload.content?.trim() ?? '';
            const sticker = this.normalizeNullableText(payload.sticker);
            const attachmentIds = payload.attachmentIds ?? [];
            if (content.length === 0 && sticker == null && attachmentIds.length == 0) {
                throw new common_1.BadRequestException('Post requires text, sticker, or attachments');
            }
            await this.ensureOwnedPostAttachments(client, userId, attachmentIds);
            const insertRes = await client.query(`
          INSERT INTO profile_activity_post (user_id, content, sticker, updated_at)
          VALUES ($1, $2, $3, NOW())
          RETURNING id
        `, [userId, content, sticker]);
            const postId = insertRes.rows[0].id;
            for (const attachmentId of attachmentIds) {
                await client.query(`
            INSERT INTO profile_activity_post_attachment (post_id, attachment_id)
            VALUES ($1, $2)
            ON CONFLICT (post_id, attachment_id) DO NOTHING
          `, [postId, attachmentId]);
            }
            const posts = await this.fetchActivityPosts(client, userId, userId, 20);
            const post = posts.find((entry) => entry.id === postId);
            return {
                success: true,
                post,
            };
        });
    }
    async updateActivityPost(userId, postId, payload, auditContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                ...auditContext,
                currentUserId: userId,
            });
            const postRes = await client.query(`
          SELECT id, content, sticker
          FROM profile_activity_post
          WHERE id = $1 AND user_id = $2
          LIMIT 1
        `, [postId, userId]);
            const existingPost = postRes.rows[0];
            if (!existingPost) {
                throw new common_1.NotFoundException('Post not found');
            }
            const nextContent = payload.content == null ? existingPost.content : payload.content.trim();
            const nextSticker = payload.sticker == null
                ? existingPost.sticker
                : this.normalizeNullableText(payload.sticker);
            const hasAttachmentUpdate = payload.attachmentIds != null;
            const nextAttachmentIds = hasAttachmentUpdate ? payload.attachmentIds ?? [] : null;
            if (nextAttachmentIds != null) {
                await this.ensureOwnedPostAttachments(client, userId, nextAttachmentIds);
            }
            const currentAttachmentCountRes = await client.query(`
          SELECT COUNT(*)::text AS count
          FROM profile_activity_post_attachment
          WHERE post_id = $1
        `, [postId]);
            const currentAttachmentCount = Number(currentAttachmentCountRes.rows[0]?.count ?? '0');
            const effectiveAttachmentCount = nextAttachmentIds == null
                ? currentAttachmentCount
                : nextAttachmentIds.length;
            if (nextContent.length === 0 && nextSticker == null && effectiveAttachmentCount == 0) {
                throw new common_1.BadRequestException('Post requires text, sticker, or attachments');
            }
            await client.query(`
          UPDATE profile_activity_post
          SET content = $1,
              sticker = $2,
              updated_at = NOW()
          WHERE id = $3 AND user_id = $4
        `, [nextContent, nextSticker, postId, userId]);
            if (nextAttachmentIds != null) {
                await client.query('DELETE FROM profile_activity_post_attachment WHERE post_id = $1', [postId]);
                for (const attachmentId of nextAttachmentIds) {
                    await client.query(`
              INSERT INTO profile_activity_post_attachment (post_id, attachment_id)
              VALUES ($1, $2)
              ON CONFLICT (post_id, attachment_id) DO NOTHING
            `, [postId, attachmentId]);
                }
            }
            const posts = await this.fetchActivityPosts(client, userId, userId, 20);
            const post = posts.find((entry) => entry.id === postId);
            return {
                success: true,
                post,
            };
        });
    }
    async deleteActivityPost(userId, postId, auditContext) {
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                ...auditContext,
                currentUserId: userId,
            });
            const deleteRes = await client.query(`
          DELETE FROM profile_activity_post
          WHERE id = $1 AND user_id = $2
        `, [postId, userId]);
            if ((deleteRes.rowCount ?? 0) === 0) {
                throw new common_1.NotFoundException('Post not found');
            }
            return { success: true };
        });
    }
    async createActivityComment(userId, postId, payload, auditContext) {
        return this.db.withTransaction(async (client) => {
            await this.ensureActivityCommentTable(client);
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                ...auditContext,
                currentUserId: userId,
            });
            const content = payload.content.trim();
            if (content.length === 0) {
                throw new common_1.BadRequestException('Comment content is required');
            }
            const postRes = await client.query(`
          SELECT id, user_id
          FROM profile_activity_post
          WHERE id = $1
          LIMIT 1
        `, [postId]);
            const post = postRes.rows[0];
            if (!post) {
                throw new common_1.NotFoundException('Post not found');
            }
            const insertRes = await client.query(`
          INSERT INTO profile_activity_comment (post_id, user_id, content, updated_at)
          VALUES ($1, $2, $3, NOW())
          RETURNING id
        `, [postId, userId, content]);
            const commentsRes = await client.query(`
          SELECT c.id,
                 c.user_id,
                 c.content,
                 c.created_at,
                 c.updated_at,
                 u.first_name,
                 u.last_name
          FROM profile_activity_comment c
          INNER JOIN app_user u ON u.id = c.user_id
          WHERE c.id = $1
          LIMIT 1
        `, [insertRes.rows[0].id]);
            const insertedComment = commentsRes.rows[0];
            const firstName = insertedComment.first_name?.trim() ?? '';
            const lastName = insertedComment.last_name?.trim() ?? '';
            const authorName = [firstName, lastName]
                .filter((value) => value.length > 0)
                .join(' ')
                .trim();
            return {
                success: true,
                comment: {
                    id: insertedComment.id,
                    userId: insertedComment.user_id,
                    authorName: authorName.length === 0 ? 'User' : authorName,
                    content: insertedComment.content,
                    createdAt: insertedComment.created_at,
                    updatedAt: insertedComment.updated_at,
                    isOwnComment: insertedComment.user_id === userId,
                },
                postOwnerId: post.user_id,
            };
        });
    }
    async getAvatar(userId) {
        return this.db.withTransaction(async (client) => {
            const avatarRes = await client.query(`
          SELECT storage_key, mime_type, file_size_bytes
          FROM file_attachment
          WHERE user_id = $1 AND attachment_type = 'avatar'
          ORDER BY uploaded_at DESC
          LIMIT 1
        `, [userId]);
            if (avatarRes.rowCount === 0) {
                return null;
            }
            const avatar = avatarRes.rows[0];
            const storageRoot = path.resolve(process.cwd(), 'uploads');
            const storagePath = path.join(storageRoot, avatar.storage_key);
            try {
                const buffer = await fs_1.promises.readFile(storagePath);
                return {
                    buffer,
                    mimeType: avatar.mime_type,
                    size: Number(avatar.file_size_bytes),
                };
            }
            catch (_) {
                throw new common_1.NotFoundException('Avatar not found on disk');
            }
        });
    }
};
exports.ProfileService = ProfileService;
exports.ProfileService = ProfileService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], ProfileService);
//# sourceMappingURL=profile.service.js.map
import { DatabaseService } from '../database/database.service';
import { AuditSqlContext } from '../database/audit-sql-context';
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
export declare class ProfileService {
    private readonly db;
    constructor(db: DatabaseService);
    private ensureThemePreferencesTable;
    private getFounderEmails;
    private computeBadgeData;
    getProfile(userId: string): Promise<{
        accountType: "user" | "company";
        user: {
            id: string;
            email: string;
            isEmailVerified: boolean;
            gender: "male" | "female" | null;
            birthDate: string | null;
            firstName: string | null;
            lastName: string | null;
            phone: string | null;
            defaultTheme: "light" | "dark";
            twoFactorEnabled: boolean;
            twoFactorPending: boolean;
        };
        userProfile: {
            jobTitle: string | null;
            yearsExperience: number | null;
            educationLevel: string | null;
            educationInstitution: string | null;
            country: string | null;
            county: string | null;
            city: string | null;
        } | null;
        companyProfile: {
            companyName: string | null;
            countryCode: string | null;
            county: string | null;
            city: string | null;
            hrFirstName: string | null;
            hrLastName: string | null;
            hrEmail: string | null;
        } | null;
        visibility: {
            showGender: boolean;
            showBirthDate: boolean;
            showJobTitle: boolean;
            showPhone: boolean;
            showCountry: boolean;
            showCounty: boolean;
            showCity: boolean;
            showYearsExperience: boolean;
            showEducationLevel: boolean;
            showEducationInstitution: boolean;
            showCompanyName: boolean;
            showCompanyCounty: boolean;
            showCompanyCity: boolean;
            showHrFirstName: boolean;
            showHrLastName: boolean;
            showHrEmail: boolean;
            showCv: boolean;
        };
        hasAvatar: boolean;
        hasCv: boolean;
        badges: ProfileBadge[];
        badgeCatalog: ProfileBadgeCatalogEntry[];
    }>;
    updateUserProfile(userId: string, payload: UpdateUserProfileDto, auditContext?: AuditSqlContext): Promise<{
        success: boolean;
    }>;
    updateCompanyProfile(userId: string, payload: UpdateCompanyProfileDto, auditContext?: AuditSqlContext): Promise<{
        success: boolean;
    }>;
    updateThemePreference(userId: string, payload: UpdateThemePreferenceDto, auditContext?: AuditSqlContext): Promise<{
        success: boolean;
        defaultTheme: "light" | "dark";
    }>;
    updateVisibility(userId: string, payload: UpdateProfileVisibilityDto, auditContext?: AuditSqlContext): Promise<{
        success: boolean;
    }>;
    getAvatar(userId: string): Promise<AvatarPayload | null>;
}
export {};

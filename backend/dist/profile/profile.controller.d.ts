import { StreamableFile } from '@nestjs/common';
import { AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { UpdateCompanyProfileDto } from './dto/update-company-profile.dto';
import { UpdateProfileVisibilityDto } from './dto/update-profile-visibility.dto';
import { UpdateThemePreferenceDto } from './dto/update-theme-preference.dto';
import { UpdateUserProfileDto } from './dto/update-user-profile.dto';
import { ProfileService } from './profile.service';
export declare class ProfileController {
    private readonly profileService;
    constructor(profileService: ProfileService);
    getProfile(req: AuthenticatedRequest): Promise<{
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
        badges: import("./profile.service").ProfileBadge[];
        badgeCatalog: import("./profile.service").ProfileBadgeCatalogEntry[];
    }>;
    updateUserProfile(req: AuthenticatedRequest, payload: UpdateUserProfileDto): Promise<{
        success: boolean;
    }>;
    updateCompanyProfile(req: AuthenticatedRequest, payload: UpdateCompanyProfileDto): Promise<{
        success: boolean;
    }>;
    updateVisibility(req: AuthenticatedRequest, payload: UpdateProfileVisibilityDto): Promise<{
        success: boolean;
    }>;
    updateThemePreference(req: AuthenticatedRequest, payload: UpdateThemePreferenceDto): Promise<{
        success: boolean;
        defaultTheme: "light" | "dark";
    }>;
    getAvatar(req: AuthenticatedRequest): Promise<StreamableFile>;
}

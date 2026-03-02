import { StreamableFile } from '@nestjs/common';
import { AuthenticatedRequest } from '../auth/jwt-auth.guard';
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
export declare class ProfileController {
    private readonly profileService;
    constructor(profileService: ProfileService);
    getProfile(req: AuthenticatedRequest): Promise<{
        accountType: "user" | "company";
        user: {
            id: string;
            email: string;
            isEmailVerified: boolean;
            createdAt: string;
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
            specialization: string | null;
            profileSummary: string | null;
            professionalStatus: "open_to_work" | "hired" | "not_available" | null;
            linkedInUrl: string | null;
            githubUrl: string | null;
            youtubeUrl: string | null;
            instagramUrl: string | null;
            tiktokUrl: string | null;
            country: string | null;
            county: string | null;
            city: string | null;
        } | null;
        userExperiences: {
            id: string;
            companyName: string;
            jobTitle: string;
            description: string | null;
            startMonth: number;
            startYear: number;
            endMonth: number | null;
            endYear: number | null;
            isCurrent: boolean;
            showOnProfile: boolean;
        }[];
        userEducations: {
            id: string;
            educationLevel: string;
            university: string;
            specialization: string;
            startMonth: number;
            startYear: number;
            endMonth: number | null;
            endYear: number | null;
            isCurrent: boolean;
            showOnProfile: boolean;
        }[];
        userSkills: {
            id: string;
            category: "language" | "soft" | "hard";
            name: string;
            score: number;
            isVisible: boolean;
        }[];
        userProjects: {
            id: string;
            title: string;
            description: string | null;
            githubUrl: string | null;
            startMonth: number;
            startYear: number;
            endMonth: number | null;
            endYear: number | null;
            isCurrent: boolean;
            showOnProfile: boolean;
        }[];
        companyProfile: {
            companyName: string | null;
            countryCode: string | null;
            county: string | null;
            city: string | null;
            hrFirstName: string | null;
            hrLastName: string | null;
            hrEmail: string | null;
        } | null;
        activityPosts: {
            id: string;
            content: string;
            sticker: string | null;
            createdAt: string;
            updatedAt: string;
            canEdit: boolean;
            attachments: {
                id: string;
                fileName: string;
                mimeType: string | null;
                fileSizeBytes: number;
            }[];
            comments: {
                id: string;
                userId: string;
                authorName: string;
                content: string;
                createdAt: string;
                updatedAt: string;
                isOwnComment: boolean;
            }[];
        }[];
        canPostActivity: boolean;
        canCommentActivity: boolean;
        visibility: {
            showGender: boolean;
            showBirthDate: boolean;
            showAccountCreatedDate: boolean;
            showAccountCreatedTime: boolean;
            showJobTitle: boolean;
            showPhone: boolean;
            showCountry: boolean;
            showCounty: boolean;
            showCity: boolean;
            showYearsExperience: boolean;
            showEducationLevel: boolean;
            showEducationInstitution: boolean;
            showSpecialization: boolean;
            showCompanyName: boolean;
            showCompanyCounty: boolean;
            showCompanyCity: boolean;
            showHrFirstName: boolean;
            showHrLastName: boolean;
            showHrEmail: boolean;
            showCv: boolean;
            showProfileSummary: boolean;
            showProfessionalStatus: boolean;
            showLinkedIn: boolean;
            showGithub: boolean;
            showYoutube: boolean;
            showInstagram: boolean;
            showTiktok: boolean;
        };
        hasAvatar: boolean;
        hasCv: boolean;
        badges: import("./profile.service").ProfileBadge[];
        badgeCatalog: import("./profile.service").ProfileBadgeCatalogEntry[];
    }>;
    updateUserProfile(req: AuthenticatedRequest, payload: UpdateUserProfileDto): Promise<{
        success: boolean;
    }>;
    setUserExperiences(req: AuthenticatedRequest, payload: SetUserExperiencesDto): Promise<{
        success: boolean;
    }>;
    setUserEducations(req: AuthenticatedRequest, payload: SetUserEducationsDto): Promise<{
        success: boolean;
    }>;
    setUserSkills(req: AuthenticatedRequest, payload: SetUserSkillsDto): Promise<{
        success: boolean;
    }>;
    setUserProjects(req: AuthenticatedRequest, payload: SetUserProjectsDto): Promise<{
        success: boolean;
    }>;
    searchUsers(req: AuthenticatedRequest, query: string, field: string, page: number, limit: number): Promise<{
        page: number;
        limit: number;
        total: number;
        items: {
            userId: string;
            email: string;
            firstName: string | null;
            lastName: string | null;
            jobTitle: string | null;
            yearsExperience: number | null;
            professionalStatus: string | null;
            city: string | null;
            county: string | null;
            country: string | null;
        }[];
    }>;
    getUserProfileById(req: AuthenticatedRequest, userId: string): Promise<{
        accountType: "user" | "company";
        user: {
            id: string;
            email: string;
            isEmailVerified: boolean;
            createdAt: string;
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
            specialization: string | null;
            profileSummary: string | null;
            professionalStatus: "open_to_work" | "hired" | "not_available" | null;
            linkedInUrl: string | null;
            githubUrl: string | null;
            youtubeUrl: string | null;
            instagramUrl: string | null;
            tiktokUrl: string | null;
            country: string | null;
            county: string | null;
            city: string | null;
        } | null;
        userExperiences: {
            id: string;
            companyName: string;
            jobTitle: string;
            description: string | null;
            startMonth: number;
            startYear: number;
            endMonth: number | null;
            endYear: number | null;
            isCurrent: boolean;
            showOnProfile: boolean;
        }[];
        userEducations: {
            id: string;
            educationLevel: string;
            university: string;
            specialization: string;
            startMonth: number;
            startYear: number;
            endMonth: number | null;
            endYear: number | null;
            isCurrent: boolean;
            showOnProfile: boolean;
        }[];
        userSkills: {
            id: string;
            category: "language" | "soft" | "hard";
            name: string;
            score: number;
            isVisible: boolean;
        }[];
        userProjects: {
            id: string;
            title: string;
            description: string | null;
            githubUrl: string | null;
            startMonth: number;
            startYear: number;
            endMonth: number | null;
            endYear: number | null;
            isCurrent: boolean;
            showOnProfile: boolean;
        }[];
        companyProfile: {
            companyName: string | null;
            countryCode: string | null;
            county: string | null;
            city: string | null;
            hrFirstName: string | null;
            hrLastName: string | null;
            hrEmail: string | null;
        } | null;
        activityPosts: {
            id: string;
            content: string;
            sticker: string | null;
            createdAt: string;
            updatedAt: string;
            canEdit: boolean;
            attachments: {
                id: string;
                fileName: string;
                mimeType: string | null;
                fileSizeBytes: number;
            }[];
            comments: {
                id: string;
                userId: string;
                authorName: string;
                content: string;
                createdAt: string;
                updatedAt: string;
                isOwnComment: boolean;
            }[];
        }[];
        canPostActivity: boolean;
        canCommentActivity: boolean;
        visibility: {
            showGender: boolean;
            showBirthDate: boolean;
            showAccountCreatedDate: boolean;
            showAccountCreatedTime: boolean;
            showJobTitle: boolean;
            showPhone: boolean;
            showCountry: boolean;
            showCounty: boolean;
            showCity: boolean;
            showYearsExperience: boolean;
            showEducationLevel: boolean;
            showEducationInstitution: boolean;
            showSpecialization: boolean;
            showCompanyName: boolean;
            showCompanyCounty: boolean;
            showCompanyCity: boolean;
            showHrFirstName: boolean;
            showHrLastName: boolean;
            showHrEmail: boolean;
            showCv: boolean;
            showProfileSummary: boolean;
            showProfessionalStatus: boolean;
            showLinkedIn: boolean;
            showGithub: boolean;
            showYoutube: boolean;
            showInstagram: boolean;
            showTiktok: boolean;
        };
        hasAvatar: boolean;
        hasCv: boolean;
        badges: import("./profile.service").ProfileBadge[];
        badgeCatalog: import("./profile.service").ProfileBadgeCatalogEntry[];
    } | {
        user: {
            birthDate: unknown;
            createdAt: unknown;
            phone: unknown;
        };
        userProfile: {
            jobTitle: unknown;
            country: unknown;
            county: unknown;
            city: unknown;
            yearsExperience: unknown;
            educationLevel: unknown;
            educationInstitution: unknown;
            specialization: unknown;
            profileSummary: unknown;
            professionalStatus: unknown;
            linkedInUrl: unknown;
            githubUrl: unknown;
            youtubeUrl: unknown;
            instagramUrl: unknown;
            tiktokUrl: unknown;
        };
        userExperiences: Record<string, unknown>[];
        userEducations: Record<string, unknown>[];
        userSkills: Record<string, unknown>[];
        userProjects: Record<string, unknown>[];
        accountType: "user" | "company";
        companyProfile: {
            companyName: string | null;
            countryCode: string | null;
            county: string | null;
            city: string | null;
            hrFirstName: string | null;
            hrLastName: string | null;
            hrEmail: string | null;
        } | null;
        activityPosts: {
            id: string;
            content: string;
            sticker: string | null;
            createdAt: string;
            updatedAt: string;
            canEdit: boolean;
            attachments: {
                id: string;
                fileName: string;
                mimeType: string | null;
                fileSizeBytes: number;
            }[];
            comments: {
                id: string;
                userId: string;
                authorName: string;
                content: string;
                createdAt: string;
                updatedAt: string;
                isOwnComment: boolean;
            }[];
        }[];
        canPostActivity: boolean;
        canCommentActivity: boolean;
        visibility: {
            showGender: boolean;
            showBirthDate: boolean;
            showAccountCreatedDate: boolean;
            showAccountCreatedTime: boolean;
            showJobTitle: boolean;
            showPhone: boolean;
            showCountry: boolean;
            showCounty: boolean;
            showCity: boolean;
            showYearsExperience: boolean;
            showEducationLevel: boolean;
            showEducationInstitution: boolean;
            showSpecialization: boolean;
            showCompanyName: boolean;
            showCompanyCounty: boolean;
            showCompanyCity: boolean;
            showHrFirstName: boolean;
            showHrLastName: boolean;
            showHrEmail: boolean;
            showCv: boolean;
            showProfileSummary: boolean;
            showProfessionalStatus: boolean;
            showLinkedIn: boolean;
            showGithub: boolean;
            showYoutube: boolean;
            showInstagram: boolean;
            showTiktok: boolean;
        };
        hasAvatar: boolean;
        hasCv: boolean;
        badges: import("./profile.service").ProfileBadge[];
        badgeCatalog: import("./profile.service").ProfileBadgeCatalogEntry[];
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
    createActivityPost(req: AuthenticatedRequest, payload: CreateActivityPostDto): Promise<{
        success: boolean;
        post: {
            id: string;
            content: string;
            sticker: string | null;
            createdAt: string;
            updatedAt: string;
            canEdit: boolean;
            attachments: {
                id: string;
                fileName: string;
                mimeType: string | null;
                fileSizeBytes: number;
            }[];
            comments: {
                id: string;
                userId: string;
                authorName: string;
                content: string;
                createdAt: string;
                updatedAt: string;
                isOwnComment: boolean;
            }[];
        } | undefined;
    }>;
    updateActivityPost(req: AuthenticatedRequest, postId: string, payload: UpdateActivityPostDto): Promise<{
        success: boolean;
        post: {
            id: string;
            content: string;
            sticker: string | null;
            createdAt: string;
            updatedAt: string;
            canEdit: boolean;
            attachments: {
                id: string;
                fileName: string;
                mimeType: string | null;
                fileSizeBytes: number;
            }[];
            comments: {
                id: string;
                userId: string;
                authorName: string;
                content: string;
                createdAt: string;
                updatedAt: string;
                isOwnComment: boolean;
            }[];
        } | undefined;
    }>;
    deleteActivityPost(req: AuthenticatedRequest, postId: string): Promise<{
        success: boolean;
    }>;
    createActivityComment(req: AuthenticatedRequest, postId: string, payload: CreateActivityCommentDto): Promise<{
        success: boolean;
        comment: {
            id: string;
            userId: string;
            authorName: string;
            content: string;
            createdAt: string;
            updatedAt: string;
            isOwnComment: boolean;
        };
        postOwnerId: string;
    }>;
    getAvatar(req: AuthenticatedRequest): Promise<StreamableFile>;
}

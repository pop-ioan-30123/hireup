export declare class UserExperienceDto {
    companyName: string;
    jobTitle: string;
    description?: string;
    startMonth: number;
    startYear: number;
    isCurrent: boolean;
    endMonth?: number;
    endYear?: number;
    showOnProfile?: boolean;
}
export declare class SetUserExperiencesDto {
    experiences: UserExperienceDto[];
}

export declare class UserEducationDto {
    educationLevel: string;
    university: string;
    specialization?: string;
    startMonth: number;
    startYear: number;
    isCurrent: boolean;
    endMonth?: number;
    endYear?: number;
    showOnProfile?: boolean;
}
export declare class SetUserEducationsDto {
    educations: UserEducationDto[];
}

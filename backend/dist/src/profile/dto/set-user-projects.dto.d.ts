export declare class UserProjectDto {
    title: string;
    description?: string;
    githubUrl?: string;
    startMonth: number;
    startYear: number;
    isCurrent: boolean;
    endMonth?: number;
    endYear?: number;
    showOnProfile?: boolean;
}
export declare class SetUserProjectsDto {
    projects: UserProjectDto[];
}

export declare class UserSkillDto {
    category: 'language' | 'soft' | 'hard';
    name: string;
    score: number;
    isVisible: boolean;
}
export declare class SetUserSkillsDto {
    skills: UserSkillDto[];
}

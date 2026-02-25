export declare class RegisterUserDto {
    email: string;
    password: string;
    firstName: string;
    lastName: string;
    gender: 'male' | 'female';
    birthDate: string;
    phone: string;
    country: string;
    county: string;
    city: string;
    jobTitle: string;
    yearsExperience: number;
    educationLevel: string;
    educationInstitution: string;
    gdprVersion: string;
    locale: string;
    ipAddress?: string;
    userAgent?: string;
}

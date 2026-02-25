export declare class RegisterCompanyDto {
    email: string;
    password: string;
    companyName: string;
    countryCode?: string;
    county?: string;
    city?: string;
    hrFirstName: string;
    hrLastName: string;
    hrEmail: string;
    gender: 'male' | 'female';
    birthDate: string;
    gdprVersion: string;
    locale: string;
    ipAddress?: string;
    userAgent?: string;
}

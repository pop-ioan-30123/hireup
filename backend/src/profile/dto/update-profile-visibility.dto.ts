import { IsBoolean, IsOptional } from 'class-validator';

export class UpdateProfileVisibilityDto {
  @IsOptional()
  @IsBoolean()
  showGender?: boolean;

  @IsOptional()
  @IsBoolean()
  showBirthDate?: boolean;

  @IsOptional()
  @IsBoolean()
  showAccountCreatedDate?: boolean;

  @IsOptional()
  @IsBoolean()
  showAccountCreatedTime?: boolean;

  @IsOptional()
  @IsBoolean()
  showJobTitle?: boolean;

  @IsOptional()
  @IsBoolean()
  showPhone?: boolean;

  @IsOptional()
  @IsBoolean()
  showCountry?: boolean;

  @IsOptional()
  @IsBoolean()
  showCounty?: boolean;

  @IsOptional()
  @IsBoolean()
  showCity?: boolean;

  @IsOptional()
  @IsBoolean()
  showYearsExperience?: boolean;

  @IsOptional()
  @IsBoolean()
  showEducationLevel?: boolean;

  @IsOptional()
  @IsBoolean()
  showEducationInstitution?: boolean;

  @IsOptional()
  @IsBoolean()
  showSpecialization?: boolean;

  @IsOptional()
  @IsBoolean()
  showCompanyName?: boolean;

  @IsOptional()
  @IsBoolean()
  showCompanyCounty?: boolean;

  @IsOptional()
  @IsBoolean()
  showCompanyCity?: boolean;

  @IsOptional()
  @IsBoolean()
  showHrFirstName?: boolean;

  @IsOptional()
  @IsBoolean()
  showHrLastName?: boolean;

  @IsOptional()
  @IsBoolean()
  showHrEmail?: boolean;

  @IsOptional()
  @IsBoolean()
  showCv?: boolean;

  @IsOptional()
  @IsBoolean()
  showProfileSummary?: boolean;

  @IsOptional()
  @IsBoolean()
  showProfessionalStatus?: boolean;

  @IsOptional()
  @IsBoolean()
  showLinkedIn?: boolean;

  @IsOptional()
  @IsBoolean()
  showGithub?: boolean;

  @IsOptional()
  @IsBoolean()
  showYoutube?: boolean;

  @IsOptional()
  @IsBoolean()
  showInstagram?: boolean;

  @IsOptional()
  @IsBoolean()
  showTiktok?: boolean;
}

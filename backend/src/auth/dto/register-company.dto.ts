import { IsDateString, IsEmail, IsIn, IsNotEmpty, IsOptional, IsString, Length } from 'class-validator';

export class RegisterCompanyDto {
  @IsEmail()
  email!: string;

  @IsString()
  @Length(8, 128)
  password!: string;

  @IsString()
  @IsNotEmpty()
  companyName!: string;

  @IsOptional()
  @IsString()
  countryCode?: string;

  @IsOptional()
  @IsString()
  county?: string;

  @IsOptional()
  @IsString()
  city?: string;

  @IsString()
  @IsNotEmpty()
  hrFirstName!: string;

  @IsString()
  @IsNotEmpty()
  hrLastName!: string;

  @IsEmail()
  hrEmail!: string;

  @IsIn(['male', 'female'])
  gender!: 'male' | 'female';

  @IsDateString()
  birthDate!: string;

  @IsString()
  @IsNotEmpty()
  gdprVersion!: string;

  @IsString()
  @IsNotEmpty()
  locale!: string;

  @IsOptional()
  @IsString()
  ipAddress?: string;

  @IsOptional()
  @IsString()
  userAgent?: string;
}
import { IsDateString, IsEmail, IsIn, IsNotEmpty, IsOptional, IsString, Length } from 'class-validator';
import { invalidEmailFormatMessage } from './email-validation-message';

export class RegisterCompanyDto {
  @IsEmail({}, { message: invalidEmailFormatMessage })
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

  @IsEmail({}, { message: invalidEmailFormatMessage })
  hrEmail!: string;

  @IsIn(['male', 'female'])
  gender!: 'male' | 'female';

  @IsOptional()
  @IsDateString()
  birthDate?: string;

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
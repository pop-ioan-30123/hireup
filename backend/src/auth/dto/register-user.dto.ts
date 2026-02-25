import { IsDateString, IsEmail, IsIn, IsInt, IsNotEmpty, IsOptional, IsString, Length, Max, Min } from 'class-validator';

export class RegisterUserDto {
  @IsEmail()
  email!: string;

  @IsString()
  @Length(8, 128)
  password!: string;

  @IsString()
  @IsNotEmpty()
  firstName!: string;

  @IsString()
  @IsNotEmpty()
  lastName!: string;

  @IsIn(['male', 'female'])
  gender!: 'male' | 'female';

  @IsDateString()
  birthDate!: string;

  @IsString()
  @IsNotEmpty()
  phone!: string;

  @IsString()
  @IsNotEmpty()
  country!: string;

  @IsString()
  @IsNotEmpty()
  county!: string;

  @IsString()
  @IsNotEmpty()
  city!: string;

  @IsString()
  @IsNotEmpty()
  jobTitle!: string;

  @IsInt()
  @Min(0)
  @Max(80)
  yearsExperience!: number;

  @IsString()
  @IsNotEmpty()
  educationLevel!: string;

  @IsString()
  @IsNotEmpty()
  educationInstitution!: string;

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
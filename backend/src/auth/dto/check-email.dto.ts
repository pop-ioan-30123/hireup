import { IsEmail, IsOptional, IsString } from 'class-validator';
import { invalidEmailFormatMessage } from './email-validation-message';

export class CheckEmailDto {
  @IsEmail({}, { message: invalidEmailFormatMessage })
  email!: string;

  @IsOptional()
  @IsString()
  locale?: string;
}

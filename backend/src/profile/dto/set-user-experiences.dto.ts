import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';

export class UserExperienceDto {
  @IsString()
  companyName!: string;

  @IsString()
  jobTitle!: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsInt()
  @Min(1)
  @Max(12)
  startMonth!: number;

  @IsInt()
  @Min(1950)
  @Max(2100)
  startYear!: number;

  @IsBoolean()
  isCurrent!: boolean;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(12)
  endMonth?: number;

  @IsOptional()
  @IsInt()
  @Min(1950)
  @Max(2100)
  endYear?: number;

  @IsOptional()
  @IsBoolean()
  showOnProfile?: boolean;
}

export class SetUserExperiencesDto {
  @IsArray()
  @ArrayMaxSize(5)
  @ValidateNested({ each: true })
  @Type(() => UserExperienceDto)
  experiences!: UserExperienceDto[];
}

import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsISO8601,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';

export class CreateActivityDto {
  @IsString()
  title!: string;

  @IsString()
  description!: string;

  @IsNumber()
  @Min(0.01)
  amountRon!: number;

  @IsInt()
  @Min(1)
  @Max(24)
  durationHours!: number;

  @IsString()
  country!: string;

  @IsString()
  county!: string;

  @IsString()
  city!: string;

  @IsISO8601()
  startAt!: string;

  @IsBoolean()
  isRecurring!: boolean;

  @IsOptional()
  @IsIn(['daily', 'weekly', 'biWeekly', 'monthly', 'byDays'])
  recurrencePattern?: 'daily' | 'weekly' | 'biWeekly' | 'monthly' | 'byDays';

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(7)
  @IsInt({ each: true })
  @Min(1, { each: true })
  @Max(7, { each: true })
  recurrenceDays?: number[];

  @IsOptional()
  @IsString()
  recurrenceLabel?: string;

  @IsOptional()
  @IsBoolean()
  mealIncluded?: boolean;
}

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

export class UpdateActivityDto {
	@IsOptional()
	@IsIn(['services'])
	section?: 'services';

	@IsOptional()
	@IsString()
	categoryKey?: string;

	@IsOptional()
	@IsString()
	subcategoryKey?: string;

	@IsOptional()
	@IsString()
	title?: string;

	@IsOptional()
	@IsString()
	description?: string;

	@IsOptional()
	@IsNumber()
	@Min(0.01)
	amountRon?: number;

	@IsOptional()
	@IsInt()
	@Min(1)
	@Max(24)
	durationHours?: number;

	@IsOptional()
	@IsString()
	country?: string;

	@IsOptional()
	@IsString()
	county?: string;

	@IsOptional()
	@IsString()
	city?: string;

	@IsOptional()
	@IsISO8601()
	startAt?: string;

	@IsOptional()
	@IsBoolean()
	isRecurring?: boolean;

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

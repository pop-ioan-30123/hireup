import { IsIn, IsOptional, IsString } from 'class-validator';

export class ListMarketplaceQueryDto {
  @IsOptional()
  @IsIn(['services'])
  section?: 'services';

  @IsOptional()
  @IsString()
  county?: string;

  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsString()
  categoryKey?: string;

  @IsOptional()
  @IsIn(['all', 'recurring', 'oneTime'])
  filter?: 'all' | 'recurring' | 'oneTime';

  @IsOptional()
  @IsIn(['postedAsc', 'postedDesc', 'dueAsc', 'dueDesc'])
  sort?: 'postedAsc' | 'postedDesc' | 'dueAsc' | 'dueDesc';
}

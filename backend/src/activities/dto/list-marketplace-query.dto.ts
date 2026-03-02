import { IsIn, IsOptional } from 'class-validator';

export class ListMarketplaceQueryDto {
  @IsOptional()
  @IsIn(['all', 'recurring', 'oneTime'])
  filter?: 'all' | 'recurring' | 'oneTime';

  @IsOptional()
  @IsIn(['postedAsc', 'postedDesc', 'dueAsc', 'dueDesc'])
  sort?: 'postedAsc' | 'postedDesc' | 'dueAsc' | 'dueDesc';
}

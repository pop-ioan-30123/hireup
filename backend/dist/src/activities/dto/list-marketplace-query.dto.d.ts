export declare class ListMarketplaceQueryDto {
    section?: 'services';
    county?: string;
    city?: string;
    categoryKey?: string;
    filter?: 'all' | 'recurring' | 'oneTime';
    sort?: 'postedAsc' | 'postedDesc' | 'dueAsc' | 'dueDesc';
}

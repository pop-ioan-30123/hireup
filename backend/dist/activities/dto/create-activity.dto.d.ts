export declare class CreateActivityDto {
    title: string;
    description: string;
    amountRon: number;
    durationHours: number;
    country: string;
    county: string;
    city: string;
    startAt: string;
    isRecurring: boolean;
    recurrencePattern?: 'daily' | 'weekly' | 'biWeekly' | 'monthly' | 'byDays';
    recurrenceDays?: number[];
    recurrenceLabel?: string;
    mealIncluded?: boolean;
}

import { AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { ActivitiesService } from './activities.service';
import { CreateActivityDto } from './dto/create-activity.dto';
import { UpdateActivityDto } from './dto/update-activity.dto';
import { ListMarketplaceQueryDto } from './dto/list-marketplace-query.dto';
export declare class ActivitiesController {
    private readonly activitiesService;
    constructor(activitiesService: ActivitiesService);
    listMarketplace(req: AuthenticatedRequest, query: ListMarketplaceQueryDto): Promise<{
        items: Record<string, unknown>[];
    }>;
    listMine(req: AuthenticatedRequest): Promise<{
        items: Record<string, unknown>[];
    }>;
    listUpcoming(req: AuthenticatedRequest): Promise<{
        items: Record<string, unknown>[];
    }>;
    listNotifications(req: AuthenticatedRequest): Promise<{
        items: {
            id: string;
            title: string;
            description: string;
            category: string;
            type: string;
            iconKey: string;
            sentDate: string;
            sentTime: string;
            sentAt: string;
            activityId: string | null;
        }[];
    }>;
    create(req: AuthenticatedRequest, payload: CreateActivityDto): Promise<{
        item: {
            id: string;
            title: string;
            description: string;
            amountRon: number;
            durationHours: number;
            country: string;
            county: string;
            city: string;
            startAt: string;
            dueAt: string;
            isRecurring: boolean;
            recurrencePattern: string | null;
            recurrenceDays: number[];
            recurrenceLabel: string | null;
            mealIncluded: boolean;
            status: "open" | "assigned" | "closed" | "cancelled";
            closeReason: string | null;
            isPostedByCurrentUser: boolean;
            owner: {
                id: string;
                fullName: string;
                rating: number;
                reviewCount: number;
            };
            provider: {
                id: string;
                fullName: string;
                rating: number;
                reviewCount: number;
            } | null;
            createdAt: string;
            updatedAt: string;
            isUpcomingForCurrentUser: boolean;
            isWarningWindowNoProvider: boolean;
            isClosedNoProvider: boolean;
            canEdit: boolean;
        };
    }>;
    update(req: AuthenticatedRequest, activityId: string, payload: UpdateActivityDto): Promise<{
        item: {
            id: string;
            title: string;
            description: string;
            amountRon: number;
            durationHours: number;
            country: string;
            county: string;
            city: string;
            startAt: string;
            dueAt: string;
            isRecurring: boolean;
            recurrencePattern: string | null;
            recurrenceDays: number[];
            recurrenceLabel: string | null;
            mealIncluded: boolean;
            status: "open" | "assigned" | "closed" | "cancelled";
            closeReason: string | null;
            isPostedByCurrentUser: boolean;
            owner: {
                id: string;
                fullName: string;
                rating: number;
                reviewCount: number;
            };
            provider: {
                id: string;
                fullName: string;
                rating: number;
                reviewCount: number;
            } | null;
            createdAt: string;
            updatedAt: string;
            isUpcomingForCurrentUser: boolean;
            isWarningWindowNoProvider: boolean;
            isClosedNoProvider: boolean;
            canEdit: boolean;
        };
    }>;
    remove(req: AuthenticatedRequest, activityId: string): Promise<{
        deleted: boolean;
    }>;
    accept(req: AuthenticatedRequest, activityId: string): Promise<{
        item: {
            id: string;
            title: string;
            description: string;
            amountRon: number;
            durationHours: number;
            country: string;
            county: string;
            city: string;
            startAt: string;
            dueAt: string;
            isRecurring: boolean;
            recurrencePattern: string | null;
            recurrenceDays: number[];
            recurrenceLabel: string | null;
            mealIncluded: boolean;
            status: "open" | "assigned" | "closed" | "cancelled";
            closeReason: string | null;
            isPostedByCurrentUser: boolean;
            owner: {
                id: string;
                fullName: string;
                rating: number;
                reviewCount: number;
            };
            provider: {
                id: string;
                fullName: string;
                rating: number;
                reviewCount: number;
            } | null;
            createdAt: string;
            updatedAt: string;
            isUpcomingForCurrentUser: boolean;
            isWarningWindowNoProvider: boolean;
            isClosedNoProvider: boolean;
            canEdit: boolean;
        };
    }>;
    removeProvider(req: AuthenticatedRequest, activityId: string): Promise<{
        item: {
            id: string;
            title: string;
            description: string;
            amountRon: number;
            durationHours: number;
            country: string;
            county: string;
            city: string;
            startAt: string;
            dueAt: string;
            isRecurring: boolean;
            recurrencePattern: string | null;
            recurrenceDays: number[];
            recurrenceLabel: string | null;
            mealIncluded: boolean;
            status: "open" | "assigned" | "closed" | "cancelled";
            closeReason: string | null;
            isPostedByCurrentUser: boolean;
            owner: {
                id: string;
                fullName: string;
                rating: number;
                reviewCount: number;
            };
            provider: {
                id: string;
                fullName: string;
                rating: number;
                reviewCount: number;
            } | null;
            createdAt: string;
            updatedAt: string;
            isUpcomingForCurrentUser: boolean;
            isWarningWindowNoProvider: boolean;
            isClosedNoProvider: boolean;
            canEdit: boolean;
        };
    }>;
}

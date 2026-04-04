import { DatabaseService } from '../database/database.service';
import { AuditSqlContext } from '../database/audit-sql-context';
import { CreateActivityDto } from './dto/create-activity.dto';
import { UpdateActivityDto } from './dto/update-activity.dto';
import { ListMarketplaceQueryDto } from './dto/list-marketplace-query.dto';
export declare class ActivitiesService {
    private readonly db;
    constructor(db: DatabaseService);
    private isMissingRelationError;
    private normalizeText;
    private fullName;
    private recurrenceLabel;
    private validatePayload;
    private processAutoCloseRules;
    private buildSortSql;
    private mapActivityRow;
    private listWithSql;
    private baseSelectSql;
    listMarketplace(userId: string, query: ListMarketplaceQueryDto, auditContext?: AuditSqlContext): Promise<{
        items: Record<string, unknown>[];
    }>;
    listMine(userId: string, auditContext?: AuditSqlContext): Promise<{
        items: Record<string, unknown>[];
    }>;
    listUpcoming(userId: string, auditContext?: AuditSqlContext): Promise<{
        items: Record<string, unknown>[];
    }>;
    listNotifications(userId: string, auditContext?: AuditSqlContext): Promise<{
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
            isRead: boolean;
            readAt: string | null;
            activityId: string | null;
        }[];
    }>;
    markNotificationsRead(userId: string, auditContext?: AuditSqlContext): Promise<{
        ok: boolean;
    }>;
    create(userId: string, payload: CreateActivityDto, auditContext?: AuditSqlContext): Promise<{
        item: {
            id: string;
            title: string;
            description: string;
            amountRon: number;
            durationHours: number;
            country: string;
            county: string;
            city: string;
            section: string;
            categoryKey: string;
            subcategoryKey: string | null;
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
    private getByIdForUser;
    update(userId: string, activityId: string, payload: UpdateActivityDto, auditContext?: AuditSqlContext): Promise<{
        item: {
            id: string;
            title: string;
            description: string;
            amountRon: number;
            durationHours: number;
            country: string;
            county: string;
            city: string;
            section: string;
            categoryKey: string;
            subcategoryKey: string | null;
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
    remove(userId: string, activityId: string, auditContext?: AuditSqlContext): Promise<{
        deleted: boolean;
    }>;
    private ensureNoOverlapForProvider;
    accept(userId: string, activityId: string, auditContext?: AuditSqlContext): Promise<{
        item: {
            id: string;
            title: string;
            description: string;
            amountRon: number;
            durationHours: number;
            country: string;
            county: string;
            city: string;
            section: string;
            categoryKey: string;
            subcategoryKey: string | null;
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
    removeProvider(userId: string, activityId: string, auditContext?: AuditSqlContext): Promise<{
        item: {
            id: string;
            title: string;
            description: string;
            amountRon: number;
            durationHours: number;
            country: string;
            county: string;
            city: string;
            section: string;
            categoryKey: string;
            subcategoryKey: string | null;
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

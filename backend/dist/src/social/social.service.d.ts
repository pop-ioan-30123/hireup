import { DatabaseService } from '../database/database.service';
import { UpdatePrivacySettingsDto } from './dto/update-privacy-settings.dto';
export declare class SocialService {
    private readonly db;
    constructor(db: DatabaseService);
    followUser(currentUserId: string, targetUserId: string): Promise<{
        ok: boolean;
        becameContact: boolean;
    }>;
    unfollowUser(currentUserId: string, targetUserId: string): Promise<{
        ok: boolean;
    }>;
    listFollowers(userId: string, viewerUserId?: string): Promise<{
        items: {
            userId: string;
            fullName: string;
            email: string;
            since: string;
        }[];
        total: number;
        isVisible: boolean;
    }>;
    listFollowing(userId: string): Promise<{
        items: {
            userId: string;
            fullName: string;
            email: string;
            since: string;
        }[];
        total: number;
    }>;
    sendContactRequest(currentUserId: string, targetUserId: string): Promise<{
        ok: boolean;
        becameContact: boolean;
    }>;
    acceptContactRequest(currentUserId: string, requesterUserId: string): Promise<{
        ok: boolean;
        becameContact: boolean;
    }>;
    rejectContactRequest(currentUserId: string, requesterUserId: string): Promise<{
        ok: boolean;
    }>;
    removeContact(currentUserId: string, targetUserId: string): Promise<{
        ok: boolean;
    }>;
    listContacts(userId: string, viewerUserId?: string): Promise<{
        items: {
            userId: string;
            fullName: string;
            email: string;
            since: string;
        }[];
        total: number;
        isVisible: boolean;
    }>;
    listPendingContactRequests(userId: string): Promise<{
        items: never[];
        total: number;
        isVisible: boolean;
    }>;
    getSocialSummary(currentUserId: string, targetUserId: string): Promise<{
        isFollowing: boolean;
        isFollower: boolean;
        contactStatus: string;
        followerCount: number;
        contactCount: number;
        showFollowerList: boolean;
        showContactList: boolean;
    }>;
    getPrivacySettings(userId: string): Promise<{
        messagesPrivacy: string;
        showFollowerList: boolean;
        showContactList: boolean;
    }>;
    updatePrivacySettings(userId: string, dto: UpdatePrivacySettingsDto): Promise<{
        messagesPrivacy: string;
        showFollowerList: boolean;
        showContactList: boolean;
    }>;
    listSocialNotifications(userId: string): Promise<{
        items: {
            id: string;
            type: "follow" | "unfollow" | "contact";
            imageKey: string;
            sentAt: string;
            isRead: boolean;
            actorUserId: string;
            actorFullName: string;
        }[];
    }>;
    markNotificationsRead(userId: string): Promise<{
        ok: boolean;
    }>;
    canSendDirectMessage(senderUserId: string, targetUserId: string): Promise<'active' | 'request'>;
    private assertUserExists;
    private canViewFollowerList;
    private canViewContactList;
    private areMutualFollowers;
    private syncAcceptedContactRows;
    private removeContactRows;
    private insertSocialNotification;
    private getPrivacyVisibility;
    private isMissingRelation;
    private isMissingColumn;
    private displayName;
}

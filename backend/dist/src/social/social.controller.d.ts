import { AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { UpdatePrivacySettingsDto } from './dto/update-privacy-settings.dto';
import { SocialService } from './social.service';
export declare class SocialController {
    private readonly socialService;
    constructor(socialService: SocialService);
    follow(req: AuthenticatedRequest, userId: string): Promise<{
        ok: boolean;
        becameContact: boolean;
    }>;
    unfollow(req: AuthenticatedRequest, userId: string): Promise<{
        ok: boolean;
    }>;
    listMyFollowers(req: AuthenticatedRequest): Promise<{
        items: {
            userId: string;
            fullName: string;
            email: string;
            since: string;
        }[];
        total: number;
        isVisible: boolean;
    }>;
    listMyFollowing(req: AuthenticatedRequest): Promise<{
        items: {
            userId: string;
            fullName: string;
            email: string;
            since: string;
        }[];
        total: number;
    }>;
    listUserFollowers(req: AuthenticatedRequest, userId: string): Promise<{
        items: {
            userId: string;
            fullName: string;
            email: string;
            since: string;
        }[];
        total: number;
        isVisible: boolean;
    }>;
    listUserFollowing(userId: string): Promise<{
        items: {
            userId: string;
            fullName: string;
            email: string;
            since: string;
        }[];
        total: number;
    }>;
    listUserContacts(req: AuthenticatedRequest, userId: string): Promise<{
        items: {
            userId: string;
            fullName: string;
            email: string;
            since: string;
        }[];
        total: number;
        isVisible: boolean;
    }>;
    sendContactRequest(req: AuthenticatedRequest, userId: string): Promise<{
        ok: boolean;
        becameContact: boolean;
    }>;
    acceptContactRequest(req: AuthenticatedRequest, userId: string): Promise<{
        ok: boolean;
        becameContact: boolean;
    }>;
    rejectContactRequest(req: AuthenticatedRequest, userId: string): Promise<{
        ok: boolean;
    }>;
    removeContact(req: AuthenticatedRequest, userId: string): Promise<{
        ok: boolean;
    }>;
    listContacts(req: AuthenticatedRequest): Promise<{
        items: {
            userId: string;
            fullName: string;
            email: string;
            since: string;
        }[];
        total: number;
        isVisible: boolean;
    }>;
    listNotifications(req: AuthenticatedRequest): Promise<{
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
    markNotificationsRead(req: AuthenticatedRequest): Promise<{
        ok: boolean;
    }>;
    listContactRequests(req: AuthenticatedRequest): Promise<{
        items: never[];
        total: number;
        isVisible: boolean;
    }>;
    getSocialSummary(req: AuthenticatedRequest, userId: string): Promise<{
        isFollowing: boolean;
        isFollower: boolean;
        contactStatus: string;
        followerCount: number;
        contactCount: number;
        showFollowerList: boolean;
        showContactList: boolean;
    }>;
    getPrivacy(req: AuthenticatedRequest): Promise<{
        messagesPrivacy: string;
        showFollowerList: boolean;
        showContactList: boolean;
    }>;
    updatePrivacy(req: AuthenticatedRequest, dto: UpdatePrivacySettingsDto): Promise<{
        messagesPrivacy: string;
        showFollowerList: boolean;
        showContactList: boolean;
    }>;
}

import { AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { CreateDmConversationDto } from './dto/create-dm-conversation.dto';
import { CreateGroupConversationDto } from './dto/create-group-conversation.dto';
import { ListMessagesQueryDto } from './dto/list-messages-query.dto';
import { PostMessageDto } from './dto/post-message.dto';
import { SetMessageReactionDto } from './dto/set-message-reaction.dto';
import { UpdateMessageDto } from './dto/update-message.dto';
import { MessagesService } from './messages.service';
export declare class MessagesController {
    private readonly messagesService;
    constructor(messagesService: MessagesService);
    listConversations(req: AuthenticatedRequest): Promise<{
        items: {
            id: string;
            type: "dm" | "group";
            title: string | null;
            createdByUserId: string;
            role: "owner" | "admin" | "member";
            unreadCount: number;
            requestStatus: "active" | "request";
            createdAt: string;
            updatedAt: string;
            lastMessageAt: string | null;
            lastMessagePreview: string | null;
            lastMessageSenderUserId: string | null;
            participants: Record<string, unknown>[];
        }[];
    }>;
    createDirectConversation(req: AuthenticatedRequest, payload: CreateDmConversationDto): Promise<{
        id: string;
        type: "dm" | "group";
        title: string | null;
        createdByUserId: string;
        role: "owner" | "admin" | "member";
        unreadCount: number;
        requestStatus: "active" | "request";
        createdAt: string;
        updatedAt: string;
        lastMessageAt: string | null;
        lastMessagePreview: string | null;
        lastMessageSenderUserId: string | null;
        participants: Record<string, unknown>[];
    }>;
    createGroupConversation(req: AuthenticatedRequest, payload: CreateGroupConversationDto): Promise<{
        id: string;
        type: "dm" | "group";
        title: string | null;
        createdByUserId: string;
        role: "owner" | "admin" | "member";
        unreadCount: number;
        requestStatus: "active" | "request";
        createdAt: string;
        updatedAt: string;
        lastMessageAt: string | null;
        lastMessagePreview: string | null;
        lastMessageSenderUserId: string | null;
        participants: Record<string, unknown>[];
    }>;
    listMessages(req: AuthenticatedRequest, conversationId: string, query: ListMessagesQueryDto): Promise<{
        items: {
            id: string;
            conversationId: string;
            senderUserId: string;
            messageKind: "text" | "system";
            ciphertext: string;
            algorithm: string;
            nonce: string | null;
            metadata: object;
            createdAt: string;
            deliveredAt: string | null;
            readAt: string | null;
            editedAt: string | null;
            deletedAt: string | null;
        }[];
        nextBefore: string;
        hasMore: boolean;
    }>;
    postMessage(req: AuthenticatedRequest, conversationId: string, payload: PostMessageDto): Promise<{
        id: string;
        conversationId: string;
        senderUserId: string;
        messageKind: "text" | "system";
        ciphertext: string;
        algorithm: string;
        nonce: string | null;
        metadata: object;
        createdAt: string;
        deliveredAt: string | null;
        readAt: string | null;
        editedAt: string | null;
        deletedAt: string | null;
    }>;
    updateMessage(req: AuthenticatedRequest, conversationId: string, messageId: string, payload: UpdateMessageDto): Promise<{
        id: string;
        conversationId: string;
        senderUserId: string;
        messageKind: "text" | "system";
        ciphertext: string;
        algorithm: string;
        nonce: string | null;
        metadata: object;
        createdAt: string;
        deliveredAt: string | null;
        readAt: string | null;
        editedAt: string | null;
        deletedAt: string | null;
    }>;
    setMessageReaction(req: AuthenticatedRequest, conversationId: string, messageId: string, payload: SetMessageReactionDto): Promise<{
        id: string;
        conversationId: string;
        senderUserId: string;
        messageKind: "text" | "system";
        ciphertext: string;
        algorithm: string;
        nonce: string | null;
        metadata: object;
        createdAt: string;
        deliveredAt: string | null;
        readAt: string | null;
        editedAt: string | null;
        deletedAt: string | null;
    }>;
    deleteMessage(req: AuthenticatedRequest, conversationId: string, messageId: string, scope?: string): Promise<{
        ok: boolean;
        scope: string;
    }>;
    markConversationRead(req: AuthenticatedRequest, conversationId: string): Promise<{
        ok: boolean;
    }>;
}

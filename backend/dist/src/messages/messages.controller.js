"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MessagesController = void 0;
const common_1 = require("@nestjs/common");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const create_dm_conversation_dto_1 = require("./dto/create-dm-conversation.dto");
const create_group_conversation_dto_1 = require("./dto/create-group-conversation.dto");
const list_messages_query_dto_1 = require("./dto/list-messages-query.dto");
const post_message_dto_1 = require("./dto/post-message.dto");
const set_message_reaction_dto_1 = require("./dto/set-message-reaction.dto");
const update_message_dto_1 = require("./dto/update-message.dto");
const messages_service_1 = require("./messages.service");
let MessagesController = class MessagesController {
    constructor(messagesService) {
        this.messagesService = messagesService;
    }
    async listConversations(req) {
        return this.messagesService.listConversations(req.user.id, req.auditContext);
    }
    async createDirectConversation(req, payload) {
        return this.messagesService.createDirectConversation(req.user.id, payload, req.auditContext);
    }
    async createGroupConversation(req, payload) {
        return this.messagesService.createGroupConversation(req.user.id, payload, req.auditContext);
    }
    async listMessages(req, conversationId, query) {
        return this.messagesService.listMessages(req.user.id, conversationId, query, req.auditContext);
    }
    async postMessage(req, conversationId, payload) {
        return this.messagesService.postMessage(req.user.id, conversationId, payload, req.auditContext);
    }
    async updateMessage(req, conversationId, messageId, payload) {
        return this.messagesService.updateMessage(req.user.id, conversationId, messageId, payload, req.auditContext);
    }
    async setMessageReaction(req, conversationId, messageId, payload) {
        return this.messagesService.setMessageReaction(req.user.id, conversationId, messageId, payload, req.auditContext);
    }
    async deleteMessage(req, conversationId, messageId, scope) {
        return this.messagesService.deleteMessage(req.user.id, conversationId, messageId, scope, req.auditContext);
    }
    async markConversationRead(req, conversationId) {
        return this.messagesService.markConversationRead(req.user.id, conversationId, req.auditContext);
    }
};
exports.MessagesController = MessagesController;
__decorate([
    (0, common_1.Get)('conversations'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], MessagesController.prototype, "listConversations", null);
__decorate([
    (0, common_1.Post)('conversations/dm'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, create_dm_conversation_dto_1.CreateDmConversationDto]),
    __metadata("design:returntype", Promise)
], MessagesController.prototype, "createDirectConversation", null);
__decorate([
    (0, common_1.Post)('conversations/group'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, create_group_conversation_dto_1.CreateGroupConversationDto]),
    __metadata("design:returntype", Promise)
], MessagesController.prototype, "createGroupConversation", null);
__decorate([
    (0, common_1.Get)('conversations/:conversationId/messages'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('conversationId', new common_1.ParseUUIDPipe())),
    __param(2, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, list_messages_query_dto_1.ListMessagesQueryDto]),
    __metadata("design:returntype", Promise)
], MessagesController.prototype, "listMessages", null);
__decorate([
    (0, common_1.Post)('conversations/:conversationId/messages'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('conversationId', new common_1.ParseUUIDPipe())),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, post_message_dto_1.PostMessageDto]),
    __metadata("design:returntype", Promise)
], MessagesController.prototype, "postMessage", null);
__decorate([
    (0, common_1.Patch)('conversations/:conversationId/messages/:messageId'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('conversationId', new common_1.ParseUUIDPipe())),
    __param(2, (0, common_1.Param)('messageId', new common_1.ParseUUIDPipe())),
    __param(3, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, String, update_message_dto_1.UpdateMessageDto]),
    __metadata("design:returntype", Promise)
], MessagesController.prototype, "updateMessage", null);
__decorate([
    (0, common_1.Post)('conversations/:conversationId/messages/:messageId/reaction'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('conversationId', new common_1.ParseUUIDPipe())),
    __param(2, (0, common_1.Param)('messageId', new common_1.ParseUUIDPipe())),
    __param(3, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, String, set_message_reaction_dto_1.SetMessageReactionDto]),
    __metadata("design:returntype", Promise)
], MessagesController.prototype, "setMessageReaction", null);
__decorate([
    (0, common_1.Delete)('conversations/:conversationId/messages/:messageId'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('conversationId', new common_1.ParseUUIDPipe())),
    __param(2, (0, common_1.Param)('messageId', new common_1.ParseUUIDPipe())),
    __param(3, (0, common_1.Query)('scope')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, String, String]),
    __metadata("design:returntype", Promise)
], MessagesController.prototype, "deleteMessage", null);
__decorate([
    (0, common_1.Post)('conversations/:conversationId/read'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('conversationId', new common_1.ParseUUIDPipe())),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], MessagesController.prototype, "markConversationRead", null);
exports.MessagesController = MessagesController = __decorate([
    (0, common_1.Controller)('messages'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    __metadata("design:paramtypes", [messages_service_1.MessagesService])
], MessagesController);
//# sourceMappingURL=messages.controller.js.map
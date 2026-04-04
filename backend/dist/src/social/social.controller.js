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
exports.SocialController = void 0;
const common_1 = require("@nestjs/common");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const update_privacy_settings_dto_1 = require("./dto/update-privacy-settings.dto");
const social_service_1 = require("./social.service");
let SocialController = class SocialController {
    constructor(socialService) {
        this.socialService = socialService;
    }
    follow(req, userId) {
        return this.socialService.followUser(req.user.id, userId);
    }
    unfollow(req, userId) {
        return this.socialService.unfollowUser(req.user.id, userId);
    }
    listMyFollowers(req) {
        return this.socialService.listFollowers(req.user.id);
    }
    listMyFollowing(req) {
        return this.socialService.listFollowing(req.user.id);
    }
    listUserFollowers(req, userId) {
        return this.socialService.listFollowers(userId, req.user.id);
    }
    listUserFollowing(userId) {
        return this.socialService.listFollowing(userId);
    }
    listUserContacts(req, userId) {
        return this.socialService.listContacts(userId, req.user.id);
    }
    sendContactRequest(req, userId) {
        return this.socialService.sendContactRequest(req.user.id, userId);
    }
    acceptContactRequest(req, userId) {
        return this.socialService.acceptContactRequest(req.user.id, userId);
    }
    rejectContactRequest(req, userId) {
        return this.socialService.rejectContactRequest(req.user.id, userId);
    }
    removeContact(req, userId) {
        return this.socialService.removeContact(req.user.id, userId);
    }
    listContacts(req) {
        return this.socialService.listContacts(req.user.id);
    }
    listNotifications(req) {
        return this.socialService.listSocialNotifications(req.user.id);
    }
    markNotificationsRead(req) {
        return this.socialService.markNotificationsRead(req.user.id);
    }
    listContactRequests(req) {
        return this.socialService.listPendingContactRequests(req.user.id);
    }
    getSocialSummary(req, userId) {
        return this.socialService.getSocialSummary(req.user.id, userId);
    }
    getPrivacy(req) {
        return this.socialService.getPrivacySettings(req.user.id);
    }
    updatePrivacy(req, dto) {
        return this.socialService.updatePrivacySettings(req.user.id, dto);
    }
};
exports.SocialController = SocialController;
__decorate([
    (0, common_1.Post)('follow/:userId'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "follow", null);
__decorate([
    (0, common_1.Delete)('follow/:userId'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "unfollow", null);
__decorate([
    (0, common_1.Get)('followers'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "listMyFollowers", null);
__decorate([
    (0, common_1.Get)('following'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "listMyFollowing", null);
__decorate([
    (0, common_1.Get)('users/:userId/followers'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "listUserFollowers", null);
__decorate([
    (0, common_1.Get)('users/:userId/following'),
    __param(0, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "listUserFollowing", null);
__decorate([
    (0, common_1.Get)('users/:userId/contacts'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "listUserContacts", null);
__decorate([
    (0, common_1.Post)('contacts/request/:userId'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "sendContactRequest", null);
__decorate([
    (0, common_1.Post)('contacts/accept/:userId'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "acceptContactRequest", null);
__decorate([
    (0, common_1.Post)('contacts/reject/:userId'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "rejectContactRequest", null);
__decorate([
    (0, common_1.Delete)('contacts/:userId'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "removeContact", null);
__decorate([
    (0, common_1.Get)('contacts'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "listContacts", null);
__decorate([
    (0, common_1.Get)('notifications'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "listNotifications", null);
__decorate([
    (0, common_1.Post)('notifications/read'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "markNotificationsRead", null);
__decorate([
    (0, common_1.Get)('contacts/requests'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "listContactRequests", null);
__decorate([
    (0, common_1.Get)('users/:userId/summary'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "getSocialSummary", null);
__decorate([
    (0, common_1.Get)('privacy'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "getPrivacy", null);
__decorate([
    (0, common_1.Patch)('privacy'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, update_privacy_settings_dto_1.UpdatePrivacySettingsDto]),
    __metadata("design:returntype", void 0)
], SocialController.prototype, "updatePrivacy", null);
exports.SocialController = SocialController = __decorate([
    (0, common_1.Controller)('social'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    __metadata("design:paramtypes", [social_service_1.SocialService])
], SocialController);
//# sourceMappingURL=social.controller.js.map
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
exports.ProfileController = void 0;
const common_1 = require("@nestjs/common");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const update_company_profile_dto_1 = require("./dto/update-company-profile.dto");
const update_profile_visibility_dto_1 = require("./dto/update-profile-visibility.dto");
const update_theme_preference_dto_1 = require("./dto/update-theme-preference.dto");
const update_user_profile_dto_1 = require("./dto/update-user-profile.dto");
const profile_service_1 = require("./profile.service");
let ProfileController = class ProfileController {
    constructor(profileService) {
        this.profileService = profileService;
    }
    async getProfile(req) {
        return this.profileService.getProfile(req.user.id);
    }
    async updateUserProfile(req, payload) {
        return this.profileService.updateUserProfile(req.user.id, payload, req.auditContext);
    }
    async updateCompanyProfile(req, payload) {
        return this.profileService.updateCompanyProfile(req.user.id, payload, req.auditContext);
    }
    async updateVisibility(req, payload) {
        return this.profileService.updateVisibility(req.user.id, payload, req.auditContext);
    }
    async updateThemePreference(req, payload) {
        return this.profileService.updateThemePreference(req.user.id, payload, req.auditContext);
    }
    async getAvatar(req) {
        const avatar = await this.profileService.getAvatar(req.user.id);
        if (!avatar) {
            throw new common_1.NotFoundException('Avatar not found');
        }
        return new common_1.StreamableFile(avatar.buffer, {
            type: avatar.mimeType ?? 'application/octet-stream',
            length: avatar.size,
            disposition: 'inline',
        });
    }
};
exports.ProfileController = ProfileController;
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Get)('me'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], ProfileController.prototype, "getProfile", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Patch)('user'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, update_user_profile_dto_1.UpdateUserProfileDto]),
    __metadata("design:returntype", Promise)
], ProfileController.prototype, "updateUserProfile", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Patch)('company'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, update_company_profile_dto_1.UpdateCompanyProfileDto]),
    __metadata("design:returntype", Promise)
], ProfileController.prototype, "updateCompanyProfile", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Patch)('visibility'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, update_profile_visibility_dto_1.UpdateProfileVisibilityDto]),
    __metadata("design:returntype", Promise)
], ProfileController.prototype, "updateVisibility", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Patch)('theme'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, update_theme_preference_dto_1.UpdateThemePreferenceDto]),
    __metadata("design:returntype", Promise)
], ProfileController.prototype, "updateThemePreference", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Get)('avatar'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], ProfileController.prototype, "getAvatar", null);
exports.ProfileController = ProfileController = __decorate([
    (0, common_1.Controller)('profile'),
    __metadata("design:paramtypes", [profile_service_1.ProfileService])
], ProfileController);
//# sourceMappingURL=profile.controller.js.map
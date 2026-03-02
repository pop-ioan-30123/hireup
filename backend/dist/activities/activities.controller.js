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
exports.ActivitiesController = void 0;
const common_1 = require("@nestjs/common");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const activities_service_1 = require("./activities.service");
const create_activity_dto_1 = require("./dto/create-activity.dto");
const update_activity_dto_1 = require("./dto/update-activity.dto");
const list_marketplace_query_dto_1 = require("./dto/list-marketplace-query.dto");
let ActivitiesController = class ActivitiesController {
    constructor(activitiesService) {
        this.activitiesService = activitiesService;
    }
    async listMarketplace(req, query) {
        return this.activitiesService.listMarketplace(req.user.id, query, req.auditContext);
    }
    async listMine(req) {
        return this.activitiesService.listMine(req.user.id, req.auditContext);
    }
    async listUpcoming(req) {
        return this.activitiesService.listUpcoming(req.user.id, req.auditContext);
    }
    async listNotifications(req) {
        return this.activitiesService.listNotifications(req.user.id, req.auditContext);
    }
    async create(req, payload) {
        return this.activitiesService.create(req.user.id, payload, req.auditContext);
    }
    async update(req, activityId, payload) {
        return this.activitiesService.update(req.user.id, activityId, payload, req.auditContext);
    }
    async remove(req, activityId) {
        return this.activitiesService.remove(req.user.id, activityId, req.auditContext);
    }
    async accept(req, activityId) {
        return this.activitiesService.accept(req.user.id, activityId, req.auditContext);
    }
    async removeProvider(req, activityId) {
        return this.activitiesService.removeProvider(req.user.id, activityId, req.auditContext);
    }
};
exports.ActivitiesController = ActivitiesController;
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, list_marketplace_query_dto_1.ListMarketplaceQueryDto]),
    __metadata("design:returntype", Promise)
], ActivitiesController.prototype, "listMarketplace", null);
__decorate([
    (0, common_1.Get)('mine'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], ActivitiesController.prototype, "listMine", null);
__decorate([
    (0, common_1.Get)('upcoming'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], ActivitiesController.prototype, "listUpcoming", null);
__decorate([
    (0, common_1.Get)('notifications'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], ActivitiesController.prototype, "listNotifications", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, create_activity_dto_1.CreateActivityDto]),
    __metadata("design:returntype", Promise)
], ActivitiesController.prototype, "create", null);
__decorate([
    (0, common_1.Patch)(':activityId'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('activityId', new common_1.ParseUUIDPipe())),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, update_activity_dto_1.UpdateActivityDto]),
    __metadata("design:returntype", Promise)
], ActivitiesController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)(':activityId'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('activityId', new common_1.ParseUUIDPipe())),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], ActivitiesController.prototype, "remove", null);
__decorate([
    (0, common_1.Post)(':activityId/accept'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('activityId', new common_1.ParseUUIDPipe())),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], ActivitiesController.prototype, "accept", null);
__decorate([
    (0, common_1.Post)(':activityId/remove-provider'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Param)('activityId', new common_1.ParseUUIDPipe())),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], ActivitiesController.prototype, "removeProvider", null);
exports.ActivitiesController = ActivitiesController = __decorate([
    (0, common_1.Controller)('activities'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    __metadata("design:paramtypes", [activities_service_1.ActivitiesService])
], ActivitiesController);
//# sourceMappingURL=activities.controller.js.map
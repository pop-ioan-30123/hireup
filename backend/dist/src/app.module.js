"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const auth_module_1 = require("./auth/auth.module");
const database_module_1 = require("./database/database.module");
const health_controller_1 = require("./health.controller");
const audit_context_middleware_1 = require("./security/audit-context.middleware");
const uploads_module_1 = require("./uploads/uploads.module");
const profile_module_1 = require("./profile/profile.module");
const activities_module_1 = require("./activities/activities.module");
const audit_module_1 = require("./audit/audit.module");
const messages_module_1 = require("./messages/messages.module");
const social_module_1 = require("./social/social.module");
let AppModule = class AppModule {
    configure(consumer) {
        consumer.apply(audit_context_middleware_1.AuditContextMiddleware).forRoutes('*');
    }
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [config_1.ConfigModule.forRoot({ isGlobal: true }), database_module_1.DatabaseModule, auth_module_1.AuthModule, uploads_module_1.UploadsModule, profile_module_1.ProfileModule, activities_module_1.ActivitiesModule, audit_module_1.AuditModule, messages_module_1.MessagesModule, social_module_1.SocialModule],
        controllers: [health_controller_1.HealthController],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map
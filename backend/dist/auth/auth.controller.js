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
exports.AuthController = void 0;
const common_1 = require("@nestjs/common");
const auth_service_1 = require("./auth.service");
const check_email_dto_1 = require("./dto/check-email.dto");
const login_dto_1 = require("./dto/login.dto");
const register_company_dto_1 = require("./dto/register-company.dto");
const register_user_dto_1 = require("./dto/register-user.dto");
const two_factor_code_dto_1 = require("./dto/two-factor-code.dto");
const jwt_auth_guard_1 = require("./jwt-auth.guard");
let AuthController = class AuthController {
    constructor(authService) {
        this.authService = authService;
    }
    registerUser(payload, req) {
        return this.authService.registerUser(payload, req.auditContext);
    }
    registerCompany(payload, req) {
        return this.authService.registerCompany(payload, req.auditContext);
    }
    login(payload, req) {
        return this.authService.login(payload, req.auditContext);
    }
    checkEmail(payload) {
        return this.authService.checkEmailAvailability(payload.email);
    }
    setupTwoFactor(req) {
        return this.authService.setupTwoFactor(req.user.id, req.user.email, req.auditContext);
    }
    cancelTwoFactorSetup(req) {
        return this.authService.cancelTwoFactorSetup(req.user.id, req.auditContext);
    }
    enableTwoFactor(req, payload) {
        return this.authService.enableTwoFactor(req.user.id, payload.code, req.auditContext);
    }
    disableTwoFactor(req, payload) {
        return this.authService.disableTwoFactor(req.user.id, payload.code, req.auditContext);
    }
    regenerateBackupCodes(req, payload) {
        return this.authService.regenerateTwoFactorBackupCodes(req.user.id, payload.code, req.auditContext);
    }
    verifyEmail(token, req) {
        return this.authService.verifyEmailToken(token, req.auditContext);
    }
    resendVerificationEmail(req) {
        return this.authService.resendEmailVerification(req.user.id, req.auditContext);
    }
};
exports.AuthController = AuthController;
__decorate([
    (0, common_1.Post)('register-user'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [register_user_dto_1.RegisterUserDto, Object]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "registerUser", null);
__decorate([
    (0, common_1.Post)('register-company'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [register_company_dto_1.RegisterCompanyDto, Object]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "registerCompany", null);
__decorate([
    (0, common_1.Post)('login'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [login_dto_1.LoginDto, Object]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "login", null);
__decorate([
    (0, common_1.Post)('check-email'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [check_email_dto_1.CheckEmailDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "checkEmail", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Post)('2fa/setup'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "setupTwoFactor", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Post)('2fa/setup/cancel'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "cancelTwoFactorSetup", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Post)('2fa/enable'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, two_factor_code_dto_1.TwoFactorCodeDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "enableTwoFactor", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Post)('2fa/disable'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, two_factor_code_dto_1.TwoFactorCodeDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "disableTwoFactor", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Post)('2fa/backup-codes/regenerate'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, two_factor_code_dto_1.TwoFactorCodeDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "regenerateBackupCodes", null);
__decorate([
    (0, common_1.Get)('verify-email'),
    __param(0, (0, common_1.Query)('token')),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "verifyEmail", null);
__decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Post)('verification/resend'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "resendVerificationEmail", null);
exports.AuthController = AuthController = __decorate([
    (0, common_1.Controller)('auth'),
    __metadata("design:paramtypes", [auth_service_1.AuthService])
], AuthController);
//# sourceMappingURL=auth.controller.js.map
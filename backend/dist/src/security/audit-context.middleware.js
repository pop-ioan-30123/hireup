"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuditContextMiddleware = void 0;
const common_1 = require("@nestjs/common");
const uuid_1 = require("uuid");
let AuditContextMiddleware = class AuditContextMiddleware {
    use(req, res, next) {
        const requestId = req.header('x-request-id') ?? (0, uuid_1.v4)();
        const ipAddress = req.ip ?? null;
        const userAgent = req.header('user-agent') ?? null;
        req.auditContext = {
            requestId,
            ipAddress,
            userAgent,
        };
        res.setHeader('x-request-id', requestId);
        next();
    }
};
exports.AuditContextMiddleware = AuditContextMiddleware;
exports.AuditContextMiddleware = AuditContextMiddleware = __decorate([
    (0, common_1.Injectable)()
], AuditContextMiddleware);
//# sourceMappingURL=audit-context.middleware.js.map
"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.UploadsService = void 0;
const common_1 = require("@nestjs/common");
const crypto_1 = require("crypto");
const fs_1 = require("fs");
const path = __importStar(require("path"));
const database_service_1 = require("../database/database.service");
const audit_sql_context_1 = require("../database/audit-sql-context");
let UploadsService = class UploadsService {
    constructor(db) {
        this.db = db;
    }
    async handleUpload(params) {
        const { file, attachmentType, targetType, userId, userEmail, auditContext } = params;
        const normalizedAttachment = attachmentType.trim();
        const normalizedTarget = targetType.trim();
        if (!['id_document', 'cv', 'avatar'].includes(normalizedAttachment)) {
            throw new common_1.BadRequestException('Unsupported attachmentType');
        }
        if (!['user', 'company'].includes(normalizedTarget)) {
            throw new common_1.BadRequestException('Unsupported targetType');
        }
        this.validateMimeAndSize(normalizedAttachment, file);
        const storageRoot = path.resolve(__dirname, '../../uploads');
        const storageDir = path.join(storageRoot, normalizedTarget, normalizedAttachment);
        await fs_1.promises.mkdir(storageDir, { recursive: true });
        const fileExt = path.extname(file.originalname).toLowerCase();
        const storageFileName = `${Date.now()}_${(0, crypto_1.randomUUID)()}${fileExt}`;
        const storagePath = path.join(storageDir, storageFileName);
        await fs_1.promises.writeFile(storagePath, file.buffer);
        const checksum = (0, crypto_1.createHash)('sha256').update(file.buffer).digest('hex');
        const storageKey = path.relative(storageRoot, storagePath).replace(/\\/g, '/');
        return this.db.withTransaction(async (client) => {
            await (0, audit_sql_context_1.applyAuditSqlContext)(client, {
                ...auditContext,
                currentUserId: userId,
                currentUserEmail: userEmail,
            });
            let companyId = null;
            let effectiveUserId = null;
            if (normalizedTarget === 'company') {
                const companyRes = await client.query('SELECT id FROM company WHERE account_user_id = $1 LIMIT 1', [userId]);
                companyId = companyRes.rows[0]?.id ?? null;
                if (!companyId) {
                    throw new common_1.BadRequestException('Company not found for user');
                }
            }
            else {
                effectiveUserId = userId;
            }
            if (normalizedAttachment === 'avatar') {
                const existingAvatarRes = normalizedTarget === 'company'
                    ? await client.query(`
                SELECT storage_key
                FROM file_attachment
                WHERE company_id = $1 AND attachment_type = 'avatar'
              `, [companyId])
                    : await client.query(`
                SELECT storage_key
                FROM file_attachment
                WHERE user_id = $1 AND attachment_type = 'avatar'
              `, [effectiveUserId]);
                for (const existingAvatar of existingAvatarRes.rows) {
                    const oldPath = path.join(storageRoot, existingAvatar.storage_key);
                    await fs_1.promises.unlink(oldPath).catch(() => undefined);
                }
                if (normalizedTarget === 'company') {
                    await client.query(`
              DELETE FROM file_attachment
              WHERE company_id = $1 AND attachment_type = 'avatar'
            `, [companyId]);
                }
                else {
                    await client.query(`
              DELETE FROM file_attachment
              WHERE user_id = $1 AND attachment_type = 'avatar'
            `, [effectiveUserId]);
                }
            }
            const insertRes = await client.query(`
          INSERT INTO file_attachment (
            user_id,
            company_id,
            attachment_type,
            original_file_name,
            mime_type,
            file_size_bytes,
            storage_key,
            sha256_checksum,
            uploaded_by,
            encrypted_at_rest
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
          RETURNING id
        `, [
                effectiveUserId,
                companyId,
                normalizedAttachment,
                file.originalname,
                file.mimetype,
                file.size,
                storageKey,
                checksum,
                userId,
                false,
            ]);
            return {
                success: true,
                attachmentId: insertRes.rows[0].id,
                storageKey,
            };
        });
    }
    validateMimeAndSize(attachmentType, file) {
        if (attachmentType === 'id_document') {
            const allowed = ['image/jpeg', 'image/png', 'image/webp'];
            if (!allowed.includes(file.mimetype)) {
                throw new common_1.BadRequestException('ID document must be an image');
            }
            if (file.size > 5 * 1024 * 1024) {
                throw new common_1.BadRequestException('ID document too large');
            }
        }
        if (attachmentType === 'cv') {
            const allowed = [
                'application/pdf',
                'application/msword',
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            ];
            if (!allowed.includes(file.mimetype)) {
                throw new common_1.BadRequestException('CV must be PDF/DOC/DOCX');
            }
            if (file.size > 10 * 1024 * 1024) {
                throw new common_1.BadRequestException('CV too large');
            }
        }
        if (attachmentType === 'avatar') {
            const allowed = ['image/jpeg', 'image/png', 'image/webp'];
            if (!allowed.includes(file.mimetype)) {
                throw new common_1.BadRequestException('Avatar must be an image');
            }
            if (file.size > 5 * 1024 * 1024) {
                throw new common_1.BadRequestException('Avatar too large');
            }
        }
    }
};
exports.UploadsService = UploadsService;
exports.UploadsService = UploadsService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], UploadsService);
//# sourceMappingURL=uploads.service.js.map
import { BadRequestException, Injectable } from '@nestjs/common';
import { createHash, randomUUID } from 'crypto';
import { promises as fs } from 'fs';
import * as path from 'path';
import { DatabaseService } from '../database/database.service';
import { applyAuditSqlContext, AuditSqlContext } from '../database/audit-sql-context';

@Injectable()
export class UploadsService {
  constructor(private readonly db: DatabaseService) {}

  async handleUpload(params: {
    file: Express.Multer.File;
    attachmentType: string;
    targetType: string;
    userId: string;
    userEmail: string;
    auditContext?: AuditSqlContext;
  }) {
    const { file, attachmentType, targetType, userId, userEmail, auditContext } = params;

    const normalizedAttachment = attachmentType.trim();
    const normalizedTarget = targetType.trim();

    if (!['id_document', 'cv', 'avatar', 'post_media', 'post_file'].includes(normalizedAttachment)) {
      throw new BadRequestException('Unsupported attachmentType');
    }

    if (!['user', 'company'].includes(normalizedTarget)) {
      throw new BadRequestException('Unsupported targetType');
    }

    this.validateMimeAndSize(normalizedAttachment, file);

    const storageRoot = path.resolve(__dirname, '../../uploads');
    const storageDir = path.join(storageRoot, normalizedTarget, normalizedAttachment);
    await fs.mkdir(storageDir, { recursive: true });

    const fileExt = path.extname(file.originalname).toLowerCase();
    const storageFileName = `${Date.now()}_${randomUUID()}${fileExt}`;
    const storagePath = path.join(storageDir, storageFileName);

    await fs.writeFile(storagePath, file.buffer);

    const checksum = createHash('sha256').update(file.buffer).digest('hex');
    const storageKey = path.relative(storageRoot, storagePath).replace(/\\/g, '/');

    return this.db.withTransaction(async (client) => {
      await applyAuditSqlContext(client, {
        ...auditContext,
        currentUserId: userId,
        currentUserEmail: userEmail,
      });

      let companyId: string | null = null;
      let effectiveUserId: string | null = null;

      if (normalizedTarget === 'company') {
        const companyRes = await client.query<{ id: string }>(
          'SELECT id FROM company WHERE account_user_id = $1 LIMIT 1',
          [userId],
        );
        companyId = companyRes.rows[0]?.id ?? null;
        if (!companyId) {
          throw new BadRequestException('Company not found for user');
        }
      } else {
        effectiveUserId = userId;
      }

      if (normalizedAttachment === 'avatar') {
        const existingAvatarRes = normalizedTarget === 'company'
          ? await client.query<{ storage_key: string }>(
              `
                SELECT storage_key
                FROM file_attachment
                WHERE company_id = $1 AND attachment_type = 'avatar'
              `,
              [companyId],
            )
          : await client.query<{ storage_key: string }>(
              `
                SELECT storage_key
                FROM file_attachment
                WHERE user_id = $1 AND attachment_type = 'avatar'
              `,
              [effectiveUserId],
            );

        for (const existingAvatar of existingAvatarRes.rows) {
          const oldPath = path.join(storageRoot, existingAvatar.storage_key);
          await fs.unlink(oldPath).catch(() => undefined);
        }

        if (normalizedTarget === 'company') {
          await client.query(
            `
              DELETE FROM file_attachment
              WHERE company_id = $1 AND attachment_type = 'avatar'
            `,
            [companyId],
          );
        } else {
          await client.query(
            `
              DELETE FROM file_attachment
              WHERE user_id = $1 AND attachment_type = 'avatar'
            `,
            [effectiveUserId],
          );
        }
      }

      const insertRes = await client.query<{ id: string }>(
        `
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
        `,
        [
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
        ],
      );

      return {
        success: true,
        attachmentId: insertRes.rows[0].id,
        storageKey,
      };
    });
  }

  private validateMimeAndSize(attachmentType: string, file: Express.Multer.File) {
    if (attachmentType === 'id_document') {
      const allowed = ['image/jpeg', 'image/png', 'image/webp'];
      if (!allowed.includes(file.mimetype)) {
        throw new BadRequestException('ID document must be an image');
      }
      if (file.size > 5 * 1024 * 1024) {
        throw new BadRequestException('ID document too large');
      }
    }

    if (attachmentType === 'cv') {
      const allowed = [
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ];
      if (!allowed.includes(file.mimetype)) {
        throw new BadRequestException('CV must be PDF/DOC/DOCX');
      }
      if (file.size > 10 * 1024 * 1024) {
        throw new BadRequestException('CV too large');
      }
    }

    if (attachmentType === 'avatar') {
      const allowed = ['image/jpeg', 'image/png', 'image/webp'];
      if (!allowed.includes(file.mimetype)) {
        throw new BadRequestException('Avatar must be an image');
      }
      if (file.size > 5 * 1024 * 1024) {
        throw new BadRequestException('Avatar too large');
      }
    }

    if (attachmentType === 'post_media') {
      const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
      if (!allowed.includes(file.mimetype)) {
        throw new BadRequestException('Post media must be an image');
      }
      if (file.size > 10 * 1024 * 1024) {
        throw new BadRequestException('Post media too large');
      }
    }

    if (attachmentType === 'post_file') {
      const allowed = [
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'text/plain',
        'application/zip',
      ];
      if (!allowed.includes(file.mimetype)) {
        throw new BadRequestException('Post file must be PDF/DOC/DOCX/TXT/ZIP');
      }
      if (file.size > 10 * 1024 * 1024) {
        throw new BadRequestException('Post file too large');
      }
    }
  }
}

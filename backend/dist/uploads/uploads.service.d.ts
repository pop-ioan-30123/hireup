import { DatabaseService } from '../database/database.service';
import { AuditSqlContext } from '../database/audit-sql-context';
export declare class UploadsService {
    private readonly db;
    constructor(db: DatabaseService);
    handleUpload(params: {
        file: Express.Multer.File;
        attachmentType: string;
        targetType: string;
        userId: string;
        userEmail: string;
        auditContext?: AuditSqlContext;
    }): Promise<{
        success: boolean;
        attachmentId: string;
        storageKey: string;
    }>;
    private validateMimeAndSize;
}

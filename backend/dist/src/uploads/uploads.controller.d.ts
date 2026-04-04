import { AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { UploadsService } from './uploads.service';
export declare class UploadsController {
    private readonly uploadsService;
    constructor(uploadsService: UploadsService);
    uploadFile(file: Express.Multer.File, attachmentType: string, targetType: string, req: AuthenticatedRequest): Promise<{
        success: boolean;
        attachmentId: string;
        storageKey: string;
    }>;
}

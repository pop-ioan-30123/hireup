import {
  BadRequestException,
  Body,
  Controller,
  Post,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { JwtAuthGuard, AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { UploadsService } from './uploads.service';

@Controller('uploads')
export class UploadsController {
  constructor(private readonly uploadsService: UploadsService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  @UseInterceptors(
    FileInterceptor('file', {
      storage: memoryStorage(),
      limits: {
        fileSize: 10 * 1024 * 1024,
      },
    }),
  )
  async uploadFile(
    @UploadedFile() file: Express.Multer.File,
    @Body('attachmentType') attachmentType: string,
    @Body('targetType') targetType: string,
    @Req() req: AuthenticatedRequest,
  ) {
    if (!file) {
      throw new BadRequestException('Missing file');
    }

    if (!attachmentType || !targetType) {
      throw new BadRequestException('Missing attachmentType or targetType');
    }

    return this.uploadsService.handleUpload({
      file,
      attachmentType,
      targetType,
      userId: req.user!.id,
      userEmail: req.user!.email,
      auditContext: req.auditContext,
    });
  }
}

import { Controller, Get, Query, Inject, UseGuards, BadRequestException } from '@nestjs/common';
import { I_STORAGE_SERVICE, IStorageService } from '../../domain/ports/storage.service.port';
import type { IStorageService as IStorageServiceInterface } from '../../domain/ports/storage.service.port';
import { JwtAuthGuard } from '../adapters/auth/jwt-auth.guard';

@Controller('storage')
@UseGuards(JwtAuthGuard)
export class StorageController {
    constructor(
        @Inject(I_STORAGE_SERVICE)
        private readonly storageService: IStorageServiceInterface,
    ) { }

    @Get('upload-params')
    async getUploadParams(
        @Query('filename') filename: string,
        @Query('mimeType') mimeType: string,
    ) {
        if (!filename || !mimeType) {
            throw new BadRequestException('filename and mimeType are required');
        }

        return await this.storageService.getUploadParams(filename, mimeType);
    }
}

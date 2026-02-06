import { Controller, Get, Query, Inject, UseGuards, BadRequestException, Request } from '@nestjs/common';
import { I_STORAGE_SERVICE, IStorageService } from '../../domain/ports/storage.service.port';
import type { IStorageService as IStorageServiceInterface } from '../../domain/ports/storage.service.port';
import { JwtAuthGuard } from '../adapters/auth/jwt-auth.guard';
import { I_GARMENT_REPOSITORY } from '../../domain/ports/garment.repository.port';
import type { IGarmentRepository } from '../../domain/ports/garment.repository.port';

@Controller('storage')
@UseGuards(JwtAuthGuard)
export class StorageController {
    constructor(
        @Inject(I_STORAGE_SERVICE)
        private readonly storageService: IStorageServiceInterface,
        @Inject(I_GARMENT_REPOSITORY)
        private readonly garmentRepository: IGarmentRepository,
    ) { }

    @Get('upload-params')
    async getUploadParams(
        @Query('filename') filename: string,
        @Query('mimeType') mimeType: string,
        @Query('hash') hash: string,
        @Request() req: any,
    ) {
        if (!filename || !mimeType) {
            throw new BadRequestException('filename and mimeType are required');
        }

        // Pre-flight check: if hash is provided, check if garment already exists
        if (hash) {
            const existing = await this.garmentRepository.findByHash(hash, req.user.userId);
            if (existing) {
                return {
                    alreadyExists: true,
                    garment: existing
                };
            }
        }

        const params = await this.storageService.getUploadParams(filename, mimeType);
        return {
            ...params,
            alreadyExists: false
        };
    }
}

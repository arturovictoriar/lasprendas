import { Controller, Post, UploadedFiles, UseInterceptors, Body, Get, Inject, Delete, Param } from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { VirtualTryOnUseCase } from '../../application/use-cases/virtual-try-on.use-case';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { I_GARMENT_REPOSITORY } from '../../domain/ports/garment.repository.port';
import type { IGarmentRepository } from '../../domain/ports/garment.repository.port';
import { I_TRY_ON_SESSION_REPOSITORY } from '../../domain/ports/try-on-session.repository.port';
import type { ITryOnSessionRepository } from '../../domain/ports/try-on-session.repository.port';

@Controller('try-on')
export class TryOnController {
    constructor(
        private readonly virtualTryOnUseCase: VirtualTryOnUseCase,
        @Inject(I_GARMENT_REPOSITORY)
        private readonly garmentRepository: IGarmentRepository,
        @Inject(I_TRY_ON_SESSION_REPOSITORY)
        private readonly sessionRepository: ITryOnSessionRepository,
    ) { }

    @Get('sessions')
    async getSessions() {
        return await this.sessionRepository.findAll();
    }

    @Get('garments')
    async getGarments() {
        return await this.garmentRepository.findAll();
    }

    @Delete('garments/:id')
    async deleteGarment(@Param('id') id: string) {
        await this.garmentRepository.delete(id);
        return { success: true };
    }

    @Post()
    @UseInterceptors(FilesInterceptor('images', 4, {
        storage: diskStorage({
            destination: './uploads',
            filename: (req, file, cb) => {
                const randomName = Array(32).fill(null).map(() => (Math.round(Math.random() * 16)).toString(16)).join('');
                cb(null, `${randomName}${extname(file.originalname)}`);
            }
        })
    }))
    async uploadGarment(
        @UploadedFiles() files: Express.Multer.File[],
        @Body('category') category: string,
        @Body('garmentIds') garmentIds?: string | string[]
    ) {
        const filePaths = files ? files.map(f => f.path) : [];
        const ids = typeof garmentIds === 'string' ? [garmentIds] : garmentIds;

        const resultPath = await this.virtualTryOnUseCase.execute(filePaths, category || 'clothing', ids);
        return {
            success: true,
            resultPath: resultPath,
            originalPaths: filePaths
        };
    }
}

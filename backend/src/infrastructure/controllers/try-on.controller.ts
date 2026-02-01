import { Controller, Post, UploadedFiles, UseInterceptors, Body, Get, Inject, Delete, Param, BadRequestException, UseGuards } from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { VirtualTryOnUseCase } from '../../application/use-cases/virtual-try-on.use-case';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { I_GARMENT_REPOSITORY } from '../../domain/ports/garment.repository.port';
import type { IGarmentRepository } from '../../domain/ports/garment.repository.port';
import { I_TRY_ON_SESSION_REPOSITORY } from '../../domain/ports/try-on-session.repository.port';
import type { ITryOnSessionRepository } from '../../domain/ports/try-on-session.repository.port';
import { JwtAuthGuard } from '../adapters/auth/jwt-auth.guard';

@Controller('try-on')
@UseGuards(JwtAuthGuard)
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

    @Get('sessions/:id')
    async getSessionById(@Param('id') id: string) {
        const session = await this.sessionRepository.findById(id);
        if (!session) return null;
        return {
            ...session,
            resultUrl: session.resultUrl, // Ensure it's explicitly here
        };
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

    @Delete('sessions/:id')
    async deleteSession(@Param('id') id: string) {
        await this.sessionRepository.delete(id);
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
        @Body('garmentIds') garmentIds?: string | string[],
        @Body('personType') personType?: string
    ) {
        const filePaths = files ? files.map(f => f.path) : [];
        const ids = typeof garmentIds === 'string' ? [garmentIds] : garmentIds;

        try {
            const sessionId = await this.virtualTryOnUseCase.execute(filePaths, category || 'clothing', ids, personType || 'female');
            return {
                success: true,
                id: sessionId,
                sessionId: sessionId
            };
        } catch (error) {
            if ((error as Error).message === 'No garments provided for try-on') {
                throw new BadRequestException((error as Error).message);
            }
            throw error;
        }
    }
}

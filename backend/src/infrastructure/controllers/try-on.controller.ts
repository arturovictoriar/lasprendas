import { Controller, Post, Body, Get, Inject, Delete, Param, BadRequestException, UseGuards, Request } from '@nestjs/common';
import { VirtualTryOnUseCase } from '../../application/use-cases/virtual-try-on.use-case';
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
    async getSessions(@Request() req: any) {
        return await this.sessionRepository.findAll(req.user.userId);
    }

    @Get('sessions/:id')
    async getSessionById(@Param('id') id: string, @Request() req: any) {
        const session = await this.sessionRepository.findById(id, req.user.userId);
        if (!session) return null;
        return {
            ...session,
            resultUrl: session.resultUrl, // Ensure it's explicitly here
        };
    }

    @Get('garments')
    async getGarments(@Request() req: any) {
        return await this.garmentRepository.findAll(req.user.userId);
    }

    @Delete('garments/:id')
    async deleteGarment(@Param('id') id: string, @Request() req: any) {
        await this.garmentRepository.delete(id, req.user.userId);
        return { success: true };
    }

    @Delete('sessions/:id')
    async deleteSession(@Param('id') id: string, @Request() req: any) {
        await this.sessionRepository.delete(id, req.user.userId);
        return { success: true };
    }

    @Post()
    async createSession(
        @Body('category') category: string,
        @Request() req: any,
        @Body('garmentKeys') garmentKeys?: string[],
        @Body('garmentIds') garmentIds?: string | string[],
        @Body('personType') personType?: string
    ) {
        const ids = typeof garmentIds === 'string' ? [garmentIds] : garmentIds;
        const keys = Array.isArray(garmentKeys) ? garmentKeys : (garmentKeys ? [garmentKeys] : []);

        try {
            const { sessionId, uploadedGarments } = await this.virtualTryOnUseCase.execute(keys, category || 'clothing', req.user.userId, ids, personType || 'female');
            return {
                success: true,
                id: sessionId,
                sessionId: sessionId,
                uploadedGarments: uploadedGarments
            };
        } catch (error) {
            if ((error as Error).message === 'No garments provided for try-on') {
                throw new BadRequestException((error as Error).message);
            }
            throw error;
        }
    }
}

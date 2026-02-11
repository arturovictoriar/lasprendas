import { Inject, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { I_GARMENT_REPOSITORY } from '../../domain/ports/garment.repository.port';
import type { IGarmentRepository } from '../../domain/ports/garment.repository.port';
import { Garment } from '../../domain/entities/garment.entity';
import { TryOnSession } from '../../domain/entities/try-on-session.entity';
import { I_TRY_ON_SESSION_REPOSITORY } from '../../domain/ports/try-on-session.repository.port';
import type { ITryOnSessionRepository } from '../../domain/ports/try-on-session.repository.port';
import { ImageProcessorService } from '../services/image-processor.service';
import { I_STORAGE_SERVICE, IStorageService } from '../../domain/ports/storage.service.port';
import type { IStorageService as IStorageServiceInterface } from '../../domain/ports/storage.service.port';

@Injectable()
export class VirtualTryOnUseCase {
    constructor(
        @Inject(I_GARMENT_REPOSITORY)
        private readonly garmentRepository: IGarmentRepository,
        @Inject(I_TRY_ON_SESSION_REPOSITORY)
        private readonly sessionRepository: ITryOnSessionRepository,
        private readonly imageProcessorService: ImageProcessorService,
        @InjectQueue('try-on')
        private readonly tryOnQueue: Queue,
        @Inject(I_STORAGE_SERVICE)
        private readonly storageService: IStorageServiceInterface,
    ) { }

    async execute(garmentImageKeys: string[], category: string, userId: string, garmentIds?: string[], personType: string = 'female', garmentHashes?: string[]): Promise<{ sessionId: string, uploadedGarments: Garment[] }> {
        // 0. Check for backpressure (Queue limit)
        const counts = await this.tryOnQueue.getJobCounts();
        if (counts.waiting > 15) {
            throw new ServiceUnavailableException('El probador virtual está lleno. Por favor intenta en un par de minutos.');
        }

        // 1. Get/Save garments
        const uploadedGarments = await Promise.all(garmentImageKeys.map(async (key, index) => {
            const url = this.storageService.getFileUrl(key);
            const hash = garmentHashes && garmentHashes[index] ? garmentHashes[index] : undefined;
            const garment = new Garment(url, category, new Date(), userId, null, undefined, hash);
            return await this.garmentRepository.save(garment);
        }));

        const existingGarments = garmentIds ? await Promise.all(garmentIds.map(id => this.garmentRepository.findById(id, userId))) : [];
        const garments = [...uploadedGarments, ...existingGarments.filter((g): g is Garment => g !== null)];

        if (garments.length === 0) {
            throw new Error('No garments provided for try-on');
        }

        // 2. Create session (without result yet)
        const anchorImage = personType === 'male' ? 'male_mannequin_anchor.png' : 'female_mannequin_anchor.png';

        const session = new TryOnSession(
            `assets/${anchorImage}`,
            null, // resultUrl will be updated by processor
            garments,
            new Date(),
            userId
        );
        const savedSession = await this.sessionRepository.save(session);

        // 3. Add job to queue
        await this.tryOnQueue.add('process-try-on', {
            sessionId: savedSession.id,
            personType,
            userId,
        });

        return {
            sessionId: savedSession.id!,
            uploadedGarments
        };
    }
}

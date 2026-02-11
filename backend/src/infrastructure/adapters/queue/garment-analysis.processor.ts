import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { Inject } from '@nestjs/common';
import { I_GARMENT_REPOSITORY } from '../../../domain/ports/garment.repository.port';
import type { IGarmentRepository } from '../../../domain/ports/garment.repository.port';
import { I_AI_METADATA_SERVICE } from '../../../domain/ports/ai-metadata.service.port';
import type { IAiMetadataService } from '../../../domain/ports/ai-metadata.service.port';
import { I_STORAGE_SERVICE } from '../../../domain/ports/storage.service.port';
import type { IStorageService } from '../../../domain/ports/storage.service.port';
import { Garment } from '../../../domain/entities/garment.entity';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

@Processor('garment-analysis')
export class GarmentAnalysisProcessor extends WorkerHost {
    constructor(
        @Inject(I_GARMENT_REPOSITORY)
        private readonly garmentRepository: IGarmentRepository,
        @Inject(I_AI_METADATA_SERVICE)
        private readonly aiMetadataService: IAiMetadataService,
        @Inject(I_STORAGE_SERVICE)
        private readonly storageService: IStorageService,
        @InjectQueue('garment-analysis')
        private readonly garmentAnalysisQueue: Queue,
    ) {
        super();
    }

    async process(job: Job<any, any, string>): Promise<any> {
        if (job.name === 'analyze-garment') {
            const { garmentId, userId } = job.data;
            const garment = await this.garmentRepository.findById(garmentId, userId);

            if (!garment) {
                console.error(`[GarmentAnalysisProcessor] Garment ${garmentId} not found`);
                return;
            }

            if (garment.deletedAt) {
                console.log(`[GarmentAnalysisProcessor] Skipping deleted garment ${garmentId}`);
                return;
            }

            const key = this.storageService.getKeyFromUrl(garment.originalUrl);
            const buffer = await this.storageService.getFileBuffer(key);

            try {
                // 1. Extract metadata
                const metadata = await this.aiMetadataService.extractMetadata(buffer);

                // 2. Generate embedding from description (using English for better vector consistency)
                const embedding = await this.aiMetadataService.generateEmbedding(metadata.ai_description.en);

                // 3. Create updated entity
                const updatedGarment = new Garment(
                    garment.originalUrl,
                    garment.createdAt,
                    garment.userId,
                    metadata,
                    embedding,
                    garment.deletedAt,
                    garment.id,
                    garment.hash
                );

                await this.garmentRepository.save(updatedGarment);

                console.log(`[GarmentAnalysisProcessor] Successfully analyzed garment ${garmentId}`);
            } catch (error) {
                console.error(`[GarmentAnalysisProcessor] Error analyzing garment ${garmentId}:`, error);
                throw error;
            }
        } else if (job.name === 'sync-garments') {
            const unprocessed = await this.garmentRepository.findUnprocessed();
            if (unprocessed.length > 0) {
                console.log(`[GarmentAnalysisProcessor] Sync job found ${unprocessed.length} unprocessed garments`);
                for (const garment of unprocessed) {
                    await this.garmentAnalysisQueue.add('analyze-garment', {
                        garmentId: garment.id,
                        userId: garment.userId,
                    });
                }
            }
        }
    }
}

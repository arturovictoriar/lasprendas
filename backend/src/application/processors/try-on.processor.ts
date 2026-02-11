import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { Inject, Injectable } from '@nestjs/common';
import { I_TRY_ON_SERVICE } from '../../domain/ports/try-on.service.port';
import type { ITryOnService } from '../../domain/ports/try-on.service.port';
import { I_TRY_ON_SESSION_REPOSITORY } from '../../domain/ports/try-on-session.repository.port';
import type { ITryOnSessionRepository } from '../../domain/ports/try-on-session.repository.port';
import { ImageProcessorService } from '../services/image-processor.service';
import { Garment } from '../../domain/entities/garment.entity';
import { I_STORAGE_SERVICE, IStorageService } from '../../domain/ports/storage.service.port';
import type { IStorageService as IStorageServiceInterface } from '../../domain/ports/storage.service.port';
import { I_AI_METADATA_SERVICE } from '../../domain/ports/ai-metadata.service.port';
import type { IAiMetadataService } from '../../domain/ports/ai-metadata.service.port';
import * as path from 'path';
import * as fs from 'fs';

@Injectable()
@Processor('try-on', {
    concurrency: 5
})
export class TryOnProcessor extends WorkerHost {
    constructor(
        @Inject(I_TRY_ON_SERVICE)
        private readonly tryOnService: ITryOnService,
        @Inject(I_TRY_ON_SESSION_REPOSITORY)
        private readonly sessionRepository: ITryOnSessionRepository,
        private readonly imageProcessorService: ImageProcessorService,
        @Inject(I_STORAGE_SERVICE)
        private readonly storageService: IStorageServiceInterface,
        @Inject(I_AI_METADATA_SERVICE)
        private readonly aiMetadataService: IAiMetadataService,
    ) {
        super();
    }

    async process(job: Job<any, any, string>): Promise<any> {
        const jobStart = performance.now();
        const { sessionId, personType, userId } = job.data;

        try {
            const session = await this.sessionRepository.findById(sessionId, userId);
            if (!session) throw new Error('Session not found');

            // 1. Prepare Mannequin (Local Asset -> Buffer)
            const anchorImage = personType === 'male' ? 'male_mannequin_anchor.png' : 'female_mannequin_anchor.png';
            const mannequinPath = path.join(process.cwd(), 'assets', anchorImage);
            const mannequinBuffer = fs.readFileSync(mannequinPath);

            // 2. Normalize garments (S3 -> Buffer -> Processed Buffer)
            const normalizedGarmentBuffers = await Promise.all(session.garments.map(async (garment) => {
                // originalUrl is now an S3 URL or we can derive the key
                // For now, let's assume we store the KEY in the entity or parse it from URL
                // Actually, in VirtualTryOnUseCase I saved the URL.
                // It's better to store keys, but for now I'll extract key from URL or just use a helper
                // The StorageAdapter knows how to handle its own URLs/keys.
                const key = this.storageService.getKeyFromUrl(garment.originalUrl);
                const buffer = await this.storageService.getFileBuffer(key);
                return await this.imageProcessorService.normalizeForTryOn(buffer);
            }));

            const prompt = `STRICT ADHERENCE TO ANCHOR IMAGE (Image 1): 
The gray mannequin in Image 1 is your ABSOLUTE ANCHOR. 
Do NOT change its pose, face (no face), skin color (gray), body shape, underwear or background.

TRANSFER TASK:
Analyze the clothing items in the additional images (Images 2, 3, etc.).
Remove DISNEY copyrighted or branded content from the images.
Fit ALL these items onto the mannequin from Image 1 simultaneously.
- Tops/Shirts go to the torso.
- Bottoms/Pants go to the legs.
- Accessories go to their respective natural positions.

REALISM & CONSISTENCY:
- Maintain the original lighting and neutral background.
- Ensure fabric draping, shadows, and scale are realistic for the mannequin's pose.
- The output MUST look like the original mannequin wearing the new clothes.
- Maintain the EXACT resolution and aspect ratio of Image 1 in the output.
- NO hallucinations, NO added people, NO changed environment.`.trim();

            // 3. Perform Try-On (Gemini)
            const resultBuffer = await this.tryOnService.performTryOn(mannequinBuffer, normalizedGarmentBuffers, prompt);

            // 4. Upload Result to S3
            const resultKey = `results/result-${Date.now()}.png`;
            const resultUrl = await this.storageService.uploadFile(resultKey, resultBuffer, 'image/png');

            // 5. AI Analysis of the resulting outfit
            try {
                const sessionMetadata = await this.aiMetadataService.extractMetadata(resultBuffer);
                const sessionEmbedding = await this.aiMetadataService.generateEmbedding(sessionMetadata.ai_description.en);
                session.metadata = sessionMetadata;
                session.embedding = sessionEmbedding;
            } catch (aiError) {
                console.warn('[TryOnProcessor] AI analysis failed for session, but continuing with resultUrl:', aiError);
            }

            // 6. Update session in DB
            session.resultUrl = resultUrl;
            await this.sessionRepository.save(session);

            const totalDuration = performance.now() - jobStart;
            console.info(`[TryOnProcessor] Job ${job.id} COMPLETED in ${(totalDuration / 1000).toFixed(2)}s`);

            return { resultUrl };
        } catch (error) {
            console.error('Error in TryOnProcessor:', error);
            throw error;
        }
    }
}

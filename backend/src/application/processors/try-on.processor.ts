import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { Inject, Injectable } from '@nestjs/common';
import { I_TRY_ON_SERVICE } from '../../domain/ports/try-on.service.port';
import type { ITryOnService } from '../../domain/ports/try-on.service.port';
import { I_TRY_ON_SESSION_REPOSITORY } from '../../domain/ports/try-on-session.repository.port';
import type { ITryOnSessionRepository } from '../../domain/ports/try-on-session.repository.port';
import { ImageProcessorService } from '../services/image-processor.service';
import { Garment } from '../../domain/entities/garment.entity';
import * as path from 'path';

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
    ) {
        super();
    }

    async process(job: Job<any, any, string>): Promise<any> {
        const jobStart = performance.now();
        const { sessionId, personType, userId } = job.data;

        try {
            const session = await this.sessionRepository.findById(sessionId, userId);
            if (!session) throw new Error('Session not found');

            // Normalize garments
            const normalizedGarments = await Promise.all(session.garments.map(async (garment) => {
                const normalizedPath = await this.imageProcessorService.normalizeForTryOn(garment.originalUrl);
                return {
                    ...garment,
                    originalUrl: normalizedPath
                };
            }));

            const anchorImage = personType === 'male' ? 'male_mannequin_anchor.png' : 'female_mannequin_anchor.png';
            const mannequinPath = path.join(process.cwd(), 'assets', anchorImage);

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

            const resultPath = await this.tryOnService.performTryOn(mannequinPath, normalizedGarments as any, prompt);
            const resultFilename = path.basename(resultPath);

            // Update session in DB
            session.resultUrl = resultFilename;
            await this.sessionRepository.save(session);

            const totalDuration = performance.now() - jobStart;
            console.info(`[TryOnProcessor] Job ${job.id} COMPLETED in ${(totalDuration / 1000).toFixed(2)}s`);

            return { resultFilename };
        } catch (error) {
            console.error('Error in TryOnProcessor:', error);
            throw error;
        }
    }
}

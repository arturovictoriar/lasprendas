import { Inject, Injectable } from '@nestjs/common';
import { I_GARMENT_REPOSITORY } from '../../domain/ports/garment.repository.port';
import type { IGarmentRepository } from '../../domain/ports/garment.repository.port';
import { I_TRY_ON_SERVICE } from '../../domain/ports/try-on.service.port';
import type { ITryOnService } from '../../domain/ports/try-on.service.port';
import { Garment } from '../../domain/entities/garment.entity';
import { TryOnSession } from '../../domain/entities/try-on-session.entity';
import { I_TRY_ON_SESSION_REPOSITORY } from '../../domain/ports/try-on-session.repository.port';
import type { ITryOnSessionRepository } from '../../domain/ports/try-on-session.repository.port';
import * as path from 'path';

@Injectable()
export class VirtualTryOnUseCase {
    constructor(
        @Inject(I_GARMENT_REPOSITORY)
        private readonly garmentRepository: IGarmentRepository,
        @Inject(I_TRY_ON_SERVICE)
        private readonly tryOnService: ITryOnService,
        @Inject(I_TRY_ON_SESSION_REPOSITORY)
        private readonly sessionRepository: ITryOnSessionRepository,
    ) { }

    async execute(garmentImagePaths: string[], category: string, garmentIds?: string[]): Promise<string> {
        // 1. Get/Save garments
        const uploadedGarments = await Promise.all(garmentImagePaths.map(async (path) => {
            const garment = new Garment(null, path, category, new Date());
            return await this.garmentRepository.save(garment);
        }));

        const existingGarments = garmentIds ? await Promise.all(garmentIds.map(id => this.garmentRepository.findById(id))) : [];
        const garments = [...uploadedGarments, ...existingGarments.filter((g): g is Garment => g !== null)];

        if (garments.length === 0) {
            throw new Error('No garments provided for try-on');
        }

        // 2. Perform Virtual Try-On
        const mannequinPath = path.join(process.cwd(), 'assets', 'mannequin_anchor.png');

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

        const resultPath = await this.tryOnService.performTryOn(mannequinPath, garments, prompt);
        const resultFilename = path.basename(resultPath);

        // 3. Save session
        const session = new TryOnSession(
            null,
            'assets/mannequin_anchor.png',
            resultFilename,
            garments,
            new Date()
        );
        await this.sessionRepository.save(session);

        return resultFilename;
    }
}

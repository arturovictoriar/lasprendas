import { Inject, Injectable } from '@nestjs/common';
import { I_GARMENT_REPOSITORY } from '../../domain/ports/garment.repository.port';
import type { IGarmentRepository } from '../../domain/ports/garment.repository.port';
import { I_TRY_ON_SERVICE } from '../../domain/ports/try-on.service.port';
import type { ITryOnService } from '../../domain/ports/try-on.service.port';
import { Garment } from '../../domain/entities/garment.entity';
import * as path from 'path';

@Injectable()
export class VirtualTryOnUseCase {
    constructor(
        @Inject(I_GARMENT_REPOSITORY)
        private readonly garmentRepository: IGarmentRepository,
        @Inject(I_TRY_ON_SERVICE)
        private readonly tryOnService: ITryOnService,
    ) { }

    async execute(garmentImagePaths: string[], category: string): Promise<string> {
        // 1. Save garment references in DB
        const garments = await Promise.all(garmentImagePaths.map(async (path) => {
            const garment = new Garment(null, path, category, new Date());
            return await this.garmentRepository.save(garment);
        }));

        // 2. Perform Virtual Try-On
        const mannequinPath = path.join(process.cwd(), 'assets', 'mannequin_anchor.png');

        const prompt = `
            STRICT ADHERENCE TO ANCHOR IMAGE (Image 1): 
            The gray mannequin in Image 1 is your ABSOLUTE ANCHOR. 
            Do NOT change its pose, face, skin color (gray), body shape, or background.
            
            TRANSFER TASK:
            Analyze the clothing items in the additional images (Images 2, 3, etc.).
            Fit ALL these items onto the mannequin from Image 1 simultaneously.
            - Tops/Shirts go to the torso.
            - Bottoms/Pants go to the legs.
            - Accessories go to their respective natural positions.
            
            REALISM & CONSISTENCY:
            - Maintain the original lighting and neutral background.
            - Ensure fabric draping, shadows, and scale are realistic for the mannequin's pose.
            - The output MUST look like the original mannequin wearing the new clothes.
            - Maintain the EXACT resolution and aspect ratio of Image 1 in the output.
            - NO hallucinations, NO added people, NO changed environment.
        `.trim();

        const resultPath = await this.tryOnService.performTryOn(mannequinPath, garments, prompt);

        return path.basename(resultPath);
    }
}

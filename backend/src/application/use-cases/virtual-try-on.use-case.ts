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

    async execute(garmentImagePath: string, category: string): Promise<string> {
        // 1. Save garment reference in DB
        const garment = new Garment(null, garmentImagePath, category, new Date());
        const savedGarment = await this.garmentRepository.save(garment);

        // 2. Perform Virtual Try-On
        const mannequinPath = path.join(process.cwd(), 'assets', 'mannequin_anchor.png');

        const prompt = `Identity and Transfer: Take the gray mannequin from Image 1 as the anchor. Analyze the clothing or accessory in the additional uploaded images and automatically fit it to the corresponding body part on the mannequin. If it's a top, fit it to the torso; if it's footwear, fit it to the feet; if it's an accessory, place it in its natural position. Maintain the mannequin's gray texture, the original studio lighting, and the neutral background. Ensure the fabric draping and scale are realistic based on the mannequin's pose. Do not modify the mannequin or the background.`;

        const resultPath = await this.tryOnService.performTryOn(mannequinPath, savedGarment, prompt);

        return path.basename(resultPath);
    }
}

import { Injectable } from '@nestjs/common';
import sharp from 'sharp';

@Injectable()
export class ImageProcessorService {
    private readonly TARGET_WIDTH = 784;
    private readonly TARGET_HEIGHT = 1024;

    async normalizeForTryOn(input: Buffer): Promise<Buffer> {
        const start = performance.now();
        const output = await sharp(input)
            .resize({
                width: this.TARGET_WIDTH,
                height: this.TARGET_HEIGHT,
                fit: 'contain',
                background: { r: 0, g: 0, b: 0, alpha: 0 } // Transparent background
            })
            .toFormat('png')
            .toBuffer();
        const duration = performance.now() - start;
        console.log(`[ImageProcessorService] Normalization (sharp) took ${duration.toFixed(2)}ms`);

        return output;
    }
}

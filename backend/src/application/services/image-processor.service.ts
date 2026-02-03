import { Injectable } from '@nestjs/common';
import sharp from 'sharp';
import * as path from 'path';

@Injectable()
export class ImageProcessorService {
    private readonly TARGET_WIDTH = 784;
    private readonly TARGET_HEIGHT = 1024;

    async normalizeForTryOn(inputPath: string): Promise<string> {
        const filename = `normalized-${path.basename(inputPath)}`;
        const outputPath = path.join(path.dirname(inputPath), filename);

        // Ensure temp directory for normalization exists if needed, 
        // but here we use the same directory as input (usually uploads/ or temp/)

        const start = performance.now();
        await sharp(inputPath)
            .resize({
                width: this.TARGET_WIDTH,
                height: this.TARGET_HEIGHT,
                fit: 'contain',
                background: { r: 0, g: 0, b: 0, alpha: 0 } // Transparent background
            })
            .toFormat('png')
            .toFile(outputPath);
        const duration = performance.now() - start;
        console.log(`[ImageProcessorService] Normalization (sharp) took ${duration.toFixed(2)}ms for ${path.basename(inputPath)}`);

        return outputPath;
    }
}

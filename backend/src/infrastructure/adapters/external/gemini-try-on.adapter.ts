import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { ITryOnService } from '../../../domain/ports/try-on.service.port';
import { Garment } from '../../../domain/entities/garment.entity';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class GeminiTryOnAdapter implements ITryOnService {
    private genAI: GoogleGenerativeAI;

    constructor(private configService: ConfigService) {
        const apiKey = this.configService.get<string>('GEMINI_API_KEY') || 'INVALID_KEY';
        this.genAI = new GoogleGenerativeAI(apiKey);
    }

    async performTryOn(mannequinPath: string, garment: Garment, prompt: string): Promise<string> {
        const model = this.genAI.getGenerativeModel({
            model: 'gemini-3-pro-image-preview',
            generationConfig: {
                temperature: 0.4,
                topP: 0.95,
            }
        });

        const mannequinImage = this.fileToGenerativePart(mannequinPath, 'image/png');
        // Assuming garment.originalUrl is the absolute path or relative to current dir
        const garmentImage = this.fileToGenerativePart(garment.originalUrl, 'image/png');

        const result = await model.generateContent([
            mannequinImage,
            garmentImage,
            prompt
        ]);

        const response = await result.response;

        const resultFilename = `result-${Date.now()}.png`;
        const resultPath = path.join(process.cwd(), 'results', resultFilename);

        // Extract image from parts
        const parts = response.candidates?.[0]?.content?.parts;
        const imagePart = parts?.find(p => p.inlineData);

        if (imagePart && imagePart.inlineData) {
            fs.writeFileSync(resultPath, Buffer.from(imagePart.inlineData.data, 'base64'));
        } else {
            // If no image returned, copy mannequin as fallback
            fs.copyFileSync(mannequinPath, resultPath);
        }

        return resultPath;
    }

    private fileToGenerativePart(path: string, mimeType: string) {
        return {
            inlineData: {
                data: Buffer.from(fs.readFileSync(path)).toString('base64'),
                mimeType
            },
        };
    }
}

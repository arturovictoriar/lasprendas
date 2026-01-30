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

    async performTryOn(mannequinPath: string, garments: Garment[], prompt: string): Promise<string> {
        const model = this.genAI.getGenerativeModel({
            model: 'gemini-3-pro-image-preview',
            generationConfig: {
                temperature: 0.2,
                topP: 0.95,
            }
        });

        const mannequinImage = this.fileToGenerativePart(mannequinPath, 'image/png');
        const garmentImages = garments.map(g => this.fileToGenerativePart(g.originalUrl, 'image/png'));

        let result;
        try {
            result = await model.generateContent([
                mannequinImage,
                ...garmentImages,
                prompt
            ]);
        } catch (error) {
            console.error('Error calling Gemini API:', error);
            if ((error as any).message?.includes('fetch failed')) {
                console.error('Network error detected. Please check if the Docker container has internet access and can reach generativelanguage.googleapis.com');
            }
            throw error;
        }

        const response = await result.response;

        const resultFilename = `result-${Date.now()}.png`;
        const resultPath = path.join(process.cwd(), 'results', resultFilename);

        // Ensure results directory exists
        const resultsDir = path.join(process.cwd(), 'results');
        if (!fs.existsSync(resultsDir)) {
            fs.mkdirSync(resultsDir, { recursive: true });
        }

        // Extract image from parts
        const parts = response.candidates?.[0]?.content?.parts;
        const imagePart = parts?.find((p: any) => p.inlineData);

        if (imagePart && imagePart.inlineData) {
            fs.writeFileSync(resultPath, Buffer.from(imagePart.inlineData.data, 'base64'));
        } else {
            // If no image returned, copy mannequin as fallback
            console.error('Gemini did not return an image part. Falling back to mannequin.');
            console.log('Full Gemini response:', JSON.stringify(response, null, 2));
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

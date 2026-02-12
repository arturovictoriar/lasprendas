import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { IAiMetadataService, AiMetadata } from '../../../domain/ports/ai-metadata.service.port';

@Injectable()
export class GeminiAiMetadataAdapter implements IAiMetadataService {
  private genAIv1: GoogleGenerativeAI;
  private genAIv1beta: GoogleGenerativeAI;

  constructor(private configService: ConfigService) {
    const apiKey = this.configService.get<string>('GEMINI_API_KEY') || 'INVALID_KEY';
    this.genAIv1 = new GoogleGenerativeAI(apiKey);
    // Direct assignment of v1beta instance is better if we want to be explicit
    this.genAIv1beta = new GoogleGenerativeAI(apiKey);
  }

  async extractMetadata(imageBuffer: Buffer): Promise<AiMetadata> {
    const model = this.genAIv1beta.getGenerativeModel(
      {
        model: 'gemini-2.0-flash-lite',
        generationConfig: {
          temperature: 0.1,
          topP: 0.95,
          responseMimeType: 'application/json',
        }
      },
      { apiVersion: 'v1beta' }
    );

    const prompt = `
Analyze the attached image of a garment or accessory (shoes, bags, hats, jewelry, watches, etc.) and extract its metadata in the following JSON format.
Keys must be exactly as specified in English.
Values for descriptive fields must be an object with 'es' and 'en' keys for Spanish and English translations.

JSON Structure:
{
  "physical": {
    "category": { "es": "...", "en": "..." },
    "subcategory": { "es": "...", "en": "..." },
    "dominant_color": {
      "name": { "es": "...", "en": "..." },
      "hex": "#..."
    },
    "color_palette": ["#...", "#..."],
    "material": { "es": "...", "en": "..." },
    "texture_pattern": { "es": "...", "en": "..." }
  },
  "design": {
    "neckline": { "es": "...", "en": "..." }, // Use null if not applicable (e.g. for accessories)
    "sleeve_length": { "es": "...", "en": "..." }, // Use null if not applicable
    "fit": { "es": "...", "en": "..." }, // Use null if not applicable
    "closure_type": { "es": "...", "en": "..." },
    "details": [
      { "es": "...", "en": "..." }
    ]
  },
  "context": {
    "occasion": [
      { "es": "...", "en": "..." }
    ],
    "season": { "es": "...", "en": "..." },
    "gender": { "es": "...", "en": "..." },
    "visual_style": { "es": "...", "en": "..." }
  },
  "ai_description": {
    "es": "...",
    "en": "..."
  }
}

Be specific and professional. For colors, use standard CSS hex codes. If a field (like neckline or sleeve_length) does not make sense for the item being analyzed (e.g. a bag or shoes), set its value to null.
`;

    const imagePart = {
      inlineData: {
        data: imageBuffer.toString('base64'),
        mimeType: 'image/jpeg'
      },
    };

    try {
      const result = await model.generateContent([prompt, imagePart]);
      const response = await result.response;
      const text = response.text();
      const parsed = JSON.parse(text);

      // If Gemini returns an array (sometimes happens with multiple items), take the first one
      if (Array.isArray(parsed)) {
        return (parsed[0] || {}) as AiMetadata;
      }
      return parsed as AiMetadata;
    } catch (error) {
      console.error('[GeminiAiMetadataAdapter] Error extracting metadata:', error);
      throw error;
    }
  }

  async generateEmbedding(text: string): Promise<number[]> {
    const model = this.genAIv1beta.getGenerativeModel(
      { model: 'gemini-embedding-001' },
      { apiVersion: 'v1beta' }
    );

    try {
      const result = await model.embedContent({
        content: { role: 'user', parts: [{ text }] },
        outputDimensionality: 768,
      } as any);
      const embedding = result.embedding;
      return embedding.values;
    } catch (error) {
      console.error('[GeminiAiMetadataAdapter] Error generating embedding:', error);
      throw error;
    }
  }
}

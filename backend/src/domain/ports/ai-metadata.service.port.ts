export interface AiMetadata {
    physical: {
        category: { es: string; en: string };
        subcategory: { es: string; en: string };
        dominant_color: {
            name: { es: string; en: string };
            hex: string;
        };
        color_palette: string[];
        material: { es: string; en: string };
        texture_pattern: { es: string; en: string };
    };
    design: {
        neckline: { es: string; en: string };
        sleeve_length: { es: string; en: string };
        fit: { es: string; en: string };
        closure_type: { es: string; en: string };
        details: Array<{ es: string; en: string }>;
    };
    context: {
        occasion: Array<{ es: string; en: string }>;
        season: { es: string; en: string };
        gender: { es: string; en: string };
        visual_style: { es: string; en: string };
    };
    ai_description: {
        es: string;
        en: string;
    };
}

export const I_AI_METADATA_SERVICE = 'I_AI_METADATA_SERVICE';

export interface IAiMetadataService {
    extractMetadata(imageBuffer: Buffer): Promise<AiMetadata>;
    generateEmbedding(text: string): Promise<number[]>;
}

import { GoogleGenerativeAI } from '@google/generative-ai';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.join(__dirname, '../.env') });

async function listModels() {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
        console.error('GEMINI_API_KEY not found');
        return;
    }

    const genAI = new GoogleGenerativeAI(apiKey);

    console.log('--- Models in v1 ---');
    try {
        // Note: The SDK doesn't have a direct listModels, we might need to use fetch or check if genAI has it
        // Actually, listing models usually requires the REST API or a specific client.
        // Let's try to just hit one that is likely there.
    } catch (e) {
        console.error(e);
    }
}

// Since the SDK is restricted, let's just try 'embedding-001' which is very stable.

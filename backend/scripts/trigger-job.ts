import { Queue } from 'bullmq';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.join(__dirname, '../.env') });

async function triggerJob() {
    const queue = new Queue('garment-analysis', {
        connection: {
            host: process.env.REDIS_HOST || 'localhost',
            port: parseInt(process.env.REDIS_PORT || '6379'),
        },
    });

    const garments = [
        { garmentId: 'ad58fbdf-1259-4f91-88f4-ffe5feaf9abe', userId: '7af3bf90-e46c-447a-870c-6d94d54f243f' },
        { garmentId: '1911bcb9-c395-4cb9-8f51-dd5d052fee37', userId: '7af3bf90-e46c-447a-870c-6d94d54f243f' }
    ];

    for (const { garmentId, userId } of garments) {
        console.log(`Adding job for garment ${garmentId}...`);
        await queue.add('analyze-garment', { garmentId, userId });
    }

    console.log('Jobs added successfully.');
    await queue.close();
}

triggerJob().catch(console.error);

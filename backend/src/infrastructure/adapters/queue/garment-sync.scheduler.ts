import { Injectable, OnModuleInit, Inject } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

@Injectable()
export class GarmentSyncScheduler implements OnModuleInit {
    constructor(
        @InjectQueue('garment-analysis')
        private readonly garmentAnalysisQueue: Queue,
    ) { }

    async onModuleInit() {
        console.log('[GarmentSyncScheduler] Initializing garment sync repeatable job...');

        // Remove existing repeatable jobs to avoid duplicates if configuration changes
        const repeatableJobs = await this.garmentAnalysisQueue.getRepeatableJobs();
        for (const job of repeatableJobs) {
            if (job.name === 'sync-garments') {
                await this.garmentAnalysisQueue.removeRepeatableByKey(job.key);
            }
        }

        // Add a repeatable job every 5 minutes
        await this.garmentAnalysisQueue.add(
            'sync-garments',
            {},
            {
                repeat: {
                    pattern: '*/5 * * * *',
                },
            },
        );
    }
}

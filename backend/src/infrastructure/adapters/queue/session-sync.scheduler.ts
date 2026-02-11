import { Injectable, OnModuleInit } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

@Injectable()
export class SessionSyncScheduler implements OnModuleInit {
    constructor(
        @InjectQueue('session-analysis')
        private readonly sessionAnalysisQueue: Queue,
    ) { }

    async onModuleInit() {
        console.log('[SessionSyncScheduler] Initializing session sync repeatable job...');

        // Remove existing jobs to avoid duplicates if necessary
        const repeatableJobs = await this.sessionAnalysisQueue.getRepeatableJobs();
        for (const job of repeatableJobs) {
            if (job.name === 'sync-sessions') {
                await this.sessionAnalysisQueue.removeRepeatableByKey(job.key);
            }
        }

        // Add repeatable job: every 5 minutes
        await this.sessionAnalysisQueue.add(
            'sync-sessions',
            {},
            {
                repeat: {
                    pattern: '*/5 * * * *',
                },
            },
        );
    }
}

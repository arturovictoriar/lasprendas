import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { Inject } from '@nestjs/common';
import { I_TRY_ON_SESSION_REPOSITORY } from '../../../domain/ports/try-on-session.repository.port';
import type { ITryOnSessionRepository } from '../../../domain/ports/try-on-session.repository.port';
import { I_AI_METADATA_SERVICE } from '../../../domain/ports/ai-metadata.service.port';
import type { IAiMetadataService } from '../../../domain/ports/ai-metadata.service.port';
import { I_STORAGE_SERVICE } from '../../../domain/ports/storage.service.port';
import type { IStorageService } from '../../../domain/ports/storage.service.port';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

@Processor('session-analysis')
export class SessionAnalysisProcessor extends WorkerHost {
    constructor(
        @Inject(I_TRY_ON_SESSION_REPOSITORY)
        private readonly sessionRepository: ITryOnSessionRepository,
        @Inject(I_AI_METADATA_SERVICE)
        private readonly aiMetadataService: IAiMetadataService,
        @Inject(I_STORAGE_SERVICE)
        private readonly storageService: IStorageService,
        @InjectQueue('session-analysis')
        private readonly sessionAnalysisQueue: Queue,
    ) {
        super();
    }

    async process(job: Job<any, any, string>): Promise<any> {
        if (job.name === 'analyze-session') {
            const { sessionId, userId } = job.data;
            const session = await this.sessionRepository.findById(sessionId, userId);

            if (!session) {
                console.error(`[SessionAnalysisProcessor] Session ${sessionId} not found`);
                return;
            }

            if (session.deletedAt || !session.resultUrl) {
                console.log(`[SessionAnalysisProcessor] Skipping session ${sessionId} (deleted or no result)`);
                return;
            }

            const key = this.storageService.getKeyFromUrl(session.resultUrl);
            const buffer = await this.storageService.getFileBuffer(key);

            try {
                console.log(`[SessionAnalysisProcessor] Starting analysis for session ${sessionId}...`);

                // 1. Extract metadata
                const metadata = await this.aiMetadataService.extractMetadata(buffer);

                // 2. Generate embedding
                const embedding = await this.aiMetadataService.generateEmbedding(metadata.ai_description.en);

                // 3. Update session
                session.metadata = metadata;
                session.embedding = embedding;

                await this.sessionRepository.save(session);

                console.log(`[SessionAnalysisProcessor] Successfully analyzed session ${sessionId}`);
            } catch (error) {
                console.error(`[SessionAnalysisProcessor] Error analyzing session ${sessionId}:`, error);
                throw error;
            }
        } else if (job.name === 'sync-sessions') {
            const unprocessed = await this.sessionRepository.findUnprocessed();
            if (unprocessed.length > 0) {
                console.log(`[SessionAnalysisProcessor] Sync job found ${unprocessed.length} unprocessed sessions`);
                for (const session of unprocessed) {
                    await this.sessionAnalysisQueue.add('analyze-session', {
                        sessionId: session.id,
                        userId: session.userId,
                    });
                }
            }
        }
    }
}

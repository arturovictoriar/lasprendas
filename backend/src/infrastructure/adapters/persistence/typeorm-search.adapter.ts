import { Inject, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull, Brackets } from 'typeorm';
import { ISearchService, SearchFilters } from '../../../domain/ports/search.service.port';
import { Garment } from '../../../domain/entities/garment.entity';
import { GarmentSchema } from './garment.schema';
import { TryOnSessionSchema } from './try-on-session.schema';
import { I_AI_METADATA_SERVICE } from '../../../domain/ports/ai-metadata.service.port';
import type { IAiMetadataService } from '../../../domain/ports/ai-metadata.service.port';

@Injectable()
export class TypeOrmSearchAdapter implements ISearchService {
    constructor(
        @InjectRepository(GarmentSchema)
        private readonly garmentRepository: Repository<GarmentSchema>,
        @InjectRepository(TryOnSessionSchema)
        private readonly sessionRepository: Repository<TryOnSessionSchema>,
        @Inject(I_AI_METADATA_SERVICE)
        private readonly aiMetadataService: IAiMetadataService,
    ) { }

    async searchGarments(filters: SearchFilters): Promise<Garment[]> {
        const { query, colorHex, category, subcategory, userId } = filters;

        let embedding: number[] | null = null;
        if (query) {
            try {
                embedding = await this.aiMetadataService.generateEmbedding(query);
            } catch (error) {
                console.warn('[TypeOrmSearchAdapter] Embedding generation failed, falling back to text search only', error);
            }
        }

        const qb = this.garmentRepository.createQueryBuilder('garment')
            .where('garment.userId = :userId', { userId })
            .andWhere('garment.deletedAt IS NULL');

        // Apply metadata filters (JSONB)
        if (category) {
            qb.andWhere("(garment.metadata->'physical'->'category'->>'en' = :category OR garment.metadata->'physical'->'category'->>'es' = :category)", { category });
        }

        if (subcategory) {
            qb.andWhere("(garment.metadata->'physical'->'subcategory'->>'en' = :subcategory OR garment.metadata->'physical'->'subcategory'->>'es' = :subcategory)", { subcategory });
        }

        if (colorHex) {
            qb.andWhere("garment.metadata->'physical'->'dominant_color'->>'hex' = :colorHex", { colorHex });
        }

        if (query) {
            if (embedding) {
                const vectorStr = `[${embedding.join(',')}]`;
                qb.addSelect(`garment.embedding <=> '${vectorStr}'`, 'distance');
            }

            qb.andWhere(new Brackets(brackets => {
                const textCondition = "garment.metadata::text ILIKE :searchQuery";
                const params = { searchQuery: `%${query}%` };

                if (embedding) {
                    // Combine vector existence OR text match
                    brackets.where('garment.embedding IS NOT NULL')
                        .orWhere(textCondition, params);
                } else {
                    brackets.where(textCondition, params);
                }
            }));

            if (embedding) {
                qb.orderBy('distance', 'ASC', 'NULLS LAST');
            } else {
                qb.orderBy('garment.createdAt', 'DESC');
            }
        } else {
            qb.orderBy('garment.createdAt', 'DESC');
        }

        const schemas = await qb.getMany();
        return schemas.map(schema => this.mapToEntity(schema));
    }

    async searchSessions(filters: SearchFilters): Promise<any[]> {
        const { query, category, userId } = filters;

        let embedding: number[] | null = null;
        if (query) {
            try {
                embedding = await this.aiMetadataService.generateEmbedding(query);
            } catch (error) {
                console.warn('[TypeOrmSearchAdapter] Embedding generation failed, falling back to text search only', error);
            }
        }

        const qb = this.sessionRepository.createQueryBuilder('session')
            .leftJoinAndSelect('session.garments', 'garment')
            .where('session.userId = :userId', { userId })
            .andWhere('session.deletedAt IS NULL')
            .andWhere('session.resultUrl IS NOT NULL');

        if (category) {
            qb.andWhere("(session.metadata->'physical'->'category'->>'en' = :category OR session.metadata->'physical'->'category'->>'es' = :category)", { category });
        }

        if (query) {
            if (embedding) {
                const vectorStr = `[${embedding.join(',')}]`;
                qb.addSelect(`session.embedding <=> '${vectorStr}'`, 'distance');
            }

            qb.andWhere(new Brackets(brackets => {
                const textCondition = "session.metadata::text ILIKE :searchQuery";
                const params = { searchQuery: `%${query}%` };

                if (embedding) {
                    brackets.where('session.embedding IS NOT NULL')
                        .orWhere(textCondition, params);
                } else {
                    brackets.where(textCondition, params);
                }
            }));

            if (embedding) {
                qb.orderBy('distance', 'ASC', 'NULLS LAST');
            } else {
                qb.orderBy('session.createdAt', 'DESC');
            }
        } else {
            qb.orderBy('session.createdAt', 'DESC');
        }

        return await qb.getMany();
    }

    private mapToEntity(schema: GarmentSchema): Garment {
        return new Garment(
            schema.originalUrl,
            schema.createdAt,
            schema.userId,
            schema.metadata,
            schema.embedding,
            schema.deletedAt,
            schema.id,
            schema.hash ?? undefined
        );
    }
}

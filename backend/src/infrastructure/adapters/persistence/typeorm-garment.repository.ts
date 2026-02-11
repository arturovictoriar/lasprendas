import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull } from 'typeorm';
import { IGarmentRepository } from '../../../domain/ports/garment.repository.port';
import { Garment } from '../../../domain/entities/garment.entity';
import { GarmentSchema } from './garment.schema';

@Injectable()
export class TypeOrmGarmentRepository implements IGarmentRepository {
    constructor(
        @InjectRepository(GarmentSchema)
        private readonly repository: Repository<GarmentSchema>,
    ) { }

    async save(garment: Garment): Promise<Garment> {
        const schema = new GarmentSchema();
        if (garment.id) schema.id = garment.id;
        schema.originalUrl = garment.originalUrl;
        schema.userId = garment.userId;
        schema.hash = garment.hash || null;
        schema.metadata = garment.metadata || null;
        schema.embedding = garment.embedding || null;

        const saved = await this.repository.save(schema);
        return this.mapToEntity(saved);
    }

    async delete(id: string, userId: string): Promise<void> {
        await this.repository.update({ id, userId }, { deletedAt: new Date() });
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
            schema.hash ?? undefined,
        );
    }

    async findById(id: string, userId: string): Promise<Garment | null> {
        const found = await this.repository.findOneBy({ id, userId });
        if (!found) return null;
        return this.mapToEntity(found);
    }

    async findByHash(hash: string, userId: string): Promise<Garment | null> {
        const found = await this.repository.findOneBy({ hash, userId, deletedAt: IsNull() } as any);
        if (!found) return null;
        return this.mapToEntity(found);
    }

    async findAll(userId: string): Promise<Garment[]> {
        const garments = await this.repository.find({
            where: { userId, deletedAt: IsNull() },
            order: { createdAt: 'DESC' }
        });
        return garments.map(g => this.mapToEntity(g));
    }

    async findUnprocessed(): Promise<Garment[]> {
        const garments = await this.repository.find({
            where: {
                metadata: IsNull(),
                deletedAt: IsNull()
            }
        });
        return garments.map(g => this.mapToEntity(g));
    }
}

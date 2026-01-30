import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull } from 'typeorm';
import { ITryOnSessionRepository } from '../../../domain/ports/try-on-session.repository.port';
import { TryOnSession } from '../../../domain/entities/try-on-session.entity';
import { TryOnSessionSchema } from './try-on-session.schema';
import { GarmentSchema } from './garment.schema';
import { Garment } from '../../../domain/entities/garment.entity';

@Injectable()
export class TypeOrmTryOnSessionRepository implements ITryOnSessionRepository {
    constructor(
        @InjectRepository(TryOnSessionSchema)
        private readonly repository: Repository<TryOnSessionSchema>,
    ) { }

    async save(session: TryOnSession): Promise<TryOnSession> {
        const schema = new TryOnSessionSchema();
        if (session.id) schema.id = session.id;
        schema.mannequinUrl = session.mannequinUrl;
        schema.resultUrl = session.resultUrl || '';

        // Map garments to schemas (assuming they already exist)
        schema.garments = session.garments.map(g => {
            const gs = new GarmentSchema();
            gs.id = g.id!;
            return gs;
        });

        const saved = await this.repository.save(schema);
        return this.mapToEntity(saved);
    }

    async delete(id: string): Promise<void> {
        await this.repository.update(id, { deletedAt: new Date() });
    }

    async findById(id: string): Promise<TryOnSession | null> {
        const found = await this.repository.findOne({
            where: { id },
            relations: ['garments']
        });
        if (!found) return null;
        return this.mapToEntity(found);
    }

    async findAll(): Promise<TryOnSession[]> {
        const list = await this.repository.find({
            where: { deletedAt: IsNull() },
            relations: ['garments'],
            order: { createdAt: 'DESC' }
        });
        return list.map(item => this.mapToEntity(item));
    }

    private mapToEntity(schema: TryOnSessionSchema): TryOnSession {
        return new TryOnSession(
            schema.id,
            schema.mannequinUrl,
            schema.resultUrl,
            (schema.garments || []).map(g => new Garment(g.id, g.originalUrl, g.category, g.createdAt, g.deletedAt)),
            schema.createdAt,
            schema.deletedAt
        );
    }
}

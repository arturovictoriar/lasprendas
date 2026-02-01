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
        schema.originalUrl = garment.originalUrl;
        schema.category = garment.category;
        schema.userId = garment.userId;

        const saved = await this.repository.save(schema);
        return this.mapToEntity(saved);
    }

    async delete(id: string, userId: string): Promise<void> {
        await this.repository.update({ id, userId }, { deletedAt: new Date() });
    }

    private mapToEntity(schema: GarmentSchema): Garment {
        return new Garment(schema.originalUrl, schema.category, schema.createdAt, schema.userId, schema.deletedAt, schema.id);
    }

    async findById(id: string, userId: string): Promise<Garment | null> {
        const found = await this.repository.findOneBy({ id, userId });
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
}

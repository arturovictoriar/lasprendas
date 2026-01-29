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

        const saved = await this.repository.save(schema);
        return this.mapToEntity(saved);
    }

    async delete(id: string): Promise<void> {
        await this.repository.update(id, { deletedAt: new Date() });
    }

    private mapToEntity(schema: GarmentSchema): Garment {
        return new Garment(schema.id, schema.originalUrl, schema.category, schema.createdAt, schema.deletedAt);
    }

    async findById(id: string): Promise<Garment | null> {
        const found = await this.repository.findOneBy({ id });
        if (!found) return null;
        return this.mapToEntity(found);
    }

    async findAll(): Promise<Garment[]> {
        const garments = await this.repository.find({
            where: { deletedAt: IsNull() },
            order: { createdAt: 'DESC' }
        });
        return garments.map(g => this.mapToEntity(g));
    }
}

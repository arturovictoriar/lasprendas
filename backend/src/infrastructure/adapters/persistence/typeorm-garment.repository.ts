import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
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
        return new Garment(saved.id, saved.originalUrl, saved.category, saved.createdAt);
    }

    async findById(id: string): Promise<Garment | null> {
        const found = await this.repository.findOneBy({ id });
        if (!found) return null;
        return new Garment(found.id, found.originalUrl, found.category, found.createdAt);
    }

    async findAll(): Promise<Garment[]> {
        const list = await this.repository.find();
        return list.map(item => new Garment(item.id, item.originalUrl, item.category, item.createdAt));
    }
}

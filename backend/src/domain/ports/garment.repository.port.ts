import { Garment } from '../entities/garment.entity';

export interface IGarmentRepository {
    save(garment: Garment): Promise<Garment>;
    findById(id: string, userId: string): Promise<Garment | null>;
    findByHash(hash: string, userId: string): Promise<Garment | null>;
    findAll(userId: string): Promise<Garment[]>;
    delete(id: string, userId: string): Promise<void>;
}

export const I_GARMENT_REPOSITORY = 'IGarmentRepository';

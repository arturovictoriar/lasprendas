import { Garment } from '../entities/garment.entity';

export interface IGarmentRepository {
    save(garment: Garment): Promise<Garment>;
    findById(id: string): Promise<Garment | null>;
    findAll(): Promise<Garment[]>;
}

export const I_GARMENT_REPOSITORY = 'IGarmentRepository';

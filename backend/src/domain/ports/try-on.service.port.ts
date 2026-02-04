import { TryOnResult } from '../entities/try-on-result.entity';
import { Garment } from '../entities/garment.entity';

export interface ITryOnService {
    performTryOn(mannequinBuffer: Buffer, garmentBuffers: Buffer[], prompt: string): Promise<Buffer>;
}

export const I_TRY_ON_SERVICE = 'ITryOnService';

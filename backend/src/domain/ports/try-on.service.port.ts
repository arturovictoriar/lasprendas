import { TryOnResult } from '../entities/try-on-result.entity';
import { Garment } from '../entities/garment.entity';

export interface ITryOnService {
    performTryOn(mannequinPath: string, garments: Garment[], prompt: string): Promise<string>; // returns the result image path
}

export const I_TRY_ON_SERVICE = 'ITryOnService';

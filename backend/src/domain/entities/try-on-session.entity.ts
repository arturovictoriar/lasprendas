import { Garment } from './garment.entity';

export class TryOnSession {
    constructor(
        public readonly mannequinUrl: string,
        public resultUrl: string | null,
        public readonly garments: Garment[],
        public readonly createdAt: Date,
        public readonly deletedAt: Date | null = null,
        public readonly id?: string,
    ) { }
}

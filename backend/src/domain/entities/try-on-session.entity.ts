import { Garment } from './garment.entity';

export class TryOnSession {
    constructor(
        public readonly id: string | null,
        public readonly mannequinUrl: string,
        public readonly resultUrl: string | null,
        public readonly garments: Garment[],
        public readonly createdAt: Date,
    ) { }
}

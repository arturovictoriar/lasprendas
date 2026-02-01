export class Garment {
    constructor(
        public readonly originalUrl: string,
        public readonly category: string,
        public readonly createdAt: Date,
        public readonly deletedAt: Date | null = null,
        public readonly id?: string,
    ) { }
}

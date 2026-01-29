export class Garment {
    constructor(
        public readonly id: string | null,
        public readonly originalUrl: string,
        public readonly category: string,
        public readonly createdAt: Date,
        public readonly deletedAt: Date | null = null
    ) { }
}

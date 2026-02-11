export class Garment {
    constructor(
        public readonly originalUrl: string,
        public readonly createdAt: Date,
        public readonly userId: string,
        public metadata: any | null = null,
        public embedding: number[] | null = null,
        public readonly deletedAt: Date | null = null,
        public readonly id: string | undefined = undefined,
        public readonly hash: string | undefined = undefined,
    ) { }
}

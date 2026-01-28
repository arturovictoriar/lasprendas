export class TryOnResult {
    constructor(
        public readonly id: string,
        public readonly garmentId: string,
        public readonly resultUrl: string,
        public readonly promptUsed: string,
        public readonly createdAt: Date,
    ) { }
}

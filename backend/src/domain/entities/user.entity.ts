export class User {
    constructor(
        public readonly email: string,
        public readonly password: string,
        public readonly name: string,
        public readonly createdAt: Date,
        public readonly id?: string,
    ) { }
}

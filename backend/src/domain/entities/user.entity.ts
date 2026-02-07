export class User {
    constructor(
        public readonly email: string,
        public password: string,
        public readonly name: string,
        public readonly createdAt: Date,
        public readonly id?: string,
        public isVerified: boolean = false,
        public lastCodeSentAt?: Date,
        public verificationAttempts: number = 0,
        public blockedUntil?: Date,
        public termsAcceptedAt?: Date,
    ) { }
}

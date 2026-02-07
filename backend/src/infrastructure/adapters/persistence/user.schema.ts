import { EntitySchema } from 'typeorm';
import { User } from '../../../domain/entities/user.entity';

export const UserSchema = new EntitySchema<User>({
    name: 'User',
    target: User,
    columns: {
        id: {
            type: 'uuid',
            primary: true,
            generated: 'uuid',
        },
        email: {
            type: 'varchar',
            unique: true,
        },
        password: {
            type: 'varchar',
        },
        name: {
            type: 'varchar',
        },
        createdAt: {
            type: 'timestamp',
            createDate: true,
        },
        isVerified: {
            type: 'boolean',
            default: false,
        },
        lastCodeSentAt: {
            type: 'timestamp',
            nullable: true,
        },
        verificationAttempts: {
            type: 'int',
            default: 0,
        },
        blockedUntil: {
            type: 'timestamp',
            nullable: true,
        },
        termsAcceptedAt: {
            type: 'timestamp',
            nullable: true,
        },
    },
});

import { TryOnSession } from '../entities/try-on-session.entity';

export interface ITryOnSessionRepository {
    save(session: TryOnSession): Promise<TryOnSession>;
    findById(id: string, userId: string): Promise<TryOnSession | null>;
    findAll(userId: string): Promise<TryOnSession[]>;
    findUnprocessed(): Promise<TryOnSession[]>;
    delete(id: string, userId: string): Promise<void>;
}

export const I_TRY_ON_SESSION_REPOSITORY = 'ITryOnSessionRepository';

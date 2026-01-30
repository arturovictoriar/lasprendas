import { TryOnSession } from '../entities/try-on-session.entity';

export interface ITryOnSessionRepository {
    save(session: TryOnSession): Promise<TryOnSession>;
    findById(id: string): Promise<TryOnSession | null>;
    findAll(): Promise<TryOnSession[]>;
    delete(id: string): Promise<void>;
}

export const I_TRY_ON_SESSION_REPOSITORY = 'ITryOnSessionRepository';

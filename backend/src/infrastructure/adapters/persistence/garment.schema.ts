import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

@Entity('garments')
export class GarmentSchema {
    @PrimaryGeneratedColumn('uuid')
    id: string;

    @Column()
    originalUrl: string;

    @Column()
    userId: string;

    @CreateDateColumn()
    createdAt: Date;

    @Column({ type: 'text', nullable: true })
    hash: string | null;

    @Column({ type: 'jsonb', nullable: true })
    metadata: any | null;

    @Column({ type: 'vector', length: 768, nullable: true })
    embedding: number[] | null;

    @Column({ type: 'timestamp', nullable: true })
    deletedAt: Date | null;
}

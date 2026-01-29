import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

@Entity('garments')
export class GarmentSchema {
    @PrimaryGeneratedColumn('uuid')
    id: string;

    @Column()
    originalUrl: string;

    @Column()
    category: string;

    @CreateDateColumn()
    createdAt: Date;

    @Column({ type: 'timestamp', nullable: true })
    deletedAt: Date | null;
}

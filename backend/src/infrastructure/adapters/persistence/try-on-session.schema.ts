import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToMany, JoinTable } from 'typeorm';
import { GarmentSchema } from './garment.schema';

@Entity('try_on_sessions')
export class TryOnSessionSchema {
    @PrimaryGeneratedColumn('uuid')
    id: string;

    @Column()
    mannequinUrl: string;

    @Column({ type: 'varchar', nullable: true })
    resultUrl: string | null;

    @ManyToMany(() => GarmentSchema)
    @JoinTable({
        name: 'session_garments',
        joinColumn: { name: 'session_id', referencedColumnName: 'id' },
        inverseJoinColumn: { name: 'garment_id', referencedColumnName: 'id' }
    })
    garments: GarmentSchema[];

    @CreateDateColumn()
    createdAt: Date;

    @Column({ type: 'timestamp', nullable: true })
    deletedAt: Date | null;
}

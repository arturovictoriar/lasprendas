import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { GarmentSchema } from './infrastructure/adapters/persistence/garment.schema';
import { TypeOrmGarmentRepository } from './infrastructure/adapters/persistence/typeorm-garment.repository';
import { I_GARMENT_REPOSITORY } from './domain/ports/garment.repository.port';
import { I_TRY_ON_SERVICE } from './domain/ports/try-on.service.port';
import { ServeStaticModule } from '@nestjs/serve-static';
import { join } from 'path';
import { GeminiTryOnAdapter } from './infrastructure/adapters/external/gemini-try-on.adapter';
import { VirtualTryOnUseCase } from './application/use-cases/virtual-try-on.use-case';
import { TryOnController } from './infrastructure/controllers/try-on.controller';

@Module({
  imports: [
    ServeStaticModule.forRoot(
      {
        rootPath: join(process.cwd(), 'uploads'),
        serveRoot: '/uploads',
      },
      {
        rootPath: join(process.cwd(), 'results'),
        serveRoot: '/results',
      },
    ),
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '../.env',
    }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        type: 'postgres',
        host: process.env.DATABASE_HOST || 'localhost',
        port: parseInt(process.env.DATABASE_PORT || '5432', 10),
        username: process.env.DATABASE_USER || 'postgres',
        password: process.env.DATABASE_PASSWORD || 'postgres',
        database: process.env.DATABASE_NAME || 'lasprendas',
        entities: [GarmentSchema],
        synchronize: true, // true for dev, use migrations for prod
      }),
    }),
    TypeOrmModule.forFeature([GarmentSchema]),
  ],
  controllers: [TryOnController],
  providers: [
    VirtualTryOnUseCase,
    {
      provide: I_GARMENT_REPOSITORY,
      useClass: TypeOrmGarmentRepository,
    },
    {
      provide: I_TRY_ON_SERVICE,
      useClass: GeminiTryOnAdapter,
    },
  ],
})
export class AppModule { }

import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { PassportModule } from '@nestjs/passport';
import { JwtModule } from '@nestjs/jwt';
import { BullModule } from '@nestjs/bullmq';
import { ThrottlerModule } from '@nestjs/throttler';
import { ServeStaticModule } from '@nestjs/serve-static';
import { join } from 'path';

import { GarmentSchema } from './infrastructure/adapters/persistence/garment.schema';
import { TypeOrmGarmentRepository } from './infrastructure/adapters/persistence/typeorm-garment.repository';
import { I_GARMENT_REPOSITORY } from './domain/ports/garment.repository.port';
import { I_TRY_ON_SERVICE } from './domain/ports/try-on.service.port';
import { GeminiTryOnAdapter } from './infrastructure/adapters/external/gemini-try-on.adapter';
import { VirtualTryOnUseCase } from './application/use-cases/virtual-try-on.use-case';
import { TryOnController } from './infrastructure/controllers/try-on.controller';
import { TryOnSessionSchema } from './infrastructure/adapters/persistence/try-on-session.schema';
import { TypeOrmTryOnSessionRepository } from './infrastructure/adapters/persistence/typeorm-try-on-session.repository';
import { I_TRY_ON_SESSION_REPOSITORY } from './domain/ports/try-on-session.repository.port';
import { ImageProcessorService } from './application/services/image-processor.service';

import { I_STORAGE_SERVICE } from './domain/ports/storage.service.port';
import { S3StorageAdapter } from './infrastructure/adapters/external/s3-storage.adapter';
import { StorageController } from './infrastructure/controllers/storage.controller';

import { UserSchema } from './infrastructure/adapters/persistence/user.schema';
import { I_USER_REPOSITORY } from './domain/ports/user.repository.port';
import { TypeOrmUserRepository } from './infrastructure/adapters/persistence/typeorm-user.repository';
import { AuthService } from './application/services/auth.service';
import { AuthController } from './infrastructure/controllers/auth.controller';
import { JwtStrategy } from './infrastructure/adapters/auth/jwt.strategy';
import { TryOnProcessor } from './application/processors/try-on.processor';
import { RedisService } from './infrastructure/adapters/persistence/redis.service';
import { MailService } from './infrastructure/adapters/mail/mail.service';
import { I_AI_METADATA_SERVICE } from './domain/ports/ai-metadata.service.port';
import { GeminiAiMetadataAdapter } from './infrastructure/adapters/external/gemini-ai-metadata.adapter';
import { GarmentAnalysisProcessor } from './infrastructure/adapters/queue/garment-analysis.processor';
import { I_SEARCH_SERVICE } from './domain/ports/search.service.port';
import { TypeOrmSearchAdapter } from './infrastructure/adapters/persistence/typeorm-search.adapter';
import { FilterController } from './infrastructure/controllers/filter.controller';
import { GarmentSyncScheduler } from './infrastructure/adapters/queue/garment-sync.scheduler';
import { SessionAnalysisProcessor } from './infrastructure/adapters/queue/session-analysis.processor';
import { SessionSyncScheduler } from './infrastructure/adapters/queue/session-sync.scheduler';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '../.env',
    }),
    ServeStaticModule.forRoot({
      rootPath: join(process.cwd(), 'assets'),
      serveRoot: '/assets',
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
        entities: [GarmentSchema, TryOnSessionSchema, UserSchema],
        synchronize: configService.get<string>('DB_SYNCHRONIZE') !== 'false',
      }),
    }),
    TypeOrmModule.forFeature([GarmentSchema, TryOnSessionSchema, UserSchema]),
    PassportModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_SECRET') || 'defaultSecret',
        signOptions: { expiresIn: '7d' },
      }),
    }),
    BullModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        connection: {
          host: configService.get<string>('REDIS_HOST') || 'localhost',
          port: configService.get<number>('REDIS_PORT') || 6379,
        },
      }),
    }),
    BullModule.registerQueue({
      name: 'try-on',
    }),
    BullModule.registerQueue({
      name: 'garment-analysis',
    }),
    BullModule.registerQueue({
      name: 'session-analysis',
    }),
    ThrottlerModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => [
        {
          ttl: 60000,
          limit: 10,
        },
      ],
    }),
  ],
  controllers: [TryOnController, AuthController, StorageController, FilterController],
  providers: [
    VirtualTryOnUseCase,
    AuthService,
    JwtStrategy,
    ...(process.env.ENABLE_WORKER === 'true' ? [TryOnProcessor, GarmentAnalysisProcessor, GarmentSyncScheduler, SessionAnalysisProcessor, SessionSyncScheduler] : []),
    {
      provide: I_GARMENT_REPOSITORY,
      useClass: TypeOrmGarmentRepository,
    },
    {
      provide: I_TRY_ON_SERVICE,
      useClass: GeminiTryOnAdapter,
    },
    {
      provide: I_TRY_ON_SESSION_REPOSITORY,
      useClass: TypeOrmTryOnSessionRepository,
    },
    {
      provide: I_USER_REPOSITORY,
      useClass: TypeOrmUserRepository,
    },
    {
      provide: I_STORAGE_SERVICE,
      useClass: S3StorageAdapter,
    },
    {
      provide: I_SEARCH_SERVICE,
      useClass: TypeOrmSearchAdapter,
    },
    {
      provide: I_AI_METADATA_SERVICE,
      useClass: GeminiAiMetadataAdapter,
    },
    ImageProcessorService,
    RedisService,
    MailService,
  ],
})
export class AppModule { }

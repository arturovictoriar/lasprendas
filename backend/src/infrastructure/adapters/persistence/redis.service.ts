import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
    private client: Redis;

    constructor(private readonly configService: ConfigService) { }

    onModuleInit() {
        this.client = new Redis({
            host: this.configService.get<string>('REDIS_HOST') || 'localhost',
            port: this.configService.get<number>('REDIS_PORT') || 6379,
        });
    }

    async setWithTTL(key: string, value: string, ttlSeconds: number): Promise<void> {
        await this.client.set(key, value, 'EX', ttlSeconds);
    }

    async get(key: string): Promise<string | null> {
        return await this.client.get(key);
    }

    async delete(key: string): Promise<void> {
        await this.client.del(key);
    }

    onModuleDestroy() {
        this.client.disconnect();
    }
}

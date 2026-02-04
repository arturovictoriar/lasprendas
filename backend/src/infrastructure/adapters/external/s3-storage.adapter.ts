import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
    S3Client,
    PutObjectCommand,
    GetObjectCommand,
    DeleteObjectCommand
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { IStorageService, StorageUploadParams } from '../../../domain/ports/storage.service.port';
import { Readable } from 'stream';

@Injectable()
export class S3StorageAdapter implements IStorageService {
    private readonly s3Client: S3Client;
    private readonly bucket: string;
    private readonly prefix: string = '';
    private readonly endpointUrl: string;

    constructor(private readonly configService: ConfigService) {
        const fullBucket = this.configService.get<string>('S3_BUCKET') || 'lasprendas';
        const endpoint = this.configService.get<string>('S3_ENDPOINT') || 'https://nyc3.digitaloceanspaces.com';
        const accessKeyId = this.configService.get<string>('S3_ACCESS_KEY');
        const secretAccessKey = this.configService.get<string>('S3_SECRET_KEY');
        const region = this.configService.get<string>('S3_REGION') || 'nyc3';

        // Handle bucket names like "lasprendas/beta"
        if (fullBucket.includes('/')) {
            const parts = fullBucket.split('/');
            this.bucket = parts[0];
            this.prefix = parts.slice(1).join('/');
        } else {
            this.bucket = fullBucket;
        }

        this.endpointUrl = endpoint.endsWith('/') ? endpoint.slice(0, -1) : endpoint;

        this.s3Client = new S3Client({
            endpoint: this.endpointUrl,
            region: region,
            credentials: {
                accessKeyId: accessKeyId || '',
                secretAccessKey: secretAccessKey || '',
            },
            // DO Spaces works better with forcePathStyle: false (virtual-host style)
            // but for some configurations it might be needed. 
            // Defaulting to what usually works for DO.
            forcePathStyle: false,
        });
    }

    private getFullKey(key: string): string {
        return this.prefix ? `${this.prefix}/${key}`.replace(/\/+/g, '/') : key;
    }

    async getUploadParams(fileName: string, mimeType: string): Promise<StorageUploadParams> {
        const baseKey = `uploads/${Date.now()}-${fileName}`;
        const fullKey = this.getFullKey(baseKey);

        try {
            const command = new PutObjectCommand({
                Bucket: this.bucket,
                Key: fullKey,
                ContentType: mimeType,
                ACL: 'public-read', // Direct access if needed, or omit if using CloudFront/Private
            });

            const uploadUrl = await getSignedUrl(this.s3Client, command, { expiresIn: 3600 });

            // Build the download URL (Public DO Spaces URL format)
            // Format: https://bucket.region.digitaloceanspaces.com/key
            // If the endpoint is already https://region.digitaloceanspaces.com, 
            // the bucket is usually prepended or part of the path depending on forcePathStyle.
            const baseUrl = this.endpointUrl.replace('https://', `https://${this.bucket}.`);
            const downloadUrl = `${baseUrl}/${fullKey}`;

            return {
                uploadUrl,
                downloadUrl,
                key: fullKey
            };
        } catch (error) {
            console.error('[S3StorageAdapter] Error generating presigned URL:', error);
            throw new InternalServerErrorException('No se pudo generar el permiso de subida');
        }
    }

    getFileUrl(key: string): string {
        const baseUrl = this.endpointUrl.replace('https://', `https://${this.bucket}.`);
        return `${baseUrl}/${key}`;
    }

    async deleteFile(key: string): Promise<void> {
        try {
            const command = new DeleteObjectCommand({
                Bucket: this.bucket,
                Key: key,
            });
            await this.s3Client.send(command);
        } catch (error) {
            console.error('[S3StorageAdapter] Error deleting file:', error);
        }
    }

    async uploadFile(key: string, body: Buffer, mimeType: string): Promise<string> {
        try {
            const fullKey = this.getFullKey(key);
            const command = new PutObjectCommand({
                Bucket: this.bucket,
                Key: fullKey,
                Body: body,
                ContentType: mimeType,
                ACL: 'public-read',
            });
            await this.s3Client.send(command);
            return this.getFileUrl(fullKey);
        } catch (error) {
            console.error('[S3StorageAdapter] Error uploading file:', error);
            throw new InternalServerErrorException('Error al subir el archivo a S3');
        }
    }

    async getFileBuffer(key: string): Promise<Buffer> {
        try {
            const command = new GetObjectCommand({
                Bucket: this.bucket,
                Key: key,
            });
            const response = await this.s3Client.send(command);
            const stream = response.Body as Readable;

            return new Promise((resolve, reject) => {
                const chunks: Buffer[] = [];
                stream.on('data', (chunk) => chunks.push(Buffer.from(chunk)));
                stream.on('error', (err) => reject(err));
                stream.on('end', () => resolve(Buffer.concat(chunks)));
            });
        } catch (error) {
            console.error('[S3StorageAdapter] Error reading file from S3:', error);
            throw new InternalServerErrorException('Error al leer el archivo de S3');
        }
    }

    getKeyFromUrl(url: string): string {
        try {
            const parsedUrl = new URL(url);
            // URL format: https://bucket.region.digitaloceanspaces.com/prefix/uploads/key
            // or https://region.digitaloceanspaces.com/bucket/prefix/uploads/key

            // For DO Spaces with virtual hosting: pathname is /prefix/uploads/key
            let key = parsedUrl.pathname;
            if (key.startsWith('/')) {
                key = key.substring(1);
            }

            // If the bucket name is the first part of pathname (path-style), remove it
            if (key.startsWith(`${this.bucket}/`)) {
                key = key.substring(this.bucket.length + 1);
            }

            return key;
        } catch (e) {
            // Fallback for non-standard URLs
            return url.split('/').slice(3).join('/');
        }
    }
}

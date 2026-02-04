export interface StorageUploadParams {
    uploadUrl: string;
    downloadUrl: string;
    key: string;
}

export interface IStorageService {
    getUploadParams(fileName: string, mimeType: string): Promise<StorageUploadParams>;
    getFileUrl(key: string): string;
    deleteFile(key: string): Promise<void>;
    uploadFile(key: string, body: Buffer, mimeType: string): Promise<string>;
    getFileBuffer(key: string): Promise<Buffer>;
    getKeyFromUrl(url: string): string;
}

export const I_STORAGE_SERVICE = 'I_STORAGE_SERVICE';

import { Controller, Post, UploadedFile, UseInterceptors, Body } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { VirtualTryOnUseCase } from '../../application/use-cases/virtual-try-on.use-case';
import { diskStorage } from 'multer';
import { extname } from 'path';

@Controller('try-on')
export class TryOnController {
    constructor(private readonly virtualTryOnUseCase: VirtualTryOnUseCase) { }

    @Post()
    @UseInterceptors(FileInterceptor('image', {
        storage: diskStorage({
            destination: './uploads',
            filename: (req, file, cb) => {
                const randomName = Array(32).fill(null).map(() => (Math.round(Math.random() * 16)).toString(16)).join('');
                cb(null, `${randomName}${extname(file.originalname)}`);
            }
        })
    }))
    async uploadGarment(
        @UploadedFile() file: Express.Multer.File,
        @Body('category') category: string
    ) {
        const resultPath = await this.virtualTryOnUseCase.execute(file.path, category || 'clothing');
        return {
            success: true,
            resultPath: resultPath,
            originalPath: file.path
        };
    }
}

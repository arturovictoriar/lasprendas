import { Controller, Post, UploadedFiles, UseInterceptors, Body } from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { VirtualTryOnUseCase } from '../../application/use-cases/virtual-try-on.use-case';
import { diskStorage } from 'multer';
import { extname } from 'path';

@Controller('try-on')
export class TryOnController {
    constructor(private readonly virtualTryOnUseCase: VirtualTryOnUseCase) { }

    @Post()
    @UseInterceptors(FilesInterceptor('images', 4, {
        storage: diskStorage({
            destination: './uploads',
            filename: (req, file, cb) => {
                const randomName = Array(32).fill(null).map(() => (Math.round(Math.random() * 16)).toString(16)).join('');
                cb(null, `${randomName}${extname(file.originalname)}`);
            }
        })
    }))
    async uploadGarment(
        @UploadedFiles() files: Express.Multer.File[],
        @Body('category') category: string
    ) {
        const filePaths = files.map(f => f.path);
        const resultPath = await this.virtualTryOnUseCase.execute(filePaths, category || 'clothing');
        return {
            success: true,
            resultPath: resultPath,
            originalPaths: filePaths
        };
    }
}

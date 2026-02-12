import { Controller, Get, Query, Request, UseGuards } from '@nestjs/common';
import { I_SEARCH_SERVICE } from '../../domain/ports/search.service.port';
import type { ISearchService } from '../../domain/ports/search.service.port';
import { Inject } from '@nestjs/common';
import { JwtAuthGuard } from '../adapters/auth/jwt-auth.guard';

@Controller('filter')
export class FilterController {
    constructor(
        @Inject(I_SEARCH_SERVICE)
        private readonly searchService: ISearchService,
    ) { }

    @UseGuards(JwtAuthGuard)
    @Get('smart-search')
    async smartSearch(
        @Query('q') query: string,
        @Query('color') colorHex: string,
        @Query('category') category: string,
        @Query('subcategory') subcategory: string,
        @Request() req: any,
    ) {
        const userId = req.user.userId;

        const results = await this.searchService.searchGarments({
            query,
            colorHex,
            category,
            subcategory,
            userId,
        });

        return results;
    }

    @UseGuards(JwtAuthGuard)
    @Get('smart-search-sessions')
    async smartSearchSessions(
        @Query('q') query: string,
        @Query('category') category: string,
        @Request() req: any,
    ) {
        const userId = req.user.userId;
        return this.searchService.searchSessions({
            query,
            category,
            userId,
        });
    }
}

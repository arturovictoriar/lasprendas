import { Garment } from '../entities/garment.entity';

export interface SearchFilters {
    query?: string;
    colorHex?: string;
    category?: string;
    subcategory?: string;
    userId: string;
}

export const I_SEARCH_SERVICE = 'I_SEARCH_SERVICE';

export interface ISearchService {
    searchGarments(filters: SearchFilters): Promise<Garment[]>;
    searchSessions(filters: SearchFilters): Promise<any[]>;
}

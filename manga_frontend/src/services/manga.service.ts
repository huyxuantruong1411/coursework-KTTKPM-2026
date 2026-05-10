import { api, compactParams } from "./api";
import type { PaginatedResponse, UUID } from "@/types/common";
import type {
  AdvancedSearchParams,
  MangaDetail,
  MangaListItem,
  MangaListParams,
  RelatedManga,
} from "@/types/manga";

export const mangaService = {
  async list(params?: MangaListParams) {
    const { data } = await api.get<PaginatedResponse<MangaListItem>>("/mangas/", {
      params: compactParams(params),
    });
    return data;
  },

  async search(q: string, limit = 10) {
    const { data } = await api.get<MangaListItem[]>("/mangas/search", {
      params: { q, limit },
    });
    return data;
  },

  async advancedSearch(params?: AdvancedSearchParams) {
    const { data } = await api.get<PaginatedResponse<MangaListItem>>("/mangas/advanced-search", {
      params: compactParams(params),
    });
    return data;
  },

  async random() {
    const { data } = await api.get<MangaListItem | { message: string }>("/mangas/random");
    return data;
  },

  async recentlyAdded(page = 1, limit = 12) {
    const { data } = await api.get<PaginatedResponse<MangaListItem>>("/mangas/recently-added", {
      params: { page, limit },
    });
    return data;
  },

  async latestUpdates(page = 1, limit = 12, inMyLists = false) {
    const { data } = await api.get<{
      items: MangaListItem[];
      page: number;
      per_page: number;
      total: number;
      total_pages: number;
    }>("/mangas/latest-updates", {
      params: { page, limit, in_my_lists: inMyLists },
    });
    return data;
  },

  async detail(mangaId: UUID) {
    const { data } = await api.get<MangaDetail>(`/mangas/${mangaId}`);
    return data;
  },

  async related(mangaId: UUID) {
    const { data } = await api.get<RelatedManga[]>(`/mangas/${mangaId}/related`);
    return data;
  },
};

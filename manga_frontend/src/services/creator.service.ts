import { api } from "./api";
import type { MangaListItem } from "@/types/manga";

export interface CreatorProfile {
  id: string;
  name: string;
  image_url: string | null;
  biography: string | null;
  created_at: string | null;
}

export interface CreatorDetailResponse {
  creator: CreatorProfile;
  mangas: {
    items: MangaListItem[];
    page: number;
    per_page: number;
    total: number;
    total_pages: number;
  };
}

export const creatorService = {
  async getCreator(id: string, page = 1, limit = 20) {
    const { data } = await api.get<CreatorDetailResponse>(`/creators/${id}`, {
      params: { page, limit },
    });
    return data;
  },
};

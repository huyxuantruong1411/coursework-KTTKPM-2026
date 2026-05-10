import { api, compactParams } from "./api";
import type { UUID } from "@/types/common";
import type { Chapter, ChapterListParams, ChapterNav } from "@/types/chapter";

export const chapterService = {
  async list(mangaId: UUID, params?: ChapterListParams) {
    const { data } = await api.get<Chapter[]>(`/manga/${mangaId}/chapters`, {
      params: compactParams(params),
    });
    return data;
  },

  async languages(mangaId: UUID) {
    const { data } = await api.get<string[]>(`/manga/${mangaId}/languages`);
    return data;
  },

  async detail(mangaId: UUID, chapterId: UUID) {
    const { data } = await api.get<ChapterNav>(`/manga/${mangaId}/chapters/${chapterId}`);
    return data;
  },
};

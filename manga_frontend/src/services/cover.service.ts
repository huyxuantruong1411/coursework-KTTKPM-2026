import { api } from "./api";
import type { UUID } from "@/types/common";
import type { Cover } from "@/types/manga";

export const coverService = {
  async primary(mangaId: UUID) {
    const { data } = await api.get<Cover>(`/covers/manga/${mangaId}`);
    return data ?? null;
  },

  async all(mangaId: UUID) {
    const { data } = await api.get<Cover[]>(`/covers/manga/${mangaId}/all`);
    return data ?? [];
  },
};

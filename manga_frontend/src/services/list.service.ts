import { api, compactParams } from "./api";
import type { PaginatedResponse, UUID } from "@/types/common";
import type {
  ListCreatePayload,
  ListUpdatePayload,
  MangaListCollection,
  MangaListDetail,
  PublicListItem,
} from "@/types/list";

export const listService = {
  async mine(mangaId?: UUID) {
    const { data } = await api.get<MangaListCollection>("/lists/", {
      params: compactParams({ manga_id: mangaId }),
    });
    return data;
  },

  async create(payload: ListCreatePayload) {
    const { data } = await api.post<{ id: UUID; slug: string }>("/lists/", payload);
    return data;
  },

  async publicLists(params?: { page?: number; limit?: number; sort?: string; q?: string }) {
    const { data } = await api.get<PaginatedResponse<PublicListItem>>("/lists/public", {
      params: compactParams(params),
    });
    return data;
  },

  async detail(listId: UUID) {
    const { data } = await api.get<MangaListDetail>(`/lists/${listId}`);
    return data;
  },

  async update(listId: UUID, payload: ListUpdatePayload) {
    const { data } = await api.put<{ success: boolean }>(`/lists/${listId}`, payload);
    return data;
  },

  async remove(listId: UUID) {
    await api.delete(`/lists/${listId}`);
  },

  async addItem(listId: UUID, mangaId: UUID) {
    const { data } = await api.post<{ success?: boolean; message?: string; item_count: number }>(
      `/lists/${listId}/items`,
      null,
      { params: { manga_id: mangaId } },
    );
    return data;
  },

  async removeItem(listId: UUID, mangaId: UUID) {
    const { data } = await api.delete<{ success: boolean; item_count: number }>(
      `/lists/${listId}/items/${mangaId}`,
    );
    return data;
  },

  async follow(listId: UUID) {
    const { data } = await api.post<{ success?: boolean; message?: string; follower_count?: number }>(
      `/lists/${listId}/follow`,
    );
    return data;
  },

  async unfollow(listId: UUID) {
    const { data } = await api.delete<{ success?: boolean; message?: string; follower_count?: number }>(
      `/lists/${listId}/follow`,
    );
    return data;
  },
};

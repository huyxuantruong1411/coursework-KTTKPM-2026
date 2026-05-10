import { api } from "./api";
import type { PaginatedResponse, UUID } from "@/types/common";
import type { ContinueReadingResponse, GroupedHistoryResponse, HistoryCreatePayload, HistoryEntry } from "@/types/history";

export const historyService = {
  async record(payload: HistoryCreatePayload) {
    const { data } = await api.post<{ success: boolean }>("/history/", payload);
    return data;
  },

  async list(page = 1, limit = 20) {
    const { data } = await api.get<PaginatedResponse<HistoryEntry>>("/history/", {
      params: { page, limit },
    });
    return data;
  },

  async grouped(limit = 100) {
    const { data } = await api.get<GroupedHistoryResponse>("/history/grouped", {
      params: { limit },
    });
    return data;
  },

  async continueReading(mangaId: UUID) {
    const { data } = await api.get<ContinueReadingResponse>(`/history/manga/${mangaId}/continue`);
    return data;
  },
};

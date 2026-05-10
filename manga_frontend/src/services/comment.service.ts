import { api } from "./api";
import type { PaginatedResponse, UUID } from "@/types/common";
import type {
  Comment,
  CommentCreatePayload,
  CommentReactionResponse,
  CommentUpdatePayload,
  ReportCreatePayload,
} from "@/types/comment";

export const commentService = {
  async list(mangaId: UUID, page = 1, limit = 20) {
    const { data } = await api.get<PaginatedResponse<Comment>>(`/comments/manga/${mangaId}/comments`, {
      params: { page, limit },
    });
    return data;
  },

  async create(mangaId: UUID, payload: CommentCreatePayload) {
    const { data } = await api.post<{ success: boolean; comment: Comment }>(
      `/comments/manga/${mangaId}/comments`,
      payload,
    );
    return data;
  },

  async update(commentId: UUID, payload: CommentUpdatePayload) {
    const { data } = await api.put<{ success: boolean; content: string; updated_at: string }>(
      `/comments/${commentId}`,
      payload,
    );
    return data;
  },

  async remove(commentId: UUID) {
    const { data } = await api.delete<{ success: boolean }>(`/comments/${commentId}`);
    return data;
  },

  async like(commentId: UUID) {
    const { data } = await api.post<CommentReactionResponse>(`/comments/${commentId}/like`);
    return data;
  },

  async dislike(commentId: UUID) {
    const { data } = await api.post<CommentReactionResponse>(`/comments/${commentId}/dislike`);
    return data;
  },

  async report(commentId: UUID, payload: ReportCreatePayload) {
    const { data } = await api.post<{ success: boolean }>(`/comments/${commentId}/report`, payload);
    return data;
  },
};

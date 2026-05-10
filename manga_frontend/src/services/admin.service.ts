import { api, compactParams } from "./api";
import type { UUID } from "@/types/common";
import type { AdminDashboard, AdminUserPage, ReportedCommentPage } from "@/types/admin";

export const adminService = {
  async dashboard(params?: { start_date?: string; end_date?: string }) {
    const { data } = await api.get<AdminDashboard>("/admin/dashboard", {
      params: compactParams(params),
    });
    return data;
  },

  async users(params?: { page?: number; limit?: number; q?: string }) {
    const { data } = await api.get<AdminUserPage>("/admin/users", {
      params: compactParams(params),
    });
    return data;
  },

  async banUser(userId: UUID) {
    const { data } = await api.post<{ success: boolean; message: string }>(`/admin/users/${userId}/ban`);
    return data;
  },

  async unbanUser(userId: UUID) {
    const { data } = await api.post<{ success: boolean; message: string }>(`/admin/users/${userId}/unban`);
    return data;
  },

  async reportedComments(params?: { page?: number; limit?: number; status?: string }) {
    const { data } = await api.get<ReportedCommentPage>("/admin/comments", {
      params: compactParams(params),
    });
    return data;
  },

  async deleteComment(commentId: UUID) {
    const { data } = await api.post<{ success: boolean }>(`/admin/comments/${commentId}/delete`);
    return data;
  },

  async ignoreComment(commentId: UUID) {
    const { data } = await api.post<{ success: boolean }>(`/admin/comments/${commentId}/ignore`);
    return data;
  },
};

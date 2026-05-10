import type { PaginatedResponse, UUID } from "./common";
import type { User } from "./user";

export interface AdminTotals {
  users: number;
  manga: number;
  pending_reports: number;
}

export interface TopMangaReport {
  manga_id: UUID;
  title?: string | null;
  readers: number;
}

export interface AdminDashboard {
  new_users_by_date: Record<string, number>;
  reading_activity_by_date: Record<string, number>;
  top_manga: TopMangaReport[];
  totals: AdminTotals;
  date_range: {
    start: string;
    end: string;
  };
}

export interface ReportedComment {
  comment_id: UUID;
  content?: string | null;
  username?: string | null;
  manga_title?: string | null;
  report_count: number;
  created_at?: string | null;
}

export type AdminUserPage = PaginatedResponse<User>;
export type ReportedCommentPage = PaginatedResponse<ReportedComment>;

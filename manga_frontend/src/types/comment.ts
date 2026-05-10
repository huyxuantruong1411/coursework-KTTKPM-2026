import type { UUID } from "./common";

export interface Comment {
  CommentId: UUID;
  UserId: UUID;
  MangaId: UUID;
  Username?: string | null;
  Avatar?: string | null;
  Content?: string | null;
  IsSpoiler: boolean;
  LikeCount: number;
  DislikeCount: number;
  IsDeleted?: boolean | null;
  CreatedAt?: string | null;
  UpdatedAt?: string | null;
}

export interface CommentCreatePayload {
  Content: string;
  ChapterId?: UUID | null;
  IsSpoiler?: boolean;
}

export interface CommentUpdatePayload {
  Content: string;
}

export interface CommentReactionResponse {
  success: boolean;
  like_count: number;
  dislike_count: number;
}

export interface ReportCreatePayload {
  Reason: string;
}

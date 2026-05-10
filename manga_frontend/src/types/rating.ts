import type { UUID } from "./common";

export interface Rating {
  RatingId?: UUID;
  UserId?: UUID;
  MangaId?: UUID;
  Score?: number | null;
  score?: number | null;
}

export interface RatingCreatePayload {
  Score: number;
}

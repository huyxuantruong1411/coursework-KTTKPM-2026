import { api } from "./api";
import type { UUID } from "@/types/common";
import type { Rating, RatingCreatePayload } from "@/types/rating";

export const ratingService = {
  async rate(mangaId: UUID, payload: RatingCreatePayload) {
    const { data } = await api.post<Rating>(`/ratings/manga/${mangaId}/rate`, payload);
    return data;
  },

  async myRating(mangaId: UUID) {
    const { data } = await api.get<Rating>(`/ratings/manga/${mangaId}/my-rating`);
    return data;
  },
};

"""Collaborative Filtering Recommendation Service.

Uses user-based collaborative filtering with cosine similarity
to recommend manga based on rating patterns of similar users.
"""
import uuid
import time
from typing import Optional

import numpy as np
from scipy.sparse import csr_matrix
from scipy.spatial.distance import cosine

from sqlalchemy import func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.models.models import Rating, Manga


# Cache for the similarity matrix
_cache: dict[str, tuple] = {}
_CACHE_TTL = 3600  # Refresh every hour


class CollaborativeFilteringService:
    """User-based collaborative filtering using rating matrix."""

    def __init__(self):
        self._user_ids: list[uuid.UUID] = []
        self._manga_ids: list[uuid.UUID] = []
        self._user_index: dict[uuid.UUID, int] = {}
        self._manga_index: dict[uuid.UUID, int] = {}
        self._rating_matrix: Optional[np.ndarray] = None
        self._built_at: float = 0

    async def _build_matrix(self, db: AsyncSession):
        """Build the user-item rating matrix from the database."""
        now = time.time()
        if self._rating_matrix is not None and (now - self._built_at) < _CACHE_TTL:
            return  # Use cached matrix

        # Fetch all ratings
        result = await db.execute(select(Rating.UserId, Rating.MangaId, Rating.Score))
        ratings = result.all()

        if not ratings:
            self._rating_matrix = None
            return

        # Build index maps
        user_set = sorted(set(r.UserId for r in ratings))
        manga_set = sorted(set(r.MangaId for r in ratings))

        self._user_ids = user_set
        self._manga_ids = manga_set
        self._user_index = {uid: i for i, uid in enumerate(user_set)}
        self._manga_index = {mid: i for i, mid in enumerate(manga_set)}

        # Build sparse matrix
        n_users = len(user_set)
        n_manga = len(manga_set)
        matrix = np.zeros((n_users, n_manga), dtype=np.float32)

        for r in ratings:
            ui = self._user_index[r.UserId]
            mi = self._manga_index[r.MangaId]
            matrix[ui][mi] = float(r.Score) if r.Score else 0.0

        self._rating_matrix = matrix
        self._built_at = now

    def _compute_similarity(self, user_idx: int, other_idx: int) -> float:
        """Compute cosine similarity between two users."""
        if self._rating_matrix is None:
            return 0.0
        u = self._rating_matrix[user_idx]
        v = self._rating_matrix[other_idx]
        # Only compare items both users have rated
        mask = (u > 0) & (v > 0)
        if mask.sum() < 2:
            return 0.0
        try:
            return 1 - cosine(u[mask], v[mask])
        except Exception:
            return 0.0

    async def recommend(
        self,
        user_id: uuid.UUID,
        db: AsyncSession,
        k_neighbors: int = 20,
        top_n: int = 20,
    ) -> list[dict]:
        """Generate recommendations for a user using collaborative filtering.

        1. Build/refresh the user-item rating matrix
        2. Find K most similar users
        3. Predict ratings for unrated manga
        4. Return top N recommendations
        """
        await self._build_matrix(db)

        if self._rating_matrix is None or user_id not in self._user_index:
            # Fallback: return popular manga
            return await self._popular_fallback(db, top_n)

        user_idx = self._user_index[user_id]
        n_users = len(self._user_ids)

        # Compute similarity with all other users
        similarities = []
        for other_idx in range(n_users):
            if other_idx == user_idx:
                continue
            sim = self._compute_similarity(user_idx, other_idx)
            if sim > 0.05:  # Minimum similarity threshold
                similarities.append((other_idx, sim))

        # Sort by similarity descending, take top K
        similarities.sort(key=lambda x: x[1], reverse=True)
        neighbors = similarities[:k_neighbors]

        if not neighbors:
            return await self._popular_fallback(db, top_n)

        # Predict ratings for unrated manga
        user_ratings = self._rating_matrix[user_idx]
        predictions = []

        for manga_idx in range(len(self._manga_ids)):
            if user_ratings[manga_idx] > 0:
                continue  # Already rated

            # Weighted average of neighbor ratings
            weighted_sum = 0.0
            sim_sum = 0.0
            for neighbor_idx, sim in neighbors:
                neighbor_rating = self._rating_matrix[neighbor_idx][manga_idx]
                if neighbor_rating > 0:
                    weighted_sum += sim * neighbor_rating
                    sim_sum += abs(sim)

            if sim_sum > 0:
                predicted_rating = weighted_sum / sim_sum
                predictions.append((manga_idx, predicted_rating))

        # Sort by predicted rating descending
        predictions.sort(key=lambda x: x[1], reverse=True)
        top_predictions = predictions[:top_n]

        # Fetch manga details
        results = []
        for manga_idx, predicted_score in top_predictions:
            manga_id = self._manga_ids[manga_idx]
            manga_r = await db.execute(
                select(Manga.TitleEn, Manga.Status, Manga.Year, Manga.ContentRating)
                .where(Manga.MangaId == manga_id)
            )
            row = manga_r.first()
            if row:
                results.append({
                    "manga_id": str(manga_id),
                    "title": row.TitleEn,
                    "status": row.Status,
                    "year": row.Year,
                    "content_rating": row.ContentRating,
                    "predicted_score": round(predicted_score, 2),
                    "source": "collaborative_filtering",
                })

        return results

    async def _popular_fallback(self, db: AsyncSession, top_n: int) -> list[dict]:
        """Fallback: return most popular manga by average rating."""
        result = await db.execute(
            select(
                Rating.MangaId,
                func.avg(Rating.Score).label("avg_score"),
                func.count().label("cnt"),
            )
            .group_by(Rating.MangaId)
            .having(func.count() >= 2)
            .order_by(func.avg(Rating.Score).desc())
            .limit(top_n)
        )
        rows = result.all()

        results = []
        for row in rows:
            manga_r = await db.execute(
                select(Manga.TitleEn, Manga.Status, Manga.Year, Manga.ContentRating)
                .where(Manga.MangaId == row.MangaId)
            )
            m = manga_r.first()
            if m:
                results.append({
                    "manga_id": str(row.MangaId),
                    "title": m.TitleEn,
                    "status": m.Status,
                    "year": m.Year,
                    "content_rating": m.ContentRating,
                    "predicted_score": round(float(row.avg_score), 2),
                    "source": "popularity",
                })

        return results


# Singleton
collab_filter = CollaborativeFilteringService()

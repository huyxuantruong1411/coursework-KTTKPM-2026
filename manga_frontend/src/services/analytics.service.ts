import { api } from "./api";
import type { MangaListItem } from "@/types/manga";

export interface UserStats {
  total_manga: number;
  total_chapters: number;
  total_sessions: number;
  total_pages: number;
  total_ratings: number;
  avg_rating: number | null;
  daily_activity: Array<{ date: string; count: number }>;
  genre_distribution: Array<{ name: string; count: number }>;
  theme_distribution: Array<{ name: string; count: number }>;
  recent_manga: Array<{ manga_id: string; title: string | null }>;
}

export interface RecommendationItem {
  manga_id: string;
  title: string | null;
  status: string | null;
  year: number | null;
  content_rating: string | null;
  predicted_score: number;
  source: "collaborative_filtering" | "popularity";
}

export interface SimilarMangaItem extends MangaListItem {
  score: number;
  relation_type: string;
}

// ─── Helpers ────────────────────────────────────────────────────

/** Pick the best English-ish title from a MangaDex title map. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function pickMdTitle(titleObj: any): string {
  if (!titleObj) return "Unknown";
  return (
    titleObj["en"] ??
    titleObj["ja-ro"] ??
    titleObj["ja"] ??
    (Object.values(titleObj)[0] as string | undefined) ??
    "Unknown"
  );
}

/**
 * Fetch manga details (title + cover) for a list of IDs straight from
 * the public MangaDex API. Returns a map of id → partial SimilarMangaItem.
 */
async function fetchMdDetails(
  ids: string[],
): Promise<Map<string, Partial<SimilarMangaItem>>> {
  const map = new Map<string, Partial<SimilarMangaItem>>();
  if (!ids.length) return map;

  try {
    const query = ids.map((id) => `ids[]=${id}`).join("&");
    const res = await fetch(
      `https://api.mangadex.org/manga?includes[]=cover_art&limit=${ids.length}&${query}`,
      { headers: { accept: "application/json" } },
    );
    if (!res.ok) return map;

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const json = await res.json();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    for (const m of json.data ?? [] as any[]) {
      const attrs = m.attributes ?? {};
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const coverRel = (m.relationships ?? []).find((r: any) => r.type === "cover_art");
      const coverUrl = coverRel?.attributes?.fileName
        ? `https://uploads.mangadex.org/covers/${m.id}/${coverRel.attributes.fileName}.256.jpg`
        : undefined;

      map.set(m.id, {
        TitleEn: pickMdTitle(attrs.title),
        Status: attrs.status ?? undefined,
        Year: attrs.year ?? undefined,
        ContentRating: attrs.contentRating ?? undefined,
        cover_url: coverUrl,
      });
    }
  } catch (e) {
    console.error("[analytics] fetchMdDetails failed", e);
  }
  return map;
}

// ─── Services ───────────────────────────────────────────────────

export const analyticsService = {
  async getUserStats() {
    const { data } = await api.get<UserStats>("/analytics/user-stats");
    return data;
  },
};

export const recommendationService = {
  async getForMe(topN = 20) {
    const { data } = await api.get<{ recommendations: RecommendationItem[]; count: number }>(
      "/recommendations/for-me",
      { params: { top_n: topN } },
    );
    return data;
  },

  async getSimilar(mangaId: string): Promise<{ recommendations: SimilarMangaItem[]; source: string }> {
    // ── Step 1: Try backend endpoint first ────────────────────────
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let backendData: any = { recommendations: [] };
    try {
      const { data } = await api.get<any>(`/recommendations/manga/${mangaId}/similar`);
      backendData = data;
    } catch (e) {
      // Backend may 404 or error — we will fall through to the MangaDex fallback below.
      console.warn("[analytics] Backend /recommendations/manga similar failed, falling back to MangaDex", e);
    }

    let valid: SimilarMangaItem[] = [];

    if (Array.isArray(backendData.recommendations) && backendData.recommendations.length > 0) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      valid = backendData.recommendations.map((r: any) => ({
        MangaId: r.manga_id,
        TitleEn: r.title ?? null,
        cover_url: r.cover_url ?? null,
        Status: r.status ?? null,
        Year: r.year ?? null,
        ContentRating: r.content_rating ?? null,
        score: r.score ?? 0,
        relation_type: r.relation_type ?? "similar",
      }));
    }

    // ── Step 2: Fallback — call MangaDex recommendation API directly ──
    // Triggered when the backend returns nothing (empty DB, endpoint not
    // implemented, or request failed). We call MangaDex from the browser.
    if (valid.length === 0) {
      try {
        const mdRes = await fetch(
          `https://api.mangadex.org/manga/${mangaId}/recommendation` +
          `?order[score]=desc` +
          `&contentRating[]=safe&contentRating[]=suggestive&contentRating[]=erotica`,
          { headers: { accept: "application/json" } },
        );

        if (mdRes.ok) {
          const mdJson = await mdRes.json();

          // Each recommendation entry has two relationships:
          //   [0] = source manga (same as mangaId)
          //   [1] = the recommended manga
          // We want the ID that is NOT mangaId.
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          const scoreMap = new Map<string, number>();
          const recIds: string[] = [];

          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          for (const entry of mdJson.data ?? [] as any[]) {
            const score: number = entry.attributes?.score ?? 0;
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            const otherRel = (entry.relationships ?? [] as any[]).find(
              // eslint-disable-next-line @typescript-eslint/no-explicit-any
              (r: any) => r.type === "manga" && r.id !== mangaId,
            );
            if (otherRel?.id) {
              recIds.push(otherRel.id);
              scoreMap.set(otherRel.id, score);
            }
          }

          if (recIds.length > 0) {
            // Fetch full details (title + cover) for all recommended IDs.
            const detailMap = await fetchMdDetails(recIds.slice(0, 20));

            valid = recIds
              .slice(0, 20)
              .map((id) => {
                const detail = detailMap.get(id) ?? {};
                return {
                  MangaId: id,
                  TitleEn: detail.TitleEn ?? null,
                  cover_url: detail.cover_url ?? null,
                  Status: detail.Status ?? null,
                  Year: detail.Year ?? null,
                  ContentRating: detail.ContentRating ?? null,
                  score: scoreMap.get(id) ?? 0,
                  relation_type: "similar",
                } as SimilarMangaItem;
              })
              .filter((item) => item.TitleEn); // drop items we couldn't resolve
          }
        }
      } catch (e) {
        console.error("[analytics] MangaDex recommendation fallback failed", e);
      }
    }

    // ── Step 3: Enrich any backend items still missing title / cover ──
    // (Only needed when the backend returned items but with incomplete data.)
    const missingIds = valid
      .filter((v) => !v.TitleEn || !v.cover_url)
      .map((v) => v.MangaId);

    if (missingIds.length > 0) {
      const detailMap = await fetchMdDetails(missingIds);
      for (const item of valid) {
        if ((!item.TitleEn || !item.cover_url) && detailMap.has(item.MangaId)) {
          const detail = detailMap.get(item.MangaId)!;
          item.TitleEn = item.TitleEn || detail.TitleEn || null;
          item.cover_url = item.cover_url || detail.cover_url || null;
          item.Status = item.Status || detail.Status || null;
        }
      }
    }

    return {
      recommendations: valid,
      source: backendData.source ?? "mangadex",
    };
  },
};
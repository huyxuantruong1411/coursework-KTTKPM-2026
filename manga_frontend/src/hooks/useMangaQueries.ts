import { useQuery } from "@tanstack/react-query";
import { chapterService } from "@/services/chapter.service";
import { mangaService } from "@/services/manga.service";
import { tagService } from "@/services/tag.service";
import { recommendationService } from "@/services/analytics.service";
import type { UUID } from "@/types/common";
import type { AdvancedSearchParams, MangaListParams } from "@/types/manga";
import type { ChapterListParams } from "@/types/chapter";

export const mangaKeys = {
  all: ["manga"] as const,
  list: (params?: MangaListParams) => [...mangaKeys.all, "list", params] as const,
  latest: (page: number, limit: number, inMyLists: boolean) => [...mangaKeys.all, "latest", page, limit, inMyLists] as const,
  recent: (page: number, limit: number) => [...mangaKeys.all, "recent", page, limit] as const,
  search: (q: string, limit: number) => [...mangaKeys.all, "search", q, limit] as const,
  advanced: (params?: AdvancedSearchParams) => [...mangaKeys.all, "advanced", params] as const,
  detail: (mangaId?: UUID) => [...mangaKeys.all, "detail", mangaId] as const,
  related: (mangaId?: UUID) => [...mangaKeys.all, "related", mangaId] as const,
  chapters: (mangaId?: UUID, params?: ChapterListParams) => [...mangaKeys.all, "chapters", mangaId, params] as const,
  languages: (mangaId?: UUID) => [...mangaKeys.all, "languages", mangaId] as const,
  recommendations: (mangaId?: UUID) => [...mangaKeys.all, "recommendations", mangaId] as const,
  tags: ["tags"] as const,
};

export function useMangaList(params?: MangaListParams) {
  return useQuery({
    queryKey: mangaKeys.list(params),
    queryFn: () => mangaService.list(params),
  });
}

export function useLatestManga(page = 1, limit = 12, inMyLists = false) {
  return useQuery({
    queryKey: mangaKeys.latest(page, limit, inMyLists),
    queryFn: () => mangaService.latestUpdates(page, limit, inMyLists),
  });
}

export function useRecentlyAdded(page = 1, limit = 12) {
  return useQuery({
    queryKey: mangaKeys.recent(page, limit),
    queryFn: () => mangaService.recentlyAdded(page, limit),
  });
}

export function useMangaSearch(q: string, limit = 8) {
  return useQuery({
    queryKey: mangaKeys.search(q, limit),
    queryFn: () => mangaService.search(q, limit),
    enabled: q.trim().length > 0,
  });
}

export function useAdvancedSearch(params?: AdvancedSearchParams) {
  return useQuery({
    queryKey: mangaKeys.advanced(params),
    queryFn: () => mangaService.advancedSearch(params),
  });
}

export function useMangaDetail(mangaId?: UUID) {
  return useQuery({
    queryKey: mangaKeys.detail(mangaId),
    queryFn: () => mangaService.detail(mangaId as UUID),
    enabled: Boolean(mangaId),
  });
}

export function useRelatedManga(mangaId?: UUID) {
  return useQuery({
    queryKey: mangaKeys.related(mangaId),
    queryFn: () => mangaService.related(mangaId as UUID),
    enabled: Boolean(mangaId),
  });
}

export function useMangaRecommendations(mangaId?: UUID) {
  return useQuery({
    queryKey: mangaKeys.recommendations(mangaId),
    queryFn: () => recommendationService.getSimilar(mangaId as string),
    enabled: Boolean(mangaId),
  });
}

export function useChapters(mangaId?: UUID, params?: ChapterListParams) {
  return useQuery({
    queryKey: mangaKeys.chapters(mangaId, params),
    queryFn: () => chapterService.list(mangaId as UUID, params),
    enabled: Boolean(mangaId),
  });
}

export function useChapterLanguages(mangaId?: UUID) {
  return useQuery({
    queryKey: mangaKeys.languages(mangaId),
    queryFn: () => chapterService.languages(mangaId as UUID),
    enabled: Boolean(mangaId),
  });
}

export function useTagGroups() {
  return useQuery({
    queryKey: mangaKeys.tags,
    queryFn: tagService.list,
    staleTime: 1000 * 60 * 15,
  });
}

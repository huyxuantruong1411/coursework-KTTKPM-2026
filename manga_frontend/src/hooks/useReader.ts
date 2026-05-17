import { useCallback, useEffect, useMemo, useState } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { chapterService } from "@/services/chapter.service";
import { historyService } from "@/services/history.service";
import { translateService } from "@/services/translate.service";
import type { UUID } from "@/types/common";

export type TranslateState =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "done"; url: string }
  | { status: "error"; message: string };

export function useReader(mangaId?: UUID, chapterId?: UUID) {
  const [currentPage, setCurrentPage] = useState(1);

  // ── Per-page translation state: pageIndex (1-based) → TranslateState ──
  const [translateStates, setTranslateStates] = useState<Record<number, TranslateState>>({});

  // ── Target language for translation ──────────────────────────────────────
  const [translateLang, setTranslateLang] = useState<string>("vi");

  const chapterQuery = useQuery({
    queryKey: ["reader", mangaId, chapterId],
    queryFn: () => chapterService.detail(mangaId as UUID, chapterId as UUID),
    enabled: Boolean(mangaId && chapterId),
  });

  const recordHistoryMutation = useMutation({
    mutationFn: (lastPage: number) =>
      historyService.record({
        MangaId: mangaId as UUID,
        ChapterId: chapterId as UUID,
        LastPageRead: lastPage,
      }),
  });

  const totalPages = chapterQuery.data?.page_urls.length ?? 0;

  const progress = useMemo(() => {
    if (!totalPages) return 0;
    return Math.round((currentPage / totalPages) * 100);
  }, [currentPage, totalPages]);

  // Reset per-page translation states when chapter changes
  useEffect(() => {
    setCurrentPage(1);
    setTranslateStates({});
  }, [chapterId]);

  useEffect(() => {
    const urls = chapterQuery.data?.page_urls.slice(0, 4) ?? [];
    urls.forEach((url) => {
      const image = new Image();
      image.src = url;
    });
  }, [chapterQuery.data?.page_urls]);

  useEffect(() => {
    if (!mangaId || !chapterId || !totalPages) return;
    const timeout = window.setTimeout(() => {
      recordHistoryMutation.mutate(currentPage);
    }, 900);
    return () => window.clearTimeout(timeout);
  }, [chapterId, currentPage, mangaId, totalPages]);

  const goToPage = useCallback(
    (page: number) => {
      const bounded = Math.min(Math.max(page, 1), Math.max(totalPages, 1));
      setCurrentPage(bounded);
      const element = document.getElementById(`reader-page-${bounded}`);
      element?.scrollIntoView({ behavior: "smooth", block: "start" });
    },
    [totalPages],
  );

  /**
   * Translate a single page (1-based index).
   * If already translated with the same language, does nothing.
   */
  const translatePage = useCallback(
    async (pageIndex: number) => {
      const pageUrls = chapterQuery.data?.page_urls;
      if (!pageUrls || pageIndex < 1 || pageIndex > pageUrls.length) return;

      const currentState = translateStates[pageIndex];
      // Skip if already loading or successfully translated in the same language
      if (currentState?.status === "loading") return;
      if (currentState?.status === "done") return;

      const imageUrl = pageUrls[pageIndex - 1];

      setTranslateStates((prev) => ({
        ...prev,
        [pageIndex]: { status: "loading" },
      }));

      try {
        const result = await translateService.translatePage({
          image_url: imageUrl,
          target_lang: translateLang,
          source_lang: "auto",
        });
        setTranslateStates((prev) => ({
          ...prev,
          [pageIndex]: { status: "done", url: result.translated_url },
        }));
      } catch (err) {
        const message = err instanceof Error ? err.message : "Translation failed";
        setTranslateStates((prev) => ({
          ...prev,
          [pageIndex]: { status: "error", message },
        }));
      }
    },
    [chapterQuery.data?.page_urls, translateLang, translateStates],
  );

  /**
   * Translate all pages of the current chapter sequentially.
   */
  const translateAllPages = useCallback(async () => {
    const pageUrls = chapterQuery.data?.page_urls ?? [];
    for (let i = 1; i <= pageUrls.length; i++) {
      await translatePage(i);
    }
  }, [chapterQuery.data?.page_urls, translatePage]);

  /**
   * Reset translation for a page (revert to original).
   */
  const resetPageTranslation = useCallback((pageIndex: number) => {
    setTranslateStates((prev) => {
      const next = { ...prev };
      delete next[pageIndex];
      return next;
    });
  }, []);

  /**
   * Reset all translations for the current chapter.
   */
  const resetAllTranslations = useCallback(() => {
    setTranslateStates({});
  }, []);

  /**
   * Change target language and clear existing translations so they
   * are re-requested with the new language on next translate call.
   */
  const changeTranslateLang = useCallback((lang: string) => {
    setTranslateLang(lang);
    setTranslateStates({});
  }, []);

  return {
    chapterQuery,
    chapter: chapterQuery.data,
    currentPage,
    totalPages,
    progress,
    setCurrentPage,
    goToPage,
    recordHistory: recordHistoryMutation,
    // Translation
    translateStates,
    translateLang,
    translatePage,
    translateAllPages,
    resetPageTranslation,
    resetAllTranslations,
    changeTranslateLang,
  };
}
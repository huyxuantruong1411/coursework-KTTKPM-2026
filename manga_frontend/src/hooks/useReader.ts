import { useCallback, useEffect, useMemo, useState } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { chapterService } from "@/services/chapter.service";
import { historyService } from "@/services/history.service";
import type { UUID } from "@/types/common";

export function useReader(mangaId?: UUID, chapterId?: UUID) {
  const [currentPage, setCurrentPage] = useState(1);

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

  useEffect(() => {
    setCurrentPage(1);
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

  return {
    chapterQuery,
    chapter: chapterQuery.data,
    currentPage,
    totalPages,
    progress,
    setCurrentPage,
    goToPage,
    recordHistory: recordHistoryMutation,
  };
}

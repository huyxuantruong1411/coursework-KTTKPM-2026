"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import {
  ArrowLeft,
  BookOpen,
  ChevronLeft,
  ChevronRight,
  Home,
  Languages,
  Loader2,
  Maximize2,
  Minimize2,
  PanelsTopLeft,
  RefreshCw,
  Settings2,
} from "lucide-react";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";
import { Skeleton } from "@/components/ui/Skeleton";
import { useReader } from "@/hooks/useReader";
import { cn } from "@/lib/utils";
import { useAppStore } from "@/store/useAppStore";
import { TRANSLATE_LANGS } from "@/services/translate.service";

export default function ReaderPage() {
  const params = useParams<{ mangaId: string; chapterId: string }>();
  const router = useRouter();
  const mangaId = params.mangaId;
  const chapterId = params.chapterId;

  const {
    chapterQuery,
    chapter,
    currentPage,
    totalPages,
    progress,
    goToPage,
    setCurrentPage,
    translateStates,
    translateLang,
    translatePage,
    translateAllPages,
    resetAllTranslations,
    changeTranslateLang,
  } = useReader(mangaId, chapterId);

  const reader = useAppStore((state) => state.reader);
  const updateReader = useAppStore((state) => state.updateReader);

  // Whether the translate lang picker is open
  const [showLangPicker, setShowLangPicker] = useState(false);
  // Whether bulk-translate is in progress
  const [isBulkTranslating, setIsBulkTranslating] = useState(false);

  useEffect(() => {
    const page = Number(new URLSearchParams(window.location.search).get("page"));
    if (page > 0) goToPage(page);
  }, [goToPage]);

  useEffect(() => {
    if (!chapter?.page_urls.length || reader.direction !== "vertical") return;
    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries
          .filter((entry) => entry.isIntersecting)
          .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
        if (visible?.target?.id) {
          const next = Number(visible.target.id.replace("reader-page-", ""));
          if (next) setCurrentPage(next);
        }
      },
      { threshold: [0.35, 0.6, 0.85] },
    );
    chapter.page_urls.forEach((_, index) => {
      const element = document.getElementById(`reader-page-${index + 1}`);
      if (element) observer.observe(element);
    });
    return () => observer.disconnect();
  }, [chapter?.page_urls, reader.direction, setCurrentPage]);

  useEffect(() => {
    function handleKey(event: KeyboardEvent) {
      if (event.key === "ArrowRight") goToPage(currentPage + 1);
      if (event.key === "ArrowLeft") goToPage(currentPage - 1);
      if (event.key === "Escape") updateReader({ showToolbar: !reader.showToolbar });
    }
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [currentPage, goToPage, reader.showToolbar, updateReader]);

  const current = chapter?.current;
  const currentImage = chapter?.page_urls[currentPage - 1];

  /** Resolve what URL to show for a given page (translated or original). */
  function resolvePageUrl(originalUrl: string, pageIndex: number): string {
    const state = translateStates[pageIndex];
    if (state?.status === "done") return state.url;
    return originalUrl;
  }

  /** Translate button for a single page. */
  function TranslatePageButton({ pageIndex }: { pageIndex: number }) {
    const state = translateStates[pageIndex];
    const isLoading = state?.status === "loading";
    const isDone = state?.status === "done";
    const isError = state?.status === "error";

    return (
      <div className="flex items-center gap-1.5">
        {isDone ? (
          // Show "revert" button when page is translated
          <button
            onClick={() => {
              // Reset to original by removing state
              resetAllTranslations();
            }}
            className="flex items-center gap-1 rounded-full bg-brand-orange/20 px-2.5 py-1 text-xs font-medium text-brand-orange hover:bg-brand-orange/30 transition"
            title="Xem bản gốc"
          >
            <RefreshCw className="h-3 w-3" aria-hidden />
            Gốc
          </button>
        ) : (
          <button
            disabled={isLoading}
            onClick={() => translatePage(pageIndex)}
            className={cn(
              "flex items-center gap-1 rounded-full px-2.5 py-1 text-xs font-medium transition",
              isLoading
                ? "bg-white/10 text-white/50 cursor-not-allowed"
                : isError
                  ? "bg-red-500/20 text-red-400 hover:bg-red-500/30"
                  : "bg-white/10 text-white/80 hover:bg-white/20",
            )}
            title={isError ? (translateStates[pageIndex] as { status: "error"; message: string }).message : `Dịch sang ${translateLang}`}
          >
            {isLoading ? (
              <Loader2 className="h-3 w-3 animate-spin" aria-hidden />
            ) : (
              <Languages className="h-3 w-3" aria-hidden />
            )}
            {isLoading ? "Đang dịch..." : isError ? "Thử lại" : "Dịch"}
          </button>
        )}
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#111] text-white">
      {/* ── Top toolbar ── */}
      <div
        className={cn(
          "fixed left-0 right-0 top-0 z-40 border-b border-white/10 bg-[#171717]/95 backdrop-blur transition",
          reader.showToolbar ? "translate-y-0" : "-translate-y-full",
        )}
      >
        <div className="flex min-h-16 items-center gap-2 px-3">
          <Link href={`/manga/${mangaId}`}>
            <Button variant="ghost" size="icon" className="text-white hover:bg-white/10" aria-label="Back to manga">
              <ArrowLeft className="h-5 w-5" aria-hidden />
            </Button>
          </Link>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-bold">
              Ch. {current?.ChapterNumber ?? "?"}
              {current?.Title ? ` - ${current.Title}` : ""}
            </p>
            <p className="text-xs text-white/60">
              Page {currentPage} / {Math.max(totalPages, 1)}
            </p>
          </div>

          {/* ── Language picker trigger ── */}
          <div className="relative">
            <Button
              variant="ghost"
              size="icon"
              className={cn(
                "text-white hover:bg-white/10",
                showLangPicker && "bg-white/10",
              )}
              onClick={() => setShowLangPicker((v) => !v)}
              aria-label="Translate language"
              title={`Ngôn ngữ dịch: ${translateLang}`}
            >
              <Languages className="h-5 w-5" aria-hidden />
            </Button>

            {/* Dropdown */}
            {showLangPicker && (
              <div className="absolute right-0 top-12 z-50 w-48 rounded-xl border border-white/10 bg-[#222] py-1 shadow-xl">
                <p className="px-3 py-1.5 text-xs font-semibold text-white/50 uppercase tracking-wide">
                  Dịch sang
                </p>
                {TRANSLATE_LANGS.map((lang) => (
                  <button
                    key={lang.code}
                    className={cn(
                      "w-full px-3 py-2 text-left text-sm hover:bg-white/10 transition",
                      translateLang === lang.code ? "text-brand-orange font-semibold" : "text-white",
                    )}
                    onClick={() => {
                      changeTranslateLang(lang.code);
                      setShowLangPicker(false);
                    }}
                  >
                    {lang.label}
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* ── Translate all pages button ── */}
          <Button
            variant="ghost"
            size="icon"
            className="text-white hover:bg-white/10"
            disabled={isBulkTranslating || !chapter?.page_urls.length}
            onClick={async () => {
              setIsBulkTranslating(true);
              await translateAllPages();
              setIsBulkTranslating(false);
            }}
            aria-label="Translate all pages"
            title="Dịch tất cả trang"
          >
            {isBulkTranslating ? (
              <Loader2 className="h-5 w-5 animate-spin" aria-hidden />
            ) : (
              <RefreshCw className="h-5 w-5" aria-hidden />
            )}
          </Button>

          <Button
            variant="ghost"
            size="icon"
            className="text-white hover:bg-white/10"
            onClick={() => updateReader({ direction: reader.direction === "vertical" ? "paged" : "vertical" })}
            aria-label="Toggle reading mode"
          >
            <PanelsTopLeft className="h-5 w-5" aria-hidden />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className="text-white hover:bg-white/10"
            onClick={() => updateReader({ fit: reader.fit === "width" ? "height" : "width" })}
            aria-label="Toggle fit"
          >
            {reader.fit === "width" ? <Maximize2 className="h-5 w-5" aria-hidden /> : <Minimize2 className="h-5 w-5" aria-hidden />}
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className="text-white hover:bg-white/10"
            onClick={() => updateReader({ showToolbar: false })}
            aria-label="Hide toolbar"
          >
            <Settings2 className="h-5 w-5" aria-hidden />
          </Button>
        </div>

        {/* Progress bar */}
        <div className="h-1 bg-white/10">
          <div className="h-full bg-brand-orange transition-all" style={{ width: `${progress}%` }} />
        </div>
      </div>

      {/* Show toolbar FAB */}
      <button
        className={cn("fixed right-4 top-4 z-50 rounded-full bg-white/10 p-3 backdrop-blur transition", reader.showToolbar && "opacity-0")}
        onClick={() => updateReader({ showToolbar: true })}
        aria-label="Show toolbar"
      >
        <Settings2 className="h-5 w-5" aria-hidden />
      </button>

      {/* ── Main content ── */}
      <main className="mx-auto min-h-screen max-w-6xl px-2 py-20">
        {chapterQuery.isLoading ? (
          <div className="mx-auto max-w-3xl space-y-3">
            {Array.from({ length: 4 }).map((_, index) => (
              <Skeleton key={index} className="h-[80vh] bg-white/10" />
            ))}
          </div>
        ) : chapter?.page_urls.length ? (
          reader.direction === "paged" ? (
            /* ── PAGED MODE ── */
            <div className="flex min-h-[calc(100vh-10rem)] items-center justify-center">
              <button
                className="fixed left-3 top-1/2 z-20 rounded-full bg-white/10 p-3"
                onClick={() => goToPage(currentPage - 1)}
                aria-label="Previous page"
              >
                <ChevronLeft className="h-6 w-6" aria-hidden />
              </button>

              {currentImage ? (
                <div className="relative flex flex-col items-center gap-2">
                  {/* Translate button above the current paged image */}
                  <div className="flex items-center gap-2 rounded-full bg-white/10 px-3 py-1.5">
                    <span className="text-xs text-white/60">Trang {currentPage}</span>
                    <TranslatePageButton pageIndex={currentPage} />
                  </div>

                  {/* Image – show translated URL if available */}
                  {translateStates[currentPage]?.status === "loading" ? (
                    <div
                      className={cn(
                        "mx-auto bg-black flex items-center justify-center",
                        reader.fit === "height"
                          ? "max-h-[calc(100vh-9rem)] w-auto min-w-[300px]"
                          : "h-auto w-full max-w-4xl min-h-[400px]",
                      )}
                    >
                      <div className="flex flex-col items-center gap-3 text-white/50">
                        <Loader2 className="h-8 w-8 animate-spin" />
                        <p className="text-sm">Đang dịch trang {currentPage}...</p>
                        <p className="text-xs text-white/30">Có thể mất 10–20 giây</p>
                      </div>
                    </div>
                  ) : (
                    <img
                      src={resolvePageUrl(currentImage, currentPage)}
                      alt={`Page ${currentPage}`}
                      className={cn(
                        "mx-auto bg-black object-contain",
                        reader.fit === "height" ? "max-h-[calc(100vh-9rem)] w-auto" : "h-auto w-full max-w-4xl",
                      )}
                    />
                  )}
                </div>
              ) : null}

              <button
                className="fixed right-3 top-1/2 z-20 rounded-full bg-white/10 p-3"
                onClick={() => goToPage(currentPage + 1)}
                aria-label="Next page"
              >
                <ChevronRight className="h-6 w-6" aria-hidden />
              </button>
            </div>
          ) : (
            /* ── VERTICAL SCROLL MODE ── */
            <div className="mx-auto max-w-4xl space-y-1">
              {chapter.page_urls.map((url, index) => {
                const pageIndex = index + 1;
                const state = translateStates[pageIndex];
                const displayUrl = state?.status === "done" ? state.url : url;

                return (
                  <div
                    key={`${pageIndex}-${url}`}
                    id={`reader-page-${pageIndex}`}
                    className="relative group"
                  >
                    {/* Per-page translate button (visible on hover) */}
                    <div
                      className={cn(
                        "absolute right-3 top-3 z-10 flex items-center gap-1.5 rounded-full bg-black/60 px-2.5 py-1.5 backdrop-blur transition",
                        "opacity-0 group-hover:opacity-100",
                        state?.status === "loading" && "opacity-100",
                        state?.status === "done" && "opacity-100",
                        state?.status === "error" && "opacity-100",
                      )}
                    >
                      <span className="text-xs text-white/50">T.{pageIndex}</span>
                      <TranslatePageButton pageIndex={pageIndex} />
                    </div>

                    {/* Loading overlay */}
                    {state?.status === "loading" && (
                      <div className="absolute inset-0 z-10 flex flex-col items-center justify-center bg-black/70 gap-3">
                        <Loader2 className="h-8 w-8 animate-spin text-brand-orange" />
                        <p className="text-sm text-white/70">Đang dịch trang {pageIndex}...</p>
                        <p className="text-xs text-white/40">Có thể mất 10–20 giây</p>
                      </div>
                    )}

                    <img
                      src={displayUrl}
                      alt={`Page ${pageIndex}`}
                      loading={index < 3 ? "eager" : "lazy"}
                      className={cn(
                        "mx-auto bg-black object-contain",
                        reader.fit === "height" ? "max-h-screen w-auto" : "h-auto w-full",
                        state?.status === "loading" && "opacity-20",
                      )}
                    />
                  </div>
                );
              })}
            </div>
          )
        ) : (
          <div className="mx-auto flex max-w-xl flex-col items-center justify-center gap-6 pt-20 px-4 text-center">
            <img
              src="https://placehold.co/600x900/111111/FFFFFF?text=Pages+Unavailable"
              alt="Pages unavailable"
              className="w-full max-w-sm rounded-2xl border border-white/10"
            />

            <EmptyState
              title="Pages temporarily unavailable"
              description="MinIO hoặc MangaDex hiện không trả về image pages. Hệ thống đã chuyển sang chế độ fallback để tránh crash demo."
              className="border-white/10 bg-white/5 text-white"
            />

            <div className="flex items-center gap-3">
              <Button
                onClick={() => window.location.reload()}
                className="bg-brand-orange hover:bg-brand-orangeHover"
              >
                Retry
              </Button>

              <Button
                variant="ghost"
                onClick={() => router.push(`/manga/${mangaId}`)}
              >
                Back to manga
              </Button>
            </div>
          </div>
        )}
      </main>

      {/* ── Bottom toolbar ── */}
      <div
        className={cn(
          "fixed bottom-0 left-0 right-0 z-40 border-t border-white/10 bg-[#171717]/95 px-3 py-3 backdrop-blur transition",
          reader.showToolbar ? "translate-y-0" : "translate-y-full",
        )}
      >
        <div className="mx-auto flex max-w-5xl items-center justify-between gap-2">
          {chapter?.prev_chapter ? (
            <Link href={`/read/${mangaId}/${chapter.prev_chapter.ChapterId}`}>
              <Button variant="light">
                <ChevronLeft className="h-4 w-4" aria-hidden />
                Prev
              </Button>
            </Link>
          ) : (
            <Button variant="light" disabled>
              <ChevronLeft className="h-4 w-4" aria-hidden />
              Prev
            </Button>
          )}
          <div className="flex items-center gap-2">
            <Link href="/">
              <Button variant="ghost" size="icon" className="text-white hover:bg-white/10" aria-label="Home">
                <Home className="h-5 w-5" aria-hidden />
              </Button>
            </Link>
            <Link href={`/manga/${mangaId}`}>
              <Button variant="ghost" size="icon" className="text-white hover:bg-white/10" aria-label="Manga detail">
                <BookOpen className="h-5 w-5" aria-hidden />
              </Button>
            </Link>
          </div>
          {chapter?.next_chapter ? (
            <Link href={`/read/${mangaId}/${chapter.next_chapter.ChapterId}`}>
              <Button>
                Next
                <ChevronRight className="h-4 w-4" aria-hidden />
              </Button>
            </Link>
          ) : (
            <Button disabled>
              Next
              <ChevronRight className="h-4 w-4" aria-hidden />
            </Button>
          )}
        </div>
      </div>

      {/* Close lang picker when clicking outside */}
      {showLangPicker && (
        <div
          className="fixed inset-0 z-30"
          onClick={() => setShowLangPicker(false)}
        />
      )}
    </div>
  );
}
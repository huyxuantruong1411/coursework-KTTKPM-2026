"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect } from "react";
import {
  ArrowLeft,
  BookOpen,
  ChevronLeft,
  ChevronRight,
  Home,
  Maximize2,
  Minimize2,
  PanelsTopLeft,
  Settings2,
} from "lucide-react";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";
import { Skeleton } from "@/components/ui/Skeleton";
import { useReader } from "@/hooks/useReader";
import { cn } from "@/lib/utils";
import { useAppStore } from "@/store/useAppStore";

export default function ReaderPage() {
  const params = useParams<{ mangaId: string; chapterId: string }>();
  const router = useRouter();
  const mangaId = params.mangaId;
  const chapterId = params.chapterId;
  const { chapterQuery, chapter, currentPage, totalPages, progress, goToPage, setCurrentPage } = useReader(mangaId, chapterId);
  const reader = useAppStore((state) => state.reader);
  const updateReader = useAppStore((state) => state.updateReader);

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

  return (
    <div className="min-h-screen bg-[#111] text-white">
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
        <div className="h-1 bg-white/10">
          <div className="h-full bg-brand-orange transition-all" style={{ width: `${progress}%` }} />
        </div>
      </div>

      <button
        className={cn("fixed right-4 top-4 z-50 rounded-full bg-white/10 p-3 backdrop-blur transition", reader.showToolbar && "opacity-0")}
        onClick={() => updateReader({ showToolbar: true })}
        aria-label="Show toolbar"
      >
        <Settings2 className="h-5 w-5" aria-hidden />
      </button>

      <main className="mx-auto min-h-screen max-w-6xl px-2 py-20">
        {chapterQuery.isLoading ? (
          <div className="mx-auto max-w-3xl space-y-3">
            {Array.from({ length: 4 }).map((_, index) => (
              <Skeleton key={index} className="h-[80vh] bg-white/10" />
            ))}
          </div>
        ) : chapter?.page_urls.length ? (
          reader.direction === "paged" ? (
            <div className="flex min-h-[calc(100vh-10rem)] items-center justify-center">
              <button className="fixed left-3 top-1/2 z-20 rounded-full bg-white/10 p-3" onClick={() => goToPage(currentPage - 1)} aria-label="Previous page">
                <ChevronLeft className="h-6 w-6" aria-hidden />
              </button>
              {currentImage ? (
                <img
                  src={currentImage}
                  alt={`Page ${currentPage}`}
                  className={cn(
                    "mx-auto bg-black object-contain",
                    reader.fit === "height" ? "max-h-[calc(100vh-9rem)] w-auto" : "h-auto w-full max-w-4xl",
                  )}
                />
              ) : null}
              <button className="fixed right-3 top-1/2 z-20 rounded-full bg-white/10 p-3" onClick={() => goToPage(currentPage + 1)} aria-label="Next page">
                <ChevronRight className="h-6 w-6" aria-hidden />
              </button>
            </div>
          ) : (
            <div className="mx-auto max-w-4xl space-y-3">
              {chapter.page_urls.map((url, index) => (
                <img
                  id={`reader-page-${index + 1}`}
                  key={url}
                  src={url}
                  alt={`Page ${index + 1}`}
                  loading={index < 3 ? "eager" : "lazy"}
                  className={cn(
                    "mx-auto bg-black object-contain",
                    reader.fit === "height" ? "max-h-screen w-auto" : "h-auto w-full",
                  )}
                />
              ))}
            </div>
          )
        ) : (
          <div className="mx-auto max-w-xl pt-20">
            <EmptyState
              title="No pages returned"
              description="Backend chapter endpoint responded, but MinIO did not return presigned page URLs."
              className="border-white/10 bg-white/5 text-white"
            />
          </div>
        )}
      </main>

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
    </div>
  );
}

"use client";

import Link from "next/link";
import { BookOpen, ChevronDown, Clock, Languages } from "lucide-react";
import { useMemo, useState } from "react";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";
import { Select } from "@/components/ui/Select";
import { Skeleton } from "@/components/ui/Skeleton";
import { formatDate } from "@/lib/utils";
import type { Chapter } from "@/types/chapter";
import type { UUID } from "@/types/common";

interface ChapterListProps {
  mangaId: UUID;
  chapters?: Chapter[];
  languages?: string[];
  isLoading?: boolean;
  selectedLang?: string;
  sort?: "asc" | "desc";
  onLangChange?: (lang: string) => void;
  onSortChange?: (sort: "asc" | "desc") => void;
}

export function ChapterList({
  mangaId,
  chapters = [],
  languages = [],
  isLoading,
  selectedLang = "",
  sort = "asc",
  onLangChange,
  onSortChange,
}: ChapterListProps) {
  const [visibleCount, setVisibleCount] = useState(30);
  const visible = useMemo(() => chapters.slice(0, visibleCount), [chapters, visibleCount]);

  return (
    <section className="card">
      <div className="flex flex-col gap-3 border-b border-bd p-4 md:flex-row md:items-center md:justify-between">
        <div>
          <h2 className="font-heading text-2xl font-semibold">Chapters</h2>
          <p className="text-sm text-tx-muted">{chapters.length} readable entries</p>
        </div>
        <div className="grid gap-2 sm:grid-cols-2 md:w-[360px]">
          <Select value={selectedLang} onChange={(event) => onLangChange?.(event.target.value)} aria-label="Language">
            <option value="">All languages</option>
            {languages.map((lang) => (
              <option key={lang} value={lang}>
                {lang.toUpperCase()}
              </option>
            ))}
          </Select>
          <Select value={sort} onChange={(event) => onSortChange?.(event.target.value as "asc" | "desc")} aria-label="Sort chapters">
            <option value="asc">Oldest first</option>
            <option value="desc">Newest first</option>
          </Select>
        </div>
      </div>
      {isLoading ? (
        <div className="space-y-2 p-4">
          {Array.from({ length: 8 }).map((_, index) => (
            <Skeleton key={index} className="h-14" />
          ))}
        </div>
      ) : visible.length ? (
        <div className="divide-y divide-bd">
          {visible.map((chapter) => (
            <Link
              key={chapter.ChapterId}
              href={`/read/${mangaId}/${chapter.ChapterId}`}
              className="flex min-h-16 items-center gap-3 px-4 py-3 transition hover:bg-surface-2"
            >
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-surface-2 text-tx">
                <BookOpen className="h-4 w-4" aria-hidden />
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-bold">
                  Ch. {chapter.ChapterNumber ?? "?"}
                  {chapter.Title ? ` - ${chapter.Title}` : ""}
                </p>
                <div className="mt-1 flex flex-wrap items-center gap-3 text-xs text-tx-muted">
                  <span className="inline-flex items-center gap-1">
                    <Languages className="h-3.5 w-3.5" aria-hidden />
                    {chapter.TranslatedLang?.toUpperCase() ?? "N/A"}
                  </span>
                  <span className="inline-flex items-center gap-1">
                    <Clock className="h-3.5 w-3.5" aria-hidden />
                    {formatDate(chapter.PublishAt ?? chapter.CreatedAt)}
                  </span>
                  {chapter.Pages ? <Badge>{chapter.Pages} pages</Badge> : null}
                </div>
              </div>
            </Link>
          ))}
          {visibleCount < chapters.length ? (
            <div className="p-4 text-center">
              <Button variant="light" onClick={() => setVisibleCount((count) => count + 30)}>
                Load more <ChevronDown className="h-4 w-4" aria-hidden />
              </Button>
            </div>
          ) : null}
        </div>
      ) : (
        <div className="p-4">
          <EmptyState title="No chapters yet" description="This manga does not have readable chapter metadata from the backend." />
        </div>
      )}
    </section>
  );
}

"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useMutation, useQuery } from "@tanstack/react-query";
import { ArrowRight, BookOpen, ExternalLink, Languages, Palette, Sparkles, Star, Users } from "lucide-react";
import { useState } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";
import { Skeleton } from "@/components/ui/Skeleton";
import { MangaCover } from "@/components/features/MangaCover";
import { ChapterList } from "@/components/features/ChapterList";
import { CommentsSection } from "@/components/features/CommentsSection";
import { ListPicker } from "@/components/features/ListPicker";
import { MangaGrid } from "@/components/features/MangaGrid";
import { RatingPanel } from "@/components/features/RatingPanel";
import {
  useChapterLanguages,
  useChapters,
  useMangaDetail,
  useRelatedManga,
  useMangaRecommendations,
} from "@/hooks/useMangaQueries";
import { useAuth } from "@/hooks/useAuth";
import { cn, formatNumber, pickDescription, titleCase } from "@/lib/utils";
import { historyService } from "@/services/history.service";
import { coverService } from "@/services/cover.service";
import type { SimilarMangaItem } from "@/services/analytics.service";

type DetailTab = "chapters" | "art" | "recommendations";

export default function MangaDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const mangaId = params.id;
  const [lang, setLang] = useState("");
  const [sort, setSort] = useState<"asc" | "desc">("asc");
  const [isSynopsisExpanded, setIsSynopsisExpanded] = useState(false);
  const [activeTab, setActiveTab] = useState<DetailTab>("chapters");
  const { isAuthenticated } = useAuth();

  const manga = useMangaDetail(mangaId);
  const chapters = useChapters(mangaId, { lang, sort });
  const languages = useChapterLanguages(mangaId);
  const related = useRelatedManga(mangaId);
  const recommendations = useMangaRecommendations(mangaId);

  // Art covers – lazy-loaded only when the Art tab is active
  const artQuery = useQuery({
    queryKey: ["covers", "all", mangaId],
    queryFn: () => coverService.all(mangaId),
    enabled: activeTab === "art" && Boolean(mangaId),
  });

  const continueMutation = useMutation({
    mutationFn: () => historyService.continueReading(mangaId),
    onSuccess: (data) => {
      const chapterId = data.chapter_id ?? chapters.data?.[0]?.ChapterId;
      if (chapterId) {
        router.push(`/read/${mangaId}/${chapterId}${data.last_page ? `?page=${data.last_page}` : ""}`);
      }
    },
    onError: () => {
      const chapterId = chapters.data?.[0]?.ChapterId;
      if (chapterId) router.push(`/read/${mangaId}/${chapterId}`);
    },
  });

  if (manga.isLoading) {
    return (
      <div className="page-shell">
        <Skeleton className="h-[360px]" />
        <div className="mt-6 grid gap-4 lg:grid-cols-[1fr_340px]">
          <Skeleton className="h-96" />
          <Skeleton className="h-96" />
        </div>
      </div>
    );
  }

  if (!manga.data) {
    return (
      <div className="page-shell">
        <EmptyState title="Manga not found" description="The backend did not return this manga id." />
      </div>
    );
  }

  const detail = manga.data;
  const description = pickDescription(detail.descriptions);
  const authors = detail.creators.filter(c => c.role?.toLowerCase() === "author");
  const artists = detail.creators.filter(c => c.role?.toLowerCase() === "artist");
  const firstChapter = chapters.data?.[0];

  // Filter related: only show manga-type items with at least a title or cover
  const filteredRelated = (related.data ?? []).filter(
    (item) => item.title !== "Unknown Manga" || item.cover_url
  );

  return (
    <div>
      {/* ── Hero Banner ── */}
      <section className="relative overflow-hidden bg-neutral-dark text-white">
        {detail.cover_url ? <img src={detail.cover_url} alt="" className="absolute inset-0 h-full w-full object-cover opacity-25" /> : null}
        <div className="absolute inset-0 bg-black/65" />
        <div className="page-shell relative grid gap-6 py-10 md:grid-cols-[220px_1fr] md:items-end">
          <MangaCover src={detail.cover_url} title={detail.TitleEn} className="aspect-[2/3] w-48 border border-white/20 shadow-floating md:w-full" />
          <div className="max-w-4xl">
            <div className="mb-4 flex flex-wrap gap-2">
              {detail.Status ? <Badge tone="orange">{titleCase(detail.Status)}</Badge> : null}
              {detail.ContentRating ? <Badge tone="warning">{titleCase(detail.ContentRating)}</Badge> : null}
              {detail.PublicationDemographic ? <Badge tone="sky">{titleCase(detail.PublicationDemographic)}</Badge> : null}
            </div>
            <h1 className="font-heading text-4xl font-bold leading-10 md:text-5xl md:leading-[56px]">{detail.TitleEn ?? "Untitled"}</h1>
            <div className="mt-3 flex flex-col gap-1">
              {authors.length > 0 ? (
                <p className="text-sm text-white/80">
                  {authors.map((a, i) => (
                    <span key={a.id || i}>
                      {a.id ? <Link href={`/creator/${a.id}`} className="hover:text-brand-orange hover:underline">{a.name}</Link> : a.name}
                      {i < authors.length - 1 ? ", " : ""}
                    </span>
                  ))}
                </p>
              ) : null}
              {artists.length > 0 && JSON.stringify(artists) !== JSON.stringify(authors) ? (
                <p className="text-xs text-white/60">
                  🎨 {artists.map((a, i) => (
                    <span key={a.id || i}>
                      {a.id ? <Link href={`/creator/${a.id}`} className="hover:text-brand-orange hover:underline">{a.name}</Link> : a.name}
                      {i < artists.length - 1 ? ", " : ""}
                    </span>
                  ))}
                </p>
              ) : null}
            </div>
            <div className="mt-5 flex flex-wrap gap-5 text-sm text-white/85">
              <span className="inline-flex items-center gap-2">
                <Star className="h-4 w-4 text-brand-orange" aria-hidden />
                {(detail.stats?.AverageRating ?? 0).toFixed(1)}
              </span>
              <span className="inline-flex items-center gap-2">
                <Users className="h-4 w-4" aria-hidden />
                {formatNumber(detail.stats?.Follows)} follows
              </span>
              <span>{detail.Year ?? "Unknown year"}</span>
              <span className="inline-flex items-center gap-2">
                <Languages className="h-4 w-4" aria-hidden />
                {detail.available_languages?.length || 0} languages
              </span>
            </div>
            <div className="mt-6 flex flex-wrap gap-3">
              <Button
                onClick={() => (isAuthenticated ? continueMutation.mutate() : firstChapter && router.push(`/read/${mangaId}/${firstChapter.ChapterId}`))}
                isLoading={continueMutation.isPending}
                disabled={!firstChapter && !chapters.isLoading}
              >
                <BookOpen className="h-4 w-4" aria-hidden />
                Continue reading
              </Button>
              {firstChapter ? (
                <Link href={`/read/${mangaId}/${firstChapter.ChapterId}`}>
                  <Button variant="light">
                    First chapter
                    <ArrowRight className="h-4 w-4" aria-hidden />
                  </Button>
                </Link>
              ) : null}
            </div>
          </div>
        </div>
      </section>

      {/* ── Main Content Grid ── */}
      <div className="page-shell grid gap-6 lg:grid-cols-[minmax(0,1fr)_340px]">
        <main className="space-y-6">
          {/* Synopsis */}
          <section className="card p-5">
            <h2 className="font-heading text-2xl font-semibold">Synopsis</h2>
            <div className="relative mt-3">
              <div className={cn("overflow-hidden transition-[max-height] duration-300 ease-in-out prose prose-sm prose-invert max-w-none text-tx-muted", isSynopsisExpanded ? "max-h-[5000px]" : "max-h-32")}>
                {description ? (
                  <ReactMarkdown 
                    remarkPlugins={[remarkGfm]}
                    components={{
                      hr: ({node, ...props}) => <hr className="my-4 border-bd" {...props} />,
                      a: ({node, ...props}) => <a className="text-brand-orange hover:underline" {...props} />
                    }}
                  >
                    {description}
                  </ReactMarkdown>
                ) : (
                  <p>No description available from backend metadata.</p>
                )}
              </div>
              {!isSynopsisExpanded && description && description.length > 300 && (
                <div className="absolute bottom-0 left-0 right-0 h-16 bg-gradient-to-t from-surface to-transparent" />
              )}
            </div>
            {description && description.length > 300 && (
              <div className="mt-2 text-center">
                <button
                  onClick={() => setIsSynopsisExpanded(!isSynopsisExpanded)}
                  className="text-xs font-semibold text-brand-orange hover:underline"
                >
                  {isSynopsisExpanded ? "Show less ▲" : "Show more ▼"}
                </button>
              </div>
            )}
            
            {detail.tags?.length ? (
              <div className="mt-6 space-y-4 border-t border-bd pt-4">
                {Object.entries(
                  detail.tags.reduce<Record<string, typeof detail.tags>>((acc, tag) => {
                    const group = tag.GroupName ? titleCase(tag.GroupName) : "Other";
                    if (!acc[group]) acc[group] = [];
                    acc[group].push(tag);
                    return acc;
                  }, {})
                ).map(([group, tags]) => {
                  const groupLower = group.toLowerCase();
                  let tone: "orange" | "sky" | "purple" | "cyan" | "default" = "default";
                  if (groupLower.includes("genre")) tone = "orange";
                  else if (groupLower.includes("theme")) tone = "sky";
                  else if (groupLower.includes("format")) tone = "purple";
                  else if (groupLower.includes("content")) tone = "cyan";

                  return (
                    <div key={group}>
                      <h3 className="mb-2 text-sm font-semibold text-tx">{group}</h3>
                      <div className="flex flex-wrap gap-2">
                        {tags?.map((tag) => (
                          <Badge key={tag.TagId} tone={tone}>
                            {tag.NameEn}
                          </Badge>
                        ))}
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : null}
          </section>

          {/* ── Tab Navigation ── */}
          <div className="flex gap-1 rounded-lg border border-bd bg-surface p-1">
            {([
              { id: "chapters" as const, label: "Chapters", icon: BookOpen },
              { id: "art" as const, label: "Art", icon: Palette },
              { id: "recommendations" as const, label: "Recommendations", icon: Sparkles },
            ]).map(tab => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={cn(
                  "flex flex-1 items-center justify-center gap-2 rounded-md px-4 py-2.5 text-sm font-semibold transition-all",
                  activeTab === tab.id
                    ? "bg-accent text-white shadow-sm"
                    : "text-tx-muted hover:bg-surface-2 hover:text-tx"
                )}
              >
                <tab.icon className="h-4 w-4" />
                {tab.label}
              </button>
            ))}
          </div>

          {/* ── Tab Content ── */}
          {activeTab === "chapters" && (
            <>
              <ChapterList
                mangaId={mangaId}
                chapters={chapters.data}
                languages={languages.data}
                isLoading={chapters.isLoading}
                selectedLang={lang}
                sort={sort}
                onLangChange={setLang}
                onSortChange={setSort}
              />
              <CommentsSection mangaId={mangaId} />
            </>
          )}

          {activeTab === "art" && (
            <section className="card p-5">
              <h2 className="mb-4 font-heading text-2xl font-semibold">Cover Art Gallery</h2>
              {artQuery.isLoading ? (
                <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4">
                  {[...Array(8)].map((_, i) => (
                    <Skeleton key={i} className="aspect-[2/3] w-full rounded-def" />
                  ))}
                </div>
              ) : artQuery.data?.length ? (
                <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4">
                  {artQuery.data.map((cover) => (
                    <a
                      key={cover.cover_id}
                      href={cover.cover_url ?? "#"}
                      target="_blank"
                      rel="noreferrer"
                      className="group relative aspect-[2/3] overflow-hidden rounded-def border border-bd bg-surface-2"
                    >
                      <img
                        src={cover.cover_url ?? ""}
                        alt={`Volume ${cover.volume || "?"}`}
                        className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
                        loading="lazy"
                      />
                      <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/80 to-transparent p-2 opacity-0 transition-opacity group-hover:opacity-100">
                        <p className="text-xs font-bold text-white">
                          {cover.volume ? `Vol. ${cover.volume}` : "Cover"}
                        </p>
                        {cover.locale && (
                          <p className="text-[10px] text-white/70">{cover.locale}</p>
                        )}
                      </div>
                    </a>
                  ))}
                </div>
              ) : (
                <EmptyState title="No cover art found" description="This manga has no additional cover art in our database." />
              )}
            </section>
          )}

          {activeTab === "recommendations" && (
            <section className="card p-5">
              <h2 className="mb-4 font-heading text-2xl font-semibold">Recommended For You</h2>
              <p className="mb-6 text-sm text-tx-muted">Similar manga recommended by the MangaDex community.</p>
              {recommendations.isLoading ? (
                <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
                  {[...Array(10)].map((_, i) => (
                    <Skeleton key={i} className="aspect-[2/3] w-full rounded-def" />
                  ))}
                </div>
              ) : recommendations.data?.recommendations?.length ? (
                <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
                  {recommendations.data.recommendations.map((item: SimilarMangaItem) => (
                    <Link
                      key={item.MangaId}
                      href={`/manga/${item.MangaId}`}
                      className="group relative flex flex-col overflow-hidden rounded-def border border-bd bg-surface-2 transition-all hover:shadow-lg hover:border-accent/30"
                    >
                      <div className="relative aspect-[2/3] overflow-hidden bg-surface">
                        {item.cover_url ? (
                          <img
                            src={item.cover_url}
                            alt={item.TitleEn ?? ""}
                            className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
                            loading="lazy"
                          />
                        ) : (
                          <div className="flex h-full w-full items-center justify-center text-tx-muted">
                            <BookOpen className="h-8 w-8" />
                          </div>
                        )}
                      </div>
                      <div className="flex-1 p-2">
                        <h3 className="line-clamp-2 text-xs font-bold text-tx group-hover:text-accent transition-colors">
                          {item.TitleEn ?? "Unknown"}
                        </h3>
                        {item.Status && (
                          <p className="mt-1 text-[10px] text-tx-muted">{titleCase(item.Status)}</p>
                        )}
                      </div>
                    </Link>
                  ))}
                </div>
              ) : (
                <EmptyState
                  title="No recommendations available"
                  description="This manga doesn't have community recommendations yet."
                  icon={Sparkles}
                />
              )}
            </section>
          )}
        </main>

        {/* ── Sidebar ── */}
        <aside className="space-y-6">
          <RatingPanel mangaId={mangaId} stats={detail.stats} />
          <ListPicker mangaId={mangaId} />
          <section className="card p-4">
            <h2 className="font-heading text-2xl font-semibold">Metadata</h2>
            <dl className="mt-4 space-y-3 text-sm">
              <Meta label="Type" value={detail.Type} />
              <Meta label="Original language" value={detail.OriginalLanguage} />
              <Meta label="Last chapter" value={detail.LastChapter} />
              <Meta label="Last volume" value={detail.LastVolume} />
              <Meta label="Demographic" value={titleCase(detail.PublicationDemographic)} />
              <Meta label="Content rating" value={titleCase(detail.ContentRating)} />
            </dl>
            {detail.alt_titles?.length ? (
              <div className="mt-5 border-t border-bd pt-4">
                <h3 className="mb-2 text-sm font-semibold text-tx">Alternative titles</h3>
                <ul className="space-y-1 text-xs text-tx-muted">
                  {detail.alt_titles.slice(0, 8).map((alt, i) => (
                    <li key={i}>• {alt.AltTitle}</li>
                  ))}
                </ul>
              </div>
            ) : null}
            {detail.links?.length ? (
              <div className="mt-5 space-y-2 border-t border-bd pt-4">
                <h3 className="mb-2 text-sm font-semibold text-tx">External links</h3>
                {detail.links.map((link, i) => (
                  <a
                    key={i}
                    href={link.Url ?? "#"}
                    target="_blank"
                    rel="noreferrer"
                    className="flex items-center justify-between border border-bd px-3 py-2 text-sm font-semibold hover:bg-surface-2"
                  >
                    {link.Provider ?? "Link"}
                    <ExternalLink className="h-4 w-4" aria-hidden />
                  </a>
                ))}
              </div>
            ) : null}
          </section>
        </aside>
      </div>

      {/* ── Related Titles ── */}
      {filteredRelated.length > 0 && (
        <section className="section-band">
          <div className="page-shell">
            <h2 className="mb-4 font-heading text-2xl font-semibold">Related titles</h2>
            <MangaGrid
              variant="compact"
              items={filteredRelated.map((item) => ({
                MangaId: item.RelatedId,
                TitleEn: item.title,
                Status: item.related_label,
                cover_url: item.cover_url,
              })) as any}
            />
          </div>
        </section>
      )}
    </div>
  );
}

function Meta({ label, value }: { label: string; value?: string | number | null }) {
  return (
    <div className="flex items-center justify-between gap-4 border-b border-bd pb-2 last:border-b-0">
      <dt className="text-tx-muted">{label}</dt>
      <dd className="text-right font-semibold">{value ?? "Unknown"}</dd>
    </div>
  );
}

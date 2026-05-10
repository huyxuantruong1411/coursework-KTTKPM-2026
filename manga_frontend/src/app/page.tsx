"use client";

import Link from "next/link";
import { ArrowRight, Compass, Sparkles, Star, TrendingUp } from "lucide-react";
import { Button } from "@/components/ui/Button";
import { SectionHeader } from "@/components/ui/SectionHeader";
import { Skeleton } from "@/components/ui/Skeleton";
import { MangaCover } from "@/components/features/MangaCover";
import { MangaGrid } from "@/components/features/MangaGrid";
import { useLatestManga, useMangaList, useRecentlyAdded } from "@/hooks/useMangaQueries";
import { formatNumber, titleCase } from "@/lib/utils";

export default function HomePage() {
  const latest = useLatestManga(1, 12);
  const recent = useRecentlyAdded(1, 12);
  const popular = useMangaList({ page: 1, limit: 6, sort: "follows_desc" });
  const featured = latest.data?.items[0] ?? popular.data?.items[0];

  return (
    <div>
      {/* ═══ HERO ═══ */}
      <section className="relative min-h-[460px] overflow-hidden bg-[#111]">
        {featured?.cover_url ? (
          <img src={featured.cover_url} alt="" className="absolute inset-0 h-full w-full object-cover opacity-30 blur-sm" />
        ) : (
          <div className="absolute inset-0 bg-gradient-to-br from-[#1a1a2e] to-[#0d0d0d]" />
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-[#0d0d0d] via-[#0d0d0d]/60 to-transparent" />
        <div className="page-shell relative flex min-h-[460px] items-end pb-10 pt-16">
          {featured ? (
            <div className="grid w-full gap-6 md:grid-cols-[180px_1fr] md:items-end animate-fadeIn">
              <MangaCover
                src={featured.cover_url}
                title={featured.TitleEn}
                className="hidden aspect-[2/3] w-44 rounded-lg border border-white/10 shadow-2xl md:block"
              />
              <div className="max-w-3xl">
                <div className="mb-4 flex flex-wrap gap-2">
                  <span className="rounded-def bg-accent px-3 py-1 text-xs font-bold uppercase text-white">Featured</span>
                  <span className="rounded-def bg-white/10 px-3 py-1 text-xs font-semibold text-white/90 backdrop-blur-sm">
                    {titleCase(featured.Status)}
                  </span>
                </div>
                <h1 className="font-heading text-4xl font-bold leading-10 text-white md:text-5xl md:leading-[56px]">
                  {featured.TitleEn ?? "Explore manga catalog"}
                </h1>
                <div className="mt-4 flex flex-wrap gap-5 text-sm text-white/80">
                  <span className="inline-flex items-center gap-2">
                    <Star className="h-4 w-4 text-accent" aria-hidden />
                    {(featured.stats?.AverageRating ?? 0).toFixed(1)} rating
                  </span>
                  <span>{formatNumber(featured.stats?.Follows)} follows</span>
                  <span>{featured.Year ?? "Unknown year"}</span>
                  <span>{titleCase(featured.PublicationDemographic)}</span>
                </div>
                <div className="mt-6 flex flex-wrap gap-3">
                  <Link href={`/manga/${featured.MangaId}`}>
                    <Button>
                      Read detail
                      <ArrowRight className="h-4 w-4" aria-hidden />
                    </Button>
                  </Link>
                  <Link href="/explore">
                    <Button variant="light">
                      <Compass className="h-4 w-4" aria-hidden />
                      Explore
                    </Button>
                  </Link>
                </div>
              </div>
            </div>
          ) : (
            <div className="w-full max-w-3xl">
              <Skeleton className="h-8 w-32 bg-white/10" />
              <Skeleton className="mt-5 h-16 w-full bg-white/10" />
              <Skeleton className="mt-4 h-5 w-2/3 bg-white/10" />
            </div>
          )}
        </div>
      </section>

      {/* ═══ LATEST UPDATES ═══ */}
      <section className="page-shell">
        <SectionHeader
          eyebrow="Live catalog"
          title="Latest updates"
          description="Freshly updated manga ordered by backend UpdatedAt metadata."
          href="/explore?sort=recent"
        />
        <MangaGrid items={latest.data?.items} isLoading={latest.isLoading} />
      </section>

      {/* ═══ RECENTLY ADDED ═══ */}
      <section className="section-band">
        <div className="page-shell">
          <SectionHeader
            eyebrow="Recently added"
            title="New in library"
            description="New catalog entries from the Manga Info service."
            href="/explore?sort=year_desc"
          />
          <MangaGrid items={recent.data?.items} isLoading={recent.isLoading} variant="compact" />
        </div>
      </section>

      {/* ═══ MOST FOLLOWED ═══ */}
      <section className="page-shell">
        <SectionHeader
          eyebrow="Discovery"
          title="Most followed"
          description="A quick scan of high-signal titles using the statistics table."
          href="/explore?sort=follows_desc"
        />
        <div className="grid gap-4 lg:grid-cols-[1fr_320px]">
          <MangaGrid items={popular.data?.items} isLoading={popular.isLoading} variant="wide" />
          <aside className="card p-6">
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-accent text-white">
              <TrendingUp className="h-6 w-6" aria-hidden />
            </div>
            <h2 className="mt-5 font-heading text-2xl font-semibold text-tx">Built for scale</h2>
            <p className="mt-3 text-sm leading-6 text-tx-muted">
              Reader pages use presigned URLs from MinIO, while catalog data remains light and cache-friendly through TanStack Query.
            </p>
            <div className="mt-5 flex items-center gap-2 text-sm font-bold text-accent">
              <Sparkles className="h-4 w-4" aria-hidden />
              FastAPI + MinIO ready
            </div>
          </aside>
        </div>
      </section>
    </div>
  );
}

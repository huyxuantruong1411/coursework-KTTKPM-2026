import Link from "next/link";
import { Star, Users } from "lucide-react";
import { Badge } from "@/components/ui/Badge";
import { formatNumber, titleCase } from "@/lib/utils";
import type { MangaListItem } from "@/types/manga";
import { MangaCover } from "./MangaCover";

interface MangaCardProps {
  manga: MangaListItem;
  variant?: "grid" | "compact" | "wide";
}

export function MangaCard({ manga, variant = "grid" }: MangaCardProps) {
  if (variant === "compact") {
    return (
      <Link
        href={`/manga/${manga.MangaId}`}
        className="card group flex gap-3 p-2 transition-transform duration-200 hover:scale-[1.01]"
      >
        <MangaCover src={manga.cover_url} title={manga.TitleEn} className="h-24 w-16 shrink-0" />
        <div className="min-w-0 py-1">
          <h3 className="line-clamp-2 text-sm font-bold leading-5 text-tx group-hover:text-accent transition-colors">
            {manga.TitleEn ?? "Untitled"}
          </h3>
          <p className="mt-1 text-xs text-tx-muted">{manga.Year ?? "Unknown"} · {titleCase(manga.Status)}</p>
          <div className="mt-2 flex flex-wrap gap-3 text-xs text-tx-muted">
            <span className="inline-flex items-center gap-1">
              <Star className="h-3.5 w-3.5 text-accent" aria-hidden />
              {(manga.stats?.AverageRating ?? 0).toFixed(1)}
            </span>
            <span className="inline-flex items-center gap-1">
              <Users className="h-3.5 w-3.5" aria-hidden />
              {formatNumber(manga.stats?.Follows)}
            </span>
          </div>
        </div>
      </Link>
    );
  }

  if (variant === "wide") {
    return (
      <Link
        href={`/manga/${manga.MangaId}`}
        className="card group flex min-h-32 gap-4 p-3 transition-transform duration-200 hover:scale-[1.005]"
      >
        <MangaCover src={manga.cover_url} title={manga.TitleEn} className="h-32 w-24 shrink-0" />
        <div className="flex min-w-0 flex-1 flex-col">
          <div className="flex flex-wrap gap-2">
            {manga.Status && <Badge tone="orange">{titleCase(manga.Status)}</Badge>}
            {manga.ContentRating && <Badge>{titleCase(manga.ContentRating)}</Badge>}
          </div>
          <h3 className="mt-3 line-clamp-2 font-heading text-xl font-semibold leading-6 text-tx group-hover:text-accent transition-colors">
            {manga.TitleEn ?? "Untitled"}
          </h3>
          <div className="mt-auto flex flex-wrap gap-4 pt-3 text-sm text-tx-muted">
            <span>{manga.Year ?? "Unknown year"}</span>
            <span>{titleCase(manga.PublicationDemographic)}</span>
            <span>{(manga.stats?.AverageRating ?? 0).toFixed(1)} rating</span>
            <span>{formatNumber(manga.stats?.Follows)} follows</span>
          </div>
        </div>
      </Link>
    );
  }

  /* default: grid card */
  return (
    <Link
      href={`/manga/${manga.MangaId}`}
      className="card group block overflow-hidden transition-transform duration-200 hover:scale-[1.03]"
    >
      <MangaCover src={manga.cover_url} title={manga.TitleEn} className="aspect-[2/3] w-full" />
      <div className="p-3">
        <h3 className="line-clamp-2 min-h-10 text-sm font-bold leading-5 text-tx group-hover:text-accent transition-colors">
          {manga.TitleEn ?? "Untitled"}
        </h3>
        <div className="mt-3 flex items-center justify-between text-xs text-tx-muted">
          <span>{manga.Year ?? "N/A"}</span>
          <span className="inline-flex items-center gap-1">
            <Star className="h-3.5 w-3.5 fill-accent text-accent" aria-hidden />
            {(manga.stats?.AverageRating ?? 0).toFixed(1)}
          </span>
        </div>
      </div>
    </Link>
  );
}

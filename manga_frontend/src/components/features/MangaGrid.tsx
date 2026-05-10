import { EmptyState } from "@/components/ui/EmptyState";
import { Skeleton } from "@/components/ui/Skeleton";
import type { MangaListItem } from "@/types/manga";
import { MangaCard } from "./MangaCard";

interface MangaGridProps {
  items?: MangaListItem[];
  isLoading?: boolean;
  variant?: "grid" | "compact" | "wide";
}

export function MangaGrid({ items = [], isLoading, variant = "grid" }: MangaGridProps) {
  if (isLoading) {
    return (
      <div className={variant === "wide" ? "grid gap-3" : "grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4 2xl:grid-cols-6"}>
        {Array.from({ length: variant === "wide" ? 6 : 12 }).map((_, index) => (
          <Skeleton key={index} className={variant === "wide" ? "h-40" : "aspect-[2/3] w-full"} />
        ))}
      </div>
    );
  }

  if (!items.length) {
    return <EmptyState title="No manga found" description="Try another keyword, filter, or make sure the backend has catalog data." />;
  }

  if (variant === "wide") {
    return (
      <div className="grid gap-3">
        {items.map((manga, index) => (
          <MangaCard key={`${manga.MangaId}-${index}`} manga={manga} variant="wide" />
        ))}
      </div>
    );
  }

  if (variant === "compact") {
    return (
      <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
        {items.map((manga, index) => (
          <MangaCard key={`${manga.MangaId}-${index}`} manga={manga} variant="compact" />
        ))}
      </div>
    );
  }

  return (
    <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4 2xl:grid-cols-6">
      {items.map((manga, index) => (
        <MangaCard key={`${manga.MangaId}-${index}`} manga={manga} />
      ))}
    </div>
  );
}

"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { LayoutGrid, List as ListIcon, Filter } from "lucide-react";
import { MangaCard } from "@/components/features/MangaCard";
import { EmptyState } from "@/components/ui/EmptyState";
import { Skeleton } from "@/components/ui/Skeleton";
import { useAuth } from "@/hooks/useAuth";
import { mangaService } from "@/services/manga.service";
import { cn } from "@/lib/utils";

export default function LatestUpdatesPage() {
  const { isAuthenticated } = useAuth();
  const [inMyLists, setInMyLists] = useState(false);
  const [viewMode, setViewMode] = useState<"grid" | "list">("grid");

  const { data, isLoading, isError } = useQuery({
    queryKey: ["manga", "latest", 1, 40, inMyLists],
    queryFn: () => mangaService.latestUpdates(1, 40, inMyLists),
  });

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <div className="mb-8 border-b border-bd pb-4">
        <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div>
            <h1 className="font-heading text-3xl font-bold">Latest Updates</h1>
            <p className="mt-2 text-sm text-tx-muted">Manga that have been recently updated with new chapters.</p>
          </div>
          
          <div className="flex items-center gap-4">
            {isAuthenticated && (
              <label className="flex items-center gap-2 cursor-pointer text-sm font-medium text-tx-muted hover:text-tx transition-colors">
                <input 
                  type="checkbox" 
                  checked={inMyLists}
                  onChange={(e) => setInMyLists(e.target.checked)}
                  className="rounded border-bd bg-surface text-brand-orange focus:ring-brand-orange"
                />
                <Filter className="h-4 w-4" />
                In my lists
              </label>
            )}
            
            <div className="flex items-center gap-1 rounded-md border border-bd bg-surface p-1">
              <button
                onClick={() => setViewMode("grid")}
                className={cn("rounded px-2 py-1 transition-colors", viewMode === "grid" ? "bg-surface-2 text-tx" : "text-tx-muted hover:text-tx")}
              >
                <LayoutGrid className="h-4 w-4" />
              </button>
              <button
                onClick={() => setViewMode("list")}
                className={cn("rounded px-2 py-1 transition-colors", viewMode === "list" ? "bg-surface-2 text-tx" : "text-tx-muted hover:text-tx")}
              >
                <ListIcon className="h-4 w-4" />
              </button>
            </div>
          </div>
        </div>
      </div>

      {isLoading ? (
        <div className={cn("grid gap-4", viewMode === "grid" ? "grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6" : "sm:grid-cols-2 lg:grid-cols-3")}>
          {[...Array(18)].map((_, i) => (
            <Skeleton key={i} className={cn("w-full rounded-def", viewMode === "grid" ? "aspect-[2/3]" : "h-36")} />
          ))}
        </div>
      ) : isError || !data?.items.length ? (
        <EmptyState title="No updates found" description={inMyLists ? "None of the manga in your lists have been updated recently." : "Check back later for new chapters."} />
      ) : (
        <div className={cn("grid gap-4", viewMode === "grid" ? "grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6" : "sm:grid-cols-2 lg:grid-cols-3")}>
          {data.items.map((manga) => (
            <MangaCard key={manga.MangaId} manga={manga} variant={viewMode === "grid" ? "grid" : "wide"} />
          ))}
        </div>
      )}
    </main>
  );
}

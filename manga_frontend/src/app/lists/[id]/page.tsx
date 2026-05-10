"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { ArrowLeft, BookmarkCheck, BookOpen, Trash2, Star, Calendar, Shield, LayoutGrid, List as ListIcon } from "lucide-react";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";
import { Skeleton } from "@/components/ui/Skeleton";
import { useToast } from "@/components/ui/Toast";
import { useAuth } from "@/hooks/useAuth";
import { cn, titleCase } from "@/lib/utils";
import { listService } from "@/services/list.service";

export default function ListDetailPage() {
  const params = useParams<{ id: string }>();
  const listId = params.id;
  const queryClient = useQueryClient();
  const { user, isAuthenticated } = useAuth();
  const { toast } = useToast();
  const [viewMode, setViewMode] = useState<"grid" | "list">("list");

  const detail = useQuery({
    queryKey: ["lists", "detail", listId],
    queryFn: () => listService.detail(listId),
  });

  const followMutation = useMutation({
    mutationFn: () => listService.follow(listId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["lists"] });
      toast("Followed list!", "success");
    },
  });

  const removeItemMutation = useMutation({
    mutationFn: (mangaId: string) => listService.removeItem(listId, mangaId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["lists", "detail", listId] });
      toast("Manga removed from list", "success");
    },
  });

  if (detail.isLoading) {
    return (
      <div className="page-shell">
        <Skeleton className="h-52" />
        <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {[1, 2, 3, 4, 5, 6].map((i) => (
            <Skeleton key={i} className="h-36" />
          ))}
        </div>
      </div>
    );
  }

  if (!detail.data) {
    return (
      <div className="page-shell">
        <EmptyState title="List not found" description="The backend could not find this MDList." />
      </div>
    );
  }

  const list = detail.data;
  const isOwner = user?.UserId === list.owner_id;

  return (
    <div className="page-shell">
      <Link href="/lists" className="focus-ring mb-4 inline-flex h-10 items-center gap-2 rounded-full px-3 text-sm font-semibold hover:bg-surface-2">
        <ArrowLeft className="h-4 w-4" aria-hidden />
        Lists
      </Link>

      {/* ── List Header with Cover ── */}
      <section className="card overflow-hidden">
        <div className="relative">
          {/* Cover background */}
          {list.cover_url ? (
            <div className="relative h-40 overflow-hidden">
              <img src={list.cover_url} alt="" className="h-full w-full object-cover" />
              <div className="absolute inset-0 bg-gradient-to-t from-[var(--surface)] via-[var(--surface)]/60 to-transparent" />
            </div>
          ) : (
            <div className="h-24 bg-gradient-to-r from-[var(--accent)]/20 to-[var(--accent-2)]/20" />
          )}
          <div className={cn("px-5 pb-5", list.cover_url ? "-mt-12 relative" : "pt-5")}>
            <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
              <div>
                <Badge tone={list.Visibility === "public" ? "sky" : "default"}>{list.Visibility}</Badge>
                <h1 className="mt-3 font-heading text-4xl font-bold">{list.Name ?? "Untitled list"}</h1>
                <p className="mt-2 text-sm text-tx-muted">
                  by {list.owner_username ?? "unknown"} · {list.ItemCount} items · {list.FollowerCount} followers
                </p>
                {list.Description ? (
                  <p className="mt-4 max-w-3xl text-sm leading-6 text-tx-muted">{list.Description}</p>
                ) : null}
              </div>
              {isAuthenticated && !isOwner ? (
                <Button onClick={() => followMutation.mutate()} isLoading={followMutation.isPending}>
                  <BookmarkCheck className="h-4 w-4" aria-hidden />
                  Follow
                </Button>
              ) : null}
            </div>
          </div>
        </div>
      </section>

      {/* ── Items Grid ── */}
      <section className="mt-6">
        <div className="mb-4 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <h2 className="font-heading text-2xl font-semibold">Manga in this list</h2>
            <Badge tone="default">{list.items.length} items</Badge>
          </div>
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
        {list.items.length ? (
          <div className={cn("grid gap-4", viewMode === "grid" ? "grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6" : "sm:grid-cols-2 lg:grid-cols-3")}>
            {list.items.map((item) => (
              <Link
                href={`/manga/${item.manga_id}`}
                key={item.manga_id}
                className={cn("card group relative flex overflow-hidden p-0 transition-all hover:shadow-lg", viewMode === "grid" ? "flex-col aspect-[2/3]" : "gap-3")}
              >
                {/* Cover */}
                <div className={cn("shrink-0 overflow-hidden bg-surface-2 relative", viewMode === "grid" ? "h-full w-full" : "h-full w-24")}>
                  {item.cover_url ? (
                    <img src={item.cover_url} alt={item.title ?? ""} className="h-full w-full object-cover transition-transform group-hover:scale-105" />
                  ) : (
                    <div className="flex h-full min-h-[120px] w-full items-center justify-center text-tx-muted">
                      <BookOpen className="h-8 w-8" />
                    </div>
                  )}
                </div>
                {/* Info */}
                <div className={cn("flex flex-1 flex-col justify-between py-3 pr-3", viewMode === "grid" ? "hidden" : "flex")}>
                  <div>
                    <p className="line-clamp-2 font-bold text-tx transition-colors hover:text-accent">
                      {item.title ?? "Unknown manga"}
                    </p>
                    <div className="mt-2 flex flex-wrap gap-1.5">
                      {item.status && (
                        <Badge tone="orange">{titleCase(item.status)}</Badge>
                      )}
                      {item.content_rating && (
                        <Badge tone="warning">{titleCase(item.content_rating)}</Badge>
                      )}
                      {item.year && (
                        <span className="inline-flex items-center gap-1 text-xs text-tx-muted">
                          <Calendar className="h-3 w-3" aria-hidden />
                          {item.year}
                        </span>
                      )}
                    </div>
                  </div>
                  <div className="mt-3 flex items-center justify-between">
                    <span className="flex h-6 w-6 items-center justify-center rounded-full bg-surface-2 text-xs font-bold text-tx-muted">
                      {item.position}
                    </span>
                    {isOwner && (
                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={() => removeItemMutation.mutate(item.manga_id)}
                        aria-label="Remove manga"
                        className="h-8 w-8 text-red-400 hover:bg-red-500/10"
                      >
                        <Trash2 className="h-4 w-4" aria-hidden />
                      </Button>
                    )}
                  </div>
                </div>

                {/* Grid Mode Info */}
                {viewMode === "grid" && (
                  <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-transparent opacity-0 transition-opacity group-hover:opacity-100 flex flex-col justify-end p-2">
                    <p className="line-clamp-2 text-xs font-bold text-white">{item.title}</p>
                    {isOwner && (
                       <button
                         onClick={(e) => { e.preventDefault(); removeItemMutation.mutate(item.manga_id); }}
                         className="absolute top-2 right-2 rounded-full bg-black/50 p-1.5 text-red-400 hover:bg-red-500 hover:text-white transition-colors"
                       >
                         <Trash2 className="h-3 w-3" />
                       </button>
                    )}
                  </div>
                )}
              </Link>
            ))}
          </div>
        ) : (
          <div className="card p-6">
            <EmptyState title="No items yet" description="Add manga to this list from a manga detail page." />
          </div>
        )}
      </section>
    </div>
  );
}

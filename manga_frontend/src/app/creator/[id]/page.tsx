"use client";

import { useQuery } from "@tanstack/react-query";
import { useParams } from "next/navigation";
import { MangaCard } from "@/components/features/MangaCard";
import { EmptyState } from "@/components/ui/EmptyState";
import { Skeleton } from "@/components/ui/Skeleton";
import { creatorService } from "@/services/creator.service";
import { User } from "lucide-react";
import Image from "next/image";

export default function CreatorPage() {
  const { id } = useParams() as { id: string };

  const { data, isLoading, isError } = useQuery({
    queryKey: ["creator", id],
    queryFn: () => creatorService.getCreator(id),
  });

  if (isLoading) {
    return (
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="flex flex-col gap-6 md:flex-row">
          <Skeleton className="h-48 w-48 shrink-0 rounded-full" />
          <div className="flex-1 space-y-4 pt-4">
            <Skeleton className="h-10 w-1/3" />
            <Skeleton className="h-24 w-full" />
          </div>
        </div>
        <div className="mt-12 grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6">
          {[...Array(6)].map((_, i) => (
            <Skeleton key={i} className="aspect-[2/3] w-full rounded-def" />
          ))}
        </div>
      </div>
    );
  }

  if (isError || !data) {
    return (
      <div className="flex min-h-[50vh] items-center justify-center">
        <EmptyState title="Creator not found" description="The creator you are looking for does not exist." />
      </div>
    );
  }

  const { creator, mangas } = data;

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      {/* ── Profile Header ── */}
      <section className="flex flex-col items-center gap-6 rounded-def bg-surface-2 p-8 md:flex-row md:items-start">
        <div className="flex h-32 w-32 shrink-0 items-center justify-center overflow-hidden rounded-full border-4 border-bd bg-surface shadow-md md:h-40 md:w-40">
          {creator.image_url ? (
            <Image
              src={creator.image_url}
              alt={creator.name}
              width={160}
              height={160}
              className="h-full w-full object-cover"
            />
          ) : (
            <User className="h-16 w-16 text-tx-muted" />
          )}
        </div>
        
        <div className="flex-1 text-center md:text-left">
          <h1 className="font-heading text-3xl font-bold text-tx">{creator.name}</h1>
          {creator.biography ? (
            <p className="mt-4 whitespace-pre-wrap text-sm leading-relaxed text-tx-muted">
              {creator.biography}
            </p>
          ) : (
            <p className="mt-4 text-sm italic text-tx-muted/60">No biography available.</p>
          )}
        </div>
      </section>

      {/* ── Manga List ── */}
      <section className="mt-12">
        <div className="mb-6 flex items-center justify-between">
          <h2 className="font-heading text-2xl font-bold">Works ({mangas.total})</h2>
        </div>

        {mangas.items.length > 0 ? (
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6">
            {mangas.items.map((manga) => (
              <MangaCard key={manga.MangaId} manga={manga} />
            ))}
          </div>
        ) : (
          <EmptyState title="No works found" description="This creator hasn't published any manga yet." />
        )}
      </section>
    </main>
  );
}

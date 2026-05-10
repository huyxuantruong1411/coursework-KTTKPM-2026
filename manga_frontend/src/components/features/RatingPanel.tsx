"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Star } from "lucide-react";
import { useState } from "react";
import { Button } from "@/components/ui/Button";
import { useAuth } from "@/hooks/useAuth";
import { cn, formatNumber } from "@/lib/utils";
import { ratingService } from "@/services/rating.service";
import type { UUID } from "@/types/common";
import type { Statistics } from "@/types/manga";

interface RatingPanelProps {
  mangaId: UUID;
  stats?: Statistics | null;
}

export function RatingPanel({ mangaId, stats }: RatingPanelProps) {
  const queryClient = useQueryClient();
  const { isAuthenticated } = useAuth();
  const [hoverScore, setHoverScore] = useState<number | null>(null);

  const myRating = useQuery({
    queryKey: ["rating", mangaId, "me"],
    queryFn: () => ratingService.myRating(mangaId),
    enabled: isAuthenticated,
    retry: false,
  });

  const rateMutation = useMutation({
    mutationFn: (Score: number) => ratingService.rate(mangaId, { Score }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["rating", mangaId, "me"] });
      queryClient.invalidateQueries({ queryKey: ["manga", "detail", mangaId] });
    },
  });

  const activeScore = hoverScore ?? myRating.data?.Score ?? myRating.data?.score ?? 0;

  return (
    <section className="card p-4">
      <div className="flex items-center justify-between gap-4">
        <div>
          <h2 className="font-heading text-2xl font-semibold">Rating</h2>
          <p className="mt-1 text-sm text-tx-muted">
            Average {(stats?.AverageRating ?? 0).toFixed(1)} - {formatNumber(stats?.Follows)} follows
          </p>
        </div>
        <div className="flex h-12 w-12 items-center justify-center rounded-full bg-brand-orange text-lg font-bold text-white">
          {(stats?.AverageRating ?? 0).toFixed(1)}
        </div>
      </div>
      <div className="mt-4 flex flex-wrap gap-1">
        {Array.from({ length: 10 }).map((_, index) => {
          const score = index + 1;
          return (
            <button
              key={score}
              disabled={!isAuthenticated || rateMutation.isPending}
              onClick={() => rateMutation.mutate(score)}
              onMouseEnter={() => setHoverScore(score)}
              onMouseLeave={() => setHoverScore(null)}
              className={cn(
                "focus-ring flex h-9 w-9 items-center justify-center rounded-full border border-bd text-xs font-bold transition text-tx",
                score <= activeScore ? "border-brand-orange bg-brand-orange text-white" : "bg-surface-2 hover:border-brand-orange",
                !isAuthenticated && "cursor-not-allowed opacity-50",
              )}
              aria-label={`Rate ${score}`}
            >
              {score}
            </button>
          );
        })}
      </div>
      <p className="mt-3 flex items-center gap-2 text-xs text-tx-muted">
        <Star className="h-4 w-4 text-brand-orange" aria-hidden />
        {isAuthenticated ? "Pick a score from 1 to 10." : "Login to save your rating."}
      </p>
    </section>
  );
}

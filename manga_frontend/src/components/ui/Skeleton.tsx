import { cn } from "@/lib/utils";

export function Skeleton({ className }: { className?: string }) {
  return <div className={cn("rounded-def bg-surface-3 animate-pulse-gentle", className)} />;
}

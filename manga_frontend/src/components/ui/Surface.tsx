import { cn } from "@/lib/utils";
import { ReactNode } from "react";

export function Surface({ className, children }: { className?: string; children: ReactNode }) {
  return <div className={cn("rounded-def border border-bd bg-surface p-4", className)}>{children}</div>;
}

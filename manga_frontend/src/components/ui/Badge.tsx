import { cn } from "@/lib/utils";
import { ReactNode } from "react";

interface BadgeProps {
  tone?: "default" | "orange" | "purple" | "cyan" | "sky" | "warning" | "green" | "red" | "neutral" | "error";
  className?: string;
  children: ReactNode;
}

const toneClasses: Record<string, string> = {
  default: "bg-surface-2 text-tx-muted border border-bd",
  neutral: "bg-surface-2 text-tx-muted border border-bd",
  orange: "bg-[rgba(255,103,64,0.12)] text-accent border border-accent/30",
  purple: "bg-[rgba(192,132,252,0.12)] text-[var(--purple)] border border-[var(--purple)]/30",
  cyan: "bg-[rgba(5,170,240,0.12)] text-[var(--cyan)] border border-[var(--cyan)]/30",
  sky: "bg-[rgba(17,153,255,0.12)] text-[var(--sky)] border border-[var(--sky)]/30",
  warning: "bg-[rgba(245,158,11,0.12)] text-[var(--amber)] border border-[var(--amber)]/30",
  green: "bg-[rgba(34,197,94,0.12)] text-[var(--green)] border border-[var(--green)]/30",
  red: "bg-[rgba(239,68,68,0.12)] text-[var(--red)] border border-[var(--red)]/30",
  error: "bg-[rgba(239,68,68,0.12)] text-[var(--red)] border border-[var(--red)]/30",
};

export function Badge({ tone = "default", className, children }: BadgeProps) {
  return (
    <span className={cn("badge", toneClasses[tone], className)}>
      {children}
    </span>
  );
}

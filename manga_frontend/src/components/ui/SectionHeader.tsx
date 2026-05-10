import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { cn } from "@/lib/utils";

interface SectionHeaderProps {
  eyebrow?: string;
  title: string;
  description?: string;
  href?: string;
  className?: string;
}

export function SectionHeader({ eyebrow, title, description, href, className }: SectionHeaderProps) {
  return (
    <div className={cn("mb-5 flex flex-col gap-1 sm:flex-row sm:items-end sm:justify-between", className)}>
      <div>
        {eyebrow && (
          <span className="mb-1 inline-block text-xs font-bold uppercase tracking-wide text-accent">
            {eyebrow}
          </span>
        )}
        <h2 className="font-heading text-2xl font-bold text-tx md:text-3xl">{title}</h2>
        {description && <p className="mt-1 max-w-xl text-sm text-tx-muted">{description}</p>}
      </div>
      {href && (
        <Link href={href} className="group inline-flex items-center gap-1 text-sm font-semibold text-accent hover:underline">
          View all
          <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-1" aria-hidden />
        </Link>
      )}
    </div>
  );
}

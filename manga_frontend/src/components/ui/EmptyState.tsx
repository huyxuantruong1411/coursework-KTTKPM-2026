import { cn } from "@/lib/utils";
import { InboxIcon, type LucideIcon } from "lucide-react";

interface EmptyStateProps {
  title?: string;
  description?: string;
  icon?: LucideIcon;
  className?: string;
}

export function EmptyState({ title = "Nothing here", description, icon: Icon, className }: EmptyStateProps) {
  const IconComponent = Icon ?? InboxIcon;
  return (
    <div className={cn("flex flex-col items-center justify-center py-16 text-center", className)}>
      <div className="flex h-14 w-14 items-center justify-center rounded-full bg-surface-2 text-tx-muted">
        <IconComponent className="h-7 w-7" aria-hidden />
      </div>
      <h3 className="mt-4 font-heading text-lg font-semibold text-tx">{title}</h3>
      {description && <p className="mt-2 max-w-sm text-sm text-tx-muted">{description}</p>}
    </div>
  );
}

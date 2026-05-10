import { cn } from "@/lib/utils";

interface MangaCoverProps {
  src?: string | null;
  title?: string | null;
  className?: string;
}

export function MangaCover({ src, title, className }: MangaCoverProps) {
  return (
    <div className={cn("overflow-hidden rounded-sm bg-surface-2", className)}>
      {src ? (
        <img
          src={src}
          alt={title ?? "Cover"}
          loading="lazy"
          className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
        />
      ) : (
        <div className="flex h-full w-full items-center justify-center bg-surface-2 p-4 text-center">
          <span className="text-xs font-bold leading-relaxed text-tx-muted/80">
            {title ? title : "No Cover"}
          </span>
        </div>
      )}
    </div>
  );
}

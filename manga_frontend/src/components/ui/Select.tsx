import { cn } from "@/lib/utils";
import { SelectHTMLAttributes } from "react";

interface SelectProps extends SelectHTMLAttributes<HTMLSelectElement> {
  label?: string;
}

export function Select({ label, className, id, children, ...props }: SelectProps) {
  const selectId = id ?? label?.toLowerCase().replace(/\s/g, "-");
  return (
    <div className="w-full">
      {label && (
        <label htmlFor={selectId} className="mb-1.5 block text-xs font-bold text-tx-muted">
          {label}
        </label>
      )}
      <select
        id={selectId}
        className={cn(
          "focus-ring h-10 w-full rounded-def border border-bd bg-surface-2 px-3 text-sm text-tx outline-none transition-colors focus:border-accent",
          className,
        )}
        {...props}
      >
        {children}
      </select>
    </div>
  );
}

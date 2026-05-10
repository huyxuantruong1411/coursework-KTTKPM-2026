import { cn } from "@/lib/utils";
import { InputHTMLAttributes } from "react";

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
}

export function Input({ label, className, id, ...props }: InputProps) {
  const inputId = id ?? label?.toLowerCase().replace(/\s/g, "-");
  return (
    <div className="w-full">
      {label && (
        <label htmlFor={inputId} className="mb-1.5 block text-xs font-bold text-tx-muted">
          {label}
        </label>
      )}
      <input
        id={inputId}
        className={cn(
          "focus-ring h-10 w-full rounded-def border border-bd bg-surface-2 px-3 text-sm text-tx outline-none transition-colors placeholder:text-tx-muted/60 focus:border-accent",
          className,
        )}
        {...props}
      />
    </div>
  );
}

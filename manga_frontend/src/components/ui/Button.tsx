import { cn } from "@/lib/utils";
import { ButtonHTMLAttributes, ReactNode } from "react";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "primary" | "light" | "ghost" | "danger";
  size?: "sm" | "md" | "icon";
  isLoading?: boolean;
  children?: ReactNode;
}

export function Button({
  variant = "primary",
  size = "md",
  isLoading,
  className,
  children,
  disabled,
  ...props
}: ButtonProps) {
  return (
    <button
      className={cn(
        "focus-ring inline-flex items-center justify-center gap-2 font-semibold transition-all duration-150 rounded-def",
        /* sizes */
        size === "sm" && "h-8 px-3 text-xs",
        size === "md" && "h-10 px-4 text-sm",
        size === "icon" && "h-10 w-10 p-0",
        /* variants */
        variant === "primary" && "bg-accent text-white hover:bg-accent-hover active:bg-accent-active shadow-sm",
        variant === "light" && "bg-surface-2 text-tx hover:bg-surface-3 border border-bd",
        variant === "ghost" && "text-tx-muted hover:bg-accent-bg hover:text-accent",
        variant === "danger" && "bg-[var(--red)] text-white hover:opacity-90",
        (disabled || isLoading) && "opacity-50 pointer-events-none",
        className,
      )}
      disabled={disabled || isLoading}
      {...props}
    >
      {isLoading ? (
        <svg className="h-4 w-4 animate-spin" viewBox="0 0 24 24" fill="none">
          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
          <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z" />
        </svg>
      ) : null}
      {children}
    </button>
  );
}

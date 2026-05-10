"use client";

import { createContext, useCallback, useContext, useState } from "react";
import { cn } from "@/lib/utils";
import { AlertCircle, CheckCircle, Info, X, XCircle } from "lucide-react";

/* ─── Types ───────────────────────────────────────────── */
type ToastVariant = "success" | "error" | "info" | "warning";

interface ToastItem {
  id: number;
  message: string;
  variant: ToastVariant;
}

interface ToastContextValue {
  toast: (message: string, variant?: ToastVariant) => void;
}

/* ─── Context ─────────────────────────────────────────── */
const ToastContext = createContext<ToastContextValue>({ toast: () => {} });

export function useToast() {
  return useContext(ToastContext);
}

let _nextId = 0;

/* ─── Provider ────────────────────────────────────────── */
export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<ToastItem[]>([]);

  const toast = useCallback((message: string, variant: ToastVariant = "info") => {
    const id = ++_nextId;
    setToasts((prev) => [...prev, { id, message, variant }]);
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 4000);
  }, []);

  const remove = useCallback((id: number) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  return (
    <ToastContext.Provider value={{ toast }}>
      {children}
      {/* Toast container – bottom-right */}
      <div className="fixed bottom-4 right-4 z-[9999] flex flex-col gap-2 pointer-events-none">
        {toasts.map((t) => (
          <ToastCard key={t.id} item={t} onClose={() => remove(t.id)} />
        ))}
      </div>
    </ToastContext.Provider>
  );
}

/* ─── Single Toast Card ───────────────────────────────── */
const variantStyles: Record<ToastVariant, string> = {
  success: "border-emerald-500/40 bg-emerald-500/10 text-emerald-400",
  error: "border-red-500/40 bg-red-500/10 text-red-400",
  warning: "border-amber-500/40 bg-amber-500/10 text-amber-400",
  info: "border-sky-500/40 bg-sky-500/10 text-sky-400",
};

const variantIcons: Record<ToastVariant, React.ElementType> = {
  success: CheckCircle,
  error: XCircle,
  warning: AlertCircle,
  info: Info,
};

function ToastCard({ item, onClose }: { item: ToastItem; onClose: () => void }) {
  const Icon = variantIcons[item.variant];
  return (
    <div
      className={cn(
        "pointer-events-auto flex min-w-72 max-w-sm items-start gap-3 rounded-lg border px-4 py-3 shadow-lg backdrop-blur-xl transition-all",
        "animate-[slideUp_0.3s_ease-out]",
        variantStyles[item.variant],
      )}
    >
      <Icon className="mt-0.5 h-5 w-5 shrink-0" aria-hidden />
      <p className="flex-1 text-sm font-medium leading-5">{item.message}</p>
      <button onClick={onClose} className="shrink-0 opacity-60 hover:opacity-100 transition-opacity" aria-label="Close">
        <X className="h-4 w-4" />
      </button>
    </div>
  );
}

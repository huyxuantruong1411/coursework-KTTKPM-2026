"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ReactNode, useEffect, useState } from "react";
import { AppShell } from "@/components/layout/AppShell";
import { ToastProvider } from "@/components/ui/Toast";
import { useAppStore } from "@/store/useAppStore";

function ThemeApplier() {
  const theme = useAppStore((s) => s.theme);

  useEffect(() => {
    document.documentElement.setAttribute("data-theme", theme);
  }, [theme]);

  return null;
}

export function Providers({ children }: { children: ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 1000 * 30,
            retry: 1,
            refetchOnWindowFocus: false,
          },
        },
      }),
  );

  const [hydrated, setHydrated] = useState(false);

  // Rehydrate Zustand store on client (skipHydration: true)
  useEffect(() => {
    useAppStore.persist.rehydrate();
    setHydrated(true);
  }, []);

  // Don't render anything until the store is rehydrated
  // This prevents hydration mismatch (server has no theme, client does)
  if (!hydrated) {
    return null;
  }

  return (
    <QueryClientProvider client={queryClient}>
      <ToastProvider>
        <ThemeApplier />
        <AppShell>{children}</AppShell>
      </ToastProvider>
    </QueryClientProvider>
  );
}


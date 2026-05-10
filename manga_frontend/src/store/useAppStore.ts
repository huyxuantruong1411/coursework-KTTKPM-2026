import { create } from "zustand";
import { persist } from "zustand/middleware";
import { API_TOKEN_STORAGE_KEY } from "@/services/api";
import type { User } from "@/types/user";

type ReaderDirection = "vertical" | "paged";
type ReaderFit = "width" | "height" | "original";
type Theme = "light" | "dark";

interface ReaderPreferences {
  direction: ReaderDirection;
  fit: ReaderFit;
  showToolbar: boolean;
}

interface AppState {
  sidebarOpen: boolean;
  mobileNavOpen: boolean;
  token: string | null;
  user: User | null;
  theme: Theme;
  chatOpen: boolean;
  reader: ReaderPreferences;
  setSidebarOpen: (open: boolean) => void;
  setMobileNavOpen: (open: boolean) => void;
  toggleSidebar: () => void;
  setAuth: (token: string, user?: User | null) => void;
  setUser: (user: User | null) => void;
  clearAuth: () => void;
  updateReader: (reader: Partial<ReaderPreferences>) => void;
  toggleTheme: () => void;
  setChatOpen: (open: boolean) => void;
  toggleChat: () => void;
}

const defaultReader: ReaderPreferences = {
  direction: "vertical",
  fit: "width",
  showToolbar: true,
};

export const useAppStore = create<AppState>()(
  persist(
    (set, get) => ({
      sidebarOpen: true,
      mobileNavOpen: false,
      token: null,
      user: null,
      theme: "dark",
      chatOpen: false,
      reader: defaultReader,
      setSidebarOpen: (open) => set({ sidebarOpen: open }),
      setMobileNavOpen: (open) => set({ mobileNavOpen: open }),
      toggleSidebar: () => set({ sidebarOpen: !get().sidebarOpen }),
      setAuth: (token, user = null) => {
        if (typeof window !== "undefined") {
          window.localStorage.setItem(API_TOKEN_STORAGE_KEY, token);
        }
        set({ token, user });
      },
      setUser: (user) => set({ user }),
      clearAuth: () => {
        if (typeof window !== "undefined") {
          window.localStorage.removeItem(API_TOKEN_STORAGE_KEY);
        }
        set({ token: null, user: null });
      },
      updateReader: (reader) => set({ reader: { ...get().reader, ...reader } }),
      toggleTheme: () => {
        const next = get().theme === "dark" ? "light" : "dark";
        set({ theme: next });
      },
      setChatOpen: (open) => set({ chatOpen: open }),
      toggleChat: () => set({ chatOpen: !get().chatOpen }),
    }),
    {
      name: "manga-app-store",
      skipHydration: true,
      partialize: (state) => ({
        token: state.token,
        user: state.user,
        reader: state.reader,
        sidebarOpen: state.sidebarOpen,
        theme: state.theme,
      }),
    },
  ),
);

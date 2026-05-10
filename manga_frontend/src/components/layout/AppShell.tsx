"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { ReactNode, useMemo, useState } from "react";
import {
  BookOpen,
  Compass,
  Clock,
  History,
  Home,
  Library,
  LogIn,
  LogOut,
  Menu,
  MessageCircle,
  Moon,
  PanelLeftClose,
  PanelLeftOpen,
  Search,
  Shield,
  Shuffle,
  Sun,
  UserCircle,
  X,
} from "lucide-react";
import { useAuth } from "@/hooks/useAuth";
import { useMangaSearch } from "@/hooks/useMangaQueries";
import { cn } from "@/lib/utils";
import { mangaService } from "@/services/manga.service";
import { useAppStore } from "@/store/useAppStore";
import { Button } from "@/components/ui/Button";


const navigation = [
  { href: "/", label: "Home", icon: Home },
  { href: "/latest", label: "Latest", icon: Clock },
  { href: "/explore", label: "Explore", icon: Compass },
  { href: "/lists", label: "Lists", icon: Library },
  { href: "/chat", label: "Chat", icon: MessageCircle },
  { href: "/profile", label: "Profile", icon: UserCircle },
];

function isActive(pathname: string, href: string) {
  if (href === "/") return pathname === "/";
  return pathname.startsWith(href);
}

export function AppShell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const sidebarOpen = useAppStore((s) => s.sidebarOpen);

  if (pathname.startsWith("/read/")) {
    return <>{children}</>;
  }

  return (
    <div className="min-h-screen bg-bg text-tx transition-colors duration-300">
      <DesktopSidebar pathname={pathname} />
      <MobileDrawer pathname={pathname} />
      <div
        className={cn(
          "min-h-screen transition-all duration-300 lg:pl-[68px]",
          sidebarOpen ? "xl:pl-60" : "xl:pl-[68px]"
        )}
      >
        <TopBar />
        <main className="pb-20 lg:pb-0">{children}</main>
      </div>
      <BottomNav pathname={pathname} />
    </div>
  );
}

/* ═══════════════════════════════════════════
   DESKTOP SIDEBAR
   ═══════════════════════════════════════════ */
function DesktopSidebar({ pathname }: { pathname: string }) {
  const sidebarOpen = useAppStore((s) => s.sidebarOpen);
  const toggleSidebar = useAppStore((s) => s.toggleSidebar);
  const toggleTheme = useAppStore((s) => s.toggleTheme);
  const theme = useAppStore((s) => s.theme);
  const { isAdmin } = useAuth();

  return (
    <aside
      className={cn(
        "fixed inset-y-0 left-0 z-40 hidden border-r border-bd bg-surface transition-all duration-300 lg:flex lg:flex-col",
        sidebarOpen ? "w-60" : "w-[68px]",
      )}
    >
      {/* Logo */}
      <div className="flex h-16 items-center px-4">
        <Link href="/" className="focus-ring flex items-center gap-3 rounded-def px-1">
          <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-accent text-white">
            <BookOpen className="h-5 w-5" aria-hidden />
          </span>
          {sidebarOpen && <span className="font-heading text-xl font-bold">MangaLib</span>}
        </Link>
      </div>

      {/* Nav */}
      <nav className="flex-1 space-y-1 px-3 py-3">
        {navigation.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            title={item.label}
            className={cn(
              "focus-ring flex min-h-10 items-center gap-3 rounded-def px-3 py-2 text-sm font-medium transition-colors duration-150",
              sidebarOpen ? "justify-start" : "justify-center",
              isActive(pathname, item.href)
                ? "bg-accent text-white shadow-sm"
                : "text-tx-muted hover:bg-accent-bg hover:text-accent",
            )}
          >
            <item.icon className="h-5 w-5 shrink-0" aria-hidden />
            {sidebarOpen && <span>{item.label}</span>}
          </Link>
        ))}
        {isAdmin && (
          <Link
            href="/admin"
            title="Admin"
            className={cn(
              "focus-ring flex min-h-10 items-center gap-3 rounded-def px-3 py-2 text-sm font-medium transition-colors duration-150",
              sidebarOpen ? "justify-start" : "justify-center",
              isActive(pathname, "/admin")
                ? "bg-accent text-white shadow-sm"
                : "text-tx-muted hover:bg-accent-bg hover:text-accent",
            )}
          >
            <Shield className="h-5 w-5 shrink-0" aria-hidden />
            {sidebarOpen && <span>Admin</span>}
          </Link>
        )}
      </nav>

      {/* Bottom actions */}
      <div className="space-y-1 border-t border-bd px-3 py-3">

        <button
          onClick={toggleTheme}
          title={theme === "dark" ? "Light mode" : "Dark mode"}
          className={cn(
            "flex min-h-10 w-full items-center gap-3 rounded-def px-3 py-2 text-sm font-medium text-tx-muted transition-colors duration-150 hover:bg-accent-bg hover:text-accent",
            sidebarOpen ? "justify-start" : "justify-center",
          )}
        >
          {theme === "dark" ? <Sun className="h-5 w-5 shrink-0" aria-hidden /> : <Moon className="h-5 w-5 shrink-0" aria-hidden />}
          {sidebarOpen && <span>{theme === "dark" ? "Light mode" : "Dark mode"}</span>}
        </button>
        <Button variant="ghost" className={cn("w-full", sidebarOpen ? "justify-start" : "justify-center")} onClick={toggleSidebar}>
          {sidebarOpen ? <PanelLeftClose className="h-5 w-5" aria-hidden /> : <PanelLeftOpen className="h-5 w-5" aria-hidden />}
          {sidebarOpen && <span>Collapse</span>}
        </Button>
      </div>
    </aside>
  );
}

/* ═══════════════════════════════════════════
   MOBILE DRAWER
   ═══════════════════════════════════════════ */
function MobileDrawer({ pathname }: { pathname: string }) {
  const mobileNavOpen = useAppStore((s) => s.mobileNavOpen);
  const setMobileNavOpen = useAppStore((s) => s.setMobileNavOpen);
  const toggleTheme = useAppStore((s) => s.toggleTheme);
  const theme = useAppStore((s) => s.theme);
  const { isAdmin } = useAuth();

  return (
    <>
      <div
        className={cn(
          "fixed inset-0 z-50 bg-black/60 backdrop-blur-sm transition-opacity duration-300 lg:hidden",
          mobileNavOpen ? "opacity-100" : "pointer-events-none opacity-0",
        )}
        onClick={() => setMobileNavOpen(false)}
      />
      <aside
        className={cn(
          "fixed inset-y-0 left-0 z-50 w-72 border-r border-bd bg-surface p-4 transition-transform duration-300 lg:hidden",
          mobileNavOpen ? "translate-x-0 animate-slideInLeft" : "-translate-x-full",
        )}
      >
        <div className="mb-5 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-3" onClick={() => setMobileNavOpen(false)}>
            <span className="flex h-10 w-10 items-center justify-center rounded-lg bg-accent text-white">
              <BookOpen className="h-5 w-5" aria-hidden />
            </span>
            <span className="font-heading text-xl font-bold">MangaLib</span>
          </Link>
          <Button variant="ghost" size="icon" onClick={() => setMobileNavOpen(false)} aria-label="Close menu">
            <X className="h-5 w-5" aria-hidden />
          </Button>
        </div>
        <nav className="space-y-1">
          {[...navigation, ...(isAdmin ? [{ href: "/admin", label: "Admin", icon: Shield }] : [])].map((item) => (
            <Link
              key={item.href}
              href={item.href}
              onClick={() => setMobileNavOpen(false)}
              className={cn(
                "focus-ring flex min-h-11 items-center gap-3 rounded-def px-3 py-2 text-sm font-medium transition-colors",
                isActive(pathname, item.href)
                  ? "bg-accent text-white"
                  : "text-tx-muted hover:bg-accent-bg hover:text-accent",
              )}
            >
              <item.icon className="h-5 w-5" aria-hidden />
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="mt-auto border-t border-bd pt-3 mt-6">
          <button
            onClick={toggleTheme}
            className="flex min-h-11 w-full items-center gap-3 rounded-def px-3 py-2 text-sm font-medium text-tx-muted hover:bg-accent-bg hover:text-accent"
          >
            {theme === "dark" ? <Sun className="h-5 w-5" aria-hidden /> : <Moon className="h-5 w-5" aria-hidden />}
            {theme === "dark" ? "Light mode" : "Dark mode"}
          </button>
        </div>
      </aside>
    </>
  );
}

/* ═══════════════════════════════════════════
   TOP BAR
   ═══════════════════════════════════════════ */
function TopBar() {
  const setMobileNavOpen = useAppStore((s) => s.setMobileNavOpen);
  const { user, isAuthenticated, logout } = useAuth();

  return (
    <header className="sticky top-0 z-30 border-b border-bd bg-surface/80 backdrop-blur-lg">
      <div className="mx-auto flex h-16 max-w-content items-center gap-3 px-3 sm:px-4 md:px-6 xl:px-8">
        <Button variant="ghost" size="icon" className="lg:hidden" onClick={() => setMobileNavOpen(true)} aria-label="Open menu">
          <Menu className="h-5 w-5" aria-hidden />
        </Button>
        <SearchBox />
        <RandomButton />
        <div className="ml-auto hidden items-center gap-2 sm:flex">
          {isAuthenticated ? (
            <>
              <Link
                href="/profile"
                className="focus-ring inline-flex h-10 items-center gap-2 rounded-full px-3 text-sm font-semibold text-tx-muted hover:bg-accent-bg hover:text-accent transition-colors"
              >
                <UserCircle className="h-5 w-5" aria-hidden />
                <span className="max-w-28 truncate">{user?.Username ?? "Account"}</span>
              </Link>
              <Button variant="ghost" size="icon" onClick={logout} aria-label="Logout">
                <LogOut className="h-5 w-5" aria-hidden />
              </Button>
            </>
          ) : (
            <Link
              href="/auth/login"
              className="focus-ring inline-flex h-10 items-center gap-2 rounded-def bg-accent px-4 text-sm font-semibold text-white hover:bg-accent-hover transition-colors"
            >
              <LogIn className="h-5 w-5" aria-hidden />
              Login
            </Link>
          )}
        </div>
      </div>
    </header>
  );
}

/* ═══════════════════════════════════════════
   SEARCH BOX
   ═══════════════════════════════════════════ */
function SearchBox() {
  const router = useRouter();
  const [query, setQuery] = useState("");
  const [focused, setFocused] = useState(false);
  const trimmed = query.trim();
  const searchQuery = useMangaSearch(trimmed, 5);
  const suggestions = searchQuery.data ?? [];

  function submitSearch() {
    if (!trimmed) return;
    router.push(`/explore?q=${encodeURIComponent(trimmed)}`);
    setQuery("");
  }

  return (
    <div className="relative min-w-0 flex-1">
      <div
        className={cn(
          "flex h-11 items-center rounded-def border bg-surface-2 px-3 transition-all duration-200",
          focused ? "border-accent ring-2 ring-accent-bg" : "border-bd",
        )}
      >
        <Search className="mr-2 h-5 w-5 shrink-0 text-tx-muted" aria-hidden />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && submitSearch()}
          onFocus={() => setFocused(true)}
          onBlur={() => setTimeout(() => setFocused(false), 200)}
          placeholder="Search manga, author, alt title..."
          className="h-full min-w-0 flex-1 bg-transparent text-sm font-medium text-tx outline-none placeholder:text-tx-muted/60"
        />
      </div>
      {trimmed && suggestions.length > 0 && focused && (
        <div className="absolute left-0 right-0 top-12 z-50 overflow-hidden rounded-def border border-bd bg-surface shadow-floating animate-fadeIn">
          {suggestions.map((item) => (
            <Link
              key={item.MangaId}
              href={`/manga/${item.MangaId}`}
              onClick={() => setQuery("")}
              className="flex items-center gap-3 border-b border-bd px-3 py-2.5 last:border-b-0 hover:bg-accent-bg transition-colors"
            >
              <div className="h-12 w-9 overflow-hidden rounded-sm bg-surface-2">
                {item.cover_url ? <img src={item.cover_url} alt="" className="h-full w-full object-cover" /> : null}
              </div>
              <div className="min-w-0">
                <p className="truncate text-sm font-semibold text-tx">{item.TitleEn ?? "Untitled"}</p>
                <p className="text-xs text-tx-muted">{item.Year ?? "Unknown"} · {item.Status ?? "status"}</p>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}

/* ═══════════════════════════════════════════
   RANDOM BUTTON
   ═══════════════════════════════════════════ */
function RandomButton() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  async function goRandom() {
    setLoading(true);
    try {
      const result = await mangaService.random();
      if ("MangaId" in result) {
        router.push(`/manga/${result.MangaId}`);
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <Button variant="ghost" size="icon" onClick={goRandom} isLoading={loading} aria-label="Random manga">
      {!loading && <Shuffle className="h-5 w-5" aria-hidden />}
    </Button>
  );
}

/* ═══════════════════════════════════════════
   BOTTOM NAV
   ═══════════════════════════════════════════ */
function BottomNav({ pathname }: { pathname: string }) {
  const { isAdmin } = useAuth();
  const items = useMemo(
    () => [...navigation.slice(0, 4), ...(isAdmin ? [{ href: "/admin", label: "Admin", icon: Shield }] : [])],
    [isAdmin],
  );

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-40 grid grid-cols-6 border-t border-bd bg-surface/95 backdrop-blur-sm lg:hidden">
      {items.slice(0, 6).map((item) => (
        <Link
          key={item.href}
          href={item.href}
          className={cn(
            "flex min-h-14 flex-col items-center justify-center gap-1 text-[11px] font-semibold transition-colors",
            isActive(pathname, item.href) ? "text-accent" : "text-tx-muted",
          )}
        >
          <item.icon className="h-5 w-5" aria-hidden />
          {item.label}
        </Link>
      ))}
    </nav>
  );
}

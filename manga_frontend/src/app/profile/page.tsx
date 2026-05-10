"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  BarChart3, BookOpen, Camera, ChevronRight, Clock, Edit3, History,
  Lock, LogOut, Mail, Save, Sparkles, User as UserIcon, X,
  Activity, Hash, Star, LayoutGrid, Award, Shield,
} from "lucide-react";
import { FormEvent, useRef, useState } from "react";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";
import { Input } from "@/components/ui/Input";
import { Skeleton } from "@/components/ui/Skeleton";
import { useToast } from "@/components/ui/Toast";
import { useAuth } from "@/hooks/useAuth";
import { cn, formatDate } from "@/lib/utils";
import { authService } from "@/services/auth.service";
import { historyService } from "@/services/history.service";
import { getApiErrorMessage } from "@/services/api";
import { analyticsService } from "@/services/analytics.service";
import { recommendationService } from "@/services/analytics.service";
import type { HistoryEntry, HistoryGroup } from "@/types/history";

const TABS = [
  { id: "profile", label: "Profile", icon: UserIcon },
  { id: "history", label: "History", icon: History },
  { id: "analytics", label: "Analytics", icon: BarChart3 },
  { id: "recommendations", label: "For You", icon: Sparkles },
] as const;
type TabId = (typeof TABS)[number]["id"];

export default function ProfilePage() {
  const router = useRouter();
  const { user, isAuthenticated, isLoadingUser, logout } = useAuth();
  const [activeTab, setActiveTab] = useState<TabId>("profile");

  if (!isAuthenticated && !isLoadingUser) {
    return (
      <div className="page-shell">
        <EmptyState title="Not logged in" description="Login to view your profile." />
      </div>
    );
  }

  if (isLoadingUser || !user) {
    return (
      <div className="page-shell">
        <Skeleton className="h-60" />
        <div className="mt-6 space-y-4">
          <Skeleton className="h-96" />
        </div>
      </div>
    );
  }

  return (
    <div className="page-shell">
      {/* ── Header ── */}
      <section className="card overflow-hidden">
        <div className="relative h-32 bg-gradient-to-r from-[var(--accent)] via-[#ff8c5a] to-[var(--accent-2)]">
          <div className="absolute inset-0 bg-black/20" />
        </div>
        <div className="relative px-5 pb-5">
          <div className="flex flex-col items-start gap-4 sm:flex-row sm:items-end">
            <div className="relative -mt-12 h-24 w-24 shrink-0 rounded-full border-4 border-[var(--surface)] bg-[var(--surface-2)] shadow-lg">
              {user.Avatar ? (
                <img src={user.Avatar} alt="Avatar" className="h-full w-full rounded-full object-cover" />
              ) : (
                <div className="flex h-full w-full items-center justify-center rounded-full bg-gradient-to-br from-[var(--accent)] to-[var(--accent-2)] text-3xl font-bold text-white">
                  {(user.DisplayName || user.Username || "U").charAt(0).toUpperCase()}
                </div>
              )}
            </div>
            <div className="flex-1 py-2">
              <h1 className="font-heading text-2xl font-bold text-tx">
                {user.DisplayName || user.Username}
              </h1>
              <p className="text-sm text-tx-muted">@{user.Username}</p>
              {user.Bio && <p className="mt-1 text-sm text-tx-muted">{user.Bio}</p>}
            </div>
            <div className="flex gap-2">
              <Badge tone={user.Role === "admin" ? "orange" : "sky"}>{user.Role}</Badge>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => {
                  logout();
                  router.push("/");
                }}
              >
                <LogOut className="h-4 w-4" aria-hidden />
                Logout
              </Button>
            </div>
          </div>
        </div>
      </section>

      {/* ── Tab Bar ── */}
      <nav className="mt-6 flex gap-1 overflow-x-auto rounded-lg border border-bd bg-surface p-1" role="tablist">
        {TABS.map((tab) => {
          const Icon = tab.icon;
          return (
            <button
              key={tab.id}
              role="tab"
              aria-selected={activeTab === tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={cn(
                "flex items-center gap-2 whitespace-nowrap rounded-md px-4 py-2.5 text-sm font-semibold transition-all",
                activeTab === tab.id
                  ? "bg-accent-bg text-accent shadow-sm"
                  : "text-tx-muted hover:bg-surface-2 hover:text-tx",
              )}
            >
              <Icon className="h-4 w-4" aria-hidden />
              {tab.label}
            </button>
          );
        })}
      </nav>

      {/* ── Tab Content ── */}
      <div className="mt-6 animate-fadeIn">
        {activeTab === "profile" && <ProfileTab />}
        {activeTab === "history" && <HistoryTab />}
        {activeTab === "analytics" && <AnalyticsTab />}
        {activeTab === "recommendations" && <RecommendationsTab />}
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════
   PROFILE TAB
   ═══════════════════════════════════════════ */
function ProfileTab() {
  const { user, updateProfile } = useAuth();
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const fileRef = useRef<HTMLInputElement>(null);

  const [editing, setEditing] = useState(false);
  const [form, setForm] = useState({
    username: user?.Username ?? "",
    email: user?.Email ?? "",
    display_name: user?.DisplayName ?? "",
    bio: user?.Bio ?? "",
  });
  const [passwordForm, setPasswordForm] = useState({ current: "", new: "", confirm: "" });

  const avatarMutation = useMutation({
    mutationFn: (file: File) => authService.uploadAvatar(file),
    onSuccess: () => {
      toast("Avatar updated!", "success");
      queryClient.invalidateQueries({ queryKey: ["auth", "me"] });
    },
    onError: (e) => toast(getApiErrorMessage(e), "error"),
  });

  function handleAvatarChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (file) avatarMutation.mutate(file);
  }

  function handleSave(e: FormEvent) {
    e.preventDefault();
    const payload: Record<string, string> = {};
    if (form.username !== user?.Username) payload.username = form.username;
    if (form.email !== user?.Email) payload.email = form.email;
    if (form.display_name !== (user?.DisplayName ?? "")) payload.display_name = form.display_name;
    if (form.bio !== (user?.Bio ?? "")) payload.bio = form.bio;

    if (passwordForm.new) {
      if (passwordForm.new !== passwordForm.confirm) {
        toast("Passwords don't match", "error");
        return;
      }
      payload.current_password = passwordForm.current;
      payload.new_password = passwordForm.new;
    }

    if (Object.keys(payload).length === 0) {
      toast("No changes to save", "info");
      return;
    }

    updateProfile.mutate(payload, {
      onSuccess: () => {
        toast("Profile updated!", "success");
        setEditing(false);
        setPasswordForm({ current: "", new: "", confirm: "" });
      },
      onError: (e) => toast(getApiErrorMessage(e), "error"),
    });
  }

  return (
    <div className="grid gap-6 lg:grid-cols-[280px_1fr]">
      {/* Avatar */}
      <div className="card flex flex-col items-center gap-4 p-6">
        <div className="group relative h-36 w-36">
          <div className="h-full w-full overflow-hidden rounded-full border-2 border-bd bg-surface-2">
            {user?.Avatar ? (
              <img src={user.Avatar} alt="Avatar" className="h-full w-full object-cover" />
            ) : (
              <div className="flex h-full w-full items-center justify-center bg-gradient-to-br from-[var(--accent)] to-[var(--accent-2)] text-5xl font-bold text-white">
                {(user?.DisplayName || user?.Username || "U").charAt(0).toUpperCase()}
              </div>
            )}
          </div>
          <button
            onClick={() => fileRef.current?.click()}
            className="absolute bottom-1 right-1 flex h-10 w-10 items-center justify-center rounded-full bg-accent text-white shadow-lg transition hover:scale-110"
            aria-label="Change avatar"
          >
            <Camera className="h-5 w-5" />
          </button>
          <input
            ref={fileRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={handleAvatarChange}
          />
        </div>
        <div className="text-center">
          <p className="font-heading text-lg font-bold">{user?.DisplayName || user?.Username}</p>
          <p className="text-sm text-tx-muted">@{user?.Username}</p>
        </div>
        <div className="w-full space-y-2 text-sm text-tx-muted">
          <div className="flex items-center gap-2">
            <Mail className="h-4 w-4" aria-hidden />
            <span className="truncate">{user?.Email}</span>
          </div>
          <div className="flex items-center gap-2">
            <Clock className="h-4 w-4" aria-hidden />
            <span>Joined {user?.CreatedAt ? formatDate(user.CreatedAt) : "Unknown"}</span>
          </div>
        </div>
      </div>

      {/* Profile Form */}
      <div className="card p-6">
        <div className="flex items-center justify-between">
          <h2 className="font-heading text-xl font-semibold">Profile Information</h2>
          {!editing && (
            <Button variant="light" size="sm" onClick={() => setEditing(true)}>
              <Edit3 className="h-4 w-4" aria-hidden />
              Edit
            </Button>
          )}
        </div>
        {editing ? (
          <form onSubmit={handleSave} className="mt-6 space-y-5">
            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <label className="mb-1 block text-sm font-semibold text-tx">Username</label>
                <Input value={form.username} onChange={(e) => setForm({ ...form, username: e.target.value })} />
              </div>
              <div>
                <label className="mb-1 block text-sm font-semibold text-tx">Display Name</label>
                <Input value={form.display_name} onChange={(e) => setForm({ ...form, display_name: e.target.value })} placeholder="Optional display name" />
              </div>
            </div>
            <div>
              <label className="mb-1 block text-sm font-semibold text-tx">Email</label>
              <Input type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
            </div>
            <div>
              <label className="mb-1 block text-sm font-semibold text-tx">Bio</label>
              <textarea
                value={form.bio}
                onChange={(e) => setForm({ ...form, bio: e.target.value })}
                maxLength={500}
                placeholder="Tell us about yourself..."
                className="focus-ring min-h-20 w-full resize-y rounded-def border border-bd bg-surface-2 p-3 text-sm leading-6 text-tx outline-none placeholder:text-tx-muted/60"
              />
              <p className="mt-1 text-right text-xs text-tx-muted">{form.bio.length}/500</p>
            </div>

            {/* Password Change */}
            <div className="border-t border-bd pt-5">
              <h3 className="mb-3 flex items-center gap-2 text-sm font-semibold text-tx">
                <Lock className="h-4 w-4" aria-hidden />
                Change Password
              </h3>
              <div className="grid gap-4 sm:grid-cols-3">
                <Input type="password" placeholder="Current password" value={passwordForm.current} onChange={(e) => setPasswordForm({ ...passwordForm, current: e.target.value })} />
                <Input type="password" placeholder="New password" value={passwordForm.new} onChange={(e) => setPasswordForm({ ...passwordForm, new: e.target.value })} />
                <Input type="password" placeholder="Confirm new" value={passwordForm.confirm} onChange={(e) => setPasswordForm({ ...passwordForm, confirm: e.target.value })} />
              </div>
            </div>

            <div className="flex gap-3">
              <Button type="submit" isLoading={updateProfile.isPending}>
                <Save className="h-4 w-4" aria-hidden />
                Save Changes
              </Button>
              <Button type="button" variant="ghost" onClick={() => setEditing(false)}>
                <X className="h-4 w-4" aria-hidden />
                Cancel
              </Button>
            </div>
          </form>
        ) : (
          <dl className="mt-6 space-y-4">
            <ProfileField label="Username" value={user?.Username} />
            <ProfileField label="Display Name" value={user?.DisplayName || "Not set"} />
            <ProfileField label="Email" value={user?.Email} />
            <ProfileField label="Bio" value={user?.Bio || "No bio yet"} />
            <ProfileField label="Role" value={user?.Role} />
            <ProfileField label="Member Since" value={user?.CreatedAt ? formatDate(user.CreatedAt) : "Unknown"} />
          </dl>
        )}
      </div>
    </div>
  );
}

function ProfileField({ label, value }: { label: string; value?: string | null }) {
  return (
    <div className="flex items-center justify-between gap-4 border-b border-bd pb-3 last:border-b-0">
      <dt className="text-sm text-tx-muted">{label}</dt>
      <dd className="text-sm font-semibold text-tx">{value ?? "—"}</dd>
    </div>
  );
}

/* ═══════════════════════════════════════════
   HISTORY TAB (Grouped by Date)
   ═══════════════════════════════════════════ */
function HistoryTab() {
  const groupedQuery = useQuery({
    queryKey: ["history", "grouped"],
    queryFn: () => historyService.grouped(200),
  });

  if (groupedQuery.isLoading) {
    return (
      <div className="space-y-4">
        {[1, 2, 3].map((i) => (
          <Skeleton key={i} className="h-32" />
        ))}
      </div>
    );
  }

  const groups = groupedQuery.data?.groups ?? [];

  if (!groups.length) {
    return <EmptyState title="No reading history" description="Start reading manga to build your history." />;
  }

  return (
    <div className="space-y-6">
      {groups.map((group) => (
        <section key={group.label} className="card overflow-hidden">
          <div className="flex items-center gap-2 border-b border-bd bg-surface-2/50 px-4 py-3">
            <Clock className="h-4 w-4 text-accent" aria-hidden />
            <h3 className="text-sm font-bold text-tx">{group.label}</h3>
            <Badge tone="default">{group.items.length}</Badge>
          </div>
          <div className="divide-y divide-bd">
            {group.items.map((entry: HistoryEntry) => (
              <Link
                key={entry.HistoryId}
                href={`/read/${entry.MangaId}/${entry.ChapterId}${entry.LastPageRead ? `?page=${entry.LastPageRead}` : ""}`}
                className="flex items-center gap-3 p-3 transition-colors hover:bg-surface-2"
              >
                {/* Cover thumbnail */}
                <div className="h-16 w-11 shrink-0 overflow-hidden rounded-md bg-surface-2">
                  {entry.cover_url ? (
                    <img src={entry.cover_url} alt="" className="h-full w-full object-cover" />
                  ) : (
                    <div className="flex h-full w-full items-center justify-center text-xs text-tx-muted">
                      <BookOpen className="h-5 w-5" />
                    </div>
                  )}
                </div>
                <div className="min-w-0 flex-1">
                  <p className="truncate font-semibold text-tx">{entry.manga_title ?? "Unknown"}</p>
                  <p className="text-xs text-tx-muted">
                    Ch. {entry.chapter_number ?? "?"} · Page {entry.LastPageRead ?? "—"}
                  </p>
                  {entry.ReadAt && (
                    <p className="text-xs text-tx-muted/60">{formatDate(entry.ReadAt)}</p>
                  )}
                </div>
                <ChevronRight className="h-4 w-4 shrink-0 text-tx-muted" aria-hidden />
              </Link>
            ))}
          </div>
        </section>
      ))}
    </div>
  );
}

/* ═══════════════════════════════════════════
   ANALYTICS TAB
   ═══════════════════════════════════════════ */
function AnalyticsTab() {
  const statsQuery = useQuery({
    queryKey: ["analytics", "user-stats"],
    queryFn: () => analyticsService.getUserStats(),
  });

  if (statsQuery.isLoading) {
    return (
      <div className="space-y-6">
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {[1, 2, 3, 4].map((i) => <Skeleton key={i} className="h-24" />)}
        </div>
        <Skeleton className="h-64" />
      </div>
    );
  }

  const stats = statsQuery.data;
  if (!stats) return <EmptyState title="No data" description="Start reading to see your analytics." />;

  return (
    <div className="space-y-6">
      {/* ── Top Stats ── */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard title="Total Manga" value={stats.total_manga} icon={BookOpen} />
        <StatCard title="Chapters Read" value={stats.total_chapters} icon={Hash} />
        <StatCard title="Reading Sessions" value={stats.total_sessions} icon={Activity} />
        <StatCard title="Total Ratings" value={stats.total_ratings} icon={Star} />
      </div>

      {/* ── Distributions ── */}
      <div className="grid gap-6 lg:grid-cols-2">
        <section className="card p-5">
          <h3 className="mb-4 font-heading text-lg font-bold">Top Genres</h3>
          {stats.genre_distribution.length ? (
            <div className="space-y-3">
              {stats.genre_distribution.map((g) => (
                <div key={g.name} className="flex items-center justify-between">
                  <span className="text-sm font-medium text-tx">{g.name}</span>
                  <div className="flex items-center gap-3">
                    <div className="h-2 w-32 overflow-hidden rounded-full bg-surface-2">
                      <div
                        className="h-full bg-accent"
                        style={{ width: `${(g.count / stats.genre_distribution[0].count) * 100}%` }}
                      />
                    </div>
                    <span className="text-xs text-tx-muted">{g.count}</span>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-sm text-tx-muted">No genre data available.</p>
          )}
        </section>

        <section className="card p-5">
          <h3 className="mb-4 font-heading text-lg font-bold">Top Themes</h3>
          {stats.theme_distribution.length ? (
            <div className="flex flex-wrap gap-2">
              {stats.theme_distribution.map((t) => (
                <Badge key={t.name} tone="default">
                  {t.name} ({t.count})
                </Badge>
              ))}
            </div>
          ) : (
            <p className="text-sm text-tx-muted">No theme data available.</p>
          )}
        </section>
      </div>
    </div>
  );
}

function StatCard({ title, value, icon: Icon }: { title: string; value: number; icon: any }) {
  return (
    <div className="card p-5 transition-transform hover:-translate-y-1 hover:shadow-lg">
      <div className="flex items-center justify-between">
        <p className="text-sm font-medium text-tx-muted">{title}</p>
        <div className="flex h-8 w-8 items-center justify-center rounded-full bg-accent-bg text-accent">
          <Icon className="h-4 w-4" />
        </div>
      </div>
      <p className="mt-2 font-heading text-3xl font-bold">{value.toLocaleString()}</p>
    </div>
  );
}

/* ═══════════════════════════════════════════
   RECOMMENDATIONS TAB (Phase 3)
   ═══════════════════════════════════════════ */
function RecommendationsTab() {
  const [viewMode, setViewMode] = useState<"grid" | "list">("grid");
  const recsQuery = useQuery({
    queryKey: ["recommendations", "for-me"],
    queryFn: () => recommendationService.getForMe(18),
  });

  if (recsQuery.isLoading) {
    return (
      <div className="grid gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
        {[1, 2, 3, 4, 5, 6, 7, 8].map((i) => <Skeleton key={i} className="aspect-[2/3]" />)}
      </div>
    );
  }

  const recs = recsQuery.data?.recommendations ?? [];

  if (!recs.length) {
    return (
      <EmptyState
        title="No recommendations yet"
        description="Read and rate more manga to get personalized suggestions."
        icon={Sparkles}
      />
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3 rounded-lg border border-accent/20 bg-accent-bg px-4 py-3 text-accent">
          <Sparkles className="h-5 w-5 shrink-0" />
          <p className="text-sm font-medium">
            Personalized using collaborative filtering based on users with similar reading patterns.
          </p>
        </div>
        <div className="ml-4 flex shrink-0 gap-1 rounded-lg border border-bd bg-surface p-1">
          <button
            onClick={() => setViewMode("grid")}
            className={`rounded-md px-3 py-1.5 text-xs font-semibold transition-all ${viewMode === "grid" ? "bg-accent text-white" : "text-tx-muted hover:bg-surface-2"}`}
          >
            <LayoutGrid className="h-4 w-4" />
          </button>
          <button
            onClick={() => setViewMode("list")}
            className={`rounded-md px-3 py-1.5 text-xs font-semibold transition-all ${viewMode === "list" ? "bg-accent text-white" : "text-tx-muted hover:bg-surface-2"}`}
          >
            <Activity className="h-4 w-4" />
          </button>
        </div>
      </div>

      {viewMode === "grid" ? (
        <div className="grid gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
          {recs.map((manga) => (
            <RecCard key={manga.manga_id} manga={manga} />
          ))}
        </div>
      ) : (
        <div className="space-y-3">
          {recs.map((manga) => (
            <Link
              key={manga.manga_id}
              href={`/manga/${manga.manga_id}`}
              className="card flex gap-4 p-4 transition-colors hover:bg-surface-2"
            >
              <RecCover mangaId={manga.manga_id} />
              <div className="min-w-0 flex-1 py-1">
                <p className="truncate text-lg font-bold text-tx">{manga.title ?? "Unknown Manga"}</p>
                <div className="mt-2 flex flex-wrap items-center gap-3 text-xs text-tx-muted">
                  {manga.predicted_score > 0 && (
                    <span className="flex items-center gap-1 rounded-full bg-brand-orange/10 px-2 py-0.5 font-bold text-brand-orange">
                      <Star className="h-3 w-3 fill-current" />
                      {manga.predicted_score.toFixed(1)} match
                    </span>
                  )}
                  {manga.year && <span>{manga.year}</span>}
                  {manga.status && <span className="capitalize">{manga.status}</span>}
                  {manga.content_rating && (
                    <span className="rounded bg-surface-2 px-1.5 py-0.5 text-[10px] font-semibold uppercase">{manga.content_rating}</span>
                  )}
                </div>
                <p className="mt-1 text-xs text-tx-muted">
                  Source: {manga.source === "collaborative_filtering" ? "Collaborative Filtering" : "Popular"}
                </p>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}

/** Card component for grid view recommendations */
function RecCard({ manga }: { manga: import("@/services/analytics.service").RecommendationItem }) {
  return (
    <Link
      href={`/manga/${manga.manga_id}`}
      className="group relative flex flex-col overflow-hidden rounded-def border border-bd bg-surface-2 transition-all hover:shadow-lg hover:border-accent/30"
    >
      <div className="relative aspect-[2/3] overflow-hidden bg-surface">
        <RecCoverImage mangaId={manga.manga_id} />
        {manga.predicted_score > 0 && (
          <div className="absolute top-2 right-2 flex items-center gap-1 rounded-full bg-black/70 px-2 py-0.5 text-[10px] font-bold text-brand-orange backdrop-blur-sm">
            <Star className="h-3 w-3 fill-current" />
            {manga.predicted_score.toFixed(1)}
          </div>
        )}
      </div>
      <div className="flex-1 p-2">
        <p className="line-clamp-2 text-xs font-bold text-tx group-hover:text-accent transition-colors">
          {manga.title ?? "Unknown Manga"}
        </p>
        <div className="mt-1 flex items-center gap-2 text-[10px] text-tx-muted">
          {manga.year && <span>{manga.year}</span>}
          {manga.status && <span className="capitalize">· {manga.status}</span>}
        </div>
      </div>
    </Link>
  );
}

/** Lazy cover image for recommendation items */
function RecCoverImage({ mangaId }: { mangaId: string }) {
  const coverQuery = useQuery({
    queryKey: ["cover", mangaId],
    queryFn: async () => {
      try {
        const cover = await import("@/services/cover.service").then(m => m.coverService.primary(mangaId));
        return cover?.cover_url ?? null;
      } catch { return null; }
    },
    staleTime: 5 * 60 * 1000,
  });

  if (coverQuery.data) {
    return (
      <img
        src={coverQuery.data}
        alt=""
        className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
        loading="lazy"
      />
    );
  }

  return (
    <div className="flex h-full w-full items-center justify-center text-tx-muted">
      <BookOpen className="h-8 w-8" />
    </div>
  );
}

/** Compact cover thumbnail for list view */
function RecCover({ mangaId }: { mangaId: string }) {
  const coverQuery = useQuery({
    queryKey: ["cover", mangaId],
    queryFn: async () => {
      try {
        const cover = await import("@/services/cover.service").then(m => m.coverService.primary(mangaId));
        return cover?.cover_url ?? null;
      } catch { return null; }
    },
    staleTime: 5 * 60 * 1000,
  });

  return (
    <div className="flex h-20 w-14 shrink-0 items-center justify-center overflow-hidden rounded-md bg-surface-2">
      {coverQuery.data ? (
        <img src={coverQuery.data} alt="" className="h-full w-full object-cover" loading="lazy" />
      ) : (
        <BookOpen className="h-5 w-5 text-tx-muted" />
      )}
    </div>
  );
}


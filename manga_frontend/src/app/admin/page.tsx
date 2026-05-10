"use client";

import { useEffect, useState } from "react";
import { Area, AreaChart, ResponsiveContainer, Tooltip } from "recharts";
import { useRouter } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  Activity, Ban, BarChart3, BookOpen, CheckCircle, MessageSquare,
  Search, Shield, Trash2, Users, UserX, X,
} from "lucide-react";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";
import { Input } from "@/components/ui/Input";
import { Select } from "@/components/ui/Select";
import { Skeleton } from "@/components/ui/Skeleton";
import { useToast } from "@/components/ui/Toast";
import { useAuth } from "@/hooks/useAuth";
import { cn, formatDate, formatNumber } from "@/lib/utils";
import { adminService } from "@/services/admin.service";
import type { User } from "@/types/user";

type AdminTab = "overview" | "users" | "reports";

export default function AdminPage() {
  const router = useRouter();
  const { isAdmin, isLoadingUser } = useAuth();
  const [activeTab, setActiveTab] = useState<AdminTab>("overview");

  // Redirect non-admin users
  useEffect(() => {
    if (!isLoadingUser && !isAdmin) {
      router.replace("/");
    }
  }, [isAdmin, isLoadingUser, router]);

  if (isLoadingUser) {
    return (
      <div className="page-shell">
        <Skeleton className="h-16 mb-4" />
        <div className="grid gap-4 md:grid-cols-3">
          {[1, 2, 3].map(i => <Skeleton key={i} className="h-32" />)}
        </div>
      </div>
    );
  }

  if (!isAdmin) return null;

  return (
    <div className="page-shell">
      {/* ── Header ── */}
      <div className="mb-6">
        <div className="flex items-center gap-3 mb-2">
          <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-accent text-white">
            <Shield className="h-5 w-5" />
          </div>
          <div>
            <h1 className="font-heading text-3xl font-bold text-tx">Admin Dashboard</h1>
            <p className="text-sm text-tx-muted">Monitor platform activity, manage users, and review reported content.</p>
          </div>
        </div>
      </div>

      {/* ── Tab Navigation ── */}
      <div className="flex gap-1 rounded-lg border border-bd bg-surface p-1 mb-6">
        {([
          { id: "overview" as const, label: "Overview", icon: BarChart3 },
          { id: "users" as const, label: "Users", icon: Users },
          { id: "reports" as const, label: "Reports", icon: MessageSquare },
        ]).map(tab => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={cn(
              "flex flex-1 items-center justify-center gap-2 rounded-md px-4 py-2.5 text-sm font-semibold transition-all",
              activeTab === tab.id
                ? "bg-accent text-white shadow-sm"
                : "text-tx-muted hover:bg-surface-2 hover:text-tx"
            )}
          >
            <tab.icon className="h-4 w-4" />
            {tab.label}
          </button>
        ))}
      </div>

      {/* ── Tab Content ── */}
      {activeTab === "overview" && <OverviewTab />}
      {activeTab === "users" && <UsersTab />}
      {activeTab === "reports" && <ReportsTab />}
    </div>
  );
}

/* ═══════════════════════════════════════════
   OVERVIEW TAB
   ═══════════════════════════════════════════ */
function OverviewTab() {
  const { isAdmin } = useAuth();
  const dashboard = useQuery({
    queryKey: ["admin", "dashboard"],
    queryFn: () => adminService.dashboard(),
    enabled: isAdmin,
  });

  return (
    <div className="space-y-6">
      {/* Metrics */}
      <section className="grid gap-4 md:grid-cols-3">
        {dashboard.isLoading ? (
          [1, 2, 3].map(i => <Skeleton key={i} className="h-32" />)
        ) : (
          <>
            <MetricCard
              label="Total Users"
              value={dashboard.data?.totals.users ?? 0}
              icon={Users}
              color="accent"
            />
            <MetricCard
              label="Total Manga"
              value={dashboard.data?.totals.manga ?? 0}
              icon={BookOpen}
              color="sky"
            />
            <MetricCard
              label="Pending Reports"
              value={dashboard.data?.totals.pending_reports ?? 0}
              icon={MessageSquare}
              color="warning"
            />
          </>
        )}
      </section>

      {/* Charts */}
      <section className="grid gap-6 xl:grid-cols-2">
        <div className="card p-5">
          <h2 className="font-heading text-xl font-semibold text-tx">Top Manga by Readers</h2>
          <p className="mt-1 text-sm text-tx-muted">Most read manga in the last 30 days</p>
          <div className="mt-5 space-y-3">
            {dashboard.data?.top_manga?.length ? (
              dashboard.data.top_manga.map((item, index) => {
                const maxReaders = Math.max(...(dashboard.data?.top_manga?.map(m => m.readers) ?? [1]));
                return (
                  <div key={item.manga_id} className="flex items-center gap-3">
                    <span className={cn(
                      "flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-xs font-bold",
                      index < 3 ? "bg-accent text-white" : "bg-surface-2 text-tx-muted"
                    )}>
                      {index + 1}
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-semibold text-tx">{item.title ?? item.manga_id}</p>
                      <div className="mt-1 h-2 rounded-full bg-surface-2 overflow-hidden">
                        <div
                          className="h-full rounded-full bg-gradient-to-r from-accent to-accent/60 transition-all duration-500"
                          style={{ width: `${Math.max((item.readers / maxReaders) * 100, 5)}%` }}
                        />
                      </div>
                    </div>
                    <span className="shrink-0 text-sm font-bold text-tx tabular-nums">{item.readers}</span>
                  </div>
                );
              })
            ) : (
              <p className="text-sm text-tx-muted">No reading activity in selected range.</p>
            )}
          </div>
        </div>

        <div className="card p-5">
          <h2 className="font-heading text-xl font-semibold text-tx">Activity Window</h2>
          <p className="mt-1 text-sm text-tx-muted">Platform engagement over the last 30 days</p>
          <div className="mt-5 grid gap-5 sm:grid-cols-2">
            <AdminChart title="New Users" data={dashboard.data?.new_users_by_date} color="var(--accent)" />
            <AdminChart title="Reading Activity" data={dashboard.data?.reading_activity_by_date} color="var(--sky)" />
          </div>
        </div>
      </section>
    </div>
  );
}

/* ═══════════════════════════════════════════
   USERS TAB
   ═══════════════════════════════════════════ */
function UsersTab() {
  const { isAdmin } = useAuth();
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);

  const users = useQuery({
    queryKey: ["admin", "users", search, page],
    queryFn: () => adminService.users({ q: search, limit: 20, page }),
    enabled: isAdmin,
  });

  return (
    <div className="card overflow-hidden">
      <div className="border-b border-bd p-4">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2 className="font-heading text-xl font-semibold text-tx">User Management</h2>
            <p className="text-sm text-tx-muted">
              {users.data?.total ?? 0} total users
            </p>
          </div>
          <div className="relative sm:w-64">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-tx-muted" />
            <input
              value={search}
              onChange={(e) => { setSearch(e.target.value); setPage(1); }}
              placeholder="Search users..."
              className="w-full rounded-lg bg-surface-2 py-2 pl-9 pr-3 text-sm outline-none focus:ring-2 focus:ring-accent border border-bd"
            />
          </div>
        </div>
      </div>

      {/* Table header */}
      <div className="hidden border-b border-bd bg-surface-2 px-4 py-2 text-xs font-bold text-tx-muted uppercase tracking-wider sm:grid sm:grid-cols-[1fr_140px_100px_80px_100px]">
        <span>User</span>
        <span>Email</span>
        <span>Role</span>
        <span>Status</span>
        <span className="text-right">Actions</span>
      </div>

      {users.isLoading ? (
        <div className="space-y-2 p-4">
          {[1, 2, 3, 4, 5, 6].map(i => <Skeleton key={i} className="h-14" />)}
        </div>
      ) : users.data?.items?.length ? (
        <div className="divide-y divide-bd">
          {users.data.items.map((user) => (
            <AdminUserRow key={user.UserId} user={user} />
          ))}
        </div>
      ) : (
        <div className="p-8">
          <EmptyState title="No users found" description="Try a different search term." icon={Users} />
        </div>
      )}

      {/* Pagination */}
      {(users.data?.total_pages ?? 0) > 1 && (
        <div className="flex items-center justify-between border-t border-bd p-4">
          <p className="text-xs text-tx-muted">
            Page {page} of {users.data?.total_pages}
          </p>
          <div className="flex gap-2">
            <Button size="sm" variant="light" disabled={page <= 1} onClick={() => setPage(p => p - 1)}>
              Previous
            </Button>
            <Button size="sm" variant="light" disabled={page >= (users.data?.total_pages ?? 1)} onClick={() => setPage(p => p + 1)}>
              Next
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}

/* ═══════════════════════════════════════════
   REPORTS TAB
   ═══════════════════════════════════════════ */
function ReportsTab() {
  const { isAdmin } = useAuth();
  const [status, setStatus] = useState("");
  const [page, setPage] = useState(1);

  const comments = useQuery({
    queryKey: ["admin", "comments", status, page],
    queryFn: () => adminService.reportedComments({ status: status || undefined, limit: 20, page }),
    enabled: isAdmin,
  });

  return (
    <div className="card overflow-hidden">
      <div className="border-b border-bd p-4">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2 className="font-heading text-xl font-semibold text-tx">Reported Comments</h2>
            <p className="text-sm text-tx-muted">
              {comments.data?.total ?? 0} total reports
            </p>
          </div>
          <Select
            value={status}
            onChange={(e) => { setStatus(e.target.value); setPage(1); }}
            className="sm:w-44"
          >
            <option value="">All statuses</option>
            <option value="pending">Pending</option>
            <option value="resolved">Resolved</option>
            <option value="ignored">Ignored</option>
          </Select>
        </div>
      </div>

      {comments.isLoading ? (
        <div className="space-y-2 p-4">
          {[1, 2, 3, 4, 5, 6].map(i => <Skeleton key={i} className="h-24" />)}
        </div>
      ) : comments.data?.items?.length ? (
        <div className="divide-y divide-bd">
          {comments.data.items.map((comment) => (
            <ReportedCommentRow key={comment.comment_id} comment={comment} />
          ))}
        </div>
      ) : (
        <div className="p-8">
          <EmptyState
            title={status ? `No ${status} reports` : "No reports yet"}
            description="Reported comments from users will appear here."
            icon={MessageSquare}
          />
        </div>
      )}

      {/* Pagination */}
      {(comments.data?.total_pages ?? 0) > 1 && (
        <div className="flex items-center justify-between border-t border-bd p-4">
          <p className="text-xs text-tx-muted">
            Page {page} of {comments.data?.total_pages}
          </p>
          <div className="flex gap-2">
            <Button size="sm" variant="light" disabled={page <= 1} onClick={() => setPage(p => p - 1)}>
              Previous
            </Button>
            <Button size="sm" variant="light" disabled={page >= (comments.data?.total_pages ?? 1)} onClick={() => setPage(p => p + 1)}>
              Next
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}

/* ═══════════════════════════════════════════
   COMPONENTS
   ═══════════════════════════════════════════ */
function MetricCard({ label, value, icon: Icon, color }: {
  label: string; value: number; icon: React.ComponentType<{ className?: string }>;
  color: "accent" | "sky" | "warning";
}) {
  const colorMap = {
    accent: "bg-accent/10 text-accent",
    sky: "bg-sky-500/10 text-sky-500",
    warning: "bg-amber-500/10 text-amber-500",
  };
  return (
    <div className="card p-5 flex items-start gap-4">
      <div className={cn("flex h-12 w-12 shrink-0 items-center justify-center rounded-xl", colorMap[color])}>
        <Icon className="h-6 w-6" />
      </div>
      <div>
        <p className="text-sm font-semibold text-tx-muted">{label}</p>
        <p className="mt-1 font-heading text-3xl font-bold text-tx tabular-nums">{formatNumber(value)}</p>
      </div>
    </div>
  );
}

function AdminChart({ title, data, color }: { title: string; data?: Record<string, number>; color: string }) {
  const chartData = Object.entries(data ?? {}).slice(-14).map(([date, value]) => ({
    name: new Date(date).toLocaleDateString("en-US", { month: "short", day: "numeric" }),
    value,
  }));

  return (
    <div>
      <p className="mb-3 text-sm font-bold text-tx">{title}</p>
      <div className="h-40 rounded-def border border-bd bg-surface-2 p-4">
        {chartData.length > 0 ? (
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={chartData} margin={{ top: 5, right: 0, left: 0, bottom: 0 }}>
              <defs>
                <linearGradient id={`color-${title}`} x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor={color} stopOpacity={0.4} />
                  <stop offset="95%" stopColor={color} stopOpacity={0} />
                </linearGradient>
              </defs>
              <Tooltip
                contentStyle={{ backgroundColor: "var(--surface)", borderColor: "var(--bd)", borderRadius: "6px" }}
                itemStyle={{ color: "var(--tx)", fontWeight: "bold" }}
                labelStyle={{ color: "var(--tx-muted)", marginBottom: "4px" }}
              />
              <Area
                type="monotone"
                dataKey="value"
                name={title}
                stroke={color}
                strokeWidth={2}
                fillOpacity={1}
                fill={`url(#color-${title})`}
              />
            </AreaChart>
          </ResponsiveContainer>
        ) : (
          <div className="flex h-full items-center justify-center">
            <p className="text-xs text-tx-muted">No data</p>
          </div>
        )}
      </div>
    </div>
  );
}

function AdminUserRow({ user }: { user: User }) {
  const queryClient = useQueryClient();
  const { toast } = useToast();
  const banMutation = useMutation({
    mutationFn: () => (user.IsLocked ? adminService.unbanUser(user.UserId) : adminService.banUser(user.UserId)),
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ["admin", "users"] });
      queryClient.invalidateQueries({ queryKey: ["admin", "dashboard"] });
      toast(data.message ?? "User status updated", "success");
    },
    onError: () => toast("Failed to update user status", "error"),
  });

  return (
    <div className="flex items-center gap-3 p-4 hover:bg-surface-2 transition-colors">
      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-accent-bg text-sm font-bold text-accent">
        {user.Username.charAt(0).toUpperCase()}
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <p className="truncate font-bold text-tx">{user.Username}</p>
          {user.DisplayName && (
            <span className="text-xs text-tx-muted">({user.DisplayName})</span>
          )}
        </div>
        <p className="truncate text-xs text-tx-muted">{user.Email} · Joined {formatDate(user.CreatedAt)}</p>
      </div>
      <Badge tone={user.Role === "admin" ? "sky" : "default"} className="shrink-0">
        {user.Role}
      </Badge>
      <Badge tone={user.IsLocked ? "red" : "default"} className="shrink-0">
        {user.IsLocked ? "Locked" : "Active"}
      </Badge>
      {user.Role !== "admin" && (
        <Button
          size="sm"
          variant={user.IsLocked ? "light" : "danger"}
          onClick={() => banMutation.mutate()}
          isLoading={banMutation.isPending}
          className="shrink-0"
        >
          {user.IsLocked ? (
            <><CheckCircle className="h-4 w-4" aria-hidden /> Unban</>
          ) : (
            <><Ban className="h-4 w-4" aria-hidden /> Ban</>
          )}
        </Button>
      )}
    </div>
  );
}

function ReportedCommentRow({
  comment,
}: {
  comment: {
    comment_id: string;
    content?: string | null;
    username?: string | null;
    manga_title?: string | null;
    report_count: number;
    created_at?: string | null;
  };
}) {
  const queryClient = useQueryClient();
  const { toast } = useToast();
  const deleteMutation = useMutation({
    mutationFn: () => adminService.deleteComment(comment.comment_id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "comments"] });
      queryClient.invalidateQueries({ queryKey: ["admin", "dashboard"] });
      toast("Comment deleted and reports resolved", "success");
    },
  });
  const ignoreMutation = useMutation({
    mutationFn: () => adminService.ignoreComment(comment.comment_id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "comments"] });
      queryClient.invalidateQueries({ queryKey: ["admin", "dashboard"] });
      toast("Reports ignored", "success");
    },
  });

  return (
    <article className="p-4 hover:bg-surface-2 transition-colors">
      <div className="flex items-start gap-3">
        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-[var(--red)]/10 text-[var(--red)]">
          <UserX className="h-4 w-4" aria-hidden />
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <p className="font-bold text-tx">{comment.username ?? "Unknown"}</p>
            <Badge tone="warning">{comment.report_count} {comment.report_count === 1 ? "report" : "reports"}</Badge>
            <span className="text-xs text-tx-muted">on <span className="font-semibold">{comment.manga_title ?? "Unknown manga"}</span></span>
          </div>
          <p className="mt-1 text-xs text-tx-muted">{formatDate(comment.created_at)}</p>
          <div className="mt-2 rounded-lg border border-bd bg-surface-2 p-3">
            <p className="line-clamp-3 text-sm leading-6 text-tx-muted italic">"{comment.content}"</p>
          </div>
          <div className="mt-3 flex gap-2">
            <Button size="sm" variant="danger" onClick={() => deleteMutation.mutate()} isLoading={deleteMutation.isPending}>
              <Trash2 className="h-4 w-4" aria-hidden />
              Delete Comment
            </Button>
            <Button size="sm" variant="light" onClick={() => ignoreMutation.mutate()} isLoading={ignoreMutation.isPending}>
              <X className="h-4 w-4" aria-hidden />
              Dismiss
            </Button>
          </div>
        </div>
      </div>
    </article>
  );
}

"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { AlertTriangle, Flag, MessageSquare, Pencil, Send, ThumbsDown, ThumbsUp, Trash2, X } from "lucide-react";
import { FormEvent, useState } from "react";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";
import { Input } from "@/components/ui/Input";
import { Skeleton } from "@/components/ui/Skeleton";
import { useToast } from "@/components/ui/Toast";
import { useAuth } from "@/hooks/useAuth";
import { formatDate } from "@/lib/utils";
import { commentService } from "@/services/comment.service";
import { getApiErrorMessage } from "@/services/api";
import type { Comment } from "@/types/comment";
import type { UUID } from "@/types/common";

interface CommentsSectionProps {
  mangaId: UUID;
  chapterId?: UUID;
}

export function CommentsSection({ mangaId, chapterId }: CommentsSectionProps) {
  const queryClient = useQueryClient();
  const { user, isAuthenticated } = useAuth();
  const [content, setContent] = useState("");
  const [isSpoiler, setIsSpoiler] = useState(false);
  const [error, setError] = useState("");

  const commentsQuery = useQuery({
    queryKey: ["comments", mangaId],
    queryFn: () => commentService.list(mangaId, 1, 50),
  });

  const createMutation = useMutation({
    mutationFn: () => commentService.create(mangaId, { Content: content, ChapterId: chapterId, IsSpoiler: isSpoiler }),
    onSuccess: () => {
      setContent("");
      setIsSpoiler(false);
      setError("");
      queryClient.invalidateQueries({ queryKey: ["comments", mangaId] });
    },
    onError: (err) => setError(getApiErrorMessage(err)),
  });

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!isAuthenticated) {
      setError("Login de binh luan.");
      return;
    }
    if (content.trim().length < 5) {
      setError("Comment needs at least 5 characters.");
      return;
    }
    createMutation.mutate();
  }

  return (
    <section className="card overflow-hidden">
      <div className="border-b border-bd p-4">
        <h2 className="flex items-center gap-2 font-heading text-2xl font-semibold text-tx">
          <MessageSquare className="h-5 w-5 text-accent" aria-hidden />
          Comments
        </h2>
        <p className="mt-1 text-sm text-tx-muted">Spoiler controls, reactions, reports, edit and delete are wired to backend.</p>
      </div>
      <form onSubmit={submit} className="border-b border-bd p-4">
        <textarea
          value={content}
          onChange={(event) => setContent(event.target.value)}
          placeholder={isAuthenticated ? "Share your thought..." : "Login to comment"}
          disabled={!isAuthenticated}
          className="focus-ring min-h-24 w-full resize-y rounded-def border border-bd bg-surface-2 p-3 text-sm leading-6 text-tx outline-none disabled:opacity-50 placeholder:text-tx-muted/60"
        />
        <div className="mt-3 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <label className="flex items-center gap-2 text-sm font-semibold text-tx">
            <input
              type="checkbox"
              checked={isSpoiler}
              onChange={(event) => setIsSpoiler(event.target.checked)}
              className="h-4 w-4 accent-accent"
            />
            Mark as spoiler
          </label>
          <Button type="submit" isLoading={createMutation.isPending} disabled={!isAuthenticated}>
            <Send className="h-4 w-4" aria-hidden />
            Post
          </Button>
        </div>
        {error && <p className="mt-2 text-sm font-semibold text-[var(--red)]">{error}</p>}
      </form>
      <div className="divide-y divide-bd">
        {commentsQuery.isLoading ? (
          <div className="space-y-3 p-4">
            {Array.from({ length: 4 }).map((_, index) => (
              <Skeleton key={index} className="h-24" />
            ))}
          </div>
        ) : commentsQuery.data?.items.length ? (
          commentsQuery.data.items.map((comment) => (
            <CommentItem
              key={comment.CommentId}
              comment={comment}
              mangaId={mangaId}
              canManage={comment.UserId === user?.UserId}
            />
          ))
        ) : (
          <div className="p-4">
            <EmptyState title="No comments yet" description="Start the discussion after reading a chapter." />
          </div>
        )}
      </div>
    </section>
  );
}

const REPORT_REASONS = [
  "Spam or advertising",
  "Harassment or hate speech",
  "Unmarked spoilers",
  "Inappropriate content",
  "Misinformation",
  "Other",
];

function CommentItem({ comment, mangaId, canManage }: { comment: Comment; mangaId: UUID; canManage: boolean }) {
  const queryClient = useQueryClient();
  const { toast } = useToast();
  const [revealed, setRevealed] = useState(!comment.IsSpoiler);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(comment.Content ?? "");
  const [showReportModal, setShowReportModal] = useState(false);
  const [reportReason, setReportReason] = useState("");
  const [customReason, setCustomReason] = useState("");

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ["comments", mangaId] });

  const likeMutation = useMutation({ mutationFn: () => commentService.like(comment.CommentId), onSuccess: invalidate });
  const dislikeMutation = useMutation({ mutationFn: () => commentService.dislike(comment.CommentId), onSuccess: invalidate });
  const deleteMutation = useMutation({
    mutationFn: () => commentService.remove(comment.CommentId),
    onSuccess: () => {
      invalidate();
      toast("Comment deleted", "success");
    },
  });
  const updateMutation = useMutation({
    mutationFn: () => commentService.update(comment.CommentId, { Content: draft }),
    onSuccess: () => {
      setEditing(false);
      invalidate();
      toast("Comment updated", "success");
    },
  });
  const reportMutation = useMutation({
    mutationFn: () => {
      const reason = reportReason === "Other" ? customReason : reportReason;
      return commentService.report(comment.CommentId, { Reason: reason });
    },
    onSuccess: () => {
      setShowReportModal(false);
      setReportReason("");
      setCustomReason("");
      toast("Report submitted successfully. Thank you for helping keep the community safe!", "success");
    },
    onError: (err) => {
      toast(getApiErrorMessage(err), "error");
    },
  });

  const handleReport = () => {
    const reason = reportReason === "Other" ? customReason : reportReason;
    if (!reason.trim()) {
      toast("Please select or enter a reason for reporting.", "error");
      return;
    }
    reportMutation.mutate();
  };

  return (
    <article className="p-4">
      <div className="flex items-start gap-3">
        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-accent-bg text-sm font-bold text-accent">
          {(comment.Username ?? "U").charAt(0).toUpperCase()}
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <p className="font-bold text-tx">{comment.Username ?? "Unknown user"}</p>
            <span className="text-xs text-tx-muted">{formatDate(comment.CreatedAt)}</span>
            {comment.IsSpoiler && <Badge tone="warning">Spoiler</Badge>}
          </div>
          {editing ? (
            <div className="mt-3">
              <Input value={draft} onChange={(event) => setDraft(event.target.value)} />
              <div className="mt-2 flex gap-2">
                <Button size="sm" onClick={() => updateMutation.mutate()} isLoading={updateMutation.isPending}>
                  Save
                </Button>
                <Button size="sm" variant="ghost" onClick={() => setEditing(false)}>
                  Cancel
                </Button>
              </div>
            </div>
          ) : (
            <p className="mt-2 text-sm leading-6 text-tx-muted">
              {comment.IsSpoiler && !revealed ? (
                <button className="font-bold text-accent" onClick={() => setRevealed(true)}>
                  Show spoiler
                </button>
              ) : (
                comment.Content
              )}
            </p>
          )}
          <div className="mt-3 flex flex-wrap items-center gap-2">
            <Button size="sm" variant="ghost" onClick={() => likeMutation.mutate()}>
              <ThumbsUp className="h-4 w-4" aria-hidden />
              {comment.LikeCount}
            </Button>
            <Button size="sm" variant="ghost" onClick={() => dislikeMutation.mutate()}>
              <ThumbsDown className="h-4 w-4" aria-hidden />
              {comment.DislikeCount}
            </Button>
            {canManage && (
              <>
                <Button size="sm" variant="ghost" onClick={() => setEditing(true)}>
                  <Pencil className="h-4 w-4" aria-hidden />
                  Edit
                </Button>
                <Button size="sm" variant="ghost" onClick={() => deleteMutation.mutate()} isLoading={deleteMutation.isPending}>
                  <Trash2 className="h-4 w-4" aria-hidden />
                  Delete
                </Button>
              </>
            )}
            <Button
              size="sm"
              variant="ghost"
              onClick={() => setShowReportModal(true)}
              className="ml-auto text-tx-muted hover:text-[var(--red)]"
            >
              <Flag className="h-4 w-4" aria-hidden />
              Report
            </Button>
          </div>
        </div>
      </div>

      {/* ── Report Modal ── */}
      {showReportModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm" onClick={() => setShowReportModal(false)}>
          <div
            className="mx-4 w-full max-w-md rounded-xl border border-bd bg-surface p-6 shadow-floating animate-in fade-in zoom-in-95 duration-200"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-full bg-[var(--red)]/10">
                  <AlertTriangle className="h-5 w-5 text-[var(--red)]" />
                </div>
                <div>
                  <h3 className="font-heading text-lg font-bold text-tx">Report Comment</h3>
                  <p className="text-xs text-tx-muted">by {comment.Username}</p>
                </div>
              </div>
              <button onClick={() => setShowReportModal(false)} className="rounded-full p-1 text-tx-muted hover:bg-surface-2">
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="mt-4 rounded-lg border border-bd bg-surface-2 p-3">
              <p className="line-clamp-3 text-sm text-tx-muted italic">&ldquo;{comment.Content}&rdquo;</p>
            </div>

            <div className="mt-4">
              <p className="mb-3 text-sm font-semibold text-tx">Select a reason:</p>
              <div className="grid gap-2">
                {REPORT_REASONS.map((reason) => (
                  <button
                    key={reason}
                    onClick={() => setReportReason(reason)}
                    className={`rounded-lg border px-3 py-2 text-left text-sm font-medium transition-all ${
                      reportReason === reason
                        ? "border-accent bg-accent-bg text-accent"
                        : "border-bd text-tx-muted hover:border-accent/30 hover:bg-surface-2"
                    }`}
                  >
                    {reason}
                  </button>
                ))}
              </div>
            </div>

            {reportReason === "Other" && (
              <div className="mt-3">
                <textarea
                  value={customReason}
                  onChange={(e) => setCustomReason(e.target.value)}
                  placeholder="Please describe the issue..."
                  className="focus-ring min-h-20 w-full resize-y rounded-def border border-bd bg-surface-2 p-3 text-sm leading-6 text-tx outline-none placeholder:text-tx-muted/60"
                />
              </div>
            )}

            <div className="mt-5 flex justify-end gap-3">
              <Button variant="ghost" onClick={() => setShowReportModal(false)}>
                Cancel
              </Button>
              <Button
                variant="danger"
                onClick={handleReport}
                isLoading={reportMutation.isPending}
                disabled={!reportReason || (reportReason === "Other" && !customReason.trim())}
              >
                <Flag className="h-4 w-4" aria-hidden />
                Submit Report
              </Button>
            </div>
          </div>
        </div>
      )}
    </article>
  );
}

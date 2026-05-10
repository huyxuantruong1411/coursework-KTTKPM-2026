"use client";

import Link from "next/link";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { FormEvent, useState } from "react";
import { Eye, EyeOff, Library, Pencil, Plus, Trash2, Users } from "lucide-react";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";
import { Input } from "@/components/ui/Input";
import { SectionHeader } from "@/components/ui/SectionHeader";
import { Select } from "@/components/ui/Select";
import { Skeleton } from "@/components/ui/Skeleton";
import { useToast } from "@/components/ui/Toast";
import { useAuth } from "@/hooks/useAuth";
import { formatDate } from "@/lib/utils";
import { listService } from "@/services/list.service";
import type { MangaListBrief } from "@/types/list";

export default function ListsPage() {
  const queryClient = useQueryClient();
  const { isAuthenticated } = useAuth();
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [visibility, setVisibility] = useState("private");
  const [publicSearch, setPublicSearch] = useState("");

  const mine = useQuery({
    queryKey: ["lists", "mine"],
    queryFn: () => listService.mine(),
    enabled: isAuthenticated,
  });

  const publicLists = useQuery({
    queryKey: ["lists", "public", publicSearch],
    queryFn: () => listService.publicLists({ q: publicSearch, limit: 12, sort: "followers_desc" }),
    enabled: isAuthenticated,
  });

  const createMutation = useMutation({
    mutationFn: () => listService.create({ Name: name, Description: description, Visibility: visibility }),
    onSuccess: () => {
      setName("");
      setDescription("");
      queryClient.invalidateQueries({ queryKey: ["lists"] });
    },
  });

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (name.trim()) createMutation.mutate();
  }

  if (!isAuthenticated) {
    return (
      <div className="page-shell">
        <EmptyState title="Login required" description="MDLists are private user resources, so the backend requires a JWT token." icon={Library} />
      </div>
    );
  }

  return (
    <div className="page-shell">
      <SectionHeader
        eyebrow="Library"
        title="MDLists"
        description="Create private/public lists, manage items from manga detail, and follow community lists."
      />
      <div className="grid gap-6 lg:grid-cols-[360px_1fr]">
        <aside className="card p-4">
          <h2 className="font-heading text-2xl font-semibold">Create list</h2>
          <form onSubmit={submit} className="mt-4 space-y-3">
            <Input label="Name" value={name} onChange={(event) => setName(event.target.value)} required />
            <Input label="Description" value={description} onChange={(event) => setDescription(event.target.value)} />
            <Select label="Visibility" value={visibility} onChange={(event) => setVisibility(event.target.value)}>
              <option value="private">Private</option>
              <option value="public">Public</option>
            </Select>
            <Button type="submit" className="w-full" isLoading={createMutation.isPending}>
              <Plus className="h-4 w-4" aria-hidden />
              Create
            </Button>
          </form>
        </aside>

        <main className="space-y-6">
          <section>
            <h2 className="mb-3 font-heading text-2xl font-semibold">My lists</h2>
            {mine.isLoading ? (
              <div className="grid gap-3 md:grid-cols-2">
                {Array.from({ length: 4 }).map((_, index) => (
                  <Skeleton key={index} className="h-36" />
                ))}
              </div>
            ) : mine.data?.my_lists.length ? (
              <div className="grid gap-3 md:grid-cols-2">
                {mine.data.my_lists.map((list) => (
                  <EditableListCard key={list.ListId} list={list} />
                ))}
              </div>
            ) : (
              <EmptyState title="No personal lists yet" description="Create your first reading list from the form." />
            )}
          </section>

          <section>
            <div className="mb-3 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <h2 className="font-heading text-2xl font-semibold">Public lists</h2>
              <Input value={publicSearch} onChange={(event) => setPublicSearch(event.target.value)} placeholder="Search public lists" className="sm:w-72" />
            </div>
            {publicLists.isLoading ? (
              <div className="grid gap-3 md:grid-cols-2">
                {Array.from({ length: 4 }).map((_, index) => (
                  <Skeleton key={index} className="h-32" />
                ))}
              </div>
            ) : publicLists.data?.items.length ? (
              <div className="grid gap-3 md:grid-cols-2">
                {publicLists.data.items.map((list) => (
                  <PublicListCard key={list.ListId} list={list} />
                ))}
              </div>
            ) : (
              <EmptyState title="No public lists found" description="Try another keyword or publish one of your lists." />
            )}
          </section>
        </main>
      </div>
    </div>
  );
}

function EditableListCard({ list }: { list: MangaListBrief }) {
  const queryClient = useQueryClient();
  const { toast } = useToast();
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(list.Name ?? "");
  const [description, setDescription] = useState(list.Description ?? "");
  const [visibility, setVisibility] = useState(list.Visibility);

  const updateMutation = useMutation({
    mutationFn: () => listService.update(list.ListId, { Name: name, Description: description, Visibility: visibility }),
    onSuccess: () => {
      setEditing(false);
      queryClient.invalidateQueries({ queryKey: ["lists"] });
      toast("List updated!", "success");
    },
  });

  const deleteMutation = useMutation({
    mutationFn: () => listService.remove(list.ListId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["lists"] });
      toast("List deleted", "success");
    },
  });

  return (
    <article className="card flex overflow-hidden">
      {/* Cover thumbnail */}
      <Link href={`/lists/${list.ListId}`} className="w-20 shrink-0 bg-surface-2">
        {list.cover_url ? (
          <img src={list.cover_url} alt="" className="h-full w-full object-cover" />
        ) : (
          <div className="flex h-full min-h-[120px] w-full items-center justify-center">
            <Library className="h-6 w-6 text-tx-muted/40" />
          </div>
        )}
      </Link>
      <div className="flex-1 p-4">
        {editing ? (
          <div className="space-y-2">
            <Input value={name} onChange={(event) => setName(event.target.value)} />
            <Input value={description} onChange={(event) => setDescription(event.target.value)} />
            <Select value={visibility} onChange={(event) => setVisibility(event.target.value)}>
              <option value="private">Private</option>
              <option value="public">Public</option>
            </Select>
            <div className="flex gap-2">
              <Button size="sm" onClick={() => updateMutation.mutate()} isLoading={updateMutation.isPending}>
                Save
              </Button>
              <Button size="sm" variant="ghost" onClick={() => setEditing(false)}>
                Cancel
              </Button>
            </div>
          </div>
        ) : (
          <>
            <div className="flex items-start justify-between gap-3">
              <Link href={`/lists/${list.ListId}`} className="min-w-0">
                <h3 className="truncate font-heading text-xl font-semibold hover:text-brand-orange">{list.Name ?? "Untitled list"}</h3>
              </Link>
              <Badge tone={list.Visibility === "public" ? "sky" : "default"}>
                {list.Visibility === "public" ? <Eye className="mr-1 h-3.5 w-3.5" aria-hidden /> : <EyeOff className="mr-1 h-3.5 w-3.5" aria-hidden />}
                {list.Visibility}
              </Badge>
            </div>
            <p className="mt-2 line-clamp-2 text-sm leading-6 text-tx-muted">{list.Description || "No description."}</p>
            <div className="mt-4 flex flex-wrap gap-4 text-xs text-tx-muted">
              <span>{list.ItemCount} items</span>
              <span>{list.FollowerCount} followers</span>
              <span>{formatDate(list.UpdatedAt)}</span>
            </div>
            <div className="mt-4 flex gap-2">
              <Button size="sm" variant="light" onClick={() => setEditing(true)}>
                <Pencil className="h-4 w-4" aria-hidden />
                Edit
              </Button>
              <Button size="sm" variant="ghost" onClick={() => deleteMutation.mutate()} isLoading={deleteMutation.isPending}>
                <Trash2 className="h-4 w-4" aria-hidden />
                Delete
              </Button>
            </div>
          </>
        )}
      </div>
    </article>
  );
}

function PublicListCard({ list }: { list: MangaListBrief & { owner_username?: string | null; is_following?: boolean } }) {
  const queryClient = useQueryClient();
  const followMutation = useMutation({
    mutationFn: () => (list.is_following ? listService.unfollow(list.ListId) : listService.follow(list.ListId)),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["lists"] }),
  });

  return (
    <article className="card p-4">
      <div className="flex items-start justify-between gap-3">
        <Link href={`/lists/${list.ListId}`} className="min-w-0">
          <h3 className="truncate font-heading text-xl font-semibold hover:text-brand-orange">{list.Name ?? "Untitled list"}</h3>
          <p className="mt-1 text-xs text-tx-muted">by {list.owner_username ?? "unknown"}</p>
        </Link>
        <Badge tone="sky">public</Badge>
      </div>
      <p className="mt-2 line-clamp-2 text-sm leading-6 text-tx-muted">{list.Description || "No description."}</p>
      <div className="mt-4 flex items-center justify-between">
        <span className="inline-flex items-center gap-2 text-sm text-tx-muted">
          <Users className="h-4 w-4" aria-hidden />
          {list.FollowerCount}
        </span>
        <Button size="sm" onClick={() => followMutation.mutate()} isLoading={followMutation.isPending} variant={list.is_following ? "light" : "primary"}>
          {list.is_following ? "Unfollow" : "Follow"}
        </Button>
      </div>
    </article>
  );
}

"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { BookmarkPlus, Check, Plus, X } from "lucide-react";
import { FormEvent, useState } from "react";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";
import { Select } from "@/components/ui/Select";
import { useToast } from "@/components/ui/Toast";
import { useAuth } from "@/hooks/useAuth";
import { listService } from "@/services/list.service";
import type { UUID } from "@/types/common";

interface ListPickerProps {
  mangaId: UUID;
}

export function ListPicker({ mangaId }: ListPickerProps) {
  const queryClient = useQueryClient();
  const { isAuthenticated } = useAuth();
  const { toast } = useToast();
  const [name, setName] = useState("");
  const [visibility, setVisibility] = useState("private");

  const listsQuery = useQuery({
    queryKey: ["lists", "mine", mangaId],
    queryFn: () => listService.mine(mangaId),
    enabled: isAuthenticated,
  });

  const createMutation = useMutation({
    mutationFn: () => listService.create({ Name: name, Visibility: visibility, Description: "" }),
    onSuccess: () => {
      setName("");
      queryClient.invalidateQueries({ queryKey: ["lists"] });
      toast("Đã tạo danh sách mới!", "success");
    },
  });

  const addMutation = useMutation({
    mutationFn: (listId: UUID) => listService.addItem(listId, mangaId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["lists"] });
      toast("Đã thêm vào danh sách!", "success");
    },
  });

  const removeMutation = useMutation({
    mutationFn: (listId: UUID) => listService.removeItem(listId, mangaId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["lists"] });
      toast("Đã xóa khỏi danh sách!", "success");
    },
  });

  function createList(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!name.trim()) return;
    createMutation.mutate();
  }

  if (!isAuthenticated) {
    return (
      <section className="card p-4">
        <h2 className="font-heading text-2xl font-semibold">Library</h2>
        <p className="mt-2 text-sm text-tx-muted">Login to add this manga to private or public MDLists.</p>
      </section>
    );
  }

  const lists = listsQuery.data?.my_lists ?? [];

  return (
    <section className="card p-4">
      <h2 className="flex items-center gap-2 font-heading text-2xl font-semibold">
        <BookmarkPlus className="h-5 w-5 text-brand-orange" aria-hidden />
        Library
      </h2>
      <div className="mt-4 space-y-2">
        {lists.map((list) => (
          <div key={list.ListId} className="flex items-center gap-3 border border-bd p-2 rounded-md">
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-bold">{list.Name}</p>
              <p className="text-xs text-tx-muted">{list.ItemCount} items - {list.Visibility}</p>
            </div>

            {/* Logic Toggle Thêm/Xóa bằng Button Group Hover */}
            {list.contains ? (
              <Button
                size="sm"
                className="group relative min-w-[90px] bg-brand-orange/10 text-brand-orange hover:bg-[var(--red)] hover:text-white border border-brand-orange/30 hover:border-[var(--red)]"
                onClick={() => removeMutation.mutate(list.ListId)}
                isLoading={removeMutation.isPending && removeMutation.variables === list.ListId}
              >
                <span className="flex items-center justify-center group-hover:hidden">
                  <Check className="mr-1 h-3.5 w-3.5" aria-hidden />
                  Added
                </span>
                <span className="hidden items-center justify-center group-hover:flex">
                  <X className="mr-1 h-3.5 w-3.5" aria-hidden />
                  Remove
                </span>
              </Button>
            ) : (
              <Button
                size="sm"
                variant="light"
                className="min-w-[90px]"
                onClick={() => addMutation.mutate(list.ListId)}
                isLoading={addMutation.isPending && addMutation.variables === list.ListId}
              >
                Add
              </Button>
            )}

          </div>
        ))}
      </div>
      <form onSubmit={createList} className="mt-4 grid gap-2">
        <Input value={name} onChange={(event) => setName(event.target.value)} placeholder="New list name" />
        <div className="grid grid-cols-[1fr_auto] gap-2">
          <Select value={visibility} onChange={(event) => setVisibility(event.target.value)} aria-label="List visibility">
            <option value="private">Private</option>
            <option value="public">Public</option>
          </Select>
          <Button type="submit" isLoading={createMutation.isPending}>
            <Plus className="h-4 w-4" aria-hidden />
            Create
          </Button>
        </div>
      </form>
    </section>
  );
}
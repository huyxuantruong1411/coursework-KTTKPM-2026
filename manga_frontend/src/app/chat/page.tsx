"use client";

import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  ArrowLeft, Hash, ImagePlus, MessageCircle, Plus, Search,
  Send, Smile, Users, X, Circle,
} from "lucide-react";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { EmptyState } from "@/components/ui/EmptyState";
import { Input } from "@/components/ui/Input";
import { Skeleton } from "@/components/ui/Skeleton";
import { useToast } from "@/components/ui/Toast";
import { useAuth } from "@/hooks/useAuth";
import { cn, formatDate } from "@/lib/utils";
import { chatApi, chatService } from "@/services/chat.service";
import { api } from "@/services/api";
import type { ChatMessage, ChatRoom, WsEvent } from "@/services/chat.service";

export default function ChatPage() {
  const { user, isAuthenticated, token } = useAuth();
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const [selectedRoomId, setSelectedRoomId] = useState<string | null>(null);
  const [showNewChat, setShowNewChat] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");

  // ── Rooms query ──
  const roomsQuery = useQuery({
    queryKey: ["chat", "rooms"],
    queryFn: () => chatApi.getRooms(),
    enabled: isAuthenticated,
    refetchInterval: 15000, // Refresh every 15s
  });

  const rooms = roomsQuery.data ?? [];
  const selectedRoom = rooms.find((r) => r.room_id === selectedRoomId) ?? null;

  if (!isAuthenticated) {
    return (
      <div className="page-shell">
        <EmptyState title="Login required" description="Sign in to access chat." icon={MessageCircle} />
      </div>
    );
  }

  return (
    <div className="page-shell !p-0 flex h-[calc(100vh-64px)] overflow-hidden">
      {/* ── Sidebar: Room List ── */}
      <aside
        className={cn(
          "flex w-80 shrink-0 flex-col border-r border-bd bg-surface transition-all",
          selectedRoomId ? "hidden md:flex" : "flex w-full md:w-80",
        )}
      >
        <div className="flex items-center justify-between border-b border-bd p-4">
          <h2 className="font-heading text-xl font-bold">Messages</h2>
          <Button size="icon" variant="ghost" onClick={() => setShowNewChat(true)} aria-label="New chat">
            <Plus className="h-5 w-5" />
          </Button>
        </div>

        {/* Search */}
        <div className="border-b border-bd p-3">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-tx-muted" />
            <input
              type="text"
              placeholder="Search conversations..."
              className="w-full rounded-lg bg-surface-2 py-2 pl-9 pr-3 text-sm outline-none focus:ring-2 focus:ring-accent"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>
        </div>

        {/* Room List */}
        <div className="flex-1 overflow-y-auto">
          {roomsQuery.isLoading ? (
            <div className="space-y-2 p-3">
              {[1, 2, 3, 4].map((i) => (
                <Skeleton key={i} className="h-16" />
              ))}
            </div>
          ) : rooms.length ? (
            rooms
              .filter((r) => !searchQuery || r.name?.toLowerCase().includes(searchQuery.toLowerCase()))
              .map((room) => (
                <RoomItem
                  key={room.room_id}
                  room={room}
                  isSelected={room.room_id === selectedRoomId}
                  currentUserId={user?.UserId ?? ""}
                  onClick={() => setSelectedRoomId(room.room_id)}
                />
              ))
          ) : (
            <div className="p-6 text-center text-sm text-tx-muted">
              No conversations yet. Start one!
            </div>
          )}
        </div>
      </aside>

      {/* ── Main: Chat Thread ── */}
      <main className={cn("flex flex-1 flex-col", !selectedRoomId && "hidden md:flex")}>
        {selectedRoomId && selectedRoom ? (
          <ChatThread
            room={selectedRoom}
            userId={user?.UserId ?? ""}
            token={token}
            onBack={() => setSelectedRoomId(null)}
          />
        ) : (
          <div className="flex flex-1 items-center justify-center">
            <div className="text-center">
              <MessageCircle className="mx-auto h-12 w-12 text-tx-muted/30" />
              <p className="mt-4 text-sm text-tx-muted">Select a conversation or start a new one</p>
            </div>
          </div>
        )}
      </main>

      {/* ── New Chat Modal ── */}
      {showNewChat && (
        <NewChatModal
          onClose={() => setShowNewChat(false)}
          onCreated={(roomId) => {
            setSelectedRoomId(roomId);
            setShowNewChat(false);
            queryClient.invalidateQueries({ queryKey: ["chat", "rooms"] });
          }}
        />
      )}
    </div>
  );
}

/* ─── Room List Item ──────────────────────────────────── */
function RoomItem({
  room, isSelected, currentUserId, onClick,
}: {
  room: ChatRoom; isSelected: boolean; currentUserId: string; onClick: () => void;
}) {
  const otherUser = room.type === "direct"
    ? room.members.find((m) => m.user_id !== currentUserId)
    : null;
  const avatarLetter = (otherUser?.display_name || otherUser?.username || room.name || "?").charAt(0).toUpperCase();

  return (
    <button
      onClick={onClick}
      className={cn(
        "flex w-full items-center gap-3 p-3 text-left transition-colors hover:bg-surface-2",
        isSelected && "bg-accent-bg border-l-2 border-accent",
      )}
    >
      <div className="relative h-10 w-10 shrink-0">
        {otherUser?.avatar ? (
          <img src={otherUser.avatar} alt="" className="h-full w-full rounded-full object-cover" />
        ) : (
          <div className="flex h-full w-full items-center justify-center rounded-full bg-gradient-to-br from-[var(--accent)] to-[var(--accent-2)] text-sm font-bold text-white">
            {room.type === "group" ? <Users className="h-4 w-4" /> : avatarLetter}
          </div>
        )}
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex items-center justify-between">
          <p className="truncate text-sm font-semibold text-tx">{room.name ?? "Chat"}</p>
          {room.last_message?.created_at && (
            <span className="text-xs text-tx-muted">{formatDate(room.last_message.created_at)}</span>
          )}
        </div>
        <p className="mt-0.5 truncate text-xs text-tx-muted">
          {room.last_message?.content ?? "No messages yet"}
        </p>
      </div>
      {room.unread_count > 0 && (
        <span className="flex h-5 min-w-5 items-center justify-center rounded-full bg-accent px-1.5 text-[10px] font-bold text-white">
          {room.unread_count}
        </span>
      )}
    </button>
  );
}

/* ─── Chat Thread ─────────────────────────────────────── */
function ChatThread({
  room, userId, token, onBack,
}: {
  room: ChatRoom; userId: string; token: string | null; onBack: () => void;
}) {
  const queryClient = useQueryClient();
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState("");
  const [typingUsers, setTypingUsers] = useState<Set<string>>(new Set());
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const typingTimeout = useRef<ReturnType<typeof setTimeout>>(undefined);

  // Load message history
  const historyQuery = useQuery({
    queryKey: ["chat", "messages", room.room_id],
    queryFn: () => chatApi.getMessages(room.room_id, 1, 100),
  });

  useEffect(() => {
    if (historyQuery.data?.messages) {
      setMessages(historyQuery.data.messages);
      void chatApi.markRoomRead(room.room_id);
    }
  }, [historyQuery.data, queryClient, room.room_id]);

  // Connect WebSocket
  useEffect(() => {
    chatService.connect(room.room_id, token);

    const unsub = chatService.onMessage((event: WsEvent) => {
      if (event.type === "message") {
        const msg = event as unknown as ChatMessage;
        setMessages((prev) => {
          if (msg.message_id && prev.some((m) => m.message_id === msg.message_id)) return prev;
          return [...prev, {
            ...msg,
            message_type: msg.message_type || "text",
            status: msg.status || "sent",
            is_own: msg.sender_id === userId,
          }];
        });
        void chatApi.markRoomRead(room.room_id);
        void queryClient.invalidateQueries({ queryKey: ["chat", "rooms"] });
      } else if (event.type === "typing") {
        const uid = event.user_id as string;
        const isTyping = event.is_typing as boolean;
        setTypingUsers((prev) => {
          const next = new Set(prev);
          if (isTyping) next.add(uid);
          else next.delete(uid);
          return next;
        });
      }
    });

    return () => {
      unsub();
      chatService.disconnect();
    };
  }, [queryClient, room.room_id, token, userId]);

  // Auto-scroll
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  // Send message
  async function handleSend() {
    const text = input.trim();
    if (!text) return;
    setInput("");
    chatService.sendTyping(false);
    if (chatService.isConnected) {
      chatService.sendMessage(text);
      return;
    }
    const result = await chatApi.sendMessage(room.room_id, text);
    const localMsg: ChatMessage = {
      message_id: result.message_id,
      room_id: room.room_id,
      sender_id: userId,
      content: text,
      message_type: "text",
      status: "sent",
      created_at: result.created_at ?? new Date().toISOString(),
      is_own: true,
    };
    setMessages((prev) => [...prev, localMsg]);
    void queryClient.invalidateQueries({ queryKey: ["chat", "rooms"] });
  }

  // Handle typing indicator
  function handleInputChange(value: string) {
    setInput(value);
    chatService.sendTyping(true);
    if (typingTimeout.current) clearTimeout(typingTimeout.current);
    typingTimeout.current = setTimeout(() => chatService.sendTyping(false), 2000);
  }

  // Handle image upload
  async function handleImageUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file || !room) return;

    // Reset input để có thể chọn lại cùng file
    if (fileRef.current) fileRef.current.value = "";

    try {
      const result = await chatApi.uploadMedia(room.room_id, file);

      // Tạo optimistic message để hiển thị ngay lập tức
      const optimisticMsg: ChatMessage = {
        message_id: result.message_id,
        room_id: room.room_id,
        sender_id: userId,
        message_type: "image",
        media_url: result.media_url,
        content: "[Image]",
        status: "sent",
        created_at: new Date().toISOString(),
        is_own: true,
      };
      setMessages((prev) => {
        if (prev.some((m) => m.message_id === optimisticMsg.message_id)) return prev;
        return [...prev, optimisticMsg];
      });
      void queryClient.invalidateQueries({ queryKey: ["chat", "rooms"] });
    } catch (err) {
      console.error("Image upload failed:", err);
    }
  }

  return (
    <>
      {/* Header */}
      <div className="flex items-center gap-3 border-b border-bd px-4 py-3">
        <button onClick={onBack} className="md:hidden" aria-label="Back">
          <ArrowLeft className="h-5 w-5" />
        </button>
        <div className="flex h-9 w-9 items-center justify-center rounded-full bg-gradient-to-br from-[var(--accent)] to-[var(--accent-2)] text-sm font-bold text-white">
          {room.type === "group" ? <Users className="h-4 w-4" /> : (room.name || "?").charAt(0).toUpperCase()}
        </div>
        <div className="min-w-0 flex-1">
          <p className="truncate font-semibold text-tx">{room.name ?? "Chat"}</p>
          <p className="text-xs text-tx-muted">
            {room.members.length} member{room.members.length > 1 ? "s" : ""}
            {typingUsers.size > 0 && " · typing..."}
          </p>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4">
        {historyQuery.isLoading ? (
          <div className="space-y-3">
            {[1, 2, 3].map((i) => <Skeleton key={i} className="h-12" />)}
          </div>
        ) : messages.length === 0 ? (
          <div className="flex h-full items-center justify-center">
            <p className="text-sm text-tx-muted">Start the conversation!</p>
          </div>
        ) : (
          <div className="space-y-3">
            {messages.map((msg, idx) => (
              <MessageBubble key={msg.message_id || idx} message={msg} isOwn={msg.sender_id === userId} />
            ))}
            <div ref={messagesEndRef} />
          </div>
        )}
      </div>

      {/* Input */}
      <div className="border-t border-bd p-3">
        <div className="flex items-center gap-2">
          <button
            onClick={() => fileRef.current?.click()}
            className="shrink-0 rounded-lg p-2 text-tx-muted hover:bg-surface-2 hover:text-accent transition-colors"
            aria-label="Attach image"
          >
            <ImagePlus className="h-5 w-5" />
          </button>
          <input ref={fileRef} type="file" accept="image/*" className="hidden" onChange={handleImageUpload} />
          <input
            type="text"
            value={input}
            onChange={(e) => handleInputChange(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && handleSend()}
            placeholder="Type a message..."
            className="flex-1 rounded-lg bg-surface-2 px-4 py-2.5 text-sm outline-none focus:ring-2 focus:ring-accent"
          />
          <Button onClick={handleSend} disabled={!input.trim()} size="icon" className="shrink-0">
            <Send className="h-4 w-4" />
          </Button>
        </div>
      </div>
    </>
  );
}

/* ─── Message Bubble ──────────────────────────────────── */
function MessageBubble({ message, isOwn }: { message: ChatMessage; isOwn: boolean }) {
  const [isPreviewOpen, setIsPreviewOpen] = useState(false);

  const renderContent = (text: string) => {
    if (!text) return null;
    const regex = /([@/][0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/g;
    const parts = text.split(regex);
    return parts.map((part, i) => {
      if (part.match(/^[@/][0-9a-fA-F]{8}-/)) {
        const uuid = part.slice(1);
        return (
          <Link
            key={i}
            href={`/manga/${uuid}`}
            target="_blank"
            className="font-bold underline decoration-accent/50 underline-offset-2 transition-colors hover:text-white"
          >
            {part}
          </Link>
        );
      }
      return <span key={i}>{part}</span>;
    });
  };

  return (
    <div className={cn("flex gap-2", isOwn && "flex-row-reverse")}>
      {!isOwn && (
        <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-surface-2 text-xs font-bold">
          {(message.sender_display_name || message.sender_username || "U").charAt(0).toUpperCase()}
        </div>
      )}
      <div className={cn("max-w-[70%]", isOwn && "text-right")}>
        {!isOwn && (
          <p className="mb-1 text-xs font-semibold text-tx-muted">
            {message.sender_display_name || message.sender_username}
          </p>
        )}
        <div
          className={cn(
            "inline-block rounded-2xl px-4 py-2 text-sm leading-relaxed",
            isOwn
              ? "rounded-br-md bg-accent text-white"
              : "rounded-bl-md bg-surface-2 text-tx",
          )}
        >
          {message.message_type === "image" && message.media_url ? (
            <>
              <img
                src={message.media_url}
                alt=""
                className="max-w-60 cursor-pointer rounded-lg transition-opacity hover:opacity-90"
                onClick={() => setIsPreviewOpen(true)}
              />
              {isPreviewOpen && (
                <div
                  className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4 backdrop-blur-sm"
                  onClick={() => setIsPreviewOpen(false)}
                >
                  <div className="relative">
                    <img
                      src={message.media_url!}
                      alt="Preview"
                      className="max-h-[90vh] max-w-[90vw] rounded-lg object-contain shadow-2xl"
                      onClick={(e) => e.stopPropagation()}
                    />
                    <button
                      className="absolute -right-12 top-0 rounded-full bg-surface/20 p-2 text-white hover:bg-surface/50"
                      onClick={() => setIsPreviewOpen(false)}
                    >
                      <X className="h-6 w-6" />
                    </button>
                  </div>
                </div>
              )}
            </>
          ) : (
            renderContent(message.content ?? "")
          )}
        </div>
        {message.created_at && (
          <p className="mt-1 text-[10px] text-tx-muted/60">
            {new Date(message.created_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
          </p>
        )}
      </div>
    </div>
  );
}

/* ─── New Chat Modal ──────────────────────────────────── */
function NewChatModal({ onClose, onCreated }: { onClose: () => void; onCreated: (roomId: string) => void }) {
  const [search, setSearch] = useState("");
  const [searchResults, setSearchResults] = useState<Array<{ user_id: string; username: string; display_name?: string | null; avatar?: string | null }>>([]);
  const [loading, setLoading] = useState(false);
  const { toast } = useToast();

  async function handleSearch() {
    if (!search.trim()) return;
    setLoading(true);
    try {
      const { data } = await api.get<{ users: typeof searchResults }>("/friends/search", {
        params: { q: search },
      });
      setSearchResults(data.users);
    } catch {
      toast("Search failed", "error");
    }
    setLoading(false);
  }

  async function startChat(userId: string) {
    try {
      const result = await chatApi.createRoom("direct", [userId]);
      onCreated(result.room_id);
    } catch {
      toast("Failed to create chat", "error");
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div className="card w-full max-w-md p-6">
        <div className="flex items-center justify-between">
          <h2 className="font-heading text-xl font-bold">New Conversation</h2>
          <button onClick={onClose} className="text-tx-muted hover:text-tx">
            <X className="h-5 w-5" />
          </button>
        </div>
        <div className="mt-4 flex gap-2">
          <Input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && handleSearch()}
            placeholder="Search users..."
          />
          <Button onClick={handleSearch} isLoading={loading}>
            <Search className="h-4 w-4" />
          </Button>
        </div>
        <div className="mt-4 max-h-60 divide-y divide-bd overflow-y-auto">
          {searchResults.map((u) => (
            <button
              key={u.user_id}
              onClick={() => startChat(u.user_id)}
              className="flex w-full items-center gap-3 p-3 text-left hover:bg-surface-2"
            >
              <div className="flex h-9 w-9 items-center justify-center rounded-full bg-accent-bg text-sm font-bold text-accent">
                {(u.display_name || u.username || "U").charAt(0).toUpperCase()}
              </div>
              <div>
                <p className="text-sm font-semibold">{u.display_name || u.username}</p>
                <p className="text-xs text-tx-muted">@{u.username}</p>
              </div>
            </button>
          ))}
          {searchResults.length === 0 && search && !loading && (
            <p className="p-4 text-center text-sm text-tx-muted">No users found</p>
          )}
        </div>
      </div>
    </div>
  );
}

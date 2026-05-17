/**
 * Chat service – room-based WebSocket chat with REST API for history.
 * Supports: direct & group chats, typing indicators, message status, image sharing.
 */
import { api } from "./api";
import { API_TOKEN_STORAGE_KEY } from "./api";

/* ─── Types ───────────────────────────────────────────── */
export interface ChatMessage {
  message_id: string;
  room_id: string;
  sender_id: string;
  sender_username?: string | null;
  sender_avatar?: string | null;
  sender_display_name?: string | null;
  content?: string | null;
  message_type: string;
  media_url?: string | null;
  reply_to_id?: string | null;
  status: string;
  created_at?: string | null;
  edited_at?: string | null;
  is_own?: boolean;
}

export interface ChatRoomMember {
  user_id: string;
  username: string;
  avatar?: string | null;
  display_name?: string | null;
}

export interface ChatRoom {
  room_id: string;
  type: "direct" | "group";
  name?: string | null;
  avatar_url?: string | null;
  members: ChatRoomMember[];
  last_message?: {
    content?: string | null;
    sender_id?: string | null;
    created_at?: string | null;
    type?: string | null;
  } | null;
  unread_count: number;
  updated_at?: string | null;
}

export interface WsEvent {
  type: "message" | "typing" | "read" | "error";
  [key: string]: unknown;
}

type MessageHandler = (event: WsEvent) => void;
type ConnectionHandler = (connected: boolean) => void;

/* ─── REST API ────────────────────────────────────────── */
export const chatApi = {
  async getRooms(page = 1, limit = 50) {
    const { data } = await api.get<{ rooms: ChatRoom[] }>("/chat/rooms", {
      params: { page, limit },
    });
    return data.rooms;
  },

  async createRoom(type: "direct" | "group", userIds: string[], name?: string) {
    const { data } = await api.post<{ room_id: string; existing: boolean }>("/chat/rooms", {
      type,
      user_ids: userIds,
      name,
    });
    return data;
  },

  async getMessages(roomId: string, page = 1, limit = 50) {
    const { data } = await api.get<{
      messages: ChatMessage[];
      page: number;
      total: number;
      total_pages: number;
    }>(`/chat/rooms/${roomId}/messages`, { params: { page, limit } });
    return data;
  },

  async sendMessage(roomId: string, content: string, replyToId?: string) {
    const { data } = await api.post<{ message_id: string; created_at: string }>(
      `/chat/rooms/${roomId}/messages`,
      { content, reply_to_id: replyToId },
    );
    return data;
  },

  async uploadMedia(roomId: string, file: File) {
    const form = new FormData();
    form.append("file", file);
    const { data } = await api.post<{ message_id: string; media_url: string }>(
      `/chat/rooms/${roomId}/media`,
      form,
    );
    return data;
  },

  async markRead(messageId: string) {
    await api.put(`/chat/messages/${messageId}/read`);
  },

  async markRoomRead(roomId: string) {
    await api.post(`/chat/rooms/${roomId}/read`);
  },

  async renameRoom(roomId: string, name: string) {
    await api.put(`/chat/rooms/${roomId}`, { name });
  },

  async leaveRoom(roomId: string) {
    await api.delete(`/chat/rooms/${roomId}/members/me`);
  },

  async getMembers(roomId: string) {
    const { data } = await api.get<{ members: ChatRoomMember[] }>(`/chat/rooms/${roomId}/members`);
    return data.members;
  },

  async addMember(roomId: string, userId: string) {
    await api.post(`/chat/rooms/${roomId}/members`, { user_id: userId });
  },

  async removeMember(roomId: string, userId: string) {
    await api.delete(`/chat/rooms/${roomId}/members/${userId}`);
  },
};

/* ─── WebSocket Service ───────────────────────────────── */
class ChatWebSocketService {
  private ws: WebSocket | null = null;
  private messageHandlers: MessageHandler[] = [];
  private connectionHandlers: ConnectionHandler[] = [];
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private _currentRoomId: string | null = null;
  private _isConnected = false;
  private _token: string | null = null;
  private _reconnectAttempts = 0;

  get isConnected() {
    return this._isConnected;
  }

  get currentRoomId() {
    return this._currentRoomId;
  }

  /**
   * Connect to a specific chat room via WebSocket.
   */
  connect(roomId: string, token?: string | null) {
    // Disconnect from previous room if different
    if (this._currentRoomId && this._currentRoomId !== roomId) {
      this.disconnect();
    }

    this._token = token || (typeof window !== "undefined" ? localStorage.getItem(API_TOKEN_STORAGE_KEY) : null);
    this._currentRoomId = roomId;

    // Don't attempt connection without a valid token
    if (!this._token) {
      console.warn("[ChatWS] No auth token available, skipping connection");
      return;
    }

    if (this.ws?.readyState === WebSocket.OPEN && this._currentRoomId === roomId) return;

    if (this.ws) {
      this.ws.onclose = null; // tắt auto-reconnect của WS cũ
      this.ws.close();
      this.ws = null;
    }

    const defaultWsHost = typeof window !== "undefined"
      ? `ws://${window.location.hostname}:8000/ws`
      : "ws://localhost:8000/ws";
    const rawWsHost = (process.env.NEXT_PUBLIC_WS_URL ?? defaultWsHost).replace(/\/$/, "");
    const wsHost = rawWsHost.endsWith("/ws") ? rawWsHost : `${rawWsHost}/ws`;
    const url = `${wsHost}/chat/${roomId}?token=${encodeURIComponent(this._token)}`;

    try {
      this.ws = new WebSocket(url);

      this.ws.onopen = () => {
        this._isConnected = true;
        this._reconnectAttempts = 0;
        this.notifyConnectionHandlers(true);
      };

      this.ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data) as WsEvent;
          this.messageHandlers.forEach((h) => h(data));
        } catch {
          // ignore non-JSON
        }
      };

      this.ws.onclose = () => {
        this._isConnected = false;
        this.notifyConnectionHandlers(false);
        // Auto-reconnect with backoff (max 5 attempts)
        if (this._currentRoomId && (this._reconnectAttempts ?? 0) < 5) {
          this._reconnectAttempts = (this._reconnectAttempts ?? 0) + 1;
          const delay = Math.min(1000 * Math.pow(2, this._reconnectAttempts ?? 0), 30000);
          this.reconnectTimer = setTimeout(() => this.connect(roomId, this._token), delay);
        }
      };

      this.ws.onerror = () => {
        // onerror is always followed by onclose, no need to log scary errors
      };
    } catch (err) {
      console.error("[ChatWS] Failed to connect", err);
    }
  }

  disconnect() {
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this._currentRoomId = null;
    this.ws?.close();
    this.ws = null;
    this._isConnected = false;
    this.notifyConnectionHandlers(false);
  }

  /** Send a text message via WebSocket (real-time). */
  sendMessage(content: string) {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) return;
    this.ws.send(JSON.stringify({ type: "message", content }));
  }

  /** Send typing indicator. */
  sendTyping(isTyping: boolean) {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) return;
    this.ws.send(JSON.stringify({ type: "typing", is_typing: isTyping }));
  }

  /** Send read receipt. */
  sendRead(messageId: string) {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) return;
    this.ws.send(JSON.stringify({ type: "read", message_id: messageId }));
  }

  onMessage(handler: MessageHandler) {
    this.messageHandlers.push(handler);
    return () => {
      this.messageHandlers = this.messageHandlers.filter((h) => h !== handler);
    };
  }

  onConnection(handler: ConnectionHandler) {
    this.connectionHandlers.push(handler);
    return () => {
      this.connectionHandlers = this.connectionHandlers.filter((h) => h !== handler);
    };
  }

  private notifyConnectionHandlers(connected: boolean) {
    this.connectionHandlers.forEach((h) => h(connected));
  }
}

// Singleton
export const chatService = new ChatWebSocketService();

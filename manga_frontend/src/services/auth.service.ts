import { api } from "./api";
import type { LoginPayload, RegisterPayload, TokenResponse, User, UserUpdatePayload } from "@/types/user";

export const authService = {
  async register(payload: RegisterPayload) {
    const { data } = await api.post<User>("/auth/register", payload);
    return data;
  },

  async login(payload: LoginPayload) {
    const body = new URLSearchParams();
    body.set("username", payload.username);
    body.set("password", payload.password);

    const { data } = await api.post<TokenResponse>("/auth/login", body, {
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
    });
    return data;
  },

  async me() {
    const { data } = await api.get<User>("/auth/me");
    return data;
  },

  async updateMe(payload: UserUpdatePayload) {
    const { data } = await api.put<User>("/auth/me", payload);
    return data;
  },

  async uploadAvatar(file: File) {
    const form = new FormData();
    form.append("file", file);
    const { data } = await api.post<{ success: boolean; avatar_url: string }>("/auth/me/avatar", form);
    return data;
  },
};

import type { UUID } from "./common";

export interface TokenResponse {
  access_token: string;
  token_type: "bearer" | string;
}

export interface User {
  UserId: UUID;
  Username: string;
  Email: string;
  Avatar?: string | null;
  Role: "user" | "admin" | "uploader" | string;
  IsLocked?: boolean | null;
  CreatedAt?: string | null;
  Bio?: string | null;
  DisplayName?: string | null;
  AvatarObjectKey?: string | null;
  UpdatedAt?: string | null;
}

export interface RegisterPayload {
  username: string;
  email: string;
  password: string;
}

export interface LoginPayload {
  username: string;
  password: string;
}

export interface UserUpdatePayload {
  username?: string;
  avatar?: string;
  email?: string;
  bio?: string;
  display_name?: string;
  current_password?: string;
  new_password?: string;
}

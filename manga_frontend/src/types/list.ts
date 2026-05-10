import type { UUID } from "./common";

export type ListVisibility = "private" | "public" | string;

export interface MangaListBrief {
  ListId: UUID;
  Name?: string | null;
  Slug?: string | null;
  Description?: string | null;
  Visibility: ListVisibility;
  ItemCount: number;
  FollowerCount: number;
  UpdatedAt?: string | null;
  contains?: boolean | null;
  cover_url?: string | null;
}

export interface MangaListCollection {
  my_lists: MangaListBrief[];
  followed_lists: MangaListBrief[];
}

export interface ListMangaItem {
  manga_id: UUID;
  title?: string | null;
  position: number;
  cover_url?: string | null;
  status?: string | null;
  year?: number | null;
  content_rating?: string | null;
}

export interface MangaListDetail {
  ListId: UUID;
  Name?: string | null;
  Description?: string | null;
  Slug?: string | null;
  Visibility: ListVisibility;
  owner_id: UUID;
  owner_username?: string | null;
  ItemCount: number;
  FollowerCount: number;
  items: ListMangaItem[];
  is_following: boolean;
  cover_url?: string | null;
}

export interface PublicListItem extends MangaListBrief {
  owner_username?: string | null;
  owner_id?: UUID | null;
  is_following: boolean;
}

export interface ListCreatePayload {
  Name: string;
  Description?: string;
  Visibility: ListVisibility;
}

export interface ListUpdatePayload {
  Name?: string;
  Description?: string;
  Visibility?: ListVisibility;
}

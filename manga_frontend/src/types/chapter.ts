import type { UUID } from "./common";

export interface Chapter {
  ChapterId: UUID;
  MangaId: UUID;
  Type?: string | null;
  Volume?: string | null;
  ChapterNumber?: string | null;
  Title?: string | null;
  TranslatedLang?: string | null;
  Pages?: number | null;
  PublishAt?: string | null;
  CreatedAt?: string | null;
}

export interface ChapterNav {
  current: Chapter;
  prev_chapter?: Chapter | null;
  next_chapter?: Chapter | null;
  page_urls: string[];
}

export interface ChapterListParams {
  lang?: string;
  sort?: "asc" | "desc";
}

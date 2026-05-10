import type { UUID } from "./common";

export interface HistoryEntry {
  HistoryId: UUID;
  MangaId: UUID;
  ChapterId: UUID;
  LastPageRead?: number | null;
  ReadAt?: string | null;
  manga_title?: string | null;
  chapter_number?: string | null;
  cover_url?: string | null;
}

export interface HistoryGroup {
  label: string;
  items: HistoryEntry[];
}

export interface GroupedHistoryResponse {
  groups: HistoryGroup[];
}

export interface HistoryCreatePayload {
  MangaId: UUID;
  ChapterId: UUID;
  LastPageRead?: number | null;
}

export interface ContinueReadingResponse {
  chapter_id?: UUID | null;
  last_page?: number | null;
}

import type { UUID } from "./common";

export interface Statistics {
  Follows?: number | null;
  AverageRating?: number | null;
  BayesianRating?: number | null;
}

export interface TagBrief {
  TagId: UUID;
  GroupName?: string | null;
  NameEn?: string | null;
}

export interface AltTitle {
  LangCode?: string | null;
  AltTitle?: string | null;
}

export interface Description {
  LangCode?: string | null;
  Description?: string | null;
}

export interface LinkOut {
  Provider?: string | null;
  Url?: string | null;
}

export interface CreatorOut {
  id?: UUID;
  name?: string | null;
  role?: string | null;
}

export interface MangaListItem {
  MangaId: UUID;
  TitleEn?: string | null;
  Status?: string | null;
  Year?: number | null;
  ContentRating?: string | null;
  PublicationDemographic?: string | null;
  cover_url?: string | null;
  stats?: Statistics | null;
}

export interface MangaDetail extends MangaListItem {
  Type?: string | null;
  OriginalLanguage?: string | null;
  LastChapter?: string | null;
  LastVolume?: string | null;
  CreatedAt?: string | null;
  UpdatedAt?: string | null;
  tags: TagBrief[];
  alt_titles: AltTitle[];
  descriptions: Description[];
  links: LinkOut[];
  creators: CreatorOut[];
  available_languages: string[];
}

export interface RelatedManga {
  RelatedId: UUID;
  relation_type?: string | null;
  related_label?: string | null;
  title?: string | null;
  cover_url?: string | null;
}

export interface MangaListParams {
  page?: number;
  limit?: number;
  sort?: string;
  status?: string;
  content_rating?: string;
  demographic?: string;
  year?: number;
}

export interface AdvancedSearchParams extends MangaListParams {
  q?: string;
  include_tags?: string;
  exclude_tags?: string;
  year_from?: number;
  year_to?: number;
  original_lang?: string;
}

export interface TagGroup {
  group_name: string;
  tags: TagBrief[];
}

export interface Cover {
  cover_id?: UUID;
  manga_id?: UUID;
  volume?: string | null;
  locale?: string | null;
  fileName?: string | null;
  cover_url?: string | null;
}

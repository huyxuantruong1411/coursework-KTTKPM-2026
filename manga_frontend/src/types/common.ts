export type UUID = string;

export interface PaginatedResponse<T> {
  items: T[];
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
}

export interface MessageResponse<T = unknown> {
  message?: string;
  data?: T;
  success?: boolean;
}

export interface SelectOption {
  label: string;
  value: string;
}

export type SortDirection = "asc" | "desc";

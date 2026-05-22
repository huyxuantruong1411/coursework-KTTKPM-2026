import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatNumber(value?: number | null) {
  if (value === undefined || value === null) return "0";
  return new Intl.NumberFormat("en", { notation: value > 9999 ? "compact" : "standard" }).format(value);
}

export function formatDate(value?: string | null) {
  if (!value) return "Unknown";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "Unknown";
  return new Intl.DateTimeFormat("vi-VN", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  }).format(date);
}

export function pickDescription<T extends { LangCode?: string | null; Description?: string | null }>(items?: T[]) {
  if (!items?.length) return "";
  return (
    items.find((item) => item.LangCode === "en")?.Description ??
    items.find((item) => item.LangCode === "vi")?.Description ??
    items[0]?.Description ??
    ""
  );
}

export function titleCase(value?: string | null) {
  if (!value) return "Unknown";
  return value
    .split(/[-_\s]+/)
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

export function shortId(value?: string | null) {
  if (!value) return "";
  return value.slice(0, 8);
}

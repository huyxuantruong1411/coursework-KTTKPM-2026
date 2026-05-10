import { api } from "./api";
import type { TagGroup } from "@/types/manga";

export const tagService = {
  async list() {
    const { data } = await api.get<TagGroup[]>("/tags/");
    return data;
  },
};

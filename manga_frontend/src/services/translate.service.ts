import { api } from "./api";

export interface TranslatePageRequest {
    image_url: string;
    target_lang?: string;  // default "vi"
    source_lang?: string;  // default "auto"
}

export interface TranslatePageResponse {
    translated_url: string;
}

export const translateService = {
    async translatePage(payload: TranslatePageRequest): Promise<TranslatePageResponse> {
        const { data } = await api.post<TranslatePageResponse>("/translate/page", {
            image_url: payload.image_url,
            target_lang: payload.target_lang ?? "vi",
            source_lang: payload.source_lang ?? "auto",
        });
        return data;
    },
};

/** Map of ISO 639-1 codes to display names (for the language picker). */
export const TRANSLATE_LANGS: { code: string; label: string }[] = [
    { code: "vi", label: "Tiếng Việt" },
    { code: "en", label: "English" },
    { code: "zh-CN", label: "中文 (简体)" },
    { code: "zh-TW", label: "中文 (繁體)" },
    { code: "ko", label: "한국어" },
    { code: "ja", label: "日本語" },
    { code: "fr", label: "Français" },
    { code: "de", label: "Deutsch" },
    { code: "es", label: "Español" },
    { code: "pt", label: "Português" },
    { code: "th", label: "ภาษาไทย" },
    { code: "id", label: "Bahasa Indonesia" },
];
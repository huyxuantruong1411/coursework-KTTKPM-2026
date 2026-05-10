"use client";

import { FormEvent, Suspense, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import { Check, Filter, Grid3X3, LayoutList, List, RotateCcw, Search, X } from "lucide-react";
import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";
import { Pagination } from "@/components/ui/Pagination";
import { SectionHeader } from "@/components/ui/SectionHeader";
import { Select } from "@/components/ui/Select";
import { MangaGrid } from "@/components/features/MangaGrid";
import { useAdvancedSearch, useTagGroups } from "@/hooks/useMangaQueries";
import { cn } from "@/lib/utils";
import type { AdvancedSearchParams, TagBrief } from "@/types/manga";

const statuses = ["ongoing", "completed", "hiatus", "cancelled"];
const ratings = ["safe", "suggestive", "erotica", "pornographic"];
const demographics = ["shounen", "shoujo", "josei", "seinen"];
const languages = [
  { code: "ja", label: "Japanese" },
  { code: "ko", label: "Korean" },
  { code: "zh", label: "Chinese" },
  { code: "en", label: "English" },
  { code: "vi", label: "Vietnamese" },
];

type TagState = "none" | "include" | "exclude";
type ViewMode = "grid" | "compact" | "wide";

export default function ExplorePage() {
  return (
    <Suspense>
      <ExploreContent />
    </Suspense>
  );
}

function ExploreContent() {
  const searchParams = useSearchParams();
  const [page, setPage] = useState(1);
  const [q, setQ] = useState(searchParams.get("q") ?? "");
  const [sort, setSort] = useState(searchParams.get("sort") ?? "follows_desc");
  const [selectedStatuses, setSelectedStatuses] = useState<string[]>([]);
  const [selectedRatings, setSelectedRatings] = useState<string[]>([]);
  const [selectedDemographics, setSelectedDemographics] = useState<string[]>([]);
  const [yearFrom, setYearFrom] = useState("");
  const [yearTo, setYearTo] = useState("");
  const [originalLang, setOriginalLang] = useState("");
  const [viewMode, setViewMode] = useState<ViewMode>("grid");

  // 3-state tag management: none → include → exclude → none
  const [tagStates, setTagStates] = useState<Record<string, TagState>>({});
  const [activeTagGroup, setActiveTagGroup] = useState<string | null>(null);
  const [filtersOpen, setFiltersOpen] = useState(true);

  const includedTags = useMemo(
    () => Object.entries(tagStates).filter(([, s]) => s === "include").map(([id]) => id),
    [tagStates],
  );
  const excludedTags = useMemo(
    () => Object.entries(tagStates).filter(([, s]) => s === "exclude").map(([id]) => id),
    [tagStates],
  );

  const params = useMemo<AdvancedSearchParams>(
    () => ({
      q: q || undefined,
      page,
      limit: 24,
      sort,
      status: selectedStatuses.length ? selectedStatuses.join(",") : undefined,
      content_rating: selectedRatings.length ? selectedRatings.join(",") : undefined,
      demographic: selectedDemographics.length ? selectedDemographics.join(",") : undefined,
      year_from: yearFrom ? Number(yearFrom) : undefined,
      year_to: yearTo ? Number(yearTo) : undefined,
      include_tags: includedTags.length ? includedTags.join(",") : undefined,
      exclude_tags: excludedTags.length ? excludedTags.join(",") : undefined,
      original_lang: originalLang || undefined,
    }),
    [q, page, sort, selectedStatuses, selectedRatings, selectedDemographics, yearFrom, yearTo, includedTags, excludedTags, originalLang],
  );

  const results = useAdvancedSearch(params);
  const tagGroups = useTagGroups();

  const activeFilterCount =
    selectedStatuses.length +
    selectedRatings.length +
    selectedDemographics.length +
    includedTags.length +
    excludedTags.length +
    (yearFrom ? 1 : 0) +
    (yearTo ? 1 : 0) +
    (originalLang ? 1 : 0);

  function cycleTag(tagId: string) {
    setPage(1);
    setTagStates((prev) => {
      const current = prev[tagId] ?? "none";
      const next: TagState = current === "none" ? "include" : current === "include" ? "exclude" : "none";
      if (next === "none") {
        const { [tagId]: _, ...rest } = prev;
        return rest;
      }
      return { ...prev, [tagId]: next };
    });
  }

  function toggleMultiSelect(list: string[], item: string, setter: (v: string[]) => void) {
    setPage(1);
    setter(list.includes(item) ? list.filter((v) => v !== item) : [...list, item]);
  }

  function resetAll() {
    setPage(1);
    setQ("");
    setSort("follows_desc");
    setSelectedStatuses([]);
    setSelectedRatings([]);
    setSelectedDemographics([]);
    setYearFrom("");
    setYearTo("");
    setOriginalLang("");
    setTagStates({});
  }

  function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setPage(1);
  }

  return (
    <div className="page-shell">
      <SectionHeader
        eyebrow="Explore"
        title="Search & filter manga"
        description="Advanced search with include/exclude tags, multi-select filters, and full sorting."
      />

      <form onSubmit={submit} className="card overflow-hidden">
        {/* ═══ SEARCH BAR + VIEW TOGGLE ═══ */}
        <div className="flex flex-wrap items-center gap-3 border-b border-bd p-4">
          <div className="flex min-w-0 flex-1 items-center gap-2 rounded-def border border-bd bg-surface-2 px-3 focus-within:border-accent focus-within:ring-2 focus-within:ring-accent-bg">
            <Search className="h-4 w-4 shrink-0 text-tx-muted" aria-hidden />
            <input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="Title or alt title..."
              className="h-10 min-w-0 flex-1 bg-transparent text-sm text-tx outline-none placeholder:text-tx-muted/60"
            />
          </div>

          <Button
            type="button"
            variant={filtersOpen ? "primary" : "light"}
            size="sm"
            onClick={() => setFiltersOpen(!filtersOpen)}
          >
            <Filter className="h-4 w-4" aria-hidden />
            Filters
            {activeFilterCount > 0 && (
              <span className="ml-1 flex h-5 w-5 items-center justify-center rounded-full bg-white/20 text-[10px] font-bold">
                {activeFilterCount}
              </span>
            )}
          </Button>

          {/* View mode toggle */}
          <div className="hidden items-center gap-1 rounded-def border border-bd bg-surface-2 p-1 sm:flex">
            {([
              { mode: "grid" as ViewMode, icon: Grid3X3 },
              { mode: "compact" as ViewMode, icon: LayoutList },
              { mode: "wide" as ViewMode, icon: List },
            ]).map(({ mode, icon: Icon }) => (
              <button
                key={mode}
                type="button"
                onClick={() => setViewMode(mode)}
                className={cn(
                  "rounded-sm p-1.5 transition-colors",
                  viewMode === mode ? "bg-accent text-white" : "text-tx-muted hover:text-accent",
                )}
              >
                <Icon className="h-4 w-4" />
              </button>
            ))}
          </div>
        </div>

        {/* ═══ FILTER PANEL ═══ */}
        {filtersOpen && (
          <div className="border-b border-bd p-4 animate-fadeIn">
            <div className="grid gap-4 lg:grid-cols-[280px_1fr]">
              {/* Left: classic filters */}
              <div className="space-y-4 border-bd lg:border-r lg:pr-4">
                <Select value={sort} onChange={(e) => { setSort(e.target.value); setPage(1); }} label="Sort by">
                  <option value="follows_desc">Most followed</option>
                  <option value="rating_desc">Highest rating</option>
                  <option value="recent">Recently updated</option>
                  <option value="year_desc">Newest year</option>
                  <option value="year_asc">Oldest year</option>
                  <option value="title_asc">Title A→Z</option>
                  <option value="title_desc">Title Z→A</option>
                </Select>

                <div className="grid grid-cols-2 gap-2">
                  <Input value={yearFrom} onChange={(e) => setYearFrom(e.target.value)} placeholder="2000" label="Year from" type="number" />
                  <Input value={yearTo} onChange={(e) => setYearTo(e.target.value)} placeholder="2026" label="Year to" type="number" />
                </div>

                <Select value={originalLang} onChange={(e) => { setOriginalLang(e.target.value); setPage(1); }} label="Original language">
                  <option value="">All languages</option>
                  {languages.map((lang) => (
                    <option key={lang.code} value={lang.code}>{lang.label}</option>
                  ))}
                </Select>

                <MultiToggle
                  title="Status"
                  items={statuses}
                  selected={selectedStatuses}
                  onToggle={(item) => toggleMultiSelect(selectedStatuses, item, setSelectedStatuses)}
                />
                <MultiToggle
                  title="Content rating"
                  items={ratings}
                  selected={selectedRatings}
                  onToggle={(item) => toggleMultiSelect(selectedRatings, item, setSelectedRatings)}
                />
                <MultiToggle
                  title="Demographic"
                  items={demographics}
                  selected={selectedDemographics}
                  onToggle={(item) => toggleMultiSelect(selectedDemographics, item, setSelectedDemographics)}
                />

                <div className="flex gap-2 pt-2">
                  <Button type="submit" className="flex-1">
                    <Search className="h-4 w-4" aria-hidden />
                    Apply
                  </Button>
                  <Button type="button" variant="ghost" onClick={resetAll}>
                    <RotateCcw className="h-4 w-4" aria-hidden />
                  </Button>
                </div>
              </div>

              {/* Right: Tag selector */}
              <div className="min-w-0">
                <p className="mb-2 text-xs font-bold uppercase text-tx-muted tracking-wide">
                  Tags — click to include (✓), again to exclude (✕)
                </p>

                {/* Tag group tabs */}
                {tagGroups.data && tagGroups.data.length > 0 && (
                  <div className="mb-3 flex flex-wrap gap-1.5">
                    <button
                      type="button"
                      onClick={() => setActiveTagGroup(null)}
                      className={cn(
                        "rounded-def px-2.5 py-1 text-xs font-semibold transition-colors",
                        activeTagGroup === null
                          ? "bg-accent text-white"
                          : "bg-surface-2 text-tx-muted hover:text-accent",
                      )}
                    >
                      All
                    </button>
                    {tagGroups.data.map((group) => (
                      <button
                        key={group.group_name}
                        type="button"
                        onClick={() => setActiveTagGroup(group.group_name)}
                        className={cn(
                          "rounded-def px-2.5 py-1 text-xs font-semibold transition-colors",
                          activeTagGroup === group.group_name
                            ? "bg-accent text-white"
                            : "bg-surface-2 text-tx-muted hover:text-accent",
                        )}
                      >
                        {group.group_name}
                      </button>
                    ))}
                  </div>
                )}

                {/* Tag buttons */}
                <div className="max-h-64 overflow-y-auto rounded-def border border-bd bg-surface-2 p-3">
                  {tagGroups.data
                    ?.filter((g) => !activeTagGroup || g.group_name === activeTagGroup)
                    .map((group) => (
                      <div key={group.group_name} className="mb-3 last:mb-0">
                        <p className="mb-2 text-[10px] font-bold uppercase text-tx-muted tracking-wider">
                          {group.group_name}
                        </p>
                        <div className="flex flex-wrap gap-1.5">
                          {group.tags.map((tag) => (
                            <TagButton
                              key={tag.TagId}
                              tag={tag}
                              state={tagStates[tag.TagId] ?? "none"}
                              onCycle={() => cycleTag(tag.TagId)}
                            />
                          ))}
                        </div>
                      </div>
                    ))}
                  {!tagGroups.data?.length && (
                    <p className="text-sm text-tx-muted">Tags will appear when backend returns taxonomy data.</p>
                  )}
                </div>

                {/* Active tag summary */}
                {(includedTags.length > 0 || excludedTags.length > 0) && (
                  <div className="mt-3 flex flex-wrap gap-1.5">
                    {includedTags.map((id) => {
                      const tag = findTag(tagGroups.data, id);
                      return (
                        <button
                          key={id}
                          type="button"
                          onClick={() => cycleTag(id)}
                          className="tag-include badge gap-1"
                        >
                          <Check className="h-3 w-3" />
                          {tag?.NameEn ?? id.slice(0, 8)}
                        </button>
                      );
                    })}
                    {excludedTags.map((id) => {
                      const tag = findTag(tagGroups.data, id);
                      return (
                        <button
                          key={id}
                          type="button"
                          onClick={() => cycleTag(id)}
                          className="tag-exclude badge gap-1"
                        >
                          <X className="h-3 w-3" />
                          {tag?.NameEn ?? id.slice(0, 8)}
                        </button>
                      );
                    })}
                    <button
                      type="button"
                      onClick={() => setTagStates({})}
                      className="badge text-tx-muted hover:text-accent transition-colors"
                    >
                      Clear all tags
                    </button>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

        {/* ═══ RESULTS ═══ */}
        <div className="p-4">
          <div className="mb-4 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
            <p className="text-sm font-semibold text-tx-muted">
              {results.data?.total ?? 0} results · page {results.data?.page ?? page}
            </p>
          </div>
          <MangaGrid items={results.data?.items} isLoading={results.isLoading} variant={viewMode} />
          <Pagination page={page} totalPages={results.data?.total_pages ?? 1} onPageChange={setPage} />
        </div>
      </form>
    </div>
  );
}

/* ═══════════════════════════════════════════
   MULTI-TOGGLE (multi-select filter group)
   ═══════════════════════════════════════════ */
function MultiToggle({
  title,
  items,
  selected,
  onToggle,
}: {
  title: string;
  items: string[];
  selected: string[];
  onToggle: (item: string) => void;
}) {
  return (
    <div>
      <p className="mb-2 text-xs font-bold text-tx-muted">{title}</p>
      <div className="flex flex-wrap gap-1.5">
        {items.map((item) => (
          <button
            key={item}
            type="button"
            onClick={() => onToggle(item)}
            className={cn(
              "rounded-def px-2.5 py-1 text-xs font-semibold transition-colors",
              selected.includes(item)
                ? "bg-accent text-white"
                : "bg-surface-2 text-tx-muted hover:text-accent hover:bg-accent-bg",
            )}
          >
            {item}
          </button>
        ))}
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════
   TAG BUTTON (3-state: none → include → exclude)
   ═══════════════════════════════════════════ */
function TagButton({
  tag,
  state,
  onCycle,
}: {
  tag: TagBrief;
  state: TagState;
  onCycle: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onCycle}
      className={cn(
        "badge cursor-pointer transition-all duration-150",
        state === "include" && "tag-include",
        state === "exclude" && "tag-exclude",
        state === "none" && "tag-none hover:border-accent/40 hover:text-accent",
      )}
    >
      {state === "include" && <Check className="h-3 w-3" />}
      {state === "exclude" && <X className="h-3 w-3" />}
      {tag.NameEn}
    </button>
  );
}

/* ═══════════════════════════════════════════
   HELPER
   ═══════════════════════════════════════════ */
function findTag(
  groups: { group_name: string; tags: TagBrief[] }[] | undefined,
  tagId: string,
): TagBrief | undefined {
  if (!groups) return undefined;
  for (const g of groups) {
    const found = g.tags.find((t) => t.TagId === tagId);
    if (found) return found;
  }
  return undefined;
}

import { useState, useEffect, useRef } from "react";

const TAGS = {
    Genre: ["Action", "Adventure", "Comedy", "Drama", "Fantasy", "Horror", "Mystery", "Romance", "Sci-Fi", "Slice of Life", "Sports", "Thriller", "Psychological", "Historical", "Isekai", "Martial Arts", "Mecha", "Music", "Supernatural", "School Life"],
    Theme: ["Monsters", "Time Travel", "Revenge", "Vampires", "Magic", "Military", "Cooking", "Gaming", "Harem", "Villainess", "Reincarnation", "Survival", "Post-Apocalyptic", "Aliens", "Zombies"],
    Format: ["4-Koma", "Anthology", "Award Winning", "Doujinshi", "Long Strip", "Oneshot"],
    "Content Advisory": ["Gore", "Sexual Violence", "Suggestive", "Ecchi"],
};

const SAMPLE_MANGA = [
    { id: 1, title: "Berserk", author: "Kentaro Miura", status: "hiatus", rating: 9.4, cover: "https://placehold.co/160x220/1a1a2e/e5c46d?text=Berserk", year: 1989, genres: ["Action", "Fantasy", "Horror"], demographic: "seinen" },
    { id: 2, title: "Vagabond", author: "Takehiko Inoue", status: "hiatus", rating: 9.3, cover: "https://placehold.co/160x220/16213e/c084fc?text=Vagabond", year: 1998, genres: ["Action", "Historical", "Drama"], demographic: "seinen" },
    { id: 3, title: "Vinland Saga", author: "Makoto Yukimura", status: "ongoing", rating: 9.1, cover: "https://placehold.co/160x220/0f3460/6ee7b7?text=Vinland", year: 2005, genres: ["Action", "Adventure", "Historical"], demographic: "seinen" },
    { id: 4, title: "JoJo's Bizarre Adventure", author: "Hirohiko Araki", status: "ongoing", rating: 8.9, cover: "https://placehold.co/160x220/1a1a2e/fb923c?text=JoJo", year: 1987, genres: ["Action", "Adventure", "Supernatural"], demographic: "shounen" },
    { id: 5, title: "Chainsaw Man", author: "Tatsuki Fujimoto", status: "ongoing", rating: 8.8, cover: "https://placehold.co/160x220/16213e/f87171?text=CSM", year: 2018, genres: ["Action", "Horror", "Supernatural"], demographic: "shounen" },
    { id: 6, title: "Oyasumi Punpun", author: "Inio Asano", status: "completed", rating: 9.0, cover: "https://placehold.co/160x220/0f3460/93c5fd?text=Punpun", year: 2007, genres: ["Drama", "Psychological", "Slice of Life"], demographic: "seinen" },
    { id: 7, title: "Fullmetal Alchemist", author: "Hiromu Arakawa", status: "completed", rating: 9.2, cover: "https://placehold.co/160x220/1a1a2e/fbbf24?text=FMA", year: 2001, genres: ["Action", "Fantasy", "Adventure"], demographic: "shounen" },
    { id: 8, title: "Vinsmoke Wanted", author: "Oda Eiichiro", status: "ongoing", rating: 8.7, cover: "https://placehold.co/160x220/16213e/4ade80?text=Manga8", year: 2019, genres: ["Action", "Comedy", "Adventure"], demographic: "shounen" },
];

const CHAT_MESSAGES = [
    { id: 1, user: "Hiroshi_88", avatar: "H", msg: "Chapter mới của Berserk khi nào ra vậy?", time: "14:32", mine: false },
    { id: 2, user: "Sakura_fan", avatar: "S", msg: "Ai cũng hỏi câu đó 😭 RIP Miura sensei", time: "14:33", mine: false },
    { id: 3, user: "You", avatar: "Y", msg: "Moriura đang tiếp tục bộ này nè", time: "14:34", mine: true },
    { id: 4, user: "OtakuViet", avatar: "O", msg: "Vinland Saga arc mới hype cực luôn!", time: "14:35", mine: false },
];

const STATUS_CFG = {
    ongoing: { label: "Đang tiến hành", color: "#22c55e" },
    completed: { label: "Hoàn thành", color: "#3b82f6" },
    hiatus: { label: "Tạm dừng", color: "#f59e0b" },
    cancelled: { label: "Đã huỷ", color: "#ef4444" },
};

export default function MangaApp() {
    const [darkMode, setDarkMode] = useState(true);
    const [activeNav, setActiveNav] = useState("home");
    const [showSearch, setShowSearch] = useState(false);
    const [showChat, setShowChat] = useState(false);
    const [viewMode, setViewMode] = useState("comfortable");
    const [chatMsg, setChatMsg] = useState("");
    const [messages, setMessages] = useState(CHAT_MESSAGES);
    const [searchQuery, setSearchQuery] = useState("");
    const [includedTags, setIncludedTags] = useState([]);
    const [excludedTags, setExcludedTags] = useState([]);
    const [filters, setFilters] = useState({
        sortBy: "follows_desc", contentRating: [], demographic: [], status: [],
        yearFrom: "", yearTo: "", originalLang: "", hasTranslation: false,
    });
    const [activeTagGroup, setActiveTagGroup] = useState("Genre");
    const chatEndRef = useRef(null);

    const bg = darkMode ? "#0d0d0d" : "#f8f7f4";
    const surface = darkMode ? "#161616" : "#ffffff";
    const surface2 = darkMode ? "#1e1e1e" : "#f3f2ef";
    const surface3 = darkMode ? "#2a2a2a" : "#e8e7e3";
    const text = darkMode ? "#e8e8e8" : "#1a1a1a";
    const textMuted = darkMode ? "#888" : "#666";
    const border = darkMode ? "#2c2c2c" : "#e0deda";
    const accent = "#ff6740";
    const accentBg = darkMode ? "rgba(255,103,64,0.12)" : "rgba(255,103,64,0.08)";

    useEffect(() => {
        chatEndRef.current?.scrollIntoView({ behavior: "smooth" });
    }, [messages]);

    const toggleTag = (tag) => {
        if (includedTags.includes(tag)) {
            setIncludedTags(p => p.filter(t => t !== tag));
            setExcludedTags(p => [...p, tag]);
        } else if (excludedTags.includes(tag)) {
            setExcludedTags(p => p.filter(t => t !== tag));
        } else {
            setIncludedTags(p => [...p, tag]);
        }
    };

    const getTagState = (tag) => {
        if (includedTags.includes(tag)) return "include";
        if (excludedTags.includes(tag)) return "exclude";
        return "none";
    };

    const toggleFilter = (key, val) => {
        setFilters(f => ({
            ...f,
            [key]: f[key].includes(val) ? f[key].filter(v => v !== val) : [...f[key], val]
        }));
    };

    const sendChatMsg = () => {
        if (!chatMsg.trim()) return;
        setMessages(m => [...m, { id: Date.now(), user: "You", avatar: "Y", msg: chatMsg, time: new Date().toLocaleTimeString('vi', { hour: '2-digit', minute: '2-digit' }), mine: true }]);
        setChatMsg("");
    };

    const resetSearch = () => {
        setIncludedTags([]); setExcludedTags([]);
        setFilters({ sortBy: "follows_desc", contentRating: [], demographic: [], status: [], yearFrom: "", yearTo: "", originalLang: "", hasTranslation: false });
        setSearchQuery("");
    };

    const activeTagCount = includedTags.length + excludedTags.length +
        filters.contentRating.length + filters.demographic.length +
        filters.status.length + (filters.yearFrom ? 1 : 0) + (filters.yearTo ? 1 : 0) +
        (filters.originalLang ? 1 : 0) + (filters.hasTranslation ? 1 : 0) +
        (filters.sortBy !== "follows_desc" ? 1 : 0);

    const filteredManga = SAMPLE_MANGA.filter(m =>
        !searchQuery || m.title.toLowerCase().includes(searchQuery.toLowerCase()) || m.author.toLowerCase().includes(searchQuery.toLowerCase())
    );

    const NAV = [
        { id: "home", icon: "🏠", label: "Trang chủ" },
        { id: "browse", icon: "📚", label: "Khám phá" },
        { id: "lists", icon: "📋", label: "Danh sách" },
        { id: "history", icon: "🕐", label: "Lịch sử" },
        { id: "updates", icon: "🔔", label: "Cập nhật" },
        { id: "admin", icon: "⚙️", label: "Quản trị" },
    ];

    return (
        <div style={{ display: "flex", height: "100vh", background: bg, color: text, fontFamily: "'Noto Sans','Segoe UI',sans-serif", overflow: "hidden", fontSize: "14px" }}>

            {/* Sidebar Navigation */}
            <div style={{ width: 56, background: surface, borderRight: `1px solid ${border}`, display: "flex", flexDirection: "column", alignItems: "center", padding: "12px 0", gap: 4, flexShrink: 0 }}>
                <div style={{ width: 36, height: 36, background: accent, borderRadius: 8, display: "flex", alignItems: "center", justifyContent: "center", marginBottom: 12, cursor: "pointer", fontSize: 18 }}>📖</div>
                {NAV.map(n => (
                    <button key={n.id} onClick={() => setActiveNav(n.id)} title={n.label}
                        style={{ width: 40, height: 40, border: "none", background: activeNav === n.id ? accentBg : "transparent", borderRadius: 8, cursor: "pointer", fontSize: 18, display: "flex", alignItems: "center", justifyContent: "center", color: activeNav === n.id ? accent : textMuted, transition: "all 0.15s", position: "relative" }}>
                        {n.icon}
                        {activeNav === n.id && <div style={{ position: "absolute", left: 0, top: "50%", transform: "translateY(-50%)", width: 3, height: 20, background: accent, borderRadius: "0 2px 2px 0" }} />}
                    </button>
                ))}
                <div style={{ flex: 1 }} />
                <button onClick={() => setShowChat(!showChat)} title="Chat" style={{ width: 40, height: 40, border: "none", background: showChat ? accentBg : "transparent", borderRadius: 8, cursor: "pointer", fontSize: 18, color: showChat ? accent : textMuted, position: "relative" }}>
                    💬
                    <div style={{ position: "absolute", top: 6, right: 6, width: 8, height: 8, background: "#22c55e", borderRadius: "50%", border: `2px solid ${surface}` }} />
                </button>
                <button onClick={() => setDarkMode(!darkMode)} title="Toggle theme" style={{ width: 40, height: 40, border: "none", background: "transparent", borderRadius: 8, cursor: "pointer", fontSize: 18, color: textMuted, marginBottom: 8 }}>
                    {darkMode ? "☀️" : "🌙"}
                </button>
            </div>

            {/* Main Content */}
            <div style={{ flex: 1, display: "flex", flexDirection: "column", overflow: "hidden", minWidth: 0 }}>

                {/* Top Bar */}
                <div style={{ height: 52, background: surface, borderBottom: `1px solid ${border}`, display: "flex", alignItems: "center", padding: "0 16px", gap: 10, flexShrink: 0 }}>
                    <div style={{ flex: 1, display: "flex", alignItems: "center", gap: 8, background: surface2, borderRadius: 8, padding: "0 12px", height: 34, border: `1px solid ${border}` }}>
                        <span style={{ color: textMuted, fontSize: 16 }}>🔍</span>
                        <input value={searchQuery} onChange={e => setSearchQuery(e.target.value)} placeholder="Tìm kiếm truyện, tác giả..."
                            style={{ flex: 1, background: "transparent", border: "none", outline: "none", color: text, fontSize: 13 }} />
                        {searchQuery && <button onClick={() => setSearchQuery("")} style={{ border: "none", background: "transparent", cursor: "pointer", color: textMuted, fontSize: 16, padding: 0 }}>✕</button>}
                    </div>

                    <button onClick={() => setShowSearch(!showSearch)}
                        style={{ height: 34, padding: "0 12px", borderRadius: 8, border: `1px solid ${showSearch ? accent : border}`, background: showSearch ? accentBg : "transparent", color: showSearch ? accent : textMuted, cursor: "pointer", display: "flex", alignItems: "center", gap: 6, fontSize: 13, whiteSpace: "nowrap", transition: "all 0.15s" }}>
                        🎛️ Bộ lọc
                        {activeTagCount > 0 && <span style={{ background: accent, color: "white", borderRadius: 10, padding: "1px 6px", fontSize: 11, fontWeight: 600 }}>{activeTagCount}</span>}
                    </button>

                    <div style={{ display: "flex", gap: 2 }}>
                        {["comfortable", "list", "compact"].map(m => (
                            <button key={m} onClick={() => setViewMode(m)} style={{ width: 30, height: 30, border: "none", background: viewMode === m ? accentBg : "transparent", borderRadius: 6, cursor: "pointer", color: viewMode === m ? accent : textMuted, fontSize: 16 }}>
                                {m === "comfortable" ? "⊞" : m === "list" ? "☰" : "⊟"}
                            </button>
                        ))}
                    </div>

                    <div style={{ height: 24, width: 1, background: border }} />
                    <div style={{ width: 30, height: 30, borderRadius: "50%", background: accent, display: "flex", alignItems: "center", justifyContent: "center", color: "white", fontSize: 13, fontWeight: 600, cursor: "pointer", flexShrink: 0 }}>Y</div>
                </div>

                {/* Advanced Search Panel */}
                {showSearch && (
                    <div style={{ background: surface2, borderBottom: `1px solid ${border}`, padding: "16px", display: "flex", flexDirection: "column", gap: 14, flexShrink: 0 }}>

                        {/* Tag Selector */}
                        <div>
                            <div style={{ display: "flex", gap: 8, marginBottom: 10, flexWrap: "wrap" }}>
                                {Object.keys(TAGS).map(g => (
                                    <button key={g} onClick={() => setActiveTagGroup(g)}
                                        style={{ padding: "4px 12px", borderRadius: 20, border: `1px solid ${activeTagGroup === g ? accent : border}`, background: activeTagGroup === g ? accentBg : "transparent", color: activeTagGroup === g ? accent : textMuted, cursor: "pointer", fontSize: 12, fontWeight: activeTagGroup === g ? 600 : 400 }}>
                                        {g}
                                    </button>
                                ))}
                            </div>
                            <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
                                {TAGS[activeTagGroup].map(tag => {
                                    const state = getTagState(tag);
                                    return (
                                        <button key={tag} onClick={() => toggleTag(tag)}
                                            style={{
                                                padding: "4px 10px", borderRadius: 4, border: `1px solid ${state === "include" ? "#22c55e" : state === "exclude" ? "#ef4444" : border}`,
                                                background: state === "include" ? "rgba(34,197,94,0.12)" : state === "exclude" ? "rgba(239,68,68,0.12)" : "transparent",
                                                color: state === "include" ? "#22c55e" : state === "exclude" ? "#ef4444" : textMuted,
                                                cursor: "pointer", fontSize: 12, display: "flex", alignItems: "center", gap: 4, transition: "all 0.12s"
                                            }}>
                                            {state === "include" && <span style={{ fontSize: 11 }}>✓</span>}
                                            {state === "exclude" && <span style={{ fontSize: 11 }}>✕</span>}
                                            {tag}
                                        </button>
                                    );
                                })}
                            </div>
                            {(includedTags.length > 0 || excludedTags.length > 0) && (
                                <div style={{ marginTop: 8, fontSize: 12, color: textMuted }}>
                                    {includedTags.length > 0 && <span style={{ color: "#22c55e" }}>✓ {includedTags.join(", ")} </span>}
                                    {excludedTags.length > 0 && <span style={{ color: "#ef4444" }}>✕ {excludedTags.join(", ")}</span>}
                                </div>
                            )}
                        </div>

                        {/* Filter Row 1 */}
                        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit,minmax(150px,1fr))", gap: 10 }}>
                            <div>
                                <label style={{ fontSize: 11, color: textMuted, display: "block", marginBottom: 4 }}>Sắp xếp</label>
                                <select value={filters.sortBy} onChange={e => setFilters(f => ({ ...f, sortBy: e.target.value }))}
                                    style={{ width: "100%", background: surface3, border: `1px solid ${border}`, borderRadius: 6, color: text, padding: "6px 8px", fontSize: 12 }}>
                                    <option value="follows_desc">Lượt follow</option>
                                    <option value="rating_desc">Đánh giá cao</option>
                                    <option value="recent">Mới cập nhật</option>
                                    <option value="title_asc">Tiêu đề A-Z</option>
                                    <option value="year_desc">Năm phát hành</option>
                                </select>
                            </div>

                            <div>
                                <label style={{ fontSize: 11, color: textMuted, display: "block", marginBottom: 4 }}>Trạng thái</label>
                                <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
                                    {["ongoing", "completed", "hiatus", "cancelled"].map(s => (
                                        <button key={s} onClick={() => toggleFilter("status", s)}
                                            style={{
                                                padding: "4px 8px", borderRadius: 4, fontSize: 11, border: `1px solid ${filters.status.includes(s) ? STATUS_CFG[s].color : border}`,
                                                background: filters.status.includes(s) ? STATUS_CFG[s].color + "22" : "transparent",
                                                color: filters.status.includes(s) ? STATUS_CFG[s].color : textMuted, cursor: "pointer"
                                            }}>
                                            {STATUS_CFG[s].label}
                                        </button>
                                    ))}
                                </div>
                            </div>

                            <div>
                                <label style={{ fontSize: 11, color: textMuted, display: "block", marginBottom: 4 }}>Đối tượng</label>
                                <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
                                    {["shounen", "shoujo", "seinen", "josei"].map(d => (
                                        <button key={d} onClick={() => toggleFilter("demographic", d)}
                                            style={{
                                                padding: "4px 8px", borderRadius: 4, fontSize: 11, border: `1px solid ${filters.demographic.includes(d) ? accent : border}`,
                                                background: filters.demographic.includes(d) ? accentBg : "transparent",
                                                color: filters.demographic.includes(d) ? accent : textMuted, cursor: "pointer", textTransform: "capitalize"
                                            }}>
                                            {d}
                                        </button>
                                    ))}
                                </div>
                            </div>

                            <div>
                                <label style={{ fontSize: 11, color: textMuted, display: "block", marginBottom: 4 }}>Nội dung</label>
                                <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
                                    {["safe", "suggestive", "erotica"].map(r => (
                                        <button key={r} onClick={() => toggleFilter("contentRating", r)}
                                            style={{
                                                padding: "4px 8px", borderRadius: 4, fontSize: 11, border: `1px solid ${filters.contentRating.includes(r) ? accent : border}`,
                                                background: filters.contentRating.includes(r) ? accentBg : "transparent",
                                                color: filters.contentRating.includes(r) ? accent : textMuted, cursor: "pointer", textTransform: "capitalize"
                                            }}>
                                            {r}
                                        </button>
                                    ))}
                                </div>
                            </div>
                        </div>

                        {/* Filter Row 2 */}
                        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit,minmax(150px,1fr))", gap: 10 }}>
                            <div>
                                <label style={{ fontSize: 11, color: textMuted, display: "block", marginBottom: 4 }}>Ngôn ngữ gốc</label>
                                <select value={filters.originalLang} onChange={e => setFilters(f => ({ ...f, originalLang: e.target.value }))}
                                    style={{ width: "100%", background: surface3, border: `1px solid ${border}`, borderRadius: 6, color: text, padding: "6px 8px", fontSize: 12 }}>
                                    <option value="">Bất kỳ</option>
                                    <option value="ja">Tiếng Nhật 🇯🇵</option>
                                    <option value="ko">Tiếng Hàn 🇰🇷</option>
                                    <option value="zh">Tiếng Trung 🇨🇳</option>
                                    <option value="en">Tiếng Anh 🇺🇸</option>
                                    <option value="vi">Tiếng Việt 🇻🇳</option>
                                </select>
                            </div>

                            <div>
                                <label style={{ fontSize: 11, color: textMuted, display: "block", marginBottom: 4 }}>Năm xuất bản</label>
                                <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
                                    <input type="number" placeholder="Từ" value={filters.yearFrom} onChange={e => setFilters(f => ({ ...f, yearFrom: e.target.value }))}
                                        style={{ width: "100%", background: surface3, border: `1px solid ${border}`, borderRadius: 6, color: text, padding: "6px 8px", fontSize: 12 }} />
                                    <span style={{ color: textMuted, fontSize: 12 }}>—</span>
                                    <input type="number" placeholder="Đến" value={filters.yearTo} onChange={e => setFilters(f => ({ ...f, yearTo: e.target.value }))}
                                        style={{ width: "100%", background: surface3, border: `1px solid ${border}`, borderRadius: 6, color: text, padding: "6px 8px", fontSize: 12 }} />
                                </div>
                            </div>

                            <div style={{ display: "flex", alignItems: "flex-end", gap: 8, paddingBottom: 2 }}>
                                <label style={{ display: "flex", alignItems: "center", gap: 6, cursor: "pointer", fontSize: 12, color: textMuted }}>
                                    <div onClick={() => setFilters(f => ({ ...f, hasTranslation: !f.hasTranslation }))}
                                        style={{ width: 36, height: 20, borderRadius: 10, background: filters.hasTranslation ? accent : surface3, border: `1px solid ${border}`, cursor: "pointer", position: "relative", transition: "background 0.2s" }}>
                                        <div style={{ position: "absolute", top: 2, left: filters.hasTranslation ? 18 : 2, width: 14, height: 14, borderRadius: "50%", background: "white", transition: "left 0.2s", boxShadow: "0 1px 3px rgba(0,0,0,0.3)" }} />
                                    </div>
                                    Có bản dịch
                                </label>
                            </div>

                            <div style={{ display: "flex", alignItems: "flex-end", gap: 8 }}>
                                <button onClick={resetSearch} style={{ padding: "6px 12px", borderRadius: 6, border: `1px solid ${border}`, background: "transparent", color: textMuted, cursor: "pointer", fontSize: 12 }}>
                                    Đặt lại
                                </button>
                                <button onClick={() => setShowSearch(false)} style={{ flex: 1, padding: "6px 12px", borderRadius: 6, border: "none", background: accent, color: "white", cursor: "pointer", fontSize: 12, fontWeight: 600 }}>
                                    🔍 Tìm kiếm
                                </button>
                            </div>
                        </div>
                    </div>
                )}

                {/* Content Area */}
                <div style={{ flex: 1, overflowY: "auto", padding: "16px" }}>

                    {/* Page Title */}
                    <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 14 }}>
                        <div>
                            <h1 style={{ margin: 0, fontSize: 18, fontWeight: 600, color: text }}>
                                {activeNav === "home" ? "🔥 Nổi bật" : activeNav === "browse" ? "📚 Khám phá" : activeNav === "lists" ? "📋 Danh sách" : activeNav === "history" ? "🕐 Lịch sử đọc" : activeNav === "updates" ? "🔔 Cập nhật mới" : "⚙️ Quản trị"}
                            </h1>
                            <p style={{ margin: "2px 0 0", fontSize: 12, color: textMuted }}>{filteredManga.length} kết quả</p>
                        </div>
                    </div>

                    {/* Manga Grid */}
                    {viewMode === "comfortable" && (
                        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill,minmax(150px,1fr))", gap: 12 }}>
                            {filteredManga.map(m => (
                                <div key={m.id} style={{ background: surface, borderRadius: 10, overflow: "hidden", border: `1px solid ${border}`, cursor: "pointer", transition: "transform 0.15s", display: "flex", flexDirection: "column" }}
                                    onMouseEnter={e => e.currentTarget.style.transform = "scale(1.02)"}
                                    onMouseLeave={e => e.currentTarget.style.transform = "scale(1)"}>
                                    <div style={{ position: "relative", paddingTop: "137%" }}>
                                        <img src={m.cover} alt={m.title} style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover" }} />
                                        <div style={{ position: "absolute", top: 6, left: 6, background: STATUS_CFG[m.status].color, color: "white", fontSize: 9, fontWeight: 700, padding: "2px 5px", borderRadius: 3 }}>
                                            {STATUS_CFG[m.status].label.split(" ")[0].toUpperCase()}
                                        </div>
                                        <div style={{ position: "absolute", top: 6, right: 6, background: "rgba(0,0,0,0.7)", color: "#fbbf24", fontSize: 10, fontWeight: 600, padding: "2px 5px", borderRadius: 3 }}>
                                            ⭐ {m.rating}
                                        </div>
                                    </div>
                                    <div style={{ padding: "8px 8px 10px" }}>
                                        <p style={{ margin: "0 0 2px", fontWeight: 600, fontSize: 12, color: text, lineHeight: 1.3, display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical", overflow: "hidden" }}>{m.title}</p>
                                        <p style={{ margin: 0, fontSize: 11, color: textMuted, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{m.author}</p>
                                        <div style={{ marginTop: 6, display: "flex", flexWrap: "wrap", gap: 3 }}>
                                            {m.genres.slice(0, 2).map(g => (
                                                <span key={g} style={{ fontSize: 9, padding: "1px 5px", borderRadius: 3, background: accentBg, color: accent }}>{g}</span>
                                            ))}
                                        </div>
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}

                    {viewMode === "list" && (
                        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                            {filteredManga.map(m => (
                                <div key={m.id} style={{ background: surface, borderRadius: 10, border: `1px solid ${border}`, padding: 12, display: "flex", gap: 12, cursor: "pointer", transition: "background 0.15s" }}
                                    onMouseEnter={e => e.currentTarget.style.background = surface2}
                                    onMouseLeave={e => e.currentTarget.style.background = surface}>
                                    <img src={m.cover} alt={m.title} style={{ width: 70, height: 96, objectFit: "cover", borderRadius: 6, flexShrink: 0 }} />
                                    <div style={{ flex: 1, minWidth: 0 }}>
                                        <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 8 }}>
                                            <h3 style={{ margin: 0, fontSize: 14, fontWeight: 600, color: text, lineHeight: 1.3 }}>{m.title}</h3>
                                            <span style={{ fontSize: 12, color: "#fbbf24", whiteSpace: "nowrap" }}>⭐ {m.rating}</span>
                                        </div>
                                        <p style={{ margin: "2px 0 6px", fontSize: 12, color: textMuted }}>{m.author} · {m.year}</p>
                                        <div style={{ display: "flex", gap: 6, flexWrap: "wrap", alignItems: "center" }}>
                                            <span style={{ fontSize: 10, padding: "2px 6px", borderRadius: 3, background: STATUS_CFG[m.status].color + "22", color: STATUS_CFG[m.status].color, fontWeight: 600 }}>
                                                {STATUS_CFG[m.status].label}
                                            </span>
                                            {m.genres.slice(0, 3).map(g => (
                                                <span key={g} style={{ fontSize: 10, padding: "2px 6px", borderRadius: 3, background: accentBg, color: accent }}>{g}</span>
                                            ))}
                                        </div>
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}

                    {viewMode === "compact" && (
                        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill,minmax(100px,1fr))", gap: 8 }}>
                            {filteredManga.map(m => (
                                <div key={m.id} style={{ cursor: "pointer" }} onMouseEnter={e => e.currentTarget.querySelector("img").style.opacity = "0.8"} onMouseLeave={e => e.currentTarget.querySelector("img").style.opacity = "1"}>
                                    <div style={{ position: "relative", paddingTop: "137%", borderRadius: 6, overflow: "hidden" }}>
                                        <img src={m.cover} alt={m.title} style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", transition: "opacity 0.15s" }} />
                                        <div style={{ position: "absolute", top: 4, left: 4, background: STATUS_CFG[m.status].color, color: "white", fontSize: 8, fontWeight: 700, padding: "1px 4px", borderRadius: 2 }}>
                                            {m.status === "ongoing" ? "ON" : m.status === "completed" ? "END" : m.status === "hiatus" ? "HIA" : "CAN"}
                                        </div>
                                    </div>
                                    <p style={{ margin: "4px 0 0", fontSize: 11, fontWeight: 500, color: text, lineHeight: 1.3, display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical", overflow: "hidden" }}>{m.title}</p>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>

            {/* Chat Panel */}
            {showChat && (
                <div style={{ width: 280, background: surface, borderLeft: `1px solid ${border}`, display: "flex", flexDirection: "column", flexShrink: 0 }}>
                    <div style={{ padding: "12px 14px", borderBottom: `1px solid ${border}`, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                        <div>
                            <p style={{ margin: 0, fontWeight: 600, fontSize: 13, color: text }}>💬 Chat cộng đồng</p>
                            <p style={{ margin: 0, fontSize: 11, color: "#22c55e" }}>● 128 người trực tuyến</p>
                        </div>
                        <button onClick={() => setShowChat(false)} style={{ border: "none", background: "transparent", cursor: "pointer", color: textMuted, fontSize: 18 }}>✕</button>
                    </div>

                    <div style={{ display: "flex", gap: 8, padding: "8px 12px", borderBottom: `1px solid ${border}`, overflowX: "auto" }}>
                        {["#chung", "#berserk", "#chainsaw", "#vinland"].map(r => (
                            <button key={r} style={{ padding: "3px 10px", borderRadius: 12, border: `1px solid ${border}`, background: r === "#chung" ? accentBg : "transparent", color: r === "#chung" ? accent : textMuted, fontSize: 11, cursor: "pointer", whiteSpace: "nowrap" }}>
                                {r}
                            </button>
                        ))}
                    </div>

                    <div style={{ flex: 1, overflowY: "auto", padding: "10px 12px", display: "flex", flexDirection: "column", gap: 10 }}>
                        {messages.map(msg => (
                            <div key={msg.id} style={{ display: "flex", gap: 8, flexDirection: msg.mine ? "row-reverse" : "row", alignItems: "flex-end" }}>
                                {!msg.mine && (
                                    <div style={{ width: 28, height: 28, borderRadius: "50%", background: accent, color: "white", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 11, fontWeight: 700, flexShrink: 0 }}>
                                        {msg.avatar}
                                    </div>
                                )}
                                <div style={{ maxWidth: "75%" }}>
                                    {!msg.mine && <p style={{ margin: "0 0 2px 2px", fontSize: 10, color: textMuted }}>{msg.user}</p>}
                                    <div style={{ background: msg.mine ? accent : surface2, color: msg.mine ? "white" : text, padding: "7px 10px", borderRadius: msg.mine ? "12px 12px 4px 12px" : "12px 12px 12px 4px", fontSize: 12, lineHeight: 1.4 }}>
                                        {msg.msg}
                                    </div>
                                    <p style={{ margin: "2px 4px 0", fontSize: 10, color: textMuted, textAlign: msg.mine ? "right" : "left" }}>{msg.time}</p>
                                </div>
                            </div>
                        ))}
                        <div ref={chatEndRef} />
                    </div>

                    <div style={{ padding: "10px 12px", borderTop: `1px solid ${border}` }}>
                        <div style={{ display: "flex", gap: 6, background: surface2, borderRadius: 8, padding: "6px 10px", border: `1px solid ${border}` }}>
                            <input value={chatMsg} onChange={e => setChatMsg(e.target.value)} placeholder="Nhắn tin..." onKeyDown={e => e.key === "Enter" && sendChatMsg()}
                                style={{ flex: 1, background: "transparent", border: "none", outline: "none", color: text, fontSize: 12 }} />
                            <button onClick={sendChatMsg} style={{ border: "none", background: "transparent", cursor: "pointer", color: chatMsg ? accent : textMuted, fontSize: 18, padding: 0, lineHeight: 1 }}>
                                ➤
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
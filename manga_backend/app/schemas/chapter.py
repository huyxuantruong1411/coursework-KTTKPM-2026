import uuid
from datetime import datetime
from pydantic import BaseModel, ConfigDict


class ChapterResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    ChapterId: uuid.UUID
    MangaId: uuid.UUID
    Type: str | None = None
    Volume: str | None = None
    ChapterNumber: str | None = None
    Title: str | None = None
    TranslatedLang: str | None = None
    Pages: int | None = None
    PublishAt: datetime | None = None
    CreatedAt: datetime | None = None


class ChapterNav(BaseModel):
    """Returned together with chapter detail for prev/next navigation."""
    current: ChapterResponse
    prev_chapter: ChapterResponse | None = None
    next_chapter: ChapterResponse | None = None
    page_urls: list[str] = []


class ChapterGroupItem(BaseModel):
    chapter_number: str | None = None
    chapters: list[ChapterResponse] = []

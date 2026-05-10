import uuid
from datetime import datetime
from pydantic import BaseModel, ConfigDict


class HistoryCreate(BaseModel):
    MangaId: uuid.UUID
    ChapterId: uuid.UUID
    LastPageRead: int | None = None


class HistoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    HistoryId: uuid.UUID
    MangaId: uuid.UUID
    ChapterId: uuid.UUID
    LastPageRead: int | None = None
    ReadAt: datetime | None = None
    manga_title: str | None = None
    chapter_number: str | None = None
    cover_url: str | None = None


class HistoryGroup(BaseModel):
    label: str
    items: list[HistoryResponse] = []

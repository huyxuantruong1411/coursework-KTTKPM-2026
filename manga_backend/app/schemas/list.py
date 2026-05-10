import uuid
from datetime import datetime
from pydantic import BaseModel, ConfigDict


class ListCreate(BaseModel):
    Name: str
    Description: str | None = ""
    Visibility: str = "private"  # private | public


class ListUpdate(BaseModel):
    Name: str | None = None
    Description: str | None = None
    Visibility: str | None = None


class ListBrief(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    ListId: uuid.UUID
    Name: str | None = None
    Slug: str | None = None
    Description: str | None = None
    Visibility: str = "private"
    ItemCount: int = 0
    FollowerCount: int = 0
    UpdatedAt: datetime | None = None
    contains: bool | None = None  # whether list contains a specific manga
    cover_url: str | None = None  # cover of first manga in the list


class ListMangaItem(BaseModel):
    manga_id: uuid.UUID
    title: str | None = None
    position: int = 0
    cover_url: str | None = None
    status: str | None = None
    year: int | None = None
    content_rating: str | None = None


class ListDetailResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    ListId: uuid.UUID
    Name: str | None = None
    Description: str | None = None
    Slug: str | None = None
    Visibility: str = "private"
    owner_id: uuid.UUID
    owner_username: str | None = None
    ItemCount: int = 0
    FollowerCount: int = 0
    items: list[ListMangaItem] = []
    is_following: bool = False
    cover_url: str | None = None  # cover of first manga


class PublicListItem(BaseModel):
    ListId: uuid.UUID
    Name: str | None = None
    Description: str | None = None
    Slug: str | None = None
    Visibility: str = "public"
    ItemCount: int = 0
    FollowerCount: int = 0
    UpdatedAt: datetime | None = None
    owner_username: str | None = None
    owner_id: uuid.UUID | None = None
    is_following: bool = False
    cover_url: str | None = None

import uuid
from datetime import datetime
from pydantic import BaseModel, ConfigDict


class TagBrief(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    TagId: uuid.UUID
    GroupName: str | None = None
    NameEn: str | None = None


class AltTitle(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    LangCode: str | None = None
    AltTitle: str | None = None


class Description(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    LangCode: str | None = None
    Description: str | None = None


class LinkOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    Provider: str | None = None
    Url: str | None = None


class StatisticsOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    Follows: int | None = 0
    AverageRating: float | None = 0
    BayesianRating: float | None = 0


class CreatorOut(BaseModel):
    id: uuid.UUID | None = None
    name: str | None = None
    role: str | None = None  # author / artist


class MangaListItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    MangaId: uuid.UUID
    TitleEn: str | None = None
    Status: str | None = None
    Year: int | None = None
    ContentRating: str | None = None
    PublicationDemographic: str | None = None
    cover_url: str | None = None
    stats: StatisticsOut | None = None


class MangaDetailResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    MangaId: uuid.UUID
    Type: str | None = None
    TitleEn: str | None = None
    Status: str | None = None
    Year: int | None = None
    ContentRating: str | None = None
    PublicationDemographic: str | None = None
    OriginalLanguage: str | None = None
    LastChapter: str | None = None
    LastVolume: str | None = None
    CreatedAt: datetime | None = None
    UpdatedAt: datetime | None = None
    cover_url: str | None = None
    stats: StatisticsOut | None = None
    tags: list[TagBrief] = []
    alt_titles: list[AltTitle] = []
    descriptions: list[Description] = []
    links: list[LinkOut] = []
    creators: list[CreatorOut] = []
    available_languages: list[str] = []


class RelatedMangaOut(BaseModel):
    RelatedId: uuid.UUID
    relation_type: str | None = None
    related_label: str | None = None
    title: str | None = None
    cover_url: str | None = None

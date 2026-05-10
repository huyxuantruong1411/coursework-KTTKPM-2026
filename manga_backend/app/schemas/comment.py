import uuid
from datetime import datetime
from pydantic import BaseModel, ConfigDict


class CommentCreate(BaseModel):
    Content: str
    ChapterId: uuid.UUID | None = None
    IsSpoiler: bool = False


class CommentUpdate(BaseModel):
    Content: str


class CommentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    CommentId: uuid.UUID
    UserId: uuid.UUID
    MangaId: uuid.UUID
    Username: str | None = None
    Avatar: str | None = None
    Content: str | None = None
    IsSpoiler: bool = False
    LikeCount: int = 0
    DislikeCount: int = 0
    IsDeleted: bool | None = False
    CreatedAt: datetime | None = None
    UpdatedAt: datetime | None = None


class ReportCreate(BaseModel):
    Reason: str

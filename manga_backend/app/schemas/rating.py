import uuid
from pydantic import BaseModel, ConfigDict


class RatingCreate(BaseModel):
    Score: int  # 1-10


class RatingResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    RatingId: uuid.UUID
    UserId: uuid.UUID
    MangaId: uuid.UUID
    Score: int | None = None

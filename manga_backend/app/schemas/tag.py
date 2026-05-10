import uuid
from pydantic import BaseModel, ConfigDict


class TagResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    TagId: uuid.UUID
    GroupName: str | None = None
    NameEn: str | None = None


class TagGroup(BaseModel):
    group_name: str
    tags: list[TagResponse] = []

import uuid
from datetime import datetime
from pydantic import BaseModel, EmailStr, ConfigDict


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserCreate(BaseModel):
    username: str
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    username: str | None = None
    avatar: str | None = None
    email: EmailStr | None = None
    bio: str | None = None
    display_name: str | None = None
    current_password: str | None = None
    new_password: str | None = None


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    UserId: uuid.UUID
    Username: str
    Email: str
    Avatar: str | None = None
    Role: str
    IsLocked: bool | None = False
    CreatedAt: datetime | None = None
    Bio: str | None = None
    DisplayName: str | None = None
    AvatarObjectKey: str | None = None
    UpdatedAt: datetime | None = None

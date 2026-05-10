from typing import Any
from pydantic import BaseModel


class MessageResponse(BaseModel):
    message: str
    data: Any = None


class PaginatedResponse(BaseModel):
    items: list[Any] = []
    page: int = 1
    per_page: int = 20
    total: int = 0
    total_pages: int = 0

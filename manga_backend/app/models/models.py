"""
SQLAlchemy ORM models – khớp 100% với DB [MangaLibrary] hiện có.
Không dùng create_all(); chỉ map vào các bảng đã tồn tại.
"""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import List as PyList, Optional

from sqlalchemy import (
    String, Text, Boolean, Integer, Float, DateTime,
    ForeignKey, LargeBinary, PrimaryKeyConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.mssql import UNIQUEIDENTIFIER

from app.core.database import Base


# ═══════════════════════════════════════════
#  USER
# ═══════════════════════════════════════════
class User(Base):
    __tablename__ = "User"
    __table_args__ = {"schema": "dbo"}
 
    UserId: Mapped[uuid.UUID] = mapped_column(
        UNIQUEIDENTIFIER, primary_key=True, default=uuid.uuid4
    )
    Username: Mapped[str] = mapped_column(String(100), nullable=False)
    Email: Mapped[str] = mapped_column(String(255), nullable=False, unique=True)
    PasswordHash: Mapped[str] = mapped_column(String(255), nullable=False)
    Avatar: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    Role: Mapped[str] = mapped_column(String(20), nullable=False, default="user")
    IsLocked: Mapped[Optional[bool]] = mapped_column(
        Boolean, nullable=True, default=False
    )
    # ── Xác thực email qua OTP ──
    IsVerified: Mapped[Optional[bool]] = mapped_column(
        Boolean, nullable=True, default=False
    )
    CreatedAt: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True, default=datetime.utcnow
    )
    Bio: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    DisplayName: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    AvatarObjectKey: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    UpdatedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
 
    # relationships
    comments: Mapped[PyList["Comment"]] = relationship(
        back_populates="user", lazy="raise"
    )
    ratings: Mapped[PyList["Rating"]] = relationship(
        back_populates="user", lazy="raise"
    )
    lists: Mapped[PyList["MangaList"]] = relationship(
        back_populates="user", lazy="raise"
    )
    histories: Mapped[PyList["ReadingHistory"]] = relationship(
        back_populates="user", lazy="raise"
    )
    reports: Mapped[PyList["Report"]] = relationship(
        back_populates="user", lazy="raise"
    )
    reactions: Mapped[PyList["CommentReaction"]] = relationship(
        back_populates="user", lazy="raise"
    )


# ═══════════════════════════════════════════
#  MANGA
# ═══════════════════════════════════════════
class Manga(Base):
    __tablename__ = "Manga"
    __table_args__ = {"schema": "dbo"}

    MangaId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, primary_key=True, default=uuid.uuid4)
    Type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    TitleEn: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    ChapterNumbersResetOnNewVolume: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)
    ContentRating: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    CreatedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    UpdatedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    IsLocked: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)
    LastChapter: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    LastVolume: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    LatestUploadedChapter: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    OriginalLanguage: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)
    PublicationDemographic: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    State: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    Status: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    Year: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    OfficialLinks: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # relationships
    chapters: Mapped[PyList[Chapter]] = relationship(back_populates="manga", lazy="raise")
    comments: Mapped[PyList[Comment]] = relationship(back_populates="manga", lazy="raise")
    ratings: Mapped[PyList[Rating]] = relationship(back_populates="manga", lazy="raise")
    alt_titles: Mapped[PyList[MangaAltTitle]] = relationship(back_populates="manga", lazy="raise")
    descriptions: Mapped[PyList[MangaDescription]] = relationship(back_populates="manga", lazy="raise")
    links: Mapped[PyList[MangaLink]] = relationship(back_populates="manga", lazy="raise")
    stats: Mapped[PyList[MangaStatistics]] = relationship(back_populates="manga", lazy="raise")
    available_languages: Mapped[PyList[MangaAvailableLanguage]] = relationship(back_populates="manga", lazy="raise")
    tags: Mapped[PyList[MangaTag]] = relationship(back_populates="manga", lazy="raise")
    histories: Mapped[PyList[ReadingHistory]] = relationship(back_populates="manga", lazy="raise")


# ═══════════════════════════════════════════
#  CHAPTER
# ═══════════════════════════════════════════
class Chapter(Base):
    __tablename__ = "Chapter"
    __table_args__ = {"schema": "dbo"}

    ChapterId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, primary_key=True, default=uuid.uuid4)
    MangaId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.Manga.MangaId"), nullable=False)
    Type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    Volume: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    ChapterNumber: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    Title: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    TranslatedLang: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)
    Pages: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    PublishAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    ReadableAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    IsUnavailable: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)
    CreatedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    UpdatedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    manga: Mapped[Manga] = relationship(back_populates="chapters")
    comments: Mapped[PyList[Comment]] = relationship(back_populates="chapter", lazy="raise")
    histories: Mapped[PyList[ReadingHistory]] = relationship(back_populates="chapter", lazy="raise")


# ═══════════════════════════════════════════
#  COMMENT
# ═══════════════════════════════════════════
class Comment(Base):
    __tablename__ = "Comment"
    __table_args__ = {"schema": "dbo"}

    CommentId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, primary_key=True, default=uuid.uuid4)
    UserId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.User.UserId"), nullable=False)
    MangaId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.Manga.MangaId"), nullable=False)
    ChapterId: Mapped[Optional[uuid.UUID]] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.Chapter.ChapterId"), nullable=True)
    Content: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    CreatedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True, default=datetime.utcnow)
    UpdatedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True, default=datetime.utcnow)
    IsDeleted: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True, default=False)
    IsSpoiler: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    LikeCount: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    DislikeCount: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    user: Mapped[User] = relationship(back_populates="comments")
    manga: Mapped[Manga] = relationship(back_populates="comments")
    chapter: Mapped[Optional[Chapter]] = relationship(back_populates="comments")
    reports: Mapped[PyList[Report]] = relationship(back_populates="comment", lazy="raise")
    reactions: Mapped[PyList[CommentReaction]] = relationship(back_populates="comment", lazy="raise")


# ═══════════════════════════════════════════
#  COMMENT REACTION
# ═══════════════════════════════════════════
class CommentReaction(Base):
    __tablename__ = "CommentReaction"
    __table_args__ = {"schema": "dbo"}

    ReactionId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, primary_key=True, default=uuid.uuid4)
    CommentId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.Comment.CommentId"), nullable=False)
    UserId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.User.UserId"), nullable=False)
    Type: Mapped[str] = mapped_column(String(10), nullable=False)
    CreatedAt: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)

    comment: Mapped[Comment] = relationship(back_populates="reactions")
    user: Mapped[User] = relationship(back_populates="reactions")


# ═══════════════════════════════════════════
#  CREATOR
# ═══════════════════════════════════════════
class Creator(Base):
    __tablename__ = "Creator"
    __table_args__ = {"schema": "dbo"}

    CreatorId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, primary_key=True, default=uuid.uuid4)
    Type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    Name: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    ImageUrl: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    BiographyEn: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    BiographyJa: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    BiographyPtBr: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    CreatedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    UpdatedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    creator_relationships: Mapped[PyList[CreatorRelationship]] = relationship(back_populates="creator", lazy="raise")


class CreatorRelationship(Base):
    __tablename__ = "CreatorRelationship"
    __table_args__ = {"schema": "dbo"}

    Id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    CreatorId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.Creator.CreatorId"), nullable=False)
    RelatedId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, nullable=False)
    RelatedType: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    creator: Mapped[Creator] = relationship(back_populates="creator_relationships")


# ═══════════════════════════════════════════
#  TAG
# ═══════════════════════════════════════════
class Tag(Base):
    __tablename__ = "Tag"
    __table_args__ = {"schema": "dbo"}

    TagId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, primary_key=True, default=uuid.uuid4)
    GroupName: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    NameEn: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)

    mangas: Mapped[PyList[MangaTag]] = relationship(back_populates="tag", lazy="raise")


class MangaTag(Base):
    __tablename__ = "MangaTag"
    __table_args__ = {"schema": "dbo"}

    MangaId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.Manga.MangaId"), primary_key=True)
    TagId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.Tag.TagId"), primary_key=True)

    manga: Mapped[Manga] = relationship(back_populates="tags")
    tag: Mapped[Tag] = relationship(back_populates="mangas")


# ═══════════════════════════════════════════
#  MANGA – BẢNG PHỤ
# ═══════════════════════════════════════════
class MangaAltTitle(Base):
    __tablename__ = "MangaAltTitle"
    __table_args__ = {"schema": "dbo"}

    AltTitleId: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    MangaId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.Manga.MangaId"), nullable=False)
    LangCode: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)
    AltTitle: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    manga: Mapped[Manga] = relationship(back_populates="alt_titles")


class MangaAvailableLanguage(Base):
    __tablename__ = "MangaAvailableLanguage"
    __table_args__ = {"schema": "dbo"}

    LangId: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    MangaId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.Manga.MangaId"), nullable=False)
    LangCode: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)

    manga: Mapped[Manga] = relationship(back_populates="available_languages")


class MangaDescription(Base):
    __tablename__ = "MangaDescription"
    __table_args__ = {"schema": "dbo"}

    DescriptionId: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    MangaId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.Manga.MangaId"), nullable=False)
    LangCode: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)
    Description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    manga: Mapped[Manga] = relationship(back_populates="descriptions")


class MangaLink(Base):
    __tablename__ = "MangaLink"
    __table_args__ = {"schema": "dbo"}

    LinkId: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    MangaId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.Manga.MangaId"), nullable=False)
    Provider: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    Url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    manga: Mapped[Manga] = relationship(back_populates="links")


class MangaStatistics(Base):
    __tablename__ = "MangaStatistics"
    __table_args__ = {"schema": "dbo"}

    StatisticId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, primary_key=True, default=uuid.uuid4)
    MangaId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.Manga.MangaId"), nullable=False)
    Source: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    Follows: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    AverageRating: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    BayesianRating: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    UnavailableChapters: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    FetchedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    manga: Mapped[Manga] = relationship(back_populates="stats")


class MangaRelated(Base):
    __tablename__ = "MangaRelated"
    __table_args__ = {"schema": "dbo"}

    MangaId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.Manga.MangaId"), primary_key=True)
    RelatedId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, primary_key=True)
    Type: Mapped[str] = mapped_column(String(50), primary_key=True, nullable=False)
    Related: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    FetchedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)


# ═══════════════════════════════════════════
#  RATING / HISTORY / REPORT
# ═══════════════════════════════════════════
class Rating(Base):
    __tablename__ = "Rating"
    __table_args__ = {"schema": "dbo"}

    RatingId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, primary_key=True, default=uuid.uuid4)
    UserId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.User.UserId"), nullable=False)
    MangaId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.Manga.MangaId"), nullable=False)
    Score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    user: Mapped[User] = relationship(back_populates="ratings")
    manga: Mapped[Manga] = relationship(back_populates="ratings")


class ReadingHistory(Base):
    __tablename__ = "ReadingHistory"
    __table_args__ = {"schema": "dbo"}

    HistoryId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, primary_key=True, default=uuid.uuid4)
    UserId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.User.UserId"), nullable=False)
    MangaId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.Manga.MangaId"), nullable=False)
    ChapterId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.Chapter.ChapterId"), nullable=False)
    LastPageRead: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    ReadAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    user: Mapped[User] = relationship(back_populates="histories")
    manga: Mapped[Manga] = relationship(back_populates="histories")
    chapter: Mapped[Chapter] = relationship(back_populates="histories")


class Report(Base):
    __tablename__ = "Report"
    __table_args__ = {"schema": "dbo"}

    ReportId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, primary_key=True, default=uuid.uuid4)
    UserId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.User.UserId"), nullable=False)
    CommentId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.Comment.CommentId"), nullable=False)
    Reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    Status: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    CreatedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    user: Mapped[User] = relationship(back_populates="reports")
    comment: Mapped[Comment] = relationship(back_populates="reports")


# ═══════════════════════════════════════════
#  LIST (MDList)
# ═══════════════════════════════════════════
class MangaList(Base):
    """Tên model = MangaList để tránh xung đột với typing.List"""
    __tablename__ = "List"
    __table_args__ = {"schema": "dbo"}

    ListId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, primary_key=True, default=uuid.uuid4)
    UserId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.User.UserId"), nullable=False)
    Name: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    Description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    IsPublic: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True)
    Slug: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    Visibility: Mapped[str] = mapped_column(String(20), nullable=False, default="private")
    CreatedAt: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    UpdatedAt: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    FollowerCount: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    ItemCount: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    user: Mapped[User] = relationship(back_populates="lists")
    mangas: Mapped[PyList[ListManga]] = relationship(back_populates="list_obj", cascade="all, delete-orphan", lazy="raise")
    followers: Mapped[PyList[ListFollower]] = relationship(back_populates="list_obj", cascade="all, delete-orphan", lazy="raise")


class ListManga(Base):
    __tablename__ = "ListManga"
    __table_args__ = {"schema": "dbo"}

    ListId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.List.ListId"), primary_key=True)
    MangaId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.Manga.MangaId"), primary_key=True)
    AddedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    Position: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    list_obj: Mapped[MangaList] = relationship(back_populates="mangas")
    manga: Mapped[Manga] = relationship()


class ListFollower(Base):
    __tablename__ = "ListFollower"
    __table_args__ = (
        PrimaryKeyConstraint("ListId", "UserId", name="PK_ListFollower"),
        {"schema": "dbo"},
    )

    ListId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.List.ListId"))
    UserId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.User.UserId"))
    FollowedAt: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)

    list_obj: Mapped[MangaList] = relationship(back_populates="followers")
    user: Mapped[User] = relationship()


# ═══════════════════════════════════════════
#  COVER  (Bảng duy nhất cho cover – MinIO URLs)
# ═══════════════════════════════════════════
class Cover(Base):
    __tablename__ = "Covers"
    __table_args__ = {"schema": "dbo"}

    cover_id: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, primary_key=True, default=uuid.uuid4)
    manga_id: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, nullable=False)
    type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    volume: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    fileName: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    locale: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)
    createdAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    updatedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    version: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    rel_user_id: Mapped[Optional[uuid.UUID]] = mapped_column(UNIQUEIDENTIFIER, nullable=True)
    url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    image_data: Mapped[Optional[bytes]] = mapped_column(LargeBinary, nullable=True)


# ═══════════════════════════════════════════
#  CHAT ROOM
# ═══════════════════════════════════════════
class ChatRoom(Base):
    __tablename__ = "ChatRoom"
    __table_args__ = {"schema": "dbo"}

    RoomId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, primary_key=True, default=uuid.uuid4)
    Type: Mapped[str] = mapped_column(String(20), nullable=False, default="direct")
    Name: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    AvatarUrl: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    CreatedBy: Mapped[Optional[uuid.UUID]] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.User.UserId"), nullable=True)
    CreatedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True, default=datetime.utcnow)
    UpdatedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True, default=datetime.utcnow)

    members: Mapped[PyList["ChatRoomMember"]] = relationship(back_populates="room", lazy="raise")
    messages: Mapped[PyList["ChatMessage"]] = relationship(back_populates="room", lazy="raise")


class ChatRoomMember(Base):
    __tablename__ = "ChatRoomMember"
    __table_args__ = {"schema": "dbo"}

    RoomId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.ChatRoom.RoomId"), primary_key=True)
    UserId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.User.UserId"), primary_key=True)
    JoinedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True, default=datetime.utcnow)
    Role: Mapped[str] = mapped_column(String(20), nullable=False, default="member")
    LastReadAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    Nickname: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    IsMuted: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True, default=False)

    room: Mapped["ChatRoom"] = relationship(back_populates="members", lazy="raise")


class ChatMessage(Base):
    __tablename__ = "ChatMessage"
    __table_args__ = {"schema": "dbo"}

    MessageId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, primary_key=True, default=uuid.uuid4)
    RoomId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.ChatRoom.RoomId"), nullable=False)
    SenderId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.User.UserId"), nullable=False)
    Content: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    MessageType: Mapped[str] = mapped_column(String(20), nullable=False, default="text")
    MediaUrl: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    ReplyToId: Mapped[Optional[uuid.UUID]] = mapped_column(UNIQUEIDENTIFIER, nullable=True)
    Status: Mapped[str] = mapped_column(String(20), nullable=False, default="sent")
    CreatedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True, default=datetime.utcnow)
    EditedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    IsDeleted: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True, default=False)

    room: Mapped["ChatRoom"] = relationship(back_populates="messages", lazy="raise")


# ═══════════════════════════════════════════
#  FRIENDSHIP
# ═══════════════════════════════════════════
class Friendship(Base):
    __tablename__ = "Friendship"
    __table_args__ = {"schema": "dbo"}

    UserId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.User.UserId"), primary_key=True)
    FriendId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.User.UserId"), primary_key=True)
    Status: Mapped[str] = mapped_column(String(20), nullable=False, default="pending")
    CreatedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True, default=datetime.utcnow)


# ═══════════════════════════════════════════
#  USER PRESENCE
# ═══════════════════════════════════════════
class UserPresence(Base):
    __tablename__ = "UserPresence"
    __table_args__ = {"schema": "dbo"}

    UserId: Mapped[uuid.UUID] = mapped_column(UNIQUEIDENTIFIER, ForeignKey("dbo.User.UserId"), primary_key=True)
    IsOnline: Mapped[Optional[bool]] = mapped_column(Boolean, nullable=True, default=False)
    LastSeenAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True, default=datetime.utcnow)
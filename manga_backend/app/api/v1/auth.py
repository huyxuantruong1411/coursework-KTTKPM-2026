"""Authentication & User Profile API."""
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from fastapi.security import OAuth2PasswordRequestForm

from app.core.database import get_db
from app.core.security import verify_password, get_password_hash, create_access_token
from app.api.dependencies import get_current_user
from app.models.models import User
from app.schemas.auth import UserCreate, Token, UserResponse, UserUpdate
from app.services.minio_service import minio_service

router = APIRouter()


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(user_in: UserCreate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.Email == user_in.email))
    if result.scalars().first():
        raise HTTPException(status_code=400, detail="Email already registered")

    result2 = await db.execute(select(User).where(User.Username == user_in.username))
    if result2.scalars().first():
        raise HTTPException(status_code=400, detail="Username already taken")

    new_user = User(
        Username=user_in.username,
        Email=user_in.email,
        PasswordHash=get_password_hash(user_in.password),
        Role="user",
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    return new_user


@router.post("/login", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.Username == form_data.username))
    user = result.scalars().first()
    if not user or not verify_password(form_data.password, user.PasswordHash):
        raise HTTPException(status_code=400, detail="Incorrect username or password")
    if user.IsLocked:
        raise HTTPException(status_code=403, detail="Account is locked")

    access_token = create_access_token(data={"sub": str(user.UserId)})
    return {"access_token": access_token, "token_type": "bearer"}


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    """Get current user profile with avatar URL resolved."""
    avatar_url = current_user.Avatar
    if current_user.AvatarObjectKey:
        presigned = await minio_service.get_presigned_url(current_user.AvatarObjectKey)
        if presigned:
            avatar_url = presigned
    # Temporarily set the avatar for response serialization
    current_user.Avatar = avatar_url
    return current_user


@router.put("/me", response_model=UserResponse)
async def update_me(
    update: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update user profile: username, email, bio, display name, password."""
    if update.username is not None:
        dup = await db.execute(
            select(User).where(User.Username == update.username, User.UserId != current_user.UserId)
        )
        if dup.scalars().first():
            raise HTTPException(status_code=400, detail="Username already taken")
        current_user.Username = update.username

    if update.email is not None:
        dup = await db.execute(
            select(User).where(User.Email == update.email, User.UserId != current_user.UserId)
        )
        if dup.scalars().first():
            raise HTTPException(status_code=400, detail="Email already in use")
        current_user.Email = update.email

    if update.bio is not None:
        current_user.Bio = update.bio[:500]  # Max 500 chars

    if update.display_name is not None:
        current_user.DisplayName = update.display_name[:100]

    if update.avatar is not None:
        current_user.Avatar = update.avatar

    # Password change
    if update.new_password:
        if not update.current_password:
            raise HTTPException(status_code=400, detail="Current password required to change password")
        if not verify_password(update.current_password, current_user.PasswordHash):
            raise HTTPException(status_code=400, detail="Current password is incorrect")
        if len(update.new_password) < 6:
            raise HTTPException(status_code=400, detail="New password must be at least 6 characters")
        current_user.PasswordHash = get_password_hash(update.new_password)

    current_user.UpdatedAt = datetime.utcnow()
    await db.commit()
    await db.refresh(current_user)

    # Resolve avatar URL for response
    if current_user.AvatarObjectKey:
        presigned = await minio_service.get_presigned_url(current_user.AvatarObjectKey)
        if presigned:
            current_user.Avatar = presigned

    return current_user


@router.post("/me/avatar")
async def upload_avatar(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload avatar image to MinIO and update user profile."""
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only image files are allowed")

    # Max 5MB
    content = await file.read()
    if len(content) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large (max 5MB)")

    ext = file.filename.rsplit(".", 1)[-1] if file.filename and "." in file.filename else "jpg"
    object_key = f"avatars/{current_user.UserId}.{ext}"

    # Upload to MinIO
    await minio_service.upload_bytes(content, object_key, file.content_type)

    # Update user record
    current_user.AvatarObjectKey = object_key
    current_user.UpdatedAt = datetime.utcnow()

    # Also set Avatar to a URL for backward compatibility
    presigned = await minio_service.get_presigned_url(object_key)
    if presigned:
        current_user.Avatar = presigned

    await db.commit()
    await db.refresh(current_user)

    return {"success": True, "avatar_url": presigned or object_key}
"""Friends API – send/accept/reject/block friend requests, list friends."""
import uuid
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_, and_, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.models import Friendship, User, UserPresence

router = APIRouter()


async def _user_info(user_id: uuid.UUID, db: AsyncSession) -> dict | None:
    """Helper: get basic user info."""
    r = await db.execute(
        select(User.UserId, User.Username, User.Avatar, User.DisplayName)
        .where(User.UserId == user_id)
    )
    row = r.first()
    if not row:
        return None
    # Check online status
    presence_r = await db.execute(
        select(UserPresence.IsOnline, UserPresence.LastSeenAt)
        .where(UserPresence.UserId == user_id)
    )
    presence = presence_r.first()
    return {
        "user_id": str(row.UserId),
        "username": row.Username,
        "avatar": row.Avatar,
        "display_name": row.DisplayName,
        "is_online": bool(presence.IsOnline) if presence else False,
        "last_seen": presence.LastSeenAt.isoformat() if presence and presence.LastSeenAt else None,
    }


@router.get("/")
async def list_friends(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List accepted friends."""
    result = await db.execute(
        select(Friendship).where(
            or_(
                Friendship.UserId == current_user.UserId,
                Friendship.FriendId == current_user.UserId,
            ),
            Friendship.Status == "accepted",
        )
    )
    friendships = result.scalars().all()

    friends = []
    for f in friendships:
        friend_id = f.FriendId if f.UserId == current_user.UserId else f.UserId
        info = await _user_info(friend_id, db)
        if info:
            friends.append(info)

    return {"friends": friends}


@router.get("/requests")
async def list_requests(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List pending friend requests (received)."""
    result = await db.execute(
        select(Friendship).where(
            Friendship.FriendId == current_user.UserId,
            Friendship.Status == "pending",
        )
    )
    requests = result.scalars().all()

    items = []
    for f in requests:
        info = await _user_info(f.UserId, db)
        if info:
            info["requested_at"] = f.CreatedAt.isoformat() if f.CreatedAt else None
            items.append(info)

    return {"requests": items}


@router.post("/request/{user_id}")
async def send_request(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Send a friend request."""
    if user_id == current_user.UserId:
        raise HTTPException(status_code=400, detail="Cannot friend yourself")

    # Check if already exists
    existing = await db.execute(
        select(Friendship).where(
            or_(
                and_(Friendship.UserId == current_user.UserId, Friendship.FriendId == user_id),
                and_(Friendship.UserId == user_id, Friendship.FriendId == current_user.UserId),
            )
        )
    )
    f = existing.scalars().first()
    if f:
        if f.Status == "blocked":
            raise HTTPException(status_code=403, detail="User is blocked")
        if f.Status == "accepted":
            return {"message": "Already friends"}
        if f.Status == "pending":
            return {"message": "Request already pending"}

    db.add(Friendship(
        UserId=current_user.UserId, FriendId=user_id, Status="pending",
    ))
    await db.commit()
    return {"success": True, "message": "Friend request sent"}


@router.post("/accept/{user_id}")
async def accept_request(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Accept a friend request."""
    result = await db.execute(
        select(Friendship).where(
            Friendship.UserId == user_id,
            Friendship.FriendId == current_user.UserId,
            Friendship.Status == "pending",
        )
    )
    f = result.scalars().first()
    if not f:
        raise HTTPException(status_code=404, detail="No pending request from this user")

    f.Status = "accepted"
    await db.commit()
    return {"success": True, "message": "Friend request accepted"}


@router.post("/reject/{user_id}")
async def reject_request(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Reject a friend request."""
    result = await db.execute(
        select(Friendship).where(
            Friendship.UserId == user_id,
            Friendship.FriendId == current_user.UserId,
            Friendship.Status == "pending",
        )
    )
    f = result.scalars().first()
    if not f:
        raise HTTPException(status_code=404)

    await db.delete(f)
    await db.commit()
    return {"success": True}


@router.post("/block/{user_id}")
async def block_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Block a user."""
    existing = await db.execute(
        select(Friendship).where(
            or_(
                and_(Friendship.UserId == current_user.UserId, Friendship.FriendId == user_id),
                and_(Friendship.UserId == user_id, Friendship.FriendId == current_user.UserId),
            )
        )
    )
    f = existing.scalars().first()
    if f:
        f.Status = "blocked"
        # Ensure the blocker is the UserId side
        f.UserId = current_user.UserId
        f.FriendId = user_id
    else:
        db.add(Friendship(
            UserId=current_user.UserId, FriendId=user_id, Status="blocked",
        ))
    await db.commit()
    return {"success": True}


@router.get("/search")
async def search_users(
    q: str = Query(..., min_length=1),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Search users by username or display name."""
    like = f"%{q.strip()}%"
    result = await db.execute(
        select(User)
        .where(
            User.UserId != current_user.UserId,
            or_(User.Username.ilike(like), User.DisplayName.ilike(like)),
        )
        .limit(20)
    )
    users = result.scalars().all()

    items = []
    for u in users:
        info = await _user_info(u.UserId, db)
        if info:
            items.append(info)

    return {"users": items}

# app/api/v1/auth.py
"""Authentication & User Profile API – có OTP đăng ký + OTP quên mật khẩu."""
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from fastapi.security import OAuth2PasswordRequestForm

from app.core.database import get_db
from app.core.security import verify_password, get_password_hash, create_access_token
from app.api.dependencies import get_current_user
from app.models.models import User
from app.schemas.auth import (
    UserCreate, Token, UserResponse, UserUpdate,
    ForgotPasswordRequest, VerifyResetOtpRequest, ResetPasswordRequest,
    VerifyEmailRequest, ResendVerifyEmailRequest, MessageResponse,
)
from app.services.minio_service import minio_service
from app.services.email_service import email_service
from app.services.otp_service import otp_service

router = APIRouter()


# ═══════════════════════════════════════════════════════════════
#  ĐĂNG KÝ – gửi OTP xác thực email
# ═══════════════════════════════════════════════════════════════

@router.post("/register", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
async def register(
    user_in: UserCreate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    """
    Tạo tài khoản mới (IsVerified = False) và gửi OTP xác thực đến email.
    Tài khoản chỉ có thể đăng nhập sau khi xác thực email.
    """
    # Kiểm tra email trùng
    result = await db.execute(select(User).where(User.Email == user_in.email))
    existing_email = result.scalars().first()
    if existing_email:
        if existing_email.IsVerified:
            raise HTTPException(status_code=400, detail="Email đã được đăng ký.")
        # Tài khoản tồn tại nhưng chưa xác thực → gửi lại OTP
        otp = otp_service.set_otp(user_in.email)
        background_tasks.add_task(email_service.send_otp, user_in.email, otp, True)
        return MessageResponse(message=f"Email đã đăng ký nhưng chưa xác thực. Đã gửi lại mã OTP đến {user_in.email}.")

    # Kiểm tra username trùng
    result2 = await db.execute(select(User).where(User.Username == user_in.username))
    if result2.scalars().first():
        raise HTTPException(status_code=400, detail="Tên đăng nhập đã được sử dụng.")

    # Tạo user với IsVerified = False
    new_user = User(
        Username=user_in.username,
        Email=user_in.email,
        PasswordHash=get_password_hash(user_in.password),
        Role="user",
        IsVerified=False,
    )
    db.add(new_user)
    await db.commit()

    # Gửi OTP xác thực
    otp = otp_service.set_otp(user_in.email)
    background_tasks.add_task(email_service.send_otp, user_in.email, otp, True)

    return MessageResponse(message=f"Đăng ký thành công! Vui lòng kiểm tra email {user_in.email} để lấy mã xác thực.")


# ═══════════════════════════════════════════════════════════════
#  XÁC THỰC EMAIL – sau đăng ký
# ═══════════════════════════════════════════════════════════════

@router.post("/verify-email", response_model=MessageResponse)
async def verify_email(
    payload: VerifyEmailRequest,
    db: AsyncSession = Depends(get_db),
):
    """Xác thực email bằng OTP đã gửi sau khi đăng ký."""
    if not otp_service.verify_otp(payload.email, payload.otp):
        raise HTTPException(status_code=400, detail="Mã OTP không hợp lệ hoặc đã hết hạn.")

    result = await db.execute(select(User).where(User.Email == payload.email))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy tài khoản.")

    user.IsVerified = True
    user.UpdatedAt = datetime.utcnow()
    await db.commit()
    otp_service.delete_otp(payload.email)

    return MessageResponse(message="Xác thực email thành công! Bạn có thể đăng nhập.")


@router.post("/resend-verify-email", response_model=MessageResponse)
async def resend_verify_email(
    payload: ResendVerifyEmailRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    """Gửi lại OTP xác thực email (dành cho tài khoản chưa xác thực)."""
    result = await db.execute(select(User).where(User.Email == payload.email))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy tài khoản với email này.")
    if user.IsVerified:
        raise HTTPException(status_code=400, detail="Email này đã được xác thực rồi.")

    otp = otp_service.set_otp(payload.email)
    background_tasks.add_task(email_service.send_otp, payload.email, otp, True)
    return MessageResponse(message=f"Đã gửi lại mã OTP đến {payload.email}.")


# ═══════════════════════════════════════════════════════════════
#  ĐĂNG NHẬP
# ═══════════════════════════════════════════════════════════════

@router.post("/login", response_model=Token)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.Username == form_data.username))
    user = result.scalars().first()
    if not user or not verify_password(form_data.password, user.PasswordHash):
        raise HTTPException(status_code=400, detail="Tên đăng nhập hoặc mật khẩu không đúng.")
    if user.IsLocked:
        raise HTTPException(status_code=403, detail="Tài khoản đã bị khoá.")
    if not user.IsVerified:
        raise HTTPException(
            status_code=403,
            detail="Email chưa được xác thực. Vui lòng kiểm tra hộp thư và nhập mã OTP.",
        )

    access_token = create_access_token(data={"sub": str(user.UserId)})
    return {"access_token": access_token, "token_type": "bearer"}


# ═══════════════════════════════════════════════════════════════
#  PROFILE – GET / PUT / UPLOAD AVATAR
# ═══════════════════════════════════════════════════════════════

@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    """Lấy thông tin user hiện tại (có avatar URL từ MinIO)."""
    avatar_url = current_user.Avatar
    if current_user.AvatarObjectKey:
        presigned = await minio_service.get_presigned_url(current_user.AvatarObjectKey)
        if presigned:
            avatar_url = presigned
    current_user.Avatar = avatar_url
    return current_user


@router.put("/me", response_model=UserResponse)
async def update_me(
    update: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if update.username is not None:
        dup = await db.execute(
            select(User).where(User.Username == update.username, User.UserId != current_user.UserId)
        )
        if dup.scalars().first():
            raise HTTPException(status_code=400, detail="Tên đăng nhập đã được sử dụng.")
        current_user.Username = update.username

    if update.email is not None:
        dup = await db.execute(
            select(User).where(User.Email == update.email, User.UserId != current_user.UserId)
        )
        if dup.scalars().first():
            raise HTTPException(status_code=400, detail="Email đã được sử dụng.")
        current_user.Email = update.email

    if update.bio is not None:
        current_user.Bio = update.bio[:500]

    if update.display_name is not None:
        current_user.DisplayName = update.display_name[:100]

    if update.avatar is not None:
        current_user.Avatar = update.avatar

    if update.new_password:
        if not update.current_password:
            raise HTTPException(status_code=400, detail="Cần nhập mật khẩu hiện tại để đổi mật khẩu.")
        if not verify_password(update.current_password, current_user.PasswordHash):
            raise HTTPException(status_code=400, detail="Mật khẩu hiện tại không đúng.")
        if len(update.new_password) < 6:
            raise HTTPException(status_code=400, detail="Mật khẩu mới phải từ 6 ký tự.")
        current_user.PasswordHash = get_password_hash(update.new_password)

    current_user.UpdatedAt = datetime.utcnow()
    await db.commit()
    await db.refresh(current_user)

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
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Chỉ chấp nhận file ảnh.")

    content = await file.read()
    if len(content) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File quá lớn (tối đa 5MB).")

    ext = file.filename.rsplit(".", 1)[-1] if file.filename and "." in file.filename else "jpg"
    object_key = f"avatars/{current_user.UserId}.{ext}"

    await minio_service.upload_bytes(content, object_key, file.content_type)
    current_user.AvatarObjectKey = object_key
    current_user.UpdatedAt = datetime.utcnow()

    presigned = await minio_service.get_presigned_url(object_key)
    if presigned:
        current_user.Avatar = presigned

    await db.commit()
    await db.refresh(current_user)
    return {"success": True, "avatar_url": presigned or object_key}


# ═══════════════════════════════════════════════════════════════
#  OTP – QUÊN MẬT KHẨU
# ═══════════════════════════════════════════════════════════════

@router.post("/forgot-password", response_model=MessageResponse)
async def forgot_password(
    payload: ForgotPasswordRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    """Gửi OTP đặt lại mật khẩu đến email đã đăng ký."""
    result = await db.execute(select(User).where(User.Email == payload.email))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy tài khoản với email này.")

    otp = otp_service.set_otp(payload.email)
    background_tasks.add_task(email_service.send_otp, payload.email, otp, False)
    return MessageResponse(message=f"Đã gửi mã OTP đến {payload.email}.")


@router.post("/verify-reset-otp", response_model=MessageResponse)
async def verify_reset_otp(payload: VerifyResetOtpRequest):
    """Xác thực OTP quên mật khẩu (không xoá OTP để dùng ở bước reset)."""
    if not otp_service.verify_otp(payload.email, payload.otp):
        raise HTTPException(status_code=400, detail="Mã OTP không hợp lệ hoặc đã hết hạn.")
    return MessageResponse(message="Mã OTP hợp lệ.")


@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(
    payload: ResetPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    """Đặt lại mật khẩu mới sau khi xác thực OTP."""
    if not otp_service.verify_otp(payload.email, payload.otp):
        raise HTTPException(status_code=400, detail="Mã OTP không hợp lệ hoặc đã hết hạn.")

    result = await db.execute(select(User).where(User.Email == payload.email))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy tài khoản.")

    if len(payload.new_password) < 6:
        raise HTTPException(status_code=400, detail="Mật khẩu mới phải từ 6 ký tự.")

    user.PasswordHash = get_password_hash(payload.new_password)
    user.UpdatedAt = datetime.utcnow()
    await db.commit()
    otp_service.delete_otp(payload.email)

    return MessageResponse(message="Đổi mật khẩu thành công! Vui lòng đăng nhập lại.")
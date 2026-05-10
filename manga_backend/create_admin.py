import asyncio
import uuid
from app.core.database import AsyncSessionLocal
from app.models.models import User
from app.core.security import get_password_hash

async def main():
    async with AsyncSessionLocal() as db:
        admin_id = uuid.uuid4()
        admin_username = "admin"
        admin_password = "password123"
        hashed_password = get_password_hash(admin_password)

        new_admin = User(
            UserId=admin_id,
            Username=admin_username,
            Email="admin@mangalibrary.local",
            PasswordHash=hashed_password,
            Role="admin"
        )
        db.add(new_admin)
        await db.commit()
        print(f"✅ Admin account created successfully!")
        print(f"Username: {admin_username}")
        print(f"Password: {admin_password}")

if __name__ == "__main__":
    asyncio.run(main())

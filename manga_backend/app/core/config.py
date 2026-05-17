from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    DATABASE_URL: str
    SECRET_KEY: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080

    MINIO_ENDPOINT: str = "localhost:9000"
    MINIO_ACCESS_KEY: str = "admin"
    MINIO_SECRET_KEY: str = "password"
    MINIO_BUCKET: str = "manga-media"
    MINIO_USE_SSL: bool = False

    # Thêm cấu hình SMTP để gửi mail OTP
    SMTP_SERVER: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_ACCOUNT: str = "xuanhuy10ad3@gmail.com" # Thay bằng email thực tế của bạn
    SMTP_PASSWORD: str = "uctghzoztwckxkyy" # Thay bằng app password của bạn

    class Config:
        env_file = ".env"

settings = Settings()
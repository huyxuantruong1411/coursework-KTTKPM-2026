from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str
    SECRET_KEY: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080  # 7 days

    MINIO_ENDPOINT: str = "localhost:9000"
    MINIO_ACCESS_KEY: str = "admin"
    MINIO_SECRET_KEY: str = "password"
    MINIO_BUCKET: str = "manga-media"
    MINIO_USE_SSL: bool = False

    class Config:
        env_file = ".env"


settings = Settings()
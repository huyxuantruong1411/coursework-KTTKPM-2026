"""MinIO service – upload, presigned URLs, list chapter pages."""
import aioboto3
from uuid import uuid4
from app.core.config import settings

session = aioboto3.Session()


class MinioService:

    def _client(self):
        return session.client(
            "s3",
            endpoint_url=f"{'https' if settings.MINIO_USE_SSL else 'http'}://{settings.MINIO_ENDPOINT}",
            aws_access_key_id=settings.MINIO_ACCESS_KEY,
            aws_secret_access_key=settings.MINIO_SECRET_KEY,
        )

    async def ensure_bucket(self):
        """Create bucket if it doesn't exist."""
        async with self._client() as s3:
            try:
                await s3.head_bucket(Bucket=settings.MINIO_BUCKET)
            except Exception:
                await s3.create_bucket(Bucket=settings.MINIO_BUCKET)

    async def upload_file(self, file, folder: str) -> dict:
        """Upload an UploadFile to MinIO, return object info."""
        ext = file.filename.rsplit(".", 1)[-1] if "." in file.filename else "jpg"
        filename = f"{uuid4()}.{ext}"
        object_name = f"{folder}/{filename}"

        async with self._client() as s3:
            await s3.upload_fileobj(file.file, settings.MINIO_BUCKET, object_name)
            url = await s3.generate_presigned_url(
                "get_object",
                Params={"Bucket": settings.MINIO_BUCKET, "Key": object_name},
                ExpiresIn=86400,
            )
        return {"filename": filename, "object_name": object_name, "url": url}

    async def upload_bytes(self, data: bytes, object_name: str, content_type: str = "image/jpeg") -> str:
        """Upload raw bytes to MinIO. Returns the object key."""
        from io import BytesIO
        async with self._client() as s3:
            await s3.upload_fileobj(
                BytesIO(data), settings.MINIO_BUCKET, object_name,
                ExtraArgs={"ContentType": content_type},
            )
        return object_name

    async def get_presigned_url(self, object_name: str, expires: int = 86400) -> str:
        """Generate a presigned GET URL for an object."""
        async with self._client() as s3:
            return await s3.generate_presigned_url(
                "get_object",
                Params={"Bucket": settings.MINIO_BUCKET, "Key": object_name},
                ExpiresIn=expires,
            )

    async def list_chapter_pages(self, chapter_id: str) -> list[str]:
        """List all page image URLs for a chapter from MinIO."""
        prefix = f"chapters/{chapter_id}/"
        urls = []
        async with self._client() as s3:
            try:
                response = await s3.list_objects_v2(Bucket=settings.MINIO_BUCKET, Prefix=prefix)
                contents = response.get("Contents", [])
                # Sort by key (page order)
                contents.sort(key=lambda x: x["Key"])
                for obj in contents:
                    url = await s3.generate_presigned_url(
                        "get_object",
                        Params={"Bucket": settings.MINIO_BUCKET, "Key": obj["Key"]},
                        ExpiresIn=86400,
                    )
                    urls.append(url)
            except Exception:
                pass
        return urls

    async def delete_object(self, object_name: str):
        """Delete an object from MinIO."""
        async with self._client() as s3:
            await s3.delete_object(Bucket=settings.MINIO_BUCKET, Key=object_name)


minio_service = MinioService()
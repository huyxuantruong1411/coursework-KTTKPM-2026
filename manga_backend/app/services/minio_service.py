"""MinIO service – upload, presigned URLs, list chapter pages."""

import logging
from uuid import uuid4

import aioboto3

from app.core.config import settings

session = aioboto3.Session()
logger = logging.getLogger(__name__)


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
                logger.info("[minio] Bucket exists: %s", settings.MINIO_BUCKET)
            except Exception:
                logger.warning("[minio] Bucket missing. Creating bucket: %s", settings.MINIO_BUCKET)
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
                Params={
                    "Bucket": settings.MINIO_BUCKET,
                    "Key": object_name,
                },
                ExpiresIn=86400,
            )

        return {
            "filename": filename,
            "object_name": object_name,
            "url": url,
        }

    async def upload_bytes(
        self,
        data: bytes,
        object_name: str,
        content_type: str = "image/jpeg",
    ) -> str:
        """Upload raw bytes to MinIO. Returns object key."""

        from io import BytesIO

        async with self._client() as s3:
            await s3.upload_fileobj(
                BytesIO(data),
                settings.MINIO_BUCKET,
                object_name,
                ExtraArgs={"ContentType": content_type},
            )

        logger.info("[minio] Uploaded object: %s", object_name)
        return object_name

    async def get_presigned_url(
        self,
        object_name: str,
        expires: int = 86400,
    ) -> str:
        """Generate presigned GET URL for object."""

        async with self._client() as s3:
            return await s3.generate_presigned_url(
                "get_object",
                Params={
                    "Bucket": settings.MINIO_BUCKET,
                    "Key": object_name,
                },
                ExpiresIn=expires,
            )

    async def list_chapter_pages(self, chapter_id: str) -> list[str]:
        """
        List all page image URLs for a chapter from MinIO.

        Expected structure:
            chapters/<chapter_id>/001.jpg
            chapters/<chapter_id>/002.jpg
            ...
        """

        prefix = f"chapters/{chapter_id}/"

        logger.info("[minio] Listing chapter pages with prefix: %s", prefix)

        urls: list[str] = []

        async with self._client() as s3:
            try:
                response = await s3.list_objects_v2(
                    Bucket=settings.MINIO_BUCKET,
                    Prefix=prefix,
                )

                contents = response.get("Contents", [])

                if not contents:
                    logger.warning(
                        "[minio] No objects found for chapter %s",
                        chapter_id,
                    )
                    return []

                # Sort pages by key
                contents.sort(key=lambda x: x["Key"])

                for obj in contents:
                    key = obj["Key"]

                    # Skip directory placeholder
                    if key.endswith("/"):
                        continue

                    try:
                        url = await s3.generate_presigned_url(
                            "get_object",
                            Params={
                                "Bucket": settings.MINIO_BUCKET,
                                "Key": key,
                            },
                            ExpiresIn=86400,
                        )

                        urls.append(url)

                    except Exception as presign_exc:
                        logger.exception(
                            "[minio] Failed generating presigned URL for %s: %s",
                            key,
                            presign_exc,
                        )

                logger.info(
                    "[minio] Generated %s presigned URLs for chapter %s",
                    len(urls),
                    chapter_id,
                )

                return urls

            except Exception as exc:
                logger.exception(
                    "[minio] Failed listing chapter pages for %s: %s",
                    chapter_id,
                    exc,
                )
                return []

    async def delete_object(self, object_name: str):
        """Delete object from MinIO."""

        async with self._client() as s3:
            await s3.delete_object(
                Bucket=settings.MINIO_BUCKET,
                Key=object_name,
            )

        logger.info("[minio] Deleted object: %s", object_name)


minio_service = MinioService()
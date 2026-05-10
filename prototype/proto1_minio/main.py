import io
from fastapi import FastAPI, Response
from minio import Minio
from datetime import timedelta

app = FastAPI()

minio_client = Minio(
    "proto-minio:9000", # Giao tiếp nội bộ Docker
    access_key="admin",
    secret_key="password",
    secure=False
)

BUCKET_NAME = "manga-images"
FILE_NAME = "chapter1_page1.jpg"
DUMMY_DATA = b"x" * (5 * 1024 * 1024)

@app.on_event("startup")
def startup_event():
    if not minio_client.bucket_exists(BUCKET_NAME):
        minio_client.make_bucket(BUCKET_NAME)
        minio_client.put_object(
            BUCKET_NAME, FILE_NAME, 
            data=io.BytesIO(DUMMY_DATA), length=len(DUMMY_DATA)
        )

@app.get("/api/v1/image-direct")
def get_image_direct():
    response = minio_client.get_object(BUCKET_NAME, FILE_NAME)
    data = response.read()
    response.close()
    response.release_conn()
    return Response(content=data, media_type="image/jpeg")

@app.get("/api/v1/image-presigned")
def get_image_presigned():
    url = minio_client.presigned_get_object(
        BUCKET_NAME, FILE_NAME, expires=timedelta(hours=1)
    )
    # Trick: Đổi host nội bộ thành localhost:9011 cho Client bên ngoài truy cập được
    public_url = url.replace("proto-minio:9000", "localhost:9011")
    return {"presigned_url": public_url}
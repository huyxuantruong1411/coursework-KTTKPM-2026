import time
from fastapi import FastAPI
from worker import process_ai_nsfw

app = FastAPI()

@app.post("/upload-sync")
def upload_sync():
    time.sleep(5)
    return {"message": "Upload và kiểm duyệt thành công"}

@app.post("/upload-async")
def upload_async():
    process_ai_nsfw.delay("chapter1_page1.jpg")
    return {"message": "Đã nhận ảnh. Đang xử lý ngầm!"}
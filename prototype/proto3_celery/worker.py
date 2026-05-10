import time
from celery import Celery

celery_app = Celery("tasks", broker="redis://proto-redis-broker:6379/0")

@celery_app.task
def process_ai_nsfw(image_name):
    time.sleep(5)
    return f"Đã kiểm duyệt xong {image_name} - PASS"
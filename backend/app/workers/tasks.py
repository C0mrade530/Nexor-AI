"""Celery tasks for async audio processing.

In MVP, processing is synchronous via API endpoints.
This module is the scaffold for async background processing.
"""

# TODO: Configure Celery with Redis broker
# from celery import Celery
# celery_app = Celery("lifeos", broker=settings.redis_url)

# @celery_app.task
# async def process_session_task(session_id: str, user_id: str):
#     """Background task to process an audio session."""
#     pass

# @celery_app.task
# async def generate_daily_summary_task(user_id: str, date: str):
#     """Background task to generate daily summary."""
#     pass

# @celery_app.task
# async def cleanup_expired_audio_task():
#     """Periodic task to delete audio past retention period."""
#     pass

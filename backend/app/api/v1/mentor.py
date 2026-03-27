"""Mentor chat API — conversational AI mentor with full context awareness."""

from fastapi import APIRouter
from pydantic import BaseModel

from app.services.mentor_chat import mentor_chat_service

router = APIRouter(prefix="/mentor", tags=["mentor"])


class ChatMessageRequest(BaseModel):
    user_id: str = "demo-user"
    message: str = ""
    voice_transcript: str | None = None


@router.post("/chat")
async def send_chat_message(req: ChatMessageRequest):
    """Send a message to the AI mentor and get a response.

    The mentor automatically has context from:
    - Apple Watch (sleep, recovery, strain, HRV)
    - Plaud recordings (meetings, commitments, tasks)
    - Event history, finance data, daily summaries
    """
    return await mentor_chat_service.send_message(
        user_id=req.user_id,
        message=req.message,
        voice_transcript=req.voice_transcript,
    )


@router.get("/history")
async def get_chat_history(
    user_id: str = "demo-user",
    limit: int = 50,
    offset: int = 0,
):
    """Get mentor chat history."""
    return await mentor_chat_service.get_history(user_id, limit=limit, offset=offset)


@router.delete("/history")
async def clear_chat_history(user_id: str = "demo-user"):
    """Clear mentor chat history."""
    return await mentor_chat_service.clear_history(user_id)


@router.get("/insight")
async def get_proactive_insight(user_id: str = "demo-user"):
    """Get a proactive mentor insight based on current data.

    Returns a contextual nudge/observation without user prompt.
    Great for daily cards or notification triggers.
    """
    return await mentor_chat_service.get_proactive_insight(user_id)

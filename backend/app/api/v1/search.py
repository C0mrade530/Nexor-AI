"""Memory search endpoint — semantic search across personal history."""

from fastapi import APIRouter, Query

from app.services.processing import processing_service

router = APIRouter(prefix="/search", tags=["search"])


@router.get("")
async def search_memory(
    q: str = Query(..., description="Natural language query"),
    event_type: str | None = Query(None, description="Filter by event type"),
):
    """Search personal memory with natural language.

    Examples:
    - "What did I discuss with Misha last week?"
    - "My AI SaaS ideas from February"
    - "When did I promise to send the proposal?"
    - "Recurring problems in my meetings"
    """
    filters = {}
    if event_type:
        filters["event_type"] = event_type

    user_id = "demo-user"  # TODO: auth
    answer = await processing_service.search_memory(user_id, q, filters or None)

    return {
        "query": q,
        "answer": answer,
    }

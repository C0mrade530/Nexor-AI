"""Vector memory service — personal knowledge retrieval using ChromaDB."""

import logging
import uuid

import chromadb

from app.core.config import settings

logger = logging.getLogger(__name__)


class MemoryService:
    """Indexes events into vector store for semantic search."""

    def __init__(self):
        self._client: chromadb.ClientAPI | None = None

    @property
    def client(self) -> chromadb.ClientAPI:
        if self._client is None:
            self._client = chromadb.PersistentClient(path=settings.chroma_persist_dir)
        return self._client

    def _get_collection(self, user_id: str) -> chromadb.Collection:
        """Get or create a user-specific collection."""
        return self.client.get_or_create_collection(
            name=f"user_{user_id.replace('-', '_')}",
            metadata={"hnsw:space": "cosine"},
        )

    async def index_event(self, user_id: str, event_id: str, event_data: dict) -> None:
        """Index an event into the user's personal memory."""
        collection = self._get_collection(user_id)

        # Build document text from event fields
        parts = [
            f"Type: {event_data.get('event_type', 'unknown')}",
            f"Title: {event_data.get('title', '')}",
            f"Summary: {event_data.get('summary', '')}",
        ]

        if event_data.get("participants"):
            parts.append(f"Participants: {', '.join(event_data['participants'])}")
        if event_data.get("action_items"):
            items = [item.get("task", "") for item in event_data["action_items"]]
            parts.append(f"Action items: {'; '.join(items)}")
        if event_data.get("ideas"):
            ideas = [idea.get("text", "") for idea in event_data["ideas"]]
            parts.append(f"Ideas: {'; '.join(ideas)}")
        if event_data.get("transcript_excerpt"):
            parts.append(f"Transcript: {event_data['transcript_excerpt'][:500]}")

        document = "\n".join(parts)

        metadata = {
            "event_type": event_data.get("event_type", "unknown"),
            "date": event_data.get("started_at", ""),
            "importance": str(event_data.get("importance", 3)),
            "tags": ",".join(event_data.get("tags", [])),
        }

        collection.upsert(
            ids=[event_id],
            documents=[document],
            metadatas=[metadata],
        )

    async def search(
        self, user_id: str, query: str, n_results: int = 10, filters: dict | None = None
    ) -> list[dict]:
        """Search user's personal memory."""
        collection = self._get_collection(user_id)

        where = None
        if filters:
            where = {}
            if "event_type" in filters:
                where["event_type"] = filters["event_type"]

        results = collection.query(
            query_texts=[query],
            n_results=n_results,
            where=where if where else None,
        )

        output = []
        if results["documents"]:
            for i, doc in enumerate(results["documents"][0]):
                output.append({
                    "id": results["ids"][0][i],
                    "document": doc,
                    "metadata": results["metadatas"][0][i] if results["metadatas"] else {},
                    "distance": results["distances"][0][i] if results["distances"] else None,
                })
        return output

    async def delete_event(self, user_id: str, event_id: str) -> None:
        """Delete an event from memory (privacy/GDPR)."""
        collection = self._get_collection(user_id)
        collection.delete(ids=[event_id])

    async def delete_user_memory(self, user_id: str) -> None:
        """Delete all user memory (account deletion)."""
        collection_name = f"user_{user_id.replace('-', '_')}"
        try:
            self.client.delete_collection(collection_name)
        except Exception:
            logger.warning(f"Collection {collection_name} not found for deletion")


memory_service = MemoryService()

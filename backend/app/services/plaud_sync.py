"""Plaud NotePin integration — sync recordings from Plaud cloud.

Uses reverse-engineered Plaud API (api.plaud.ai) to:
1. List recordings from Plaud device
2. Download audio files (OPUS/MP3)
3. Trigger LifeOS processing pipeline on synced recordings

Authentication: Bearer token from plaud.ai web session.
"""

import logging
import os
import uuid
from datetime import datetime

import httpx

from app.core import store
from app.core.config import settings

logger = logging.getLogger(__name__)

PLAUD_API_BASE = "https://api.plaud.ai"
PLAUD_EU_API_BASE = "https://api-euc1.plaud.ai"


class PlaudRecording:
    """Parsed Plaud recording metadata."""

    def __init__(self, data: dict):
        self.id = data.get("id", "")
        self.filename = data.get("filename", "")
        self.duration_ms = data.get("duration_ms", 0)
        self.filesize = data.get("filesize", 0)
        self.created_at = data.get("created_at", "")
        self.has_transcription = data.get("has_transcription", False)
        self.has_summary = data.get("has_summary", False)
        self.tag_ids = data.get("tag_ids", [])

    @property
    def duration_seconds(self) -> float:
        return self.duration_ms / 1000.0

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "filename": self.filename,
            "duration_seconds": self.duration_seconds,
            "filesize": self.filesize,
            "created_at": self.created_at,
            "has_transcription": self.has_transcription,
            "has_summary": self.has_summary,
        }


class PlaudSyncService:
    """Syncs recordings from Plaud NotePin via plaud.ai cloud API."""

    def __init__(self):
        self.timeout = 60.0

    def _get_base_url(self, region: str = "us") -> str:
        if region == "eu":
            return PLAUD_EU_API_BASE
        return PLAUD_API_BASE

    def _headers(self, token: str) -> dict:
        return {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

    async def test_connection(self, token: str, region: str = "us") -> dict:
        """Test if the Plaud token is valid by listing recordings."""
        try:
            recordings = await self.list_recordings(token, region=region, limit=1)
            return {
                "connected": True,
                "recordings_available": len(recordings) > 0,
            }
        except Exception as e:
            return {
                "connected": False,
                "error": str(e),
            }

    async def list_recordings(
        self,
        token: str,
        region: str = "us",
        limit: int = 50,
    ) -> list[dict]:
        """List recent recordings from Plaud cloud."""
        base_url = self._get_base_url(region)

        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.get(
                f"{base_url}/file/list",
                params={"limit": limit},
                headers=self._headers(token),
            )
            response.raise_for_status()
            data = response.json()

        recordings = []
        items = data if isinstance(data, list) else data.get("data", data.get("files", []))
        for item in items:
            rec = PlaudRecording(item)
            recordings.append(rec.to_dict())

        return recordings

    async def get_audio_url(
        self,
        token: str,
        file_id: str,
        region: str = "us",
        opus: bool = True,
    ) -> str:
        """Get temporary download URL for a recording's audio file."""
        base_url = self._get_base_url(region)

        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.get(
                f"{base_url}/file/temp-url/{file_id}",
                params={"is_opus": 1 if opus else 0},
                headers=self._headers(token),
            )
            response.raise_for_status()
            data = response.json()

        return data.get("url", data.get("temp_url", ""))

    async def download_audio(
        self,
        token: str,
        file_id: str,
        region: str = "us",
    ) -> tuple[bytes, str]:
        """Download audio file from Plaud cloud.

        Returns (audio_bytes, filename).
        """
        url = await self.get_audio_url(token, file_id, region)
        if not url:
            raise ValueError(f"No download URL for file {file_id}")

        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.get(url)
            response.raise_for_status()

        ext = "opus" if "opus" in url.lower() else "mp3"
        filename = f"plaud_{file_id}.{ext}"

        return response.content, filename

    async def get_transcription(
        self,
        token: str,
        file_id: str,
        region: str = "us",
    ) -> dict | None:
        """Get existing transcription from Plaud if available."""
        base_url = self._get_base_url(region)

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.get(
                    f"{base_url}/file/transcription/{file_id}",
                    headers=self._headers(token),
                )
                if response.status_code == 404:
                    return None
                response.raise_for_status()
                return response.json()
        except Exception:
            return None

    async def sync_recording(
        self,
        token: str,
        file_id: str,
        user_id: str = "demo-user",
        region: str = "us",
    ) -> dict:
        """Sync a single Plaud recording into LifeOS.

        Downloads audio → saves to storage → creates session → ready for processing.
        """
        # Download audio
        audio_bytes, filename = await self.download_audio(token, file_id, region)

        # Create session
        session_id = str(uuid.uuid4())
        session_dir = os.path.join(settings.storage_path, session_id)
        os.makedirs(session_dir, exist_ok=True)

        # Save audio file
        audio_path = os.path.join(session_dir, filename)
        with open(audio_path, "wb") as f:
            f.write(audio_bytes)

        # Register session in store
        now = datetime.utcnow().isoformat()
        store.sessions[session_id] = {
            "id": session_id,
            "user_id": user_id,
            "source": "plaud_notepin",
            "plaud_file_id": file_id,
            "consent_mode": "private",
            "status": "uploaded",
            "started_at": now,
            "created_at": now,
        }

        # Register chunk
        store.chunks.setdefault(session_id, []).append({
            "id": str(uuid.uuid4()),
            "session_id": session_id,
            "chunk_index": 0,
            "filename": filename,
            "size_bytes": len(audio_bytes),
            "duration_seconds": 0,
            "status": "uploaded",
            "created_at": now,
        })

        # Check if Plaud already has a transcription
        plaud_transcript = await self.get_transcription(token, file_id, region)

        return {
            "session_id": session_id,
            "plaud_file_id": file_id,
            "filename": filename,
            "size_bytes": len(audio_bytes),
            "status": "uploaded",
            "has_plaud_transcription": plaud_transcript is not None,
            "plaud_transcription": plaud_transcript,
        }

    async def sync_all_new(
        self,
        token: str,
        user_id: str = "demo-user",
        region: str = "us",
        limit: int = 20,
    ) -> dict:
        """Sync all new (unsynced) recordings from Plaud."""
        recordings = await self.list_recordings(token, region=region, limit=limit)

        # Find already-synced file IDs
        synced_ids = {
            s.get("plaud_file_id")
            for s in store.sessions.values()
            if s.get("source") == "plaud_notepin"
        }

        new_recordings = [
            r for r in recordings
            if r["id"] not in synced_ids
        ]

        synced = []
        failed = []

        for rec in new_recordings:
            try:
                result = await self.sync_recording(
                    token=token,
                    file_id=rec["id"],
                    user_id=user_id,
                    region=region,
                )
                synced.append(result)
            except Exception as e:
                logger.error(f"Failed to sync Plaud recording {rec['id']}: {e}")
                failed.append({
                    "file_id": rec["id"],
                    "filename": rec.get("filename", ""),
                    "error": str(e),
                })

        return {
            "total_available": len(recordings),
            "already_synced": len(synced_ids),
            "newly_synced": len(synced),
            "failed": len(failed),
            "synced_sessions": synced,
            "failures": failed,
        }


plaud_service = PlaudSyncService()

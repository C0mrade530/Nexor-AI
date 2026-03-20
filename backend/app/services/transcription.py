"""Audio transcription service via CometAPI (OpenAI Whisper compatible)."""

import logging

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)


class TranscriptionResult:
    def __init__(
        self,
        text: str,
        language: str,
        confidence: float,
        segments: list[dict] | None = None,
        speakers: list[dict] | None = None,
    ):
        self.text = text
        self.language = language
        self.confidence = confidence
        self.segments = segments or []
        self.speakers = speakers or []


class TranscriptionService:
    """Transcription via CometAPI Whisper endpoint (OpenAI-compatible)."""

    def __init__(self):
        self.base_url = settings.openai_base_url.rstrip("/")
        self.api_key = settings.get_openai_key()
        self.model = settings.whisper_model

    async def transcribe(
        self, audio_path: str, language_hint: str = "ru"
    ) -> TranscriptionResult:
        """Transcribe audio file via CometAPI Whisper."""
        if settings.transcription_provider == "deepgram":
            return await self._transcribe_deepgram(audio_path, language_hint)
        return await self._transcribe_whisper(audio_path, language_hint)

    async def _transcribe_whisper(
        self, audio_path: str, language_hint: str
    ) -> TranscriptionResult:
        """Transcribe using Whisper via CometAPI (OpenAI-compatible endpoint).

        POST {base_url}/audio/transcriptions
        """
        url = f"{self.base_url}/audio/transcriptions"

        with open(audio_path, "rb") as f:
            audio_data = f.read()

        # Determine content type from extension
        ext = audio_path.rsplit(".", 1)[-1].lower()
        content_type_map = {
            "wav": "audio/wav",
            "mp3": "audio/mpeg",
            "m4a": "audio/mp4",
            "webm": "audio/webm",
            "ogg": "audio/ogg",
            "flac": "audio/flac",
        }
        content_type = content_type_map.get(ext, "audio/wav")
        filename = audio_path.rsplit("/", 1)[-1]

        async with httpx.AsyncClient(timeout=180.0) as client:
            response = await client.post(
                url,
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                },
                files={
                    "file": (filename, audio_data, content_type),
                },
                data={
                    "model": self.model,
                    "response_format": "verbose_json",
                    "language": language_hint if language_hint != "auto" else "",
                    "timestamp_granularities[]": "segment",
                },
            )
            response.raise_for_status()
            data = response.json()

        # Parse response
        text = data.get("text", "")
        language = data.get("language", language_hint)

        segments = []
        for seg in data.get("segments", []):
            segments.append({
                "start": seg.get("start", 0),
                "end": seg.get("end", 0),
                "text": seg.get("text", ""),
            })

        logger.info(
            f"Whisper transcription complete: {len(text)} chars, "
            f"{len(segments)} segments, language={language}"
        )

        return TranscriptionResult(
            text=text,
            language=language,
            confidence=0.92,
            segments=segments,
        )

    async def _transcribe_deepgram(
        self, audio_path: str, language_hint: str
    ) -> TranscriptionResult:
        """Fallback: transcribe using Deepgram with diarization."""
        url = "https://api.deepgram.com/v1/listen"
        params = {
            "model": "nova-2",
            "language": language_hint,
            "punctuate": "true",
            "diarize": "true",
            "smart_format": "true",
        }

        with open(audio_path, "rb") as f:
            audio_data = f.read()

        async with httpx.AsyncClient(timeout=120.0) as client:
            resp = await client.post(
                url,
                params=params,
                content=audio_data,
                headers={
                    "Authorization": f"Token {settings.deepgram_api_key}",
                    "Content-Type": "audio/wav",
                },
            )
            resp.raise_for_status()
            data = resp.json()

        channel = data["results"]["channels"][0]
        alternative = channel["alternatives"][0]

        speakers = []
        if "words" in alternative:
            current_speaker = None
            current_text: list[str] = []
            for word in alternative["words"]:
                speaker = word.get("speaker", 0)
                if speaker != current_speaker:
                    if current_text:
                        speakers.append({
                            "speaker": current_speaker,
                            "text": " ".join(current_text),
                        })
                    current_speaker = speaker
                    current_text = [word["word"]]
                else:
                    current_text.append(word["word"])
            if current_text:
                speakers.append({"speaker": current_speaker, "text": " ".join(current_text)})

        return TranscriptionResult(
            text=alternative["transcript"],
            language=language_hint,
            confidence=alternative.get("confidence", 0.0),
            speakers=speakers,
        )


transcription_service = TranscriptionService()

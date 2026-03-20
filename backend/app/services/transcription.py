"""Audio transcription service — supports Whisper and Deepgram."""

import logging
from pathlib import Path

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
    """Transcription with diarization support."""

    def __init__(self):
        self.provider = settings.transcription_provider

    async def transcribe(self, audio_path: str, language_hint: str = "ru") -> TranscriptionResult:
        """Transcribe audio file and return structured result."""
        if self.provider == "openai_whisper":
            return await self._transcribe_whisper(audio_path, language_hint)
        elif self.provider == "deepgram":
            return await self._transcribe_deepgram(audio_path, language_hint)
        else:
            raise ValueError(f"Unknown transcription provider: {self.provider}")

    async def _transcribe_whisper(
        self, audio_path: str, language_hint: str
    ) -> TranscriptionResult:
        """Transcribe using OpenAI Whisper API."""
        import openai

        client = openai.AsyncOpenAI(api_key=settings.openai_api_key)

        with open(audio_path, "rb") as audio_file:
            response = await client.audio.transcriptions.create(
                model="whisper-1",
                file=audio_file,
                language=language_hint if language_hint != "auto" else None,
                response_format="verbose_json",
                timestamp_granularities=["segment"],
            )

        segments = []
        if hasattr(response, "segments") and response.segments:
            segments = [
                {
                    "start": s.start if hasattr(s, "start") else s.get("start"),
                    "end": s.end if hasattr(s, "end") else s.get("end"),
                    "text": s.text if hasattr(s, "text") else s.get("text"),
                }
                for s in response.segments
            ]

        return TranscriptionResult(
            text=response.text,
            language=response.language if hasattr(response, "language") else language_hint,
            confidence=0.9,  # Whisper doesn't return per-file confidence
            segments=segments,
        )

    async def _transcribe_deepgram(
        self, audio_path: str, language_hint: str
    ) -> TranscriptionResult:
        """Transcribe using Deepgram with diarization."""
        import httpx

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

        async with httpx.AsyncClient() as client:
            resp = await client.post(
                url,
                params=params,
                content=audio_data,
                headers={
                    "Authorization": f"Token {settings.deepgram_api_key}",
                    "Content-Type": "audio/wav",
                },
                timeout=120.0,
            )
            resp.raise_for_status()
            data = resp.json()

        channel = data["results"]["channels"][0]
        alternative = channel["alternatives"][0]

        speakers = []
        if "words" in alternative:
            current_speaker = None
            current_text = []
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
            language=data["results"].get("channels", [{}])[0]
            .get("detected_language", language_hint),
            confidence=alternative.get("confidence", 0.0),
            speakers=speakers,
        )


transcription_service = TranscriptionService()

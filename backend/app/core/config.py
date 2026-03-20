"""Application configuration with privacy-first defaults."""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # App
    app_name: str = "LifeOS"
    app_version: str = "0.1.0"
    debug: bool = False
    api_prefix: str = "/api/v1"

    # Database
    database_url: str = "postgresql+asyncpg://lifeos:lifeos@localhost:5432/lifeos"

    # Redis
    redis_url: str = "redis://localhost:6379/0"

    # Storage
    storage_backend: str = "local"  # "local" | "s3"
    storage_path: str = "./audio_storage"
    s3_bucket: str = ""
    s3_region: str = "us-east-1"

    # Auth
    secret_key: str = "CHANGE-ME-IN-PRODUCTION"
    access_token_expire_minutes: int = 60 * 24 * 7  # 1 week
    algorithm: str = "HS256"

    # CometAPI — single API gateway for all AI services
    cometapi_key: str = ""
    cometapi_base_url: str = "https://api.cometapi.com/v1"

    # Claude (via CometAPI — Anthropic-compatible)
    anthropic_base_url: str = "https://api.cometapi.com/v1"
    anthropic_api_key: str = ""  # falls back to cometapi_key
    default_llm_model: str = "claude-sonnet-4-20250514"

    # Whisper transcription (via CometAPI — OpenAI-compatible)
    openai_base_url: str = "https://api.cometapi.com/v1"
    openai_api_key: str = ""  # falls back to cometapi_key
    whisper_model: str = "whisper-1"

    # Transcription settings
    transcription_provider: str = "whisper"  # "whisper" | "deepgram"
    deepgram_api_key: str = ""
    max_audio_chunk_seconds: int = 300  # 5 min chunks

    # Privacy defaults
    audio_retention_policy: str = "after_transcription"  # "keep_all" | "after_transcription" | "summaries_only"
    audio_retention_days: int = 30
    encrypt_at_rest: bool = True
    default_consent_mode: str = "private"  # "private" | "meeting" | "public"

    # Integrations
    google_calendar_client_id: str = ""
    google_calendar_client_secret: str = ""

    # Vector DB
    chroma_persist_dir: str = "./chroma_data"

    model_config = {"env_file": ".env", "env_prefix": "LIFEOS_"}

    def get_anthropic_key(self) -> str:
        """Return Anthropic API key, falling back to CometAPI key."""
        return self.anthropic_api_key or self.cometapi_key

    def get_openai_key(self) -> str:
        """Return OpenAI API key for Whisper, falling back to CometAPI key."""
        return self.openai_api_key or self.cometapi_key


settings = Settings()

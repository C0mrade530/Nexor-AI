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

    # AI / LLM
    anthropic_api_key: str = ""
    openai_api_key: str = ""  # for Whisper transcription
    default_llm_provider: str = "anthropic"
    default_llm_model: str = "claude-sonnet-4-20250514"

    # Transcription
    transcription_provider: str = "openai_whisper"  # "openai_whisper" | "deepgram"
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


settings = Settings()

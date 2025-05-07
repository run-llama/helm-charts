from typing import Optional
from uuid import UUID
from pydantic import Field, SecretStr, AnyHttpUrl
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    LLAMACLOUD_API_BASE_URL: AnyHttpUrl = Field(
        default="http://localhost:8000",
        description="Base URL for LlamaCloud API",
    )
    LLAMACLOUD_PROJECT_API_KEY: SecretStr = Field(
        description="API key for LlamaCloud project",
        min_length=1,
    )
    LLAMACLOUD_DATA_SINK_ID: Optional[UUID] = Field(
        default=None,
        description="Data sink ID for LlamaCloud",
    )
    OPENAI_API_KEY: SecretStr = Field(
        description="API key for OpenAI",
        min_length=1,
    )

settings = Settings()

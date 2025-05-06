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

settings = Settings()

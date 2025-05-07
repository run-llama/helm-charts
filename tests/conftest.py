from typing import AsyncGenerator
import asyncio
from llama_cloud.client import AsyncLlamaCloud
from httpx import AsyncClient
from settings import settings
import pytest

@pytest.fixture(scope="function")
async def llama_cloud_client() -> AsyncGenerator[AsyncLlamaCloud, None]:
    """
    Fixture to create a session-scoped LlamaCloud client.
    """
    async with AsyncClient(timeout=60) as client:
        client = AsyncLlamaCloud(
            base_url=str(settings.LLAMACLOUD_API_BASE_URL),
            token=settings.LLAMACLOUD_PROJECT_API_KEY.get_secret_value(),
            httpx_client=client,
        )
        yield client

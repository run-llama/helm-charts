from typing import AsyncGenerator
from uuid import uuid4
import asyncio
import pytest
import time
from settings import settings
from llama_cloud.client import AsyncLlamaCloud
from llama_cloud.types import (
    PipelineCreate,
    PipelineFileCreate,
    Pipeline,
    File,
    ManagedIngestionStatus,
    ManagedIngestionStatusResponse,
    PipelineTransformConfig_Auto,
    OpenAiEmbedding,
    PipelineCreateEmbeddingConfig_OpenaiEmbedding,
    RetrievalMode,
)


async def wait_for_pipeline_ingestion(
    llama_cloud_client: AsyncLlamaCloud,
    pipeline_id: str,
    timeout: int = 300,
) -> ManagedIngestionStatusResponse:
    """
    Wait for the pipeline ingestion to complete.
    """
    start_time = time.time()
    while True:
        res = await llama_cloud_client.pipelines.get_pipeline_status(pipeline_id=pipeline_id)
        terminal_statuses = [
            ManagedIngestionStatus.SUCCESS,
            ManagedIngestionStatus.ERROR,
            ManagedIngestionStatus.PARTIAL_SUCCESS,
        ]
        if res.status in terminal_statuses:
            return res
        if time.time() - start_time > timeout:
            raise TimeoutError(f"Pipeline ingestion did not complete within {timeout} seconds.")
        await asyncio.sleep(5)


@pytest.fixture()
async def simple_file(llama_cloud_client: AsyncLlamaCloud) -> AsyncGenerator[File, None]:
    """
    Fixture to create a simple file for testing.
    """
    with open("./test_data/five_pages.pdf", "rb") as file:
        file = await llama_cloud_client.files.upload_file(
            upload_file=file,
        )
        assert file.id is not None
        yield file
        # cleanup
        await llama_cloud_client.files.delete_file(id=file.id)


@pytest.fixture()
async def simple_pipeline(llama_cloud_client: AsyncLlamaCloud) -> AsyncGenerator[Pipeline, None]:
    """
    Fixture to create a simple pipeline for testing.
    """
    embedding_config = PipelineCreateEmbeddingConfig_OpenaiEmbedding(
        type="OPENAI_EMBEDDING",
        component=OpenAiEmbedding(
            model_name="text-embedding-ada-002",
            embed_batch_size=100,
            num_workers=1,
            api_key=settings.OPENAI_API_KEY.get_secret_value(),
        )
    )
    pipeline_create = PipelineCreate(
        name=f"test-pipeline-{uuid4()}",
        data_sink_id=settings.LLAMACLOUD_DATA_SINK_ID,
        transform_config=PipelineTransformConfig_Auto(mode="auto"),
        embedding_config=embedding_config,
    )
    pipeline = await llama_cloud_client.pipelines.create_pipeline(request=pipeline_create)
    assert pipeline.id is not None
    assert pipeline.name == pipeline_create.name
    if settings.LLAMACLOUD_DATA_SINK_ID:
        assert pipeline.data_sink.id == settings.LLAMACLOUD_DATA_SINK_ID

    yield pipeline

    # cleanup
    await llama_cloud_client.pipelines.delete_pipeline(pipeline_id=pipeline.id)


async def test_index_ingestion(
    llama_cloud_client: AsyncLlamaCloud,
    simple_file: File,
    simple_pipeline: Pipeline,
) -> None:
    # add file to pipeline
    await llama_cloud_client.pipelines.add_files_to_pipeline_api(
        pipeline_id=simple_pipeline.id,
        request=[PipelineFileCreate(file_id=simple_file.id)],
    )

    res = await wait_for_pipeline_ingestion(
        llama_cloud_client=llama_cloud_client,
        pipeline_id=simple_pipeline.id,
    )

    assert res.status == ManagedIngestionStatus.SUCCESS, f"Pipeline ingestion failed with error: {str(res.error)}"

    # smoke test retrieval
    results = await llama_cloud_client.pipelines.run_search(
        pipeline_id=simple_pipeline.id,
        query="What is in this document?",
        dense_similarity_top_k=5,
        retrieval_mode=RetrievalMode.CHUNKS,
    )
    assert len(results.retrieval_nodes) == 5
    for node in results.retrieval_nodes:
        assert node.node.text in set(map(str, range(5)))


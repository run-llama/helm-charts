from llama_cloud.client import AsyncLlamaCloud

async def delete_file(llama_cloud_client: AsyncLlamaCloud, file_id: str):
    """
    Delete a file from LlamaCloud.
    """
    await llama_cloud_client.files.delete_file(id=file_id)


async def test_file_upload(llama_cloud_client: AsyncLlamaCloud):
    with open("./test_data/five_pages.pdf", "rb") as file:
        file = await llama_cloud_client.files.upload_file(
            upload_file=file,
        )
        assert file.id is not None
        assert file.name == "five_pages.pdf"
        assert file.file_size > 0
        # cleanup
        await delete_file(llama_cloud_client, file.id)


async def test_file_upload_from_url(llama_cloud_client: AsyncLlamaCloud):
    file_url = "https://docs.llamaindex.ai/robots.txt"
    file = await llama_cloud_client.files.upload_file_from_url(
        url=file_url,
    )
    assert file.id is not None
    assert file.name == "robots.txt"
    assert file.file_size > 0
    # cleanup
    await delete_file(llama_cloud_client, file.id)

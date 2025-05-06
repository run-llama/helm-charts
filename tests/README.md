# BYOC Tests

This is a collection of test scripts for ensuring that various features in your llama-cloud helm chart deployment are working as expected.

## Setup

This uses [`uv`](https://docs.astral.sh/uv) to manage dependencies and [`pytest`](https://docs.pytest.org/en/stable/) for running tests.

To install the project dependencies, run `uv sync`.

Lastly, you will need to setup the `.env` file. To start this, create one based off of the provided template:
```
cp .env.template .env
```

You will need to fill in the template values with the values from your environment. See the comments for descriptions of how each field should be set.

## Run Tests

Once you've followed the setup instructions, run all tests by running the following command from within this `tests` directory:
```
uv run -- pytest .
```

You can also select a particular test to run with the following syntax:
```
uv run -- pytest ./index/test_file.py::test_file_upload
```

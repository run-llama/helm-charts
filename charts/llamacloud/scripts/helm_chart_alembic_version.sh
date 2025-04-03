#!/bin/bash

# Function to display usage information
usage() {
  echo "Usage: $0 <helm-chart-version> [--image <image-name>]"
  exit 1
}

# Check if at least one argument is provided
if [ $# -eq 0 ]; then
  usage
fi

# Initialize variables
HELM_CHART_VERSION=""
IMAGE_NAME=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --image)
      IMAGE_NAME="$2"
      shift 2
      ;;
    *)
      if [ -z "$HELM_CHART_VERSION" ]; then
        HELM_CHART_VERSION="$1"
        IMAGE_NAME="llamaindex/llamacloud-backend:$HELM_CHART_VERSION"
      else
        usage
      fi
      shift
      ;;
  esac
done

# Ensure IMAGE_NAME is set
if [ -z "$IMAGE_NAME" ]; then
  echo "Error: No image name provided."
  usage
fi

# Pull the Docker image and capture the output
echo "Pulling Docker image: $IMAGE_NAME"
PULL_OUTPUT=$(docker pull $IMAGE_NAME)

# Run the script inside the Docker container and capture the output
LATEST_VERSION=$(docker run --rm \
  -v $(pwd)/scripts/temp.env:/app/temp.env \
  -v $(pwd)/scripts/extract_alembic_history.sh:/extract_alembic_history.sh \
  $IMAGE_NAME bash -c "bash /extract_alembic_history.sh")


# Cleanup: Remove the Docker image if it was newly pulled
if echo "$PULL_OUTPUT" | grep -q "Downloaded newer image"; then
  echo "Cleaning up by deleting the downloaded image: $IMAGE_NAME"
  docker rmi $IMAGE_NAME
else
  echo "Skipping cleanup because the image had already existed previously."
  echo "If you wish to manually clean up the image, you can run: docker rmi $IMAGE_NAME"
fi

# Output the latest alembic version stamp
printf "\n\n\n"
if [ -z "$LATEST_VERSION" ] || [ -z "$(echo $LATEST_VERSION | xargs)" ]; then
  echo "Error: Alembic version extraction didn't work. You may want to debug by checking the above output from the script."
  exit 1
else
  echo "Latest alembic version for helm chart version $HELM_CHART_VERSION: $LATEST_VERSION"
fi

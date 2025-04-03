#!/bin/bash

# Export environment variables from temp.env
export $(grep -v '^#' /app/temp.env | xargs)

# Run the alembic history command and extract the latest version stamp
LATEST_VERSION=$(alembic history | head -n 1 | awk '{print $3}')

# Output the latest alembic version stamp
echo $LATEST_VERSION

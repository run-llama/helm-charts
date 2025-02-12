#! /bin/bash

echo "Setting up filestore buckets..."

# Create the buckets
buckets=("llama-platform-parsed-documents" "llama-platform-etl" "llama-platform-external-components" "llama-platform-file-parsing" "llama-platform-raw-files" "llama-cloud-parse-output" "llama-platform-file-screenshots" "llama-platform-extract-output" "llama-platform-upload" "llama-platform-output")

for bucket in "${buckets[@]}"; do
    echo "Checking if bucket ${bucket} exists..."
    if curl -s "http://localhost:8092/${bucket}" | grep -q "The specified bucket does not exist"; then
        echo "Creating bucket ${bucket}..."
        curl -s -X PUT "http://localhost:8092/${bucket}"
    else
        echo "Bucket ${bucket} already exists"
    fi
done

echo "Filestore buckets created successfully!"

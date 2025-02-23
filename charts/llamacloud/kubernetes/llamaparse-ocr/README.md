# LlamaParse OCR Manifests

This directory contains the manifests for the LlamaParse OCR service. Provided here is a simple Kustomize setup for deploying the llamaparse-ocr service to your Kubernetes cluster. This is intended to be used as a starting point for your own deployment.

## License Key

To obtain a license key, please contact us at [support@llamacloud.com](mailto:support@llamacloud.com).

## Basic Usage

```bash
export LLAMACLOUD_LICENSE_KEY=<your-license-key>
echo "$LLAMACLOUD_LICENSE_KEY" > license-key

# Build the manifests and view the output
kustomize build .

# Build and apply the manifests to your cluster
kustomize build . | kubectl apply -f -
```

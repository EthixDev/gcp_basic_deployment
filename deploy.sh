#!/bin/bash
set -euo pipefail

PROJECT_ID="<GCP_PROJECT_ID>"
REGION="<GCP_REGION>"
SA_KEY_FILE="<GCP_SA_KEY_FILE>"

REPO="<ARTIFACT_REGISTRY_REPO>"
IMAGE_NAME="<IMAGE_NAME>"
IMAGE_TAG="<IMAGE_TAG>"

SERVICE_NAME="<CLOUD_RUN_SERVICE_NAME>"

TMP_GCLOUD_CONFIG="$(mktemp -d)"
trap 'rm -rf "$TMP_GCLOUD_CONFIG"' EXIT

export CLOUDSDK_CONFIG="$TMP_GCLOUD_CONFIG"
export CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE="$(pwd)/$SA_KEY_FILE"

if [ ! -f "$CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE" ]; then
  echo "Service account key not found: $CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE"
  exit 1
fi

gcloud services enable \
  artifactregistry.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  --project="$PROJECT_ID" \
  --quiet

if ! gcloud artifacts repositories describe "$REPO" \
  --location="$REGION" \
  --project="$PROJECT_ID" >/dev/null 2>&1; then

  gcloud artifacts repositories create "$REPO" \
    --repository-format=docker \
    --location="$REGION" \
    --project="$PROJECT_ID" \
    --quiet
fi

IMAGE_URI="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO/$IMAGE_NAME:$IMAGE_TAG"

echo "🏗️ Building and pushing image with Cloud Build..."
gcloud builds submit . \
  --tag "$IMAGE_URI" \
  --project "$PROJECT_ID" \
  --quiet

echo "🚀 Deploying image to Cloud Run..."
gcloud run deploy "$SERVICE_NAME" \
  --image "$IMAGE_URI" \
  --region "$REGION" \
  --platform managed \
  --project "$PROJECT_ID" \
  --quiet

echo "Done: $SERVICE_NAME"
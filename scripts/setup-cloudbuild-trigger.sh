#!/usr/bin/env bash
# Create Cloud Build trigger: auto build + update routing-engine on push to main
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-cybertranspay}"
REGION="${REGION:-europe-west1}"
TRIGGER_NAME="${TRIGGER_NAME:-routing-engine-main}"
REPO_OWNER="${REPO_OWNER:-tyom2001-cell}"
REPO_NAME="${REPO_NAME:-cybertranspay}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== Cloud Build trigger setup ==="
echo "Project: $PROJECT_ID"
echo "Trigger: $TRIGGER_NAME (branch main)"
echo

echo "[1/3] IAM permissions..."
bash "$ROOT/scripts/grant-cloudbuild-permissions.sh"

echo
echo "[2/3] Checking existing trigger..."
if gcloud builds triggers describe "$TRIGGER_NAME" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "Trigger \"$TRIGGER_NAME\" already exists."
else
  echo "[3/3] Creating trigger..."
  if ! gcloud builds triggers create github \
    --name="$TRIGGER_NAME" \
    --repo-name="$REPO_NAME" \
    --repo-owner="$REPO_OWNER" \
    --branch-pattern='^main$' \
    --build-config=cloudbuild.yaml \
    --region="$REGION" \
    --project="$PROJECT_ID"; then
    echo
    echo "FAILED to create trigger."
    echo "Connect GitHub first:"
    echo "  https://console.cloud.google.com/cloud-build/triggers/connect?project=$PROJECT_ID"
    exit 1
  fi
fi

echo
echo "=== Triggers ==="
gcloud builds triggers list --region="$REGION" --project="$PROJECT_ID"
echo
echo "Done. Push to main will run: build -> push -> update Cloud Run."

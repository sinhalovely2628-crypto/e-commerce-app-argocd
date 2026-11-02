
#!/usr/bin/env bash
set -Eeuo pipefail

# Usage:
# ./scripts/update-image-tag.sh <manifest-path> <container-name> <image:tag>

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <manifest-path> <container-name> <image:tag>"
    exit 1
fi

MANIFEST="$1"
CONTAINER_NAME="$2"
NEW_IMAGE="$3"
BRANCH="${BRANCH_NAME:-${GIT_BRANCH:-main}}"
BRANCH="${BRANCH##*/}"

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if [[ ! -f "$MANIFEST" ]]; then
    echo "ERROR: Manifest not found: $MANIFEST"
    exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
    echo "ERROR: Install Mike Farah yq version 4 first."
    exit 1
fi

CONTAINER_COUNT=$(
    CONTAINER_NAME="$CONTAINER_NAME" \
    yq '[.spec.template.spec.containers[] |
    select(.name == strenv(CONTAINER_NAME))] | length' "$MANIFEST"
)

if [[ "$CONTAINER_COUNT" -ne 1 ]]; then
    echo "ERROR: Expected one matching container. Found: $CONTAINER_COUNT"
    exit 1
fi

CONTAINER_NAME="$CONTAINER_NAME" \
NEW_IMAGE="$NEW_IMAGE" \
yq -i '(.spec.template.spec.containers[] |
select(.name == strenv(CONTAINER_NAME)).image) = strenv(NEW_IMAGE)' "$MANIFEST"

echo "Updated image:"
yq '.spec.template.spec.containers[] |
select(.name == "ecom-web").image' "$MANIFEST"

if git diff --quiet -- "$MANIFEST"; then
    echo "No changes detected."
    exit 0
fi

git add -- "$MANIFEST"

git config user.name "Jenkins GitOps"
git config user.email "jenkins-gitops@example.invalid"

git commit -m "GitOps: update ${CONTAINER_NAME} image to ${NEW_IMAGE}"

git push origin "HEAD:${BRANCH}"

echo "SUCCESS: Updated manifest pushed to GitHub."

#!/usr/bin/env bash
#
# gh-release-stage.sh — Apply GH Release prerelease + latest flags per direct-distro ladder
#
# Used by every desktop sub-action that uploads to GH Releases. Lifted from
# kmp-project-template/deployment/_shared/scripts/gh-release-stage.sh.
#
# Usage:
#   bash gh-release-stage.sh <tag> <stage>
# Where <stage> ∈ {prerelease, beta, stable}.
#
# Mapping:
#   prerelease → prerelease: true,  latest: false   (Stage 1)
#   beta       → prerelease: false, latest: false   (Stage 2)
#   stable     → prerelease: false, latest: true    (Stage 3)
#
set -euo pipefail

TAG="${1:?tag required}"
STAGE="${2:-stable}"

case "$STAGE" in
  prerelease) PRERELEASE=true;  LATEST=false ;;
  beta)       PRERELEASE=false; LATEST=false ;;
  stable)     PRERELEASE=false; LATEST=true  ;;
  *)          echo "Invalid STAGE: $STAGE (expected: prerelease | beta | stable)" >&2; exit 2 ;;
esac

REPO_ARG=()
[[ -n "${GITHUB_REPOSITORY:-}" ]] && REPO_ARG=(--repo "$GITHUB_REPOSITORY")

gh release edit "$TAG" --prerelease="$PRERELEASE" --latest="$LATEST" "${REPO_ARG[@]}" >/dev/null
echo "🏷  Release $TAG → prerelease=$PRERELEASE, latest=$LATEST"

#!/usr/bin/env bash
#
# gh-release-ensure.sh — Create the GitHub Release for <tag> if it does not exist.
#
# Restores the "create the release after the FIRST successful deployment, then
# keep updating it + adding artifacts" model. Every desktop sub-action that
# uploads an installer to a GH Release calls this BEFORE `gh release upload`, so
# whichever platform/stage lands first creates the release and all later
# platforms/stages upload to the same tag (`--clobber` accumulates DEB + EXE +
# MSI). Idempotent: a no-op when the release already exists.
#
# Usage:
#   bash gh-release-ensure.sh <tag> [stage]
# Where <stage> ∈ {prerelease, beta, stable} (default: prerelease). The final
# prerelease/latest flags are set by gh-release-stage.sh AFTER the upload; this
# script only guarantees the release EXISTS, seeding it as a prerelease so a
# half-finished release is never surfaced as "latest".
#
set -euo pipefail

TAG="${1:?tag required}"
STAGE="${2:-prerelease}"

REPO_ARG=()
[[ -n "${GITHUB_REPOSITORY:-}" ]] && REPO_ARG=(--repo "$GITHUB_REPOSITORY")

if gh release view "$TAG" "${REPO_ARG[@]}" >/dev/null 2>&1; then
  echo "ℹ️  Release $TAG already exists — uploading to it."
  exit 0
fi

# First successful deployment for this tag → create the release. Seed the flags
# per the current stage (stable → latest, otherwise prerelease); gh-release-stage.sh
# re-affirms them after the upload as the ladder promotes.
CREATE_FLAG=(--prerelease)
[[ "$STAGE" == "stable" ]] && CREATE_FLAG=(--latest)
gh release create "$TAG" \
  --title "$TAG" \
  --notes "Automated multi-platform release $TAG. Artifacts are added as each platform/stage completes." \
  "${CREATE_FLAG[@]}" \
  "${REPO_ARG[@]}"
echo "🆕 Created release $TAG (first successful deployment, stage=$STAGE)."

#!/usr/bin/env bash
#
# promotion-log-append.sh — Optional audit log helper
# Mirror of publish-apple-kmp/_shared/scripts/promotion-log-append.sh.
# No-op if consumer doesn't have deployment/PROMOTION_LOG.yaml.
#
set -euo pipefail

PLATFORM=""; LANE=""; STAGE=""; TAG=""; ACTOR=""; RUN_ID=""
while [ $# -gt 0 ]; do
  case "$1" in
    --platform) shift; PLATFORM="${1:-}" ;;
    --lane)     shift; LANE="${1:-}"     ;;
    --stage)    shift; STAGE="${1:-}"    ;;
    --tag)      shift; TAG="${1:-}"      ;;
    --actor)    shift; ACTOR="${1:-}"    ;;
    --run-id)   shift; RUN_ID="${1:-}"   ;;
    *)          echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
  shift || true
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG="$REPO_ROOT/deployment/PROMOTION_LOG.yaml"
[[ -f "$LOG" ]] || exit 0

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SHA="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
TARGET="${PLATFORM}-${LANE}"
[[ -n "$STAGE" ]] && TARGET="${TARGET}-${STAGE}"
CI_URL="local"
[[ -n "${GITHUB_REPOSITORY:-}" && "$RUN_ID" != "local" ]] && \
  CI_URL="https://github.com/${GITHUB_REPOSITORY}/actions/runs/${RUN_ID}"

cat >> "$LOG" <<EOF

  - timestamp:    "$TS"
    actor:        "${ACTOR:-ci-system}"
    target:       "$TARGET"
    tier:         1
    version_to:   "${TAG:-auto}"
    commit_sha:   "$SHA"
    ci_run_url:   "$CI_URL"
    outcome:      "success"
EOF

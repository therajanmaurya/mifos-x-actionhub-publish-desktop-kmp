#!/usr/bin/env bash
#
# setup-trusted-signing.sh — Verify Azure Trusted Signing env vars are set
#
# Used by windows-msi-signed/ as a pre-flight check. The actual signing is
# performed by azure/trusted-signing-action@v0.5.0 inside the composite action.
#
set -euo pipefail

: "${AZURE_TS_TENANT_ID:?AZURE_TS_TENANT_ID required}"
: "${AZURE_TS_CLIENT_ID:?AZURE_TS_CLIENT_ID required}"
: "${AZURE_TS_CLIENT_SECRET:?AZURE_TS_CLIENT_SECRET required}"
: "${AZURE_TS_ENDPOINT:?AZURE_TS_ENDPOINT required}"
: "${TRUSTED_SIGNING_ACCOUNT_NAME:?TRUSTED_SIGNING_ACCOUNT_NAME required}"
: "${CERTIFICATE_PROFILE_NAME:?CERTIFICATE_PROFILE_NAME required}"

echo "✅ Azure Trusted Signing env vars present"

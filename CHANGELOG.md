# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## v2.0.0 — Constellation consolidation (planned)

### Added

- `build/` — Compose Desktop build (Windows + Linux matrix). Lifted from `openMF/mifos-x-actionhub-build-desktop-app-kmp@v1.0.1`.
- `windows-exe/` 🆕 — Unsigned EXE → GH Release. Was inline `script.sh` in `kmp-project-template/deployment/desktop/windows-exe/`.
- `windows-msi-signed/` — MSI + Azure Trusted Signing → GH Release. Lifted from `openMF/mifos-x-actionhub-publish-desktop-app-kmp@v2.0.0` `msi-signed/`.
- `windows-microsoft-store/` — MSIX submission. Lifted from `openMF/mifos-x-actionhub-publish-desktop-app-kmp@v2.0.0` `microsoft-store/`.
- `linux-deb/` 🆕 — DEB package → GH Release. Was inline `script.sh` in `kmp-project-template/deployment/desktop/linux-deb/`.
- `_shared/scripts/common/gh-release-stage.sh` — prerelease/beta/stable flag flip helper. Lifted from `kmp-project-template/deployment/_shared/scripts/gh-release-stage.sh` (written this session).
- `_shared/scripts/common/promotion-log-append.sh` — append to deployment/PROMOTION_LOG.yaml.
- `_shared/scripts/windows/setup-trusted-signing.sh` — Azure Trusted Signing setup wrapper.

### Excluded from this repo (moved to publish-apple-kmp)

- `mac-dmg-notarized/` → `openMF/mifos-x-actionhub-publish-apple-kmp/mac-dmg-notarized/`. Requires Apple Dev Program (Match for Developer ID cert), so co-located with iOS work.
- `mac-dmg-unsigned/` → `openMF/mifos-x-actionhub-publish-apple-kmp/mac-dmg-unsigned/`. Sibling of notarized; lives with macOS sub-actions.

This is a SHAPE CHANGE from `openMF/mifos-x-actionhub-publish-desktop-app-kmp@v2.0.0` which included Mac DMG targets. Consumers using `publish-desktop-app-kmp@v2.0.0` for Mac targets must update refs to `publish-apple-kmp` during the deprecation window.

### Supersedes (6-month deprecation window from 2026-09-01)

- `openMF/mifos-x-actionhub-build-desktop-app-kmp`
- `openMF/mifos-x-actionhub-publish-desktop-app-kmp` (rename: drop `-app-` from name; Mac DMG content moves to publish-apple-kmp)

### Refs

- Epic: `actionhub-constellation-consolidation`
- Companion repos: `openMF/mifos-x-actionhub-publish-android-kmp@v2.0.0`, `openMF/mifos-x-actionhub-publish-apple-kmp@v2.0.0`, `openMF/mifos-x-actionhub-publish-web-kmp@v2.0.0`
- Orchestrator: `openMF/mifos-x-actionhub@v1.0.17` — adds `release-desktop.yaml` reusable workflow

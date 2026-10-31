# mifos-x-actionhub-publish-desktop-kmp

[![Release](https://img.shields.io/github/v/release/therajanmaurya/mifos-x-actionhub-publish-desktop-kmp?label=release&logo=github)](https://github.com/therajanmaurya/mifos-x-actionhub-publish-desktop-kmp/releases/latest)
[![PR Check](https://github.com/therajanmaurya/mifos-x-actionhub-publish-desktop-kmp/actions/workflows/pr-check.yaml/badge.svg)](https://github.com/therajanmaurya/mifos-x-actionhub-publish-desktop-kmp/actions/workflows/pr-check.yaml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](./LICENSE)

> Composite GitHub Actions for KMP **Desktop (Windows + Linux only)**: EXE, MSI (Azure Trusted Signing), Microsoft Store, DEB. macOS desktop targets live in [`mifos-x-actionhub-publish-apple-kmp`](https://github.com/openMF/mifos-x-actionhub-publish-apple-kmp) since they share Apple Dev Program infrastructure.

## Why Windows + Linux only

The existing `publish-desktop-app-kmp@v2.0.0` mixed Mac DMG with Windows/Linux targets. Splitting Mac off into the Apple repo gives:
- Apple shared infra (Match repo, ASC API, notarytool) co-located with iOS work
- This repo focuses on non-Apple desktop with cleaner secret/auth model (Azure Trusted Signing for Windows, apt for Linux)

## What this provides

5 composite sub-actions:

| Sub-action | OS | Purpose |
|---|---|---|
| [`build/`](./build/) | Win + Linux matrix | Compose Desktop build (`packageReleaseDistributionForCurrentOS`) |
| [`windows-exe/`](./windows-exe/) | windows-latest | Unsigned Windows EXE installer → GitHub Release |
| [`windows-msi-signed/`](./windows-msi-signed/) | windows-latest | Windows MSI + Azure Trusted Signing → GitHub Release |
| [`windows-microsoft-store/`](./windows-microsoft-store/) | windows-latest | MSIX submission to Microsoft Store (Partner Center API) |
| [`linux-deb/`](./linux-deb/) | ubuntu-26.04 | Linux DEB package → GitHub Release |

## Promotion ladder (GH Release direct distribution)

Direct-distribution targets use GH Release flag flipping:

| Stage | `gh release` flags |
|---|---|
| **Stage 1 — prerelease** | `prerelease=true, latest=false` |
| **Stage 2 — beta** | `prerelease=false, latest=false` |
| **Stage 3 — stable** | `prerelease=false, latest=true` |

Each sub-action accepts a `stage` input controlling these flags after upload. Promotion between stages (no rebuild) calls `_shared/scripts/gh-release-stage.sh` directly.

## Repository structure

```
.
├── README.md
├── LICENSE
├── CHANGELOG.md
├── action.yaml                                 ← root composite (matrix build default)
├── .github/workflows/{pr-check,release}.yaml
├── build/, windows-exe/, windows-msi-signed/,
├── windows-microsoft-store/, linux-deb/        ← 5 sub-actions
├── _shared/
│   └── scripts/
│       ├── windows/setup-trusted-signing.sh
│       ├── linux/                              ← (future)
│       └── common/
│           ├── gh-release-stage.sh             ← prerelease/beta/stable flag flip
│           └── promotion-log-append.sh
└── examples/
    ├── consumer-release-windows.yml
    └── consumer-release-linux.yml
```

## Quick start — Windows EXE Stage 1 (prerelease)

```yaml
- uses: openMF/mifos-x-actionhub-publish-desktop-kmp/windows-exe@v2.0.0
  with:
    desktop_package_name: cmp-desktop
    flavor:               prod
    github_tag:           v2026.06.15
    stage:                prerelease
```

## Quick start — Promote existing tag to stable (no rebuild)

```yaml
- uses: openMF/mifos-x-actionhub-publish-desktop-kmp/windows-exe@v2.0.0
  with:
    desktop_package_name: cmp-desktop
    github_tag:           v2026.06.15
    stage:                stable
    promote_only:         true       # skip build; flip GH Release flags only
```

For the **full ladder run with approval gates**, see [`openMF/mifos-x-actionhub/.github/workflows/release-desktop.yaml`](https://github.com/openMF/mifos-x-actionhub/blob/main/.github/workflows/release-desktop.yaml).

## Supersedes (legacy repos)

| Old | New |
|---|---|
| `openMF/mifos-x-actionhub-build-desktop-app-kmp@v1.0.1` | `./build/@v2.0.0` |
| `openMF/mifos-x-actionhub-publish-desktop-app-kmp@v2.0.0` — `msi-signed/` | `./windows-msi-signed/@v2.0.0` |
| `openMF/mifos-x-actionhub-publish-desktop-app-kmp@v2.0.0` — `microsoft-store/` | `./windows-microsoft-store/@v2.0.0` |
| (no legacy — was inline `script.sh` in `kmp-project-template`) | `./windows-exe/@v2.0.0` 🆕 |
| (no legacy — was inline `script.sh` in `kmp-project-template`) | `./linux-deb/@v2.0.0` 🆕 |

**Note**: `publish-desktop-app-kmp@v2.0.0`'s `dmg-notarized/` sub-action moves to `publish-apple-kmp/mac-dmg-notarized/` since it requires Apple Dev infrastructure.

## License

[Apache 2.0](./LICENSE)

## Runner images — one place to change

Every job picks its runner in this order:

1. an explicit input from the caller (e.g. `runner_pool_mac: '["self-hosted","macOS"]'`), else
2. the configuration variable **`CI_RUNNER_LINUX`** / **`CI_RUNNER_MAC`** / **`CI_RUNNER_WINDOWS`**, else
3. the label pinned in the workflow today.

Variables resolve from the **calling** repository's context, so set them once at the organization level
(Settings → Secrets and variables → Actions → Variables) and every repo using these workflows follows.
When GitHub ships a new image (e.g. `macos-16`), change `CI_RUNNER_MAC` — no PR, no release, and rolling back is
the same one edit. With no variable set, nothing changes.

`CI_RUNNER_MAC` must name an image whose Xcode can build your iOS targets. Change images in a quiet window: run one
PR check on the new image first, because a new image is also a new toolchain.

# CLAUDE.md — mifos-x-actionhub-publish-desktop-kmp (Tier 3 — Windows + Linux)

> **You are in a TIER-3 PUBLISH repo.** Before editing anything, check whether
> the change actually belongs in the **orchestrator** (`openMF/mifos-x-actionhub`).
> Full decision guide: [`mifos-x-actionhub/CONTRIBUTING.md`](https://github.com/openMF/mifos-x-actionhub/blob/main/CONTRIBUTING.md)

## The 3-tier chain

```
Consumer (kmp-project-template + forks)        Tier 1 — thin wrapper
    └─ uses @v1.0.X →
openMF/mifos-x-actionhub                       Tier 2 — orchestrator
    └─ uses @v2.0.X →
publish-android-kmp                            Tier 3 — Android ladder
publish-apple-kmp                              Tier 3 — iOS + macOS
publish-desktop-kmp (THIS REPO)                Tier 3 — Windows + Linux
publish-web-kmp                                Tier 3 — Web hosts
```

This repo serves **Windows + Linux** desktop only. macOS desktop targets live
in `publish-apple-kmp` (shared Apple Dev Program / Match infra). Targets:
`windows-exe`, `windows-msi-signed`, `windows-microsoft-store`, `linux-deb`.

## What lives here (Desktop-specific)

| Concern | File | Owns |
|---|---|---|
| Ladder workflow | `.github/workflows/release.yaml` | rungs: prerelease → beta → stable (GH Release flag-flip) |
| Composite actions | `{target}/action.yaml` | per-target build + sign (Compose Desktop, Azure Trusted Signing) |
| Validate-secrets preflight | `release.yaml#validate-secrets` | per-target: linux-deb=none, windows-signed=azure_*, ms-store=+ms_store_* |

## "Should this change go HERE or in the orchestrator?"

### ✅ Edit HERE when…
- Adding a new desktop target (e.g. `linux-snap`, `linux-flatpak`, `windows-portable-exe`)
- Changing Azure Trusted Signing flow
- Changing Microsoft Partner Center upload logic
- Adding Compose Desktop build flags
- Updating MSI/EXE/DEB packaging steps
- Changing GitHub Environment names (`desktop-windows-msi-signed-prerelease` → …)
- Bumping Windows runner image, JDK version
- Adjusting per-target `validate-secrets` env list

### ❌ DON'T edit here — go to orchestrator when…
- Changing the consumer-facing `workflow_dispatch` form (the `desktop_win_rung`, `desktop_linux_rung`, `desktop_win_artifact` choices live in `release-multi-platform-v2.yaml`)
- Adding cross-platform validation
- Adding a non-desktop target (Web → publish-web-kmp; macOS → publish-apple-kmp)

## Versioning

| Bump | When |
|---|---|
| Patch (`v2.0.4` → `v2.0.5`) | any change inside the ladder |
| Minor (`v2.0.X` → `v2.1.0`) | new target added (e.g. `linux-snap`) |
| Major (`v2.X.X` → `v3.0.0`) | breaking — target removed, secret renamed |

After merging:
1. Tag `v2.0.{X+1}` on `dev` (the only long-lived branch)
2. Bump orchestrator's `publish-desktop-kmp/.github/workflows/release.yaml@v2.0.{X}` → `@v2.0.{X+1}`
3. Tag orchestrator patch, bump consumer wrappers

## Desktop secret schema (per target — canonical names match V2_GUIDE.md)

| Target | Secrets required |
|---|---|
| `linux-deb` | (none) |
| `windows-exe`, `windows-msi-signed` | `azure_client_id`, `azure_tenant_id`, `azure_subscription_id`, `azure_trusted_signing_endpoint`, `azure_trusted_signing_account`, `azure_cert_profile_name` |
| `windows-microsoft-store` | all 6 `azure_*` above + `microsoft_store_client_id`, `microsoft_store_client_secret` |

## Don't

- ❌ Don't reference floating tags
- ❌ Don't add macOS targets here — they belong in `publish-apple-kmp`
- ❌ Don't hardcode artifact names — the orchestrator passes `target` as input

## Always

- ✅ Tag immediately after merge
- ✅ Bump orchestrator's ref pin in the same coordinated release
- ✅ When adding a new target, also add a `case` branch in `validate-secrets`
- ✅ Match canonical lowercase snake_case secret names

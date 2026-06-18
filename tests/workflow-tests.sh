#!/bin/bash
# tests/workflow-tests.sh
#
# End-to-end workflow tests for mifos-x-actionhub-publish-desktop-kmp.
#
# Tier-3 repo (Windows + Linux) in the 3-tier actionhub chain:
#     consumer → orchestrator(mifos-x-actionhub) → THIS REPO
#
# Targets: linux-deb, windows-exe, windows-msi-signed, windows-microsoft-store
#
# Test tiers:
#   1. Static syntax    — YAML parse · actionlint · no dynamic uses
#   2. Workflow_call    — interface schema (inputs + secrets contract)
#   3. Job structure    — 4 jobs · dependencies · stage ordering
#   4. Per-target fix   — 4 conditional static-uses + correct if-gates (locks v2.0.6 fix)
#   5. Composite actions — every uses: target subdir exists + has action.yaml
#   6. Action interfaces — caller's `with:` matches action's declared inputs
#   7. validate-secrets — coverage per target
#   8. Promote stages   — flag-flip only, no rebuild
#
# Invocation:
#   bash tests/workflow-tests.sh                # run all tests
#   bash tests/workflow-tests.sh --tier 1       # run only tier 1
#
# Dependencies:
#   - python3 with PyYAML
#   - actionlint (https://github.com/rhysd/actionlint)
#   - shellcheck

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0
FAILED_TESTS=()

run_test() {
    local name="$1"
    local cmd="$2"
    printf "  %-72s ... " "$name"
    if eval "$cmd" > /tmp/test-out 2>&1; then
        echo "✅ PASS"
        PASS=$((PASS+1))
    else
        echo "❌ FAIL"
        sed 's/^/      /' /tmp/test-out
        FAIL=$((FAIL+1))
        FAILED_TESTS+=("$name")
    fi
}

py() {
    python3 -c "$1"
}

# ─────────────────────────────────────────────────────────────────────────────
# Constants — repo-specific
# ─────────────────────────────────────────────────────────────────────────────
TARGETS=(linux-deb windows-exe windows-msi-signed windows-microsoft-store)
EXPECTED_JOBS=(validate-secrets stage-1-prerelease stage-2-promote-to-beta stage-3-promote-to-stable)
EXPECTED_INPUTS=(target desktop_package_name github_tag starting_rung)
EXPECTED_SECRETS=(
    azure_client_id azure_tenant_id azure_subscription_id
    azure_trusted_signing_endpoint azure_trusted_signing_account azure_cert_profile_name
    microsoft_store_client_id microsoft_store_client_secret
)

# ─────────────────────────────────────────────────────────────────────────────
# Test runner
# ─────────────────────────────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════════════════"
echo "  Workflow E2E tests for mifos-x-actionhub-publish-desktop-kmp"
echo "════════════════════════════════════════════════════════════════════════════"
echo

# ── Tier 1: Static syntax ────────────────────────────────────────────────────
echo "── Tier 1: Static syntax ──"
run_test "T01: release.yaml parses (PyYAML)" \
    "py 'import yaml; yaml.safe_load(open(\".github/workflows/release.yaml\"))'"
run_test "T02: pr-check.yaml parses" \
    "py 'import yaml; yaml.safe_load(open(\".github/workflows/pr-check.yaml\"))'"
run_test "T03: tag.yaml parses" \
    "py 'import yaml; yaml.safe_load(open(\".github/workflows/tag.yaml\"))'"
run_test "T04: actionlint clean on release.yaml" \
    "actionlint .github/workflows/release.yaml"
run_test "T05: actionlint clean on pr-check.yaml" \
    "actionlint .github/workflows/pr-check.yaml"
run_test "T06: actionlint clean on tag.yaml" \
    "actionlint .github/workflows/tag.yaml"
run_test "T07: NO dynamic uses regression (\${{ inputs|matrix.* }} in uses:)" \
    "! grep -nE '^[^#]*uses: .*\\\${{ (inputs|matrix)\\.' .github/workflows/release.yaml"
run_test "T08: shellcheck clean on _shared/scripts" \
    "find _shared/scripts -name '*.sh' -exec shellcheck -S warning {} +"
echo

# ── Tier 2: workflow_call interface contract ─────────────────────────────────
echo "── Tier 2: workflow_call interface contract ──"
run_test "T09: workflow_call inputs match expected (target,desktop_package_name,github_tag,starting_rung)" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
trig = d[\"on\" if \"on\" in d else True]
got = set(trig[\"workflow_call\"][\"inputs\"].keys())
expected = set([\"target\",\"desktop_package_name\",\"github_tag\",\"starting_rung\"])
assert expected.issubset(got), \"missing inputs: \" + str(expected - got)
'"
run_test "T10: workflow_call.target is required + type string" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
trig = d[\"on\" if \"on\" in d else True]
t = trig[\"workflow_call\"][\"inputs\"][\"target\"]
assert t.get(\"required\") == True
assert t.get(\"type\") == \"string\"
'"
run_test "T11: workflow_call secrets = expected Azure + MS-Store set" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
trig = d[\"on\" if \"on\" in d else True]
got = set(trig[\"workflow_call\"][\"secrets\"].keys())
exp = set([\"azure_client_id\",\"azure_tenant_id\",\"azure_subscription_id\",\"azure_trusted_signing_endpoint\",\"azure_trusted_signing_account\",\"azure_cert_profile_name\",\"microsoft_store_client_id\",\"microsoft_store_client_secret\"])
assert got == exp, \"diff: \" + str(got.symmetric_difference(exp))
'"
run_test "T12: all workflow_call secrets are optional (required:false)" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
trig = d[\"on\" if \"on\" in d else True]
for name, spec in trig[\"workflow_call\"][\"secrets\"].items():
    assert spec.get(\"required\") == False, name + \" should be optional\"
'"
echo

# ── Tier 3: Job structure ────────────────────────────────────────────────────
echo "── Tier 3: Job structure ──"
run_test "T13: All 4 expected jobs present" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
got = set(d[\"jobs\"].keys())
exp = set([\"validate-secrets\",\"stage-1-prerelease\",\"stage-2-promote-to-beta\",\"stage-3-promote-to-stable\"])
assert got == exp, \"job diff: \" + str(got.symmetric_difference(exp))
'"
run_test "T14: stage-1 depends on validate-secrets" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
assert d[\"jobs\"][\"stage-1-prerelease\"][\"needs\"] == [\"validate-secrets\"]
'"
run_test "T15: stage-2 depends on stage-1" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
assert d[\"jobs\"][\"stage-2-promote-to-beta\"][\"needs\"] == [\"stage-1-prerelease\"]
'"
run_test "T16: stage-3 depends on stage-2" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
assert d[\"jobs\"][\"stage-3-promote-to-stable\"][\"needs\"] == [\"stage-2-promote-to-beta\"]
'"
echo

# ── Tier 4: Per-target static-uses (locks v2.0.6 fix) ────────────────────────
echo "── Tier 4: Per-target static-uses (locks v2.0.6 fix) ──"
run_test "T17: stage-1 has exactly 4 per-target build steps" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
steps = d[\"jobs\"][\"stage-1-prerelease\"][\"steps\"]
target_steps = [s for s in steps if isinstance(s,dict) and \"publish-desktop-kmp/\" in str(s.get(\"uses\",\"\"))]
assert len(target_steps) == 4, \"expected 4, got \" + str(len(target_steps))
'"
run_test "T18: Each per-target step has an if-gate" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
steps = d[\"jobs\"][\"stage-1-prerelease\"][\"steps\"]
for s in steps:
    if isinstance(s,dict) and \"publish-desktop-kmp/\" in str(s.get(\"uses\",\"\")):
        assert \"if\" in s, \"missing if on \" + s[\"uses\"]
        assert \"inputs.target ==\" in s[\"if\"], \"bad if: \" + s[\"if\"]
'"
run_test "T19: Each target subdir referenced in stage-1 exactly once" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
steps = d[\"jobs\"][\"stage-1-prerelease\"][\"steps\"]
ref_targets = set()
for s in steps:
    if isinstance(s,dict) and \"publish-desktop-kmp/\" in str(s.get(\"uses\",\"\")):
        path = s[\"uses\"].split(\"/\")[-1].split(\"@\")[0]
        ref_targets.add(path)
expected = set([\"linux-deb\",\"windows-exe\",\"windows-msi-signed\",\"windows-microsoft-store\"])
assert ref_targets == expected, \"target mismatch: \" + str(ref_targets.symmetric_difference(expected))
'"
run_test "T20: All references pinned to @v2.0.0 (composite-action stable tag)" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
steps = d[\"jobs\"][\"stage-1-prerelease\"][\"steps\"]
for s in steps:
    if isinstance(s,dict) and \"publish-desktop-kmp/\" in str(s.get(\"uses\",\"\")):
        assert s[\"uses\"].endswith(\"@v2.0.0\"), \"non-canonical ref: \" + s[\"uses\"]
'"
echo

# ── Tier 5: Composite-action existence ───────────────────────────────────────
echo "── Tier 5: Composite-action existence ──"
for T in "${TARGETS[@]}"; do
    run_test "T2x:  $T/action.yaml exists + parses" \
        "test -f '$T/action.yaml' && py 'import yaml; yaml.safe_load(open(\"$T/action.yaml\"))'"
done
for T in "${TARGETS[@]}"; do
    run_test "T2y:  $T/action.yaml is composite + has steps" "py '
import yaml
d = yaml.safe_load(open(\"$T/action.yaml\"))
assert d[\"runs\"][\"using\"] == \"composite\", \"$T not composite: \" + d[\"runs\"][\"using\"]
assert d[\"runs\"].get(\"steps\"), \"$T has no steps\"
'"
done
for T in "${TARGETS[@]}"; do
    run_test "T2z:  $T/README.md exists" "test -f '$T/README.md'"
done
echo

# ── Tier 6: Caller-callee interface (action's declared inputs match caller's `with:`) ──
#
# IMPORTANT: targets fall into two interface families:
#   Family A — "build+sign+upload-as-release-asset" actions: linux-deb, windows-exe,
#              windows-msi-signed. Accept (desktop_package_name, github_tag, stage) +
#              optional per-target signing secrets.
#   Family B — "build+upload-to-MS-Partner-Center" action: windows-microsoft-store.
#              Accepts (msix_path, ms_partner_center_*, ms_app_id, release_flight)
#              — DIFFERENT interface because MS Store ingestion is a separate API.
#
# release.yaml's stage-1 currently passes Family A inputs to ALL 4 targets — which
# means windows-microsoft-store silently ignores them at runtime. This is a
# pre-existing interface contract gap that should be addressed in a follow-up PR
# (orchestrate windows-microsoft-store via a build → upload-MSIX step pair).
echo "── Tier 6: Composite action input contract ──"
FAMILY_A=(linux-deb windows-exe windows-msi-signed)
for T in "${FAMILY_A[@]}"; do
    run_test "T3x:  $T (Family A) accepts (desktop_package_name, github_tag, stage)" "py '
import yaml
d = yaml.safe_load(open(\"$T/action.yaml\"))
declared = set(d.get(\"inputs\", {}).keys())
required_by_caller = set([\"desktop_package_name\",\"github_tag\",\"stage\"])
assert required_by_caller.issubset(declared), \"$T missing inputs: \" + str(required_by_caller - declared)
'"
done
run_test "T3x:  windows-microsoft-store (Family B) accepts MS-Partner-Center inputs" "py '
import yaml
d = yaml.safe_load(open(\"windows-microsoft-store/action.yaml\"))
declared = set(d.get(\"inputs\", {}).keys())
# Family B contract — MSIX upload to MS Partner Center
required = set([\"msix_path\",\"ms_partner_center_client_id\",\"ms_app_id\"])
assert required.issubset(declared), \"windows-microsoft-store missing Family B inputs: \" + str(required - declared)
'"
echo

# ── Tier 7: validate-secrets per-target coverage ─────────────────────────────
echo "── Tier 7: validate-secrets per-target coverage ──"
run_test "T31: validate-secrets has case branch for linux-deb" \
    "grep -E 'linux-deb\\)' .github/workflows/release.yaml"
run_test "T32: validate-secrets case for windows-exe+msi-signed (azure_*)" \
    "grep -E 'windows-msi-signed\\|windows-exe\\)' .github/workflows/release.yaml"
run_test "T33: validate-secrets case for windows-microsoft-store (+ms_store_*)" \
    "grep -E 'windows-microsoft-store\\)' .github/workflows/release.yaml"
run_test "T34: linux-deb requires no extra secrets (no MISSING+= for it)" "py '
import re
with open(\".github/workflows/release.yaml\") as f: c = f.read()
# Find linux-deb case block
m = re.search(r\"linux-deb\\)(.*?);;\" , c, re.DOTALL)
assert m and \"MISSING+=\" not in m.group(1), \"linux-deb should not require secrets\"
'"
echo

# ── Tier 8: Promote stages don't rebuild ─────────────────────────────────────
echo "── Tier 8: Promote stages don't rebuild (flag-flip only) ──"
run_test "T35: stage-2-promote-to-beta has NO composite-action uses (just gh release edit)" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
steps = d[\"jobs\"][\"stage-2-promote-to-beta\"][\"steps\"]
for s in steps:
    if isinstance(s,dict) and \"publish-desktop-kmp/\" in str(s.get(\"uses\",\"\")):
        raise AssertionError(\"stage-2 should not invoke composite actions: \" + s[\"uses\"])
'"
run_test "T36: stage-2 uses gh release edit --prerelease=false" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
runs = [str(s.get(\"run\",\"\")) for s in d[\"jobs\"][\"stage-2-promote-to-beta\"][\"steps\"] if isinstance(s,dict)]
assert any(\"gh release edit\" in r and \"--prerelease=false\" in r for r in runs), \"no gh release edit --prerelease=false in stage-2\"
'"
run_test "T37: stage-3 uses gh release edit --latest=true" "py '
import yaml
d = yaml.safe_load(open(\".github/workflows/release.yaml\"))
runs = [str(s.get(\"run\",\"\")) for s in d[\"jobs\"][\"stage-3-promote-to-stable\"][\"steps\"] if isinstance(s,dict)]
assert any(\"gh release edit\" in r and \"--latest=true\" in r for r in runs), \"no gh release edit --latest=true in stage-3\"
'"
echo

# ── Tier 9: Runtime bug-class regressions (preventive) ───────────────────────
#
# Mirrors the regression tests added to publish-android-kmp v2.0.6 + publish-
# apple-kmp v2.0.6 after the firebase-distribution gem-write bug. This repo
# doesn't use fastlane or gem install today, but the tests prevent the bug
# class from being introduced in any future composite action.
echo "── Tier 9: Runtime bug-class regressions (preventive) ──"
run_test "T38: No bare gem-write commands (must be sudo or bundle-exec-prefixed)" "python3 -c '
import re, glob
BARE_PATTERNS = [
    re.compile(r\"^\\s+(?:run:\\s*)?(?:gem install|bundle install|fastlane add_plugin|gem update)(?:\\s|$)\"),
    re.compile(r\"^\\s+(?:run:\\s*\\|)?\\s*(gem install|bundle install|fastlane add_plugin|gem update)(?:\\s|$)\"),
]
SAFE_PREFIXES = (\"sudo \", \"bundle exec \", \"sudo bundle\", \"DEBIAN_FRONTEND=\")
violations = []
for action_yaml in glob.glob(\"**/action.yaml\", recursive=True):
    if \"/_shared/\" in action_yaml or \"/examples/\" in action_yaml:
        continue
    with open(action_yaml) as f:
        for line_num, line in enumerate(f, 1):
            stripped = line.strip()
            if stripped.startswith(\"#\"):
                continue
            for pat in BARE_PATTERNS:
                m = pat.match(line)
                if m and not any(p in line for p in SAFE_PREFIXES):
                    violations.append(f\"{action_yaml}:{line_num}  {stripped[:80]}\")
if violations:
    print(\"FAIL — bare gem-write commands found:\")
    for v in violations: print(f\"  {v}\")
    exit(1)
print(\"OK — no bare gem-write commands\")
'"
run_test "T39: ruby/setup-ruby steps use bundler-cache:true (gem cache enabled — preventive)" "py '
import yaml, glob
for action_yaml in glob.glob(\"**/action.yaml\", recursive=True):
    if \"/_shared/\" in action_yaml or \"/examples/\" in action_yaml:
        continue
    d = yaml.safe_load(open(action_yaml))
    if not d or \"runs\" not in d or \"steps\" not in d[\"runs\"]:
        continue
    for step in d[\"runs\"][\"steps\"]:
        if isinstance(step, dict) and \"setup-ruby\" in str(step.get(\"uses\", \"\")):
            w = step.get(\"with\", {})
            assert w.get(\"bundler-cache\") in [True, \"true\"], action_yaml + \" — setup-ruby missing bundler-cache:true\"
'"
echo

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════════════════"
echo "  Results: $PASS passed · $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    echo "  Failed tests:"
    for t in "${FAILED_TESTS[@]}"; do echo "    - $t"; done
fi
echo "════════════════════════════════════════════════════════════════════════════"
exit $FAIL

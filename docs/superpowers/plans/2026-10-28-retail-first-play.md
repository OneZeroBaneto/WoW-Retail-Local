# Retail first-play Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement inline. Steps use checkbox syntax for tracking.

**Goal:** Make tomorrow's native Windows Retail test reproducible and diagnose failures before gameplay.
**Architecture:** Extend existing PowerShell orchestration with real-content checks and account/client setup; manually dispatched Windows CI builds the pinned patched core and tests a disposable installation.
**Tech Stack:** Existing PowerShell 7.4, TrinityCore C++20, MySQL8.0, VS2022, GitHub Actions.
**Spec:** ../specs/2026-10-28-retail-first-play.md

## Global Constraints
- Retail first because only Retail client is available; preserve Forever and share applicable fixes.
- Exact core/client/patch pins; loopback-only, separate data, no forced shutdowns or credential resets.
- No automatic launcher-license acceptance or unsupported build relabeling.
- Record Mac, Windows-build, DB, auth and real gameplay evidence separately.

## Review Focus
- Missing MySQL dependent OpenSSL DLLs must be copied before OpenSSL's selected libraries.
- Existing client portal settings must be backed up. Restore unchanged files exactly; preserve later non-portal preferences and refuse a conflicting portal.
- Existing game accounts cannot have their password silently replaced.
- Fresh setup can resume after a completed stage; failed or stale stages are not success.
- Packages/diagnostics must omit secrets and must not call untested gameplay passed.

### Task 1: Real Windows build pipeline
Files: scripts/ci/Build-Windows.ps1, .github/workflows/windows-build.yml, scripts/lib/Windows.psm1, Workspace.psm1, tests/Run.Tests.ps1.
Interfaces: Build-Core(..., WithTests), Install-RuntimeLibraries(settings,runtime); build.json retains source+patch provenance.
- [ ] Add failing regression for MySQL-specific libcrypto/libssl transitive dependencies, implement copy order, run full suite.
- [ ] Add manual CI: verified OpenSSL installer, static Boost, pinned source build, CTest, disposable DB import, BNet REST smoke and sanitized binary package.
- [ ] Validate workflow and PowerShell syntax; present concrete remote execution choice after workflow exists.

### Task 2: Data and client readiness
Files: scripts/lib/Readiness.psm1, scripts/Manage.ps1, tests/Readiness.Tests.ps1, docs/research.
Interfaces: Get-ReadinessSql(profile), Test-ReadinessRows(rows), Set-LocalClientPortal(path), Restore-ClientPortal(path).
- [ ] Inspect actual downloaded TDB in an isolated disposable database; record human starting rows, mobs, quests and loot.
- [ ] Write failing tests for missing starter/spawn/template/loot evidence and preserved client config; implement and run full suite.
- [ ] Add native Windows readiness action and reversible local portal setup; check client version and launcher provenance.

### Task 3: First-run handoff
Files: scripts/Setup.ps1, scripts/Account.ps1, setup/account/diagnostic batch entrypoints, docs and packages.
Interfaces: setup stages consume existing Manage actions; account creation uses owned supervisor console and verifies auth DB rows before recording success.
- [ ] Write behavioral tests for stage resume, wrong-build early stop and existing-account preservation; implement minimal setup helpers.
- [ ] Add normal-account creation and usable logs/diagnostics without secret export.
- [ ] Run portable suites and native console probe; independent final review; correct material findings; regenerate ZIPs and state remaining Windows/client tests.

Ruling: user already authorized implementation. Continue inline; no new design approval required. Existing codex/windows-preparation branch is isolated and clean at dee9425.

Ruling: WoW writes settings on exit. Preserve those later preferences and restore only the owned portal when necessary; rejecting every changed file would prevent normal relaunch and restore. Conflicting portals remain protected. Regression observed failing and then passing.

# Windows preparation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Prepare separate reproducible Windows-native Forever and Retail projects on macOS.
**Architecture:** Small PowerShell orchestration repositories with immutable upstream manifests; source fetched into ignored vendor/core. Local settings and secrets generate isolated runtime configuration. A supervisor owns exactly the processes it starts.
**Tech Stack:** PowerShell >=7.4, Git, CMake >=3.24, VS2022 x64, MySQL 8.0, OpenSSL 3, Boost, 7-Zip.
**Spec:** ../specs/2026-10-28-windows-server-preparation.md

## Global Constraints
- Windows deployment; macOS development and portable tests.
- Loopback only; dedicated MySQL directories and prefixed databases.
- No overwriting existing source changes, credentials, data or occupied ports.
- No automatic Battle.net updates or claim of verified gameplay.

## Review Focus
- Paths with spaces and command metacharacters: native argument arrays, no shell execution.
- Repeated preparation: credentials stable and configs remain attached to one root.
- Occupied ports/PID reuse: no other installation stopped or reused.
- Shutdown/backup failure: preserve data and refuse an inconsistent backup.
- Download/source mismatch: stop before install; fixed SHA and SHA-256 validation.

### Task 1: Workspace contract
Files: sources.lock.json, scripts/lib/Workspace.psm1, tests/Run.Tests.ps1.
Interfaces: Read-Profile, Initialize-Workspace, Read-LocalSettings, Assert-ClientVersion, Assert-FileHash, Get-RealmSql, Invoke-Native.
- [x] Write tests for repeat configure, unsafe paths, isolated database config, version/hash rejection, native argv and exit status; run RED.
- [x] Implement pure configuration/filesystem helpers and native boundary; run GREEN.

### Task 2: Windows preparation
Files: scripts/Manage.ps1, scripts/lib/Windows.psm1.
Interfaces: pinned source acquisition, native build/install, extraction and local database provisioning.
- [x] Add tests for source mismatch and data manifest validation; run RED.
- [x] Implement Windows-only entrypoints, dependency diagnostics, data extraction marker and DB bootstrap.
- [x] Check syntax and portable suite.

### Task 3: Owned runtime lifecycle
Files: scripts/lib/Process.psm1, scripts/Supervisor.ps1.
Interfaces: Start-OwnedProcess, Send-OwnedInput, Complete-OwnedProcess, Assert-PortsFree, shutdown/command request queue.
- [x] Write real child-process tests for arguments, output capture, console shutdown and conflict refusal; run RED.
- [x] Implement supervisor, stop path and offline MySQL backup; run GREEN.

### Task 4: Handoff
Files: README.md, docs/WINDOWS-ACCEPTANCE.md, .github/workflows/validate.yml, batch entrypoints, tests.
- [x] Create Retail profile from the same tested orchestration, with separate pins and database prefix.
- [x] Run complete portable suite for both repos and syntax checks for every PowerShell file.
- [x] Independent whole-project review, fix material issues, commit both repositories and package tracked files.
- [x] Record exact verified evidence and Windows/gameplay checks remaining.

Ruling: execution is authorized by the user's request to prepare everything; proceed inline without another approval round. Fresh repositories already provide isolation; no TBC worktree is needed.

Execution evidence: ../../VALIDATION.md. Windows build and gameplay are pending acceptance, not part of the completed Mac preparation evidence.

---
name: Known L2 gaps by sprint
description: Remediation items R-01..R-18 mapped to Métra development sprints, with their MASVS control and target file
type: project
---

**P-0b (current):**
- R-01 STORAGE-2: `android:allowBackup="false"` + `data_extraction_rules.xml` → AndroidManifest.xml
- R-02 CRYPTO-2: `getOrCreateDatabaseKey()` String→Uint8List + zero after use → key_management_service.dart, app_database.dart
- R-03 STORAGE-1: `IOSOptions(accessibility: KeychainAccessibility.whenUnlockedThisDeviceOnly)` → encryption_provider.dart

**P-1 (quality + CI) — P-1 shipped, items NOT closed:**
- R-01 STORAGE-2: still open — tag v0.1.0-p1 L2 blocker (19/24=79%, need ≥20/24=83%)
- R-04 CODE-3: `flutter pub audit` + `osv-scanner` in CI quality.yml — not closed
- R-05 CODE-1: `minSdk = 26` explicit in build.gradle.kts — not closed

**P-1 new observations (not yet R-items in plan):**
- Router date parsing: `app_router.dart:48-53` `int.parse` without try/catch — hardening only, no MASVS FAIL
- TextFieldMetra notes: missing `enableSuggestions: false` / `autocorrect: false` — L2 PLATFORM-3 gap, address in P-5 with R-06/R-09

**Pre-distribution (BLOCKER — before any external release):**
- R-10 RESILIENCE-2: generate release keystore; remove debug signing config from release build type

**P-5 (Settings + UI):**
- R-06 PLATFORM-3: FLAG_SECURE Android + blur iOS on sensitive screens
- R-07 AUTH-2: optional biometric lock with BIOMETRIC_STRONG + CryptoObject binding
- R-08 AUTH-3: re-auth on DB deletion and backup restore overwrite
- R-09 STORAGE-2: screenshot suppression UI component

**P-6 (Cloud sync):**
- R-11 NETWORK-1: network_security_config.xml with cleartextTrafficPermitted=false
- R-12 PLATFORM-1: OAuth callback via App Links (Digital Asset Links), not custom URL scheme
- R-13 AUTH-1: OAuth token storage in secure storage, never in DB

**P-7 (Polish + Release):**
- R-14 RESILIENCE-1: Play Integrity API + App Attest (non-blocking warning)
- R-15 RESILIENCE-3: `flutter build --obfuscate --split-debug-info` + R8/ProGuard
- R-16 RESILIENCE-4: re-evaluate anti-Frida; passive detection only if at all
- R-17 PRIVACY-3: publish Privacy Policy on GitHub Pages before store submission
- R-18 CODE-2: Play Core In-App Update post-v1.0

**Why:** Single source of truth for outstanding security work items, so they don't need to be re-derived from the audit docs each session.
**How to apply:** When a PR closes one of these items, mark it resolved here and update project_audit_state.md accordingly.

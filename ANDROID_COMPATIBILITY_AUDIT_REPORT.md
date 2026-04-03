# Android compatibility audit report

**Date:** Post-audit  
**Goal:** Maximum device compatibility and Play Store production release (no UI/business logic changes).

---

## Summary

- **Gradle (app):** Already compliant — no code changes.
- **Manifest:** Optional `uses-feature` entries added so hardware is not required.
- **Billing:** Unchanged; `com.android.vending.BILLING` permission already present.
- **Firebase / billing logic:** Not modified.

---

## 1. Gradle config (`android/app/build.gradle.kts`)

**Status: No changes.**

Current `defaultConfig` already matches requirements:

- `minSdk = 21` (Kotlin DSL; equivalent to `minSdkVersion 21`)
- `targetSdk = 34`
- `multiDexEnabled = true`

There is **no** `ndk { abiFilters ... }` block, so all ABIs are allowed (arm64-v8a, armeabi-v7a, x86_64, x86 as applicable).

---

## 2. Manifest cleanup (`android/app/src/main/AndroidManifest.xml`)

**Status: Updated.**

- **Before:** No `uses-feature` elements (plugins could merge in required features and reduce device support).
- **After:** Added explicit optional features so merged manifest does not require hardware and Play Console device support is not unnecessarily restricted:

  - `android.hardware.camera` — `required="false"`
  - `android.hardware.camera.autofocus` — `required="false"`
  - `android.hardware.location.gps` — `required="false"`
  - `android.hardware.location` — `required="false"`
  - `android.hardware.touchscreen` — `required="false"` (helps TV/automotive)
  - `android.hardware.wifi` — `required="false"`
  - `android.hardware.telephony` — `required="false"`
  - `android.hardware.microphone` — `required="false"`

No existing `uses-feature` or `required="true"` entries were present to remove; only optional declarations were added.

---

## 3. Device-blocking configs

**Status: None found in source.**

- Searched for: `uses-feature`, `required="true"`, `abiFilters`, `split`, `abi` in `*.xml`, `*.gradle`, `*.kts`.
- **Source:** No `abiFilters`, no `splits` ABI restrictions, no `uses-feature` with `required="true"` in app or Android source.
- **Build outputs** under `build/` contain merged manifest with `required="false"` from dependencies; those are generated and not edited.

---

## 4. Multidex

**Status: No changes.**

Already in `android/app/build.gradle.kts`:

- `defaultConfig { multiDexEnabled = true }`
- `implementation("androidx.multidex:multidex:2.0.1")`

---

## 5. Play Billing

**Status: No changes.**

- Permission present: `<uses-permission android:name="com.android.vending.BILLING"/>`
- Billing and subscription code were not modified.

---

## 6. Bundle config

**Status: No changes.**

`android/app/build.gradle.kts` already contains:

```kotlin
bundle {
    language { enableSplit = false }
    density { enableSplit = true }
    abi { enableSplit = false }
}
```

---

## 7. Flutter build

Release App Bundle command (unchanged):

```bash
flutter build appbundle --release
```

Use this for Play Store uploads.

---

## 8. Files modified

| File | Change |
|------|--------|
| **android/app/src/main/AndroidManifest.xml** | Added 8 optional `<uses-feature android:required="false"/>` entries (camera, camera.autofocus, location.gps, location, touchscreen, wifi, telephony, microphone) to avoid required hardware and improve device/tablet compatibility and Play Console device support. |

No other files were modified. Gradle, bundle, multidex, and billing were already in a compliant state.

---

## Checklist

- [x] minSdk 21, targetSdk 34, multiDexEnabled true  
- [x] No abiFilters; all ABIs allowed  
- [x] Optional uses-feature (no required hardware)  
- [x] No device-blocking configs in source  
- [x] Multidex enabled and dependency present  
- [x] BILLING permission present; billing code unchanged  
- [x] Bundle: language split off, density split on, abi split off  
- [x] Flutter build: `flutter build appbundle --release`  
- [x] No UI or business logic changes  

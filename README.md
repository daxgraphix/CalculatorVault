# Calculator Vault

A disguised calculator app with an encrypted private vault, built Flutter-first
following your established stack: **Riverpod + GoRouter + Hive (hand-written
TypeAdapters, no build_runner) + feature-first Clean Architecture**.

## What's implemented (full source, runnable MVP+)

- **Calculator**: real tokenizer → recursive-descent parser → evaluator
  (correct operator precedence, not string-splitting), memory (MC/MR/M+/M−/MS),
  history (Hive-backed), optional scientific functions, accessible semantic
  labels on every key.
- **Vault access trigger**: long-press `=` always opens vault sign-in;
  optionally set a secret numeric code in Settings that opens the vault
  instead of showing a calculator result.
- **Authentication**: PIN (4–8 digits, weak-PIN rejection) or password
  (8+ chars). Credential is never stored — only an Argon2id-derived verifier
  hash. 5 failed attempts triggers an exponential-backoff lockout.
- **Crypto**: Argon2id key derivation (same approach as SafeText), AES-256-GCM
  authenticated encryption, streaming/chunked file encryption so large videos
  never load fully into RAM. A random master key is generated once and
  "wrapped" (encrypted) by the PIN/password-derived key — changing your PIN
  only re-wraps this key, it never re-encrypts your files.
- **Key protection**: the wrapped master key and credential verifier are
  stored via `flutter_secure_storage`, which on Android uses
  `EncryptedSharedPreferences` backed by the Android Keystore (hardware-backed
  on supported devices). See the note below on why this replaces a hand-rolled
  Keystore MethodChannel.
- **Vault**: encrypted photos, videos, audio, documents; folders/albums;
  favorites; universal search; sort (newest/oldest/name/size); multi-select
  (favorite / move / delete); recycle bin with configurable retention;
  encrypted thumbnails (never written to disk in plaintext).
- **Import pipeline**: encrypt → verify → commit-to-database, in that order,
  so a crash mid-import never leaves an orphaned database record.
- **Backup/restore**: `.cvault` encrypted archive with its own independent
  password (different from your vault PIN/password), so backups stay
  portable without exposing your device's key hierarchy.
- **Auto-lock**: configurable duration (Immediate/30s/1m/5m/10m/Never),
  app-lifecycle-aware (backgrounding locks the session per policy).
- **Screen protection**: `FLAG_SECURE` via a small native Kotlin
  `MethodChannel` (`android/.../MainActivity.kt`) — this is the one place
  Flutter genuinely can't do it alone.
- **Settings**: change PIN/password (re-wraps master key only), auto-lock,
  screen protection toggle, recycle-bin retention, theme, backup/restore,
  reset app (double-confirmed, wipes everything).
- **No unnecessary permissions**: manifest only requests media read access —
  no INTERNET, location, contacts, SMS, or call-log permissions.

## Two deliberate deviations from the original spec — and why

1. **Hive instead of Drift.** Drift requires `build_runner` codegen; per your
   established convention across SafeText/ChuoBaz/TAI Translator, this build
   uses Hive with hand-written `TypeAdapter`s (`lib/core/storage/models/`) so
   `flutter pub get && flutter run` works with zero codegen step.
2. **`flutter_secure_storage` instead of a raw Keystore MethodChannel for key
   wrapping.** On Android this already stores data in
   `EncryptedSharedPreferences` with the encryption key held in the Android
   Keystore — so you get real hardware-backed key protection without
   hand-rolling `KeyGenParameterSpec`/`Cipher` Kotlin code. The **screen
   protection** (`FLAG_SECURE`) native bridge *is* included, since Flutter has
   no equivalent for that one.
   If you later want StrongBox pinning or custom key attestation, implement
   the `SecureKeyStore` interface (`lib/core/security/secure_key_store.dart`)
   natively — nothing above that layer needs to change.

## Running it

```bash
flutter pub get
flutter run
```

No `build_runner`, no codegen, no backend, no signing setup required for a
debug build. The release `buildTypes` block in `android/app/build.gradle`
currently signs with the debug key so `flutter run --release` also works out
of the box — **replace this with your own signing config before publishing**.

Copy `android/local.properties.example` to `android/local.properties` and set
`sdk.dir` / `flutter.sdk` for your machine (this file is normally
machine-specific and isn't meant to be committed).

## What you'd still want to add before a store release

- **App icon**: placeholder icons are included (`android/.../mipmap-*/ic_launcher.png`)
  so the project builds — swap in real launcher art.
- **Adaptive icon / notification icon** if you want them.
- **Release signing config** (currently uses the debug keystore).
- **Scientific mode row layout** only shows 6 functions by default (sin, cos,
  tan, log, ln, sqrt) — asin/acos/atan/power/π/e are implemented in
  `ScientificFunctions` but not yet wired to extra buttons; trivial to add.
- **EncryptedThumbnail** currently stores the full original image as the
  "thumbnail" for photos (simplest correct approach) rather than a downscaled
  copy — fine functionally, but a real downscale pass (e.g. via `image`
  package) would cut vault storage size noticeably for large photo libraries.
- Real device testing of the streaming encrypt/decrypt path with multi-GB
  video files, and of Argon2id timing on lower-end Android devices (tune the
  `memory`/`iterations` params in `CryptoService.deriveKey` if unlock feels
  slow on older hardware).

## Project structure

```
lib/
  app/                    theme, router, root widget
  core/
    crypto/                Argon2id + AES-256-GCM (CryptoService)
    security/               credential verification, session/lock manager, secure key store
    storage/                Hive boxes, hand-written models, file manager
    platform/               FLAG_SECURE MethodChannel bridge
  features/
    calculator/             engine (tokenizer/parser/evaluator), state, UI
    onboarding/              welcome → privacy → security choice → credential setup
    authentication/          vault unlock screen
    vault/                   home, media grid, viewer, import, recycle bin
    folders/                 albums
    backup/                  .cvault create/restore
    settings/                all settings screens
android/
  app/src/main/kotlin/.../MainActivity.kt   FLAG_SECURE bridge
```

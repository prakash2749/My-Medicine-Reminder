# Medicine Reminder 💊

A modern Flutter application designed to help users track, manage, and never miss their daily medications. Built with Flutter, Provider state management, and Supabase backend services.

---

## 🚀 Getting Started

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run Locally in Debug Mode
The app requires Supabase environment variables supplied via `--dart-define-from-file`:

```bash
flutter run --dart-define-from-file=config/dev.json
```

---

## 🧪 Local Pre-Push Checklist (CI/CD Verification)

Before pushing any commits to GitHub, run these commands to ensure GitHub Actions CI passes:

```bash
# 1. Format code (required by CI)
dart format lib test

# 2. Check for syntax, static analysis, and lint errors
flutter analyze

# 3. Run all unit and widget tests with coverage
flutter test --coverage
```

> **Quick one-liner for PowerShell (Windows):**
> ```powershell
> dart format lib test; flutter analyze; flutter test
> ```

---

## 📦 Build & Release (APK & AAB)

All release commands require the environment configuration file:

### 1. Standard Release APK (Universal)
Generates a single standalone APK suitable for direct device testing and sideloading:
```bash
flutter build apk --release --dart-define-from-file=config/dev.json
```
- **Output:** `build/app/outputs/flutter-apk/app-release.apk`

### 2. Split-per-ABI APKs (Optimized size)
Generates individual APKs per CPU architecture (`arm64-v8a`, `armeabi-v7a`, `x86_64`) for smaller download sizes:
```bash
flutter build apk --release --split-per-abi --dart-define-from-file=config/dev.json
```
- **Output:** `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, etc.

### 3. Google Play Store App Bundle (AAB)
Generates the Android App Bundle for submission to Google Play Console:
```bash
flutter build appbundle --release --dart-define-from-file=config/dev.json
```
- **Output:** `build/app/outputs/bundle/release/app-release.aab`

### 4. Clean Build Cache
If you encounter stale build artifacts or configuration caching issues:
```bash
flutter clean
flutter pub get
```

---

## ⚙️ GitHub Actions CI/CD Setup

### Required Variables (`Settings` > `Secrets and variables` > `Actions` > `Variables`)
| Variable | Description | Example / Recommended Value |
|---|---|---|
| `FLUTTER_VERSION` | Target Flutter SDK version for CI runner | `3.47.6` |
| `SUPABASE_CLI_VERSION` | Version of Supabase CLI for database migrations | `latest` |

### Required Secrets (`Settings` > `Secrets and variables` > `Actions` > `Secrets`)
*(Required for `deliver-staging-db.yml` database deployment)*
| Secret | Description |
|---|---|
| `SUPABASE_ACCESS_TOKEN` | Personal Access Token from Supabase account |
| `SUPABASE_DB_PASSWORD` | Database password for staging project |
| `SUPABASE_PROJECT_REF` | Staging project reference ID |

---

## 🏗️ Architecture & Structure
For detailed component structure, state management patterns, and best practices, see [ARCHITECTURE.md](ARCHITECTURE.md).

# Recipe App

Cross-platform recipe manager (iOS, iPadOS, macOS, Windows) built with Flutter.

This repository currently contains Milestone 1:
- App shell/navigation for v1 screens
- Local SQLite database bootstrap for offline-first foundation
- Passing analysis and tests

## Local Setup

Flutter SDK is installed at:
- `<path-to-your-flutter-sdk>`

Optional: add Flutter to your shell PATH:

```bash
echo 'export PATH="<path-to-your-flutter-sdk>/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## Run Commands

From the repository root:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d macos
```

## Web/GitHub Pages

From the repository root, use the following command sequence to (re)generate the static web artifact for GitHub Pages:

```bash
flutter config --enable-web
flutter create --platforms=web .
flutter pub get
flutter build web --release
ls -la build/web/index.html
```

Notes:
- `flutter build web` writes output to `build/web/` by default.
- `ls -la build/web/index.html` is the quick verification step that confirms `index.html` was produced.
- If you publish from GitHub Pages, upload or deploy the contents of `build/web/`.

## Project Notes

- Product scope and requirements are in `PRODUCT_V1.md`.
- Main app entry is `lib/main.dart`.
- Database bootstrap is `lib/data/app_database.dart`.

## Safari Extension (Milestone 7 in progress)

Safari extension source is under:

- `safari_extension/web`

Setup instructions are in:

- `safari_extension/README.md`

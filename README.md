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

This project includes a GitHub Actions workflow at `.github/workflows/deploy-pages.yml`
that builds and deploys the web app to GitHub Pages whenever changes are pushed
to `main`.

### One-time repository setup (GitHub)

1. Open **Settings → Pages**.
2. Set **Source** to **GitHub Actions**.

### Local build verification

From the repository root, use the following command sequence to generate and
verify the same kind of static artifact used by Pages:

```bash
flutter config --enable-web
flutter pub get
flutter build web --release --base-href /<repository-name>/
ls -la build/web/index.html
```

Notes:
- `flutter build web` writes output to `build/web/` by default.
- The `--base-href /<repository-name>/` argument is required for project sites
  served from `https://<owner>.github.io/<repository-name>/`.
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

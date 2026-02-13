# Recipe App

Cross-platform recipe manager (iOS, iPadOS, macOS, Windows) built with Flutter.

This repository currently contains Milestone 1:
- App shell/navigation for v1 screens
- Local SQLite database bootstrap for offline-first foundation
- Passing analysis and tests

## Local Setup

Flutter SDK is installed at:
- `/Users/dougshay/flutter`

Optional: add Flutter to your shell PATH:

```bash
echo 'export PATH="/Users/dougshay/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## Run Commands

From `/Users/dougshay/Developer/RecipeApp`:

```bash
/Users/dougshay/flutter/bin/flutter pub get
/Users/dougshay/flutter/bin/flutter analyze
/Users/dougshay/flutter/bin/flutter test
/Users/dougshay/flutter/bin/flutter run -d macos
```

## Project Notes

- Product scope and requirements are in `/Users/dougshay/Developer/RecipeApp/PRODUCT_V1.md`.
- Main app entry is `/Users/dougshay/Developer/RecipeApp/lib/main.dart`.
- Database bootstrap is `/Users/dougshay/Developer/RecipeApp/lib/data/app_database.dart`.

## Safari Extension (Milestone 7 in progress)

Safari extension source is under:

- `/Users/dougshay/Developer/RecipeApp/safari_extension/web`

Setup instructions are in:

- `/Users/dougshay/Developer/RecipeApp/safari_extension/README.md`

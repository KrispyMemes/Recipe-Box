# Safari Extension (v2)

This folder contains a Safari Web Extension scaffold that sends recipe URLs
into the app through the existing deep link:

- `recipeapp://import?url=<encoded-http-url>`

## Web Extension Source

- `web/manifest.json`
- `web/background.js`
- `web/popup.html`
- `web/popup.css`
- `web/popup.js`

## Build a Safari App Extension (macOS)

Run from this repository root:

```bash
xcrun safari-web-extension-converter \
  ./safari_extension/web \
  --project-location ./safari_extension/generated \
  --app-name "Recipe App Safari Extension" \
  --bundle-identifier "com.example.recipeapp.safari"
```

This creates an Xcode project under:

- `safari_extension/generated`

Then:

1. Open the generated Xcode project.
2. Select the app scheme and run it once.
3. In Safari: `Settings` -> `Extensions` -> enable `Recipe App Safari Extension`.
4. Use the toolbar popup button `Save Recipe URL`.

## Notes

- The extension requires your Flutter app to be installed/running, since it
  launches `recipeapp://...` deep links.
- If the current page is not `http/https`, popup will show a validation error.

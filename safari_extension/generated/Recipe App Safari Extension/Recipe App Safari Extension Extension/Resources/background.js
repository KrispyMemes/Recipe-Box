const ext = globalThis.browser ?? globalThis.chrome;

function normalizeImportUrl(raw) {
  if (!raw || typeof raw !== "string") {
    return null;
  }

  const value = raw.trim();
  if (!value) {
    return null;
  }

  try {
    const parsed = new URL(value);
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
      return null;
    }
    return parsed.toString();
  } catch (_) {
    return null;
  }
}

function buildDeepLink(url) {
  return `recipeapp://import?url=${encodeURIComponent(url)}`;
}

async function openRecipeImport(url) {
  const normalized = normalizeImportUrl(url);
  if (!normalized) {
    return { ok: false, error: "invalid_url" };
  }

  const deepLink = buildDeepLink(normalized);
  await ext.tabs.create({ url: deepLink });
  return { ok: true };
}

async function openRecipeImportFromTab(tab) {
  const url = tab?.url ?? "";
  return openRecipeImport(url);
}

if (ext.runtime?.onInstalled) {
  ext.runtime.onInstalled.addListener(() => {
    if (!ext.contextMenus?.create) {
      return;
    }

    ext.contextMenus.create({
      id: "recipe-app-save-link",
      title: "Save Link to Recipe App",
      contexts: ["link"],
    });

    ext.contextMenus.create({
      id: "recipe-app-save-page",
      title: "Save Page to Recipe App",
      contexts: ["page"],
    });
  });
}

if (ext.contextMenus?.onClicked) {
  ext.contextMenus.onClicked.addListener(async (info, tab) => {
    if (info.menuItemId === "recipe-app-save-link" && info.linkUrl) {
      await openRecipeImport(info.linkUrl);
      return;
    }

    if (info.menuItemId === "recipe-app-save-page") {
      await openRecipeImportFromTab(tab);
    }
  });
}

if (ext.runtime?.onMessage) {
  ext.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    if (!message || message.type !== "save-url") {
      return false;
    }

    openRecipeImport(message.url)
      .then((result) => sendResponse(result))
      .catch((error) =>
        sendResponse({ ok: false, error: String(error ?? "unknown_error") }),
      );

    return true;
  });
}

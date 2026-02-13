const ext = globalThis.browser ?? globalThis.chrome;

const urlInput = document.getElementById("url-input");
const saveButton = document.getElementById("save-button");
const statusNode = document.getElementById("status");

function setStatus(message, kind = "") {
  statusNode.textContent = message;
  statusNode.className = kind;
}

function normalizeHttpUrl(raw) {
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

async function getActiveTabUrl() {
  const tabs = await ext.tabs.query({ active: true, currentWindow: true });
  if (!tabs || tabs.length === 0) {
    return "";
  }

  const tab = tabs[0];
  const tabUrl = tab?.url ?? "";
  return normalizeHttpUrl(tabUrl) ?? "";
}

async function sendUrlToApp(url) {
  return ext.runtime.sendMessage({ type: "save-url", url });
}

async function init() {
  const activeUrl = await getActiveTabUrl();
  urlInput.value = activeUrl;
  if (!activeUrl) {
    setStatus("This tab does not have a valid http/https URL.", "error");
  }
}

saveButton.addEventListener("click", async () => {
  const normalized = normalizeHttpUrl(urlInput.value);
  if (!normalized) {
    setStatus("Enter a valid http/https URL.", "error");
    return;
  }

  saveButton.disabled = true;
  setStatus("Opening Recipe App…");

  try {
    const response = await sendUrlToApp(normalized);
    if (!response?.ok) {
      setStatus("Could not open Recipe App.", "error");
      return;
    }

    setStatus("Sent to Recipe App.", "success");
    window.close();
  } catch (_) {
    setStatus("Could not open Recipe App.", "error");
  } finally {
    saveButton.disabled = false;
  }
});

init().catch(() => {
  setStatus("Unable to load current tab URL.", "error");
});

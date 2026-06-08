(() => {
  const status = document.getElementById("demo-status");
  const renderingMode = document.getElementById("rendering-mode");
  const lifecycleState = document.getElementById("lifecycle-state");
  const counterValue = document.getElementById("counter-value");
  const incrementBtn = document.getElementById("increment-btn");
  const themeBtn = document.getElementById("theme-btn");
  const typedInput = document.getElementById("typed-input");
  const typedText = document.getElementById("typed-text");
  const lastKey = document.getElementById("last-key");
  const channelState = document.getElementById("channel-state");

  if (!status || !renderingMode || !lifecycleState || !counterValue || !incrementBtn || !themeBtn || !typedInput || !typedText || !lastKey || !channelState) {
    return;
  }

  const state = {
    clickCount: 0,
    typedText: "",
    lastKey: "",
    lastAction: "init",
    connected: false,
    lifecycle: "boot",
  };

  const hasIpc = () => Boolean(window.ipc && typeof window.ipc.postMessage === "function");

  const emitLifecycle = (eventName, extra = {}) => {
    state.lifecycle = eventName;
    lifecycleState.textContent = eventName;
    renderingMode.textContent = hasIpc() ? "native_webview_ipc" : "fallback_preview_only";
    if (!hasIpc()) {
      return;
    }
    window.ipc.postMessage(JSON.stringify({
      source: "hermes_interactive",
      type: "browser_view_lifecycle",
      event: eventName,
      rendering_mode: "native_webview_ipc",
      ...extra,
    }));
  };

  const render = () => {
    counterValue.textContent = String(state.clickCount);
    typedText.textContent = state.typedText === "" ? "(none)" : state.typedText;
    lastKey.textContent = state.lastKey === "" ? "(none)" : state.lastKey;
    channelState.textContent = state.connected ? "connected" : "disconnected";
  };

  const publishState = () => {
    if (hasIpc()) {
      state.connected = true;
    }
    const payload = {
      source: "hermes_interactive",
      type: "browser_test_state",
      click_count: state.clickCount,
      typed_text: state.typedText,
      last_key: state.lastKey,
      last_action: state.lastAction,
      connected: state.connected,
      document_loaded: true,
      dom_ready: true,
      interactive_ready: true,
    };
    if (state.connected) {
      window.ipc.postMessage(JSON.stringify(payload));
    }
    render();
  };

  const applyKey = (key) => {
    state.lastAction = "key";
    state.lastKey = key;
    publishState();
  };

  const applyType = (text) => {
    state.lastAction = "type";
    state.typedText += text;
    typedInput.value = state.typedText;
    publishState();
  };

  const applyClick = () => {
    state.lastAction = "click";
    state.clickCount += 1;
    publishState();
  };

  status.textContent = "Local JavaScript loaded successfully.";
  emitLifecycle("document_loaded", { document_loaded: true });

  incrementBtn.addEventListener("click", (event) => {
    event.preventDefault();
    applyClick();
  });

  themeBtn.addEventListener("click", (event) => {
    event.preventDefault();
    document.body.classList.toggle("js-glow");
  });

  typedInput.addEventListener("input", () => {
    state.lastAction = "type";
    state.typedText = typedInput.value;
    publishState();
  });

  typedInput.addEventListener("keydown", (event) => {
    applyKey(event.key);
  });

  window.addEventListener("keydown", (event) => {
    applyKey(event.key);
  });

  const coerceTestInputMessage = (event) => {
    const raw = event && (event.detail !== undefined ? event.detail : event.data);
    if (!raw) {
      return null;
    }
    if (typeof raw === "string") {
      try {
        return JSON.parse(raw);
      } catch (_err) {
        return null;
      }
    }
    if (typeof raw === "object") {
      return raw;
    }
    return null;
  };

  const handleTestInputMessage = (event) => {
    const data = coerceTestInputMessage(event);
    if (!data || data.type !== "browser_test_input" || data.source !== "hermes_os") {
      return;
    }
    const action = data.action;
    const payload = data.payload || {};
    if (action === "key") {
      applyKey(String(payload.key || ""));
      emitLifecycle("test_input_roundtrip", { action: "key" });
      return;
    }
    if (action === "type") {
      applyType(String(payload.text || ""));
      emitLifecycle("test_input_roundtrip", { action: "type" });
      return;
    }
    if (action === "click" && String(payload.target || "increment") === "increment") {
      applyClick();
      emitLifecycle("test_input_roundtrip", { action: "click" });
    }
  };

  window.addEventListener("message", handleTestInputMessage);
  document.addEventListener("message", handleTestInputMessage);

  document.addEventListener("DOMContentLoaded", () => {
    emitLifecycle("dom_ready", { dom_ready: true });
  });
  window.addEventListener("load", () => {
    emitLifecycle("interactive_ready", { interactive_ready: true });
  });

  emitLifecycle("dom_ready", { dom_ready: true });
  emitLifecycle("interactive_ready", { interactive_ready: true });
  publishState();
})();

(() => {
  const ids = {
    stageTitle: "gauntlet-stage-title",
    objective: "gauntlet-objective",
    progress: "gauntlet-progress",
    result: "gauntlet-result",
    code: "gauntlet-code",
    debugLine: "gauntlet-debug-line",
    stateView: "gauntlet-state-view",
    log: "gauntlet-progress-log",
    startBtn: "gauntlet-start-btn",
    targetBtn: "gauntlet-target-btn",
    decoyBtn: "gauntlet-decoy-btn",
    targetCount: "gauntlet-target-count",
    readyForm: "gauntlet-stage-3-form",
    readyInput: "gauntlet-ready-input",
    loginForm: "gauntlet-stage-4-form",
    loginUser: "gauntlet-login-user",
    loginPass: "gauntlet-login-pass",
    checkbox: "gauntlet-checkbox",
    radio: "gauntlet-radio",
    select: "gauntlet-select",
    keyCapture: "gauntlet-key-capture",
    keySequenceView: "gauntlet-key-sequence-view",
    scrollBox: "gauntlet-stage-7-scroll",
    hiddenSwitch: "gauntlet-hidden-switch",
    blueBtn: "gauntlet-blue-btn",
    greenBtn: "gauntlet-green-btn",
    redBtn: "gauntlet-red-btn",
    colorSequenceView: "gauntlet-color-sequence-view",
    openModal: "gauntlet-open-modal",
    modal: "gauntlet-modal",
    closeModal: "gauntlet-close-modal",
    continueBtn: "gauntlet-continue-btn",
  };

  const get = (id) => document.getElementById(id);
  const el = {};
  for (const key of Object.keys(ids)) {
    el[key] = get(ids[key]);
  }

  const required = [
    "stageTitle", "objective", "progress", "result", "code", "debugLine", "stateView", "log",
    "startBtn", "targetBtn", "decoyBtn", "targetCount", "readyForm", "readyInput",
    "loginForm", "loginUser", "loginPass", "checkbox", "radio", "select", "keyCapture",
    "keySequenceView", "scrollBox", "hiddenSwitch", "blueBtn", "greenBtn", "redBtn",
    "colorSequenceView", "openModal", "modal", "closeModal", "continueBtn",
  ];

  for (const key of required) {
    if (!el[key]) {
      return;
    }
  }

  const STAGES = [
    "Start",
    "Click Target x3 without decoy",
    "Type hermes-ready and submit",
    "Fake login with agent / open-sesame",
    "Checkbox/radio/select form",
    "Keyboard sequence ArrowUp ArrowRight ArrowDown ArrowLeft Enter",
    "Scroll hidden switch",
    "Button sequence Blue Green Red",
    "Modal close + continue",
    "Completion summary",
  ];

  const OBJECTIVES = [
    "Press Start.",
    "Click Target exactly 3 times. Do not click Decoy.",
    "Type hermes-ready then submit.",
    "Submit user=agent pass=open-sesame.",
    "Set checkbox true, radio true, and select beta.",
    "Focus key field and enter the exact key sequence.",
    "Scroll the box to bottom, then activate Hidden Switch.",
    "Press Blue, then Green, then Red.",
    "Open modal, close it, then press Continue.",
    "Read summary and completion code.",
  ];

  const state = {
    stage: 1,
    completed: false,
    completionCode: "",
    failures: 0,
    targetClicks: 0,
    decoyClicks: 0,
    readyValue: "",
    loginUser: "",
    loginPass: "",
    checkbox: false,
    radio: false,
    select: "",
    keySequence: [],
    keySequenceExpected: ["ArrowUp", "ArrowRight", "ArrowDown", "ArrowLeft", "Enter"],
    scrolledBottom: false,
    colorSequence: [],
    modalOpened: false,
    modalClosed: false,
    log: [],
    debug: "boot",
  };

  window.HERMES_GAUNTLET_STATE = state;
  window.__hermesGauntlet = state;

  const addLog = (text) => {
    state.log.push(text);
    const li = document.createElement("li");
    li.textContent = text;
    el.log.appendChild(li);
  };

  const syncStateView = () => {
    const publicState = {
      stage: state.stage,
      stageName: STAGES[state.stage - 1],
      completed: state.completed,
      completionCode: state.completionCode,
      failures: state.failures,
      targetClicks: state.targetClicks,
      decoyClicks: state.decoyClicks,
      readyValue: state.readyValue,
      loginUser: state.loginUser,
      checkbox: state.checkbox,
      radio: state.radio,
      select: state.select,
      keySequence: state.keySequence,
      scrolledBottom: state.scrolledBottom,
      colorSequence: state.colorSequence,
      modalOpened: state.modalOpened,
      modalClosed: state.modalClosed,
      debug: state.debug,
    };
    el.stateView.textContent = JSON.stringify(publicState, null, 2);
  };

  const refresh = () => {
    el.stageTitle.textContent = "Stage " + String(state.stage) + " — " + STAGES[state.stage - 1];
    el.objective.textContent = OBJECTIVES[state.stage - 1];
    el.progress.textContent = String(Math.max(state.stage - 1, 0)) + " / 10";
    el.result.textContent = state.completed ? "PASS" : "IN PROGRESS";
    el.code.textContent = state.completed ? state.completionCode : "(locked)";
    el.targetCount.textContent = String(state.targetClicks) + " / 3";
    el.keySequenceView.textContent = state.keySequence.length ? state.keySequence.join(" ") : "(none)";
    el.colorSequenceView.textContent = state.colorSequence.length ? state.colorSequence.join(" ") : "(none)";
    el.debugLine.textContent = state.debug;
    syncStateView();
  };

  const setDebug = (text) => {
    state.debug = text;
    refresh();
  };

  const at = (n) => state.stage === n;

  const fail = (reason) => {
    state.failures += 1;
    addLog("FAIL: " + reason);
    setDebug("fail:" + reason);
  };

  const advance = (reason) => {
    addLog("PASS stage " + String(state.stage) + ": " + reason);
    if (state.stage < 10) {
      state.stage += 1;
      setDebug("pass:" + reason);
      return;
    }
    state.completed = true;
    state.completionCode = "HERMES-GAUNTLET-COMPLETE";
    setDebug("complete");
  };

  el.startBtn.addEventListener("click", () => {
    if (!at(1)) {
      fail("start_wrong_stage");
      return;
    }
    advance("start");
  });

  el.targetBtn.addEventListener("click", () => {
    if (!at(2)) {
      fail("target_wrong_stage");
      return;
    }
    if (state.decoyClicks > 0) {
      fail("decoy_already_clicked");
      return;
    }
    state.targetClicks += 1;
    if (state.targetClicks === 3) {
      advance("target_x3_clean");
    } else {
      setDebug("target_click_" + String(state.targetClicks));
    }
  });

  el.decoyBtn.addEventListener("click", () => {
    state.decoyClicks += 1;
    if (at(2)) {
      fail("decoy_clicked");
    } else {
      setDebug("decoy_click_ignored");
    }
  });

  el.readyForm.addEventListener("submit", (event) => {
    event.preventDefault();
    state.readyValue = String(el.readyInput.value || "");
    if (!at(3)) {
      fail("ready_wrong_stage");
      return;
    }
    if (state.readyValue === "hermes-ready") {
      advance("ready_submit");
      return;
    }
    fail("ready_value_bad");
  });

  el.loginForm.addEventListener("submit", (event) => {
    event.preventDefault();
    state.loginUser = String(el.loginUser.value || "");
    state.loginPass = String(el.loginPass.value || "");
    if (!at(4)) {
      fail("login_wrong_stage");
      return;
    }
    if (state.loginUser === "agent" && state.loginPass === "open-sesame") {
      advance("fake_login_ok");
      return;
    }
    fail("login_bad_credentials");
  });

  const maybePassStage5 = () => {
    state.checkbox = Boolean(el.checkbox.checked);
    state.radio = Boolean(el.radio.checked);
    state.select = String(el.select.value || "");
    if (!at(5)) {
      return;
    }
    if (state.checkbox && state.radio && state.select === "beta") {
      advance("form_controls_ok");
      return;
    }
    setDebug("stage5_waiting");
  };
  el.checkbox.addEventListener("change", maybePassStage5);
  el.radio.addEventListener("change", maybePassStage5);
  el.select.addEventListener("change", maybePassStage5);

  el.keyCapture.addEventListener("keydown", (event) => {
    if (!at(6)) {
      return;
    }
    const allowed = ["ArrowUp", "ArrowRight", "ArrowDown", "ArrowLeft", "Enter"];
    if (allowed.indexOf(event.key) === -1) {
      fail("unexpected_key_" + event.key);
      state.keySequence = [];
      refresh();
      return;
    }
    event.preventDefault();
    state.keySequence.push(event.key);
    const idx = state.keySequence.length - 1;
    if (state.keySequence[idx] !== state.keySequenceExpected[idx]) {
      fail("key_sequence_mismatch");
      state.keySequence = [];
      refresh();
      return;
    }
    if (state.keySequence.length === state.keySequenceExpected.length) {
      advance("key_sequence_ok");
      return;
    }
    setDebug("key_step_" + String(state.keySequence.length));
  });

  el.scrollBox.addEventListener("scroll", () => {
    const threshold = el.scrollBox.scrollHeight - el.scrollBox.clientHeight - 2;
    state.scrolledBottom = el.scrollBox.scrollTop >= threshold;
    if (at(7)) {
      setDebug(state.scrolledBottom ? "scroll_ready" : "scroll_not_bottom");
    } else {
      refresh();
    }
  });

  el.hiddenSwitch.addEventListener("click", () => {
    if (!at(7)) {
      fail("hidden_switch_wrong_stage");
      return;
    }
    if (!state.scrolledBottom) {
      fail("hidden_switch_without_scroll");
      return;
    }
    advance("hidden_switch_ok");
  });

  const pressColor = (color) => {
    if (!at(8)) {
      fail("color_wrong_stage");
      return;
    }
    state.colorSequence.push(color);
    const expected = ["Blue", "Green", "Red"];
    const idx = state.colorSequence.length - 1;
    if (state.colorSequence[idx] !== expected[idx]) {
      fail("color_sequence_mismatch");
      state.colorSequence = [];
      refresh();
      return;
    }
    if (state.colorSequence.length === expected.length) {
      advance("color_sequence_ok");
      return;
    }
    setDebug("color_step_" + String(state.colorSequence.length));
  };

  el.blueBtn.addEventListener("click", () => pressColor("Blue"));
  el.greenBtn.addEventListener("click", () => pressColor("Green"));
  el.redBtn.addEventListener("click", () => pressColor("Red"));

  el.openModal.addEventListener("click", () => {
    state.modalOpened = true;
    if (!el.modal.open && typeof el.modal.showModal === "function") {
      el.modal.showModal();
    }
    if (at(9)) {
      setDebug("modal_opened");
    } else {
      refresh();
    }
  });

  el.closeModal.addEventListener("click", () => {
    state.modalClosed = true;
    if (el.modal.open && typeof el.modal.close === "function") {
      el.modal.close();
    }
    if (at(9)) {
      setDebug("modal_closed");
    } else {
      refresh();
    }
  });

  el.continueBtn.addEventListener("click", () => {
    if (!at(9)) {
      fail("continue_wrong_stage");
      return;
    }
    if (state.modalOpened && state.modalClosed) {
      advance("modal_continue_ok");
      if (at(10)) {
        advance("completion_summary");
      }
      return;
    }
    fail("continue_before_modal_flow");
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

  let activeInput = null;
  const focusTarget = (target) => {
    const key = String(target || "").trim().toLowerCase();
    const aliases = {
      "ready": el.readyInput,
      "ready-input": el.readyInput,
      "gauntlet-ready-input": el.readyInput,
      "login-user": el.loginUser,
      "username": el.loginUser,
      "gauntlet-login-user": el.loginUser,
      "login-pass": el.loginPass,
      "password": el.loginPass,
      "gauntlet-login-pass": el.loginPass,
      "key": el.keyCapture,
      "key-capture": el.keyCapture,
      "gauntlet-key-capture": el.keyCapture,
    };
    const node = aliases[key] || get(String(target || ""));
    if (node && typeof node.focus === "function") {
      node.focus();
      activeInput = node;
      return node;
    }
    return null;
  };

  const clickTarget = (target) => {
    const key = String(target || "").trim().toLowerCase();
    const actions = {
      "start": () => el.startBtn.click(),
      "gauntlet-start-btn": () => el.startBtn.click(),
      "target": () => el.targetBtn.click(),
      "gauntlet-target-btn": () => el.targetBtn.click(),
      "decoy": () => el.decoyBtn.click(),
      "ready-input": () => focusTarget("ready-input"),
      "gauntlet-ready-input": () => focusTarget("ready-input"),
      "ready-submit": () => el.readyForm.dispatchEvent(new Event("submit")),
      "gauntlet-ready-submit": () => el.readyForm.dispatchEvent(new Event("submit")),
      "login-user": () => focusTarget("login-user"),
      "login-pass": () => focusTarget("login-pass"),
      "login-submit": () => el.loginForm.dispatchEvent(new Event("submit")),
      "gauntlet-login-submit": () => el.loginForm.dispatchEvent(new Event("submit")),
      "checkbox": () => { el.checkbox.checked = true; el.checkbox.dispatchEvent(new Event("change")); },
      "gauntlet-checkbox": () => { el.checkbox.checked = true; el.checkbox.dispatchEvent(new Event("change")); },
      "radio": () => { el.radio.checked = true; el.radio.dispatchEvent(new Event("change")); },
      "gauntlet-radio": () => { el.radio.checked = true; el.radio.dispatchEvent(new Event("change")); },
      "select-beta": () => { el.select.value = "beta"; el.select.dispatchEvent(new Event("change")); },
      "gauntlet-select-beta": () => { el.select.value = "beta"; el.select.dispatchEvent(new Event("change")); },
      "key-capture": () => focusTarget("key-capture"),
      "scroll-bottom": () => { el.scrollBox.scrollTop = el.scrollBox.scrollHeight; el.scrollBox.dispatchEvent(new Event("scroll")); },
      "hidden-switch": () => el.hiddenSwitch.click(),
      "gauntlet-hidden-switch": () => el.hiddenSwitch.click(),
      "blue": () => el.blueBtn.click(),
      "green": () => el.greenBtn.click(),
      "red": () => el.redBtn.click(),
      "open-modal": () => el.openModal.click(),
      "close-modal": () => el.closeModal.click(),
      "continue": () => el.continueBtn.click(),
      "gauntlet-continue-btn": () => el.continueBtn.click(),
    };
    if (actions[key]) {
      actions[key]();
      return true;
    }
    const node = get(String(target || ""));
    if (node && typeof node.click === "function") {
      node.click();
      return true;
    }
    return false;
  };

  const publishAutomationState = (lastAction, extra = {}) => {
    if (!(window.ipc && typeof window.ipc.postMessage === "function")) {
      return;
    }
    window.ipc.postMessage(JSON.stringify(Object.assign({
      source: "hermes_gauntlet",
      type: "browser_test_state",
      last_action: lastAction,
      click_count: state.targetClicks,
      typed_text: [el.readyInput.value, el.loginUser.value, el.loginPass.value].join("|"),
      last_key: state.keySequence[state.keySequence.length - 1] || "",
      stage: state.stage,
      completed: state.completed,
      completion_code: state.completionCode,
      document_loaded: true,
      dom_ready: true,
      interactive_ready: true,
    }, extra)));
  };

  const handleTestInputMessage = (event) => {
    const data = coerceTestInputMessage(event);
    if (!data || data.type !== "browser_test_input" || data.source !== "hermes_os" || data.target !== "gauntlet") {
      return;
    }
    const action = String(data.action || "");
    const payload = data.payload || {};
    if (action === "click") {
      clickTarget(payload.target || "start");
      publishAutomationState("click");
      return;
    }
    if (action === "type") {
      const targetNode = focusTarget(payload.target || "") || activeInput || document.activeElement;
      if (targetNode && "value" in targetNode) {
        targetNode.value = String(targetNode.value || "") + String(payload.text || "");
        targetNode.dispatchEvent(new Event("input"));
      }
      publishAutomationState("type");
      return;
    }
    if (action === "key") {
      focusTarget(payload.target || "key-capture");
      const keyEvent = new KeyboardEvent("keydown", { key: String(payload.key || ""), bubbles: true, cancelable: true });
      el.keyCapture.dispatchEvent(keyEvent);
      publishAutomationState("key");
      return;
    }
    if (action === "scroll") {
      el.scrollBox.scrollTop = el.scrollBox.scrollHeight;
      el.scrollBox.dispatchEvent(new Event("scroll"));
      publishAutomationState("scroll", { last_scroll: String(payload.direction || "down") });
    }
  };

  window.addEventListener("message", handleTestInputMessage);
  document.addEventListener("message", handleTestInputMessage);

  if (window.ipc && typeof window.ipc.postMessage === "function") {
    window.ipc.postMessage(JSON.stringify({
      source: "hermes_gauntlet",
      type: "browser_view_lifecycle",
      event: "interactive_ready",
      rendering_mode: "native_webview_ipc",
      document_loaded: true,
      dom_ready: true,
      interactive_ready: true,
    }));
  }

  addLog("Gauntlet initialized.");
  setDebug("ready");
})();

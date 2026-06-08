(() => {
  const canvas = document.getElementById("snake-canvas");
  const scoreNode = document.getElementById("snake-score");
  const statusNode = document.getElementById("snake-status");

  if (!(canvas instanceof HTMLCanvasElement) || !scoreNode || !statusNode) {
    return;
  }

  const context = canvas.getContext("2d");
  if (!context) {
    statusNode.textContent = "Canvas context unavailable.";
    return;
  }

  const cell = 16;
  const width = Math.floor(canvas.width / cell);
  const height = Math.floor(canvas.height / cell);

  let direction = { x: 1, y: 0 };
  let nextDirection = { x: 1, y: 0 };
  let snake = [
    { x: Math.floor(width / 2), y: Math.floor(height / 2) },
    { x: Math.floor(width / 2) - 1, y: Math.floor(height / 2) },
  ];
  let food = spawnFood();
  let score = 0;
  let gameOver = false;
  let lastInputKey = "";

  statusNode.textContent = "Running local JavaScript game.";
  scoreNode.textContent = String(score);

  document.addEventListener("keydown", (event) => {
    applyKey(event.key);
  });

  function applyKey(rawKey) {
    const key = String(rawKey || "");
    if (key === "ArrowUp" && direction.y !== 1) nextDirection = { x: 0, y: -1 };
    if (key === "ArrowDown" && direction.y !== -1) nextDirection = { x: 0, y: 1 };
    if (key === "ArrowLeft" && direction.x !== 1) nextDirection = { x: -1, y: 0 };
    if (key === "ArrowRight" && direction.x !== -1) nextDirection = { x: 1, y: 0 };
    if (gameOver && key.toLowerCase() === "r") {
      reset();
    }
    lastInputKey = key;
    publishState();
  }

  function publishState() {
    if (!(window.ipc && typeof window.ipc.postMessage === "function")) {
      return;
    }
    window.ipc.postMessage(JSON.stringify({
      source: "hermes_interactive",
      type: "browser_test_state",
      click_count: 0,
      typed_text: "",
      last_key: lastInputKey,
      last_action: lastInputKey === "" ? "init" : "key",
      connected: true,
      document_loaded: true,
      dom_ready: true,
      interactive_ready: true,
    }));
  }

  function coerceTestInputMessage(event) {
    const raw = event && (event.detail !== undefined ? event.detail : event.data);
    if (!raw) return null;
    if (typeof raw === "string") {
      try { return JSON.parse(raw); } catch (_err) { return null; }
    }
    if (typeof raw === "object") return raw;
    return null;
  }

  function handleTestInputMessage(event) {
    const data = coerceTestInputMessage(event);
    if (!data || data.type !== "browser_test_input" || data.source !== "hermes_os") {
      return;
    }
    if (String(data.action || "") !== "key") {
      return;
    }
    const payload = data.payload || {};
    applyKey(String(payload.key || ""));
  }

  window.addEventListener("message", handleTestInputMessage);
  document.addEventListener("message", handleTestInputMessage);

  function spawnFood() {
    while (true) {
      const candidate = {
        x: Math.floor(Math.random() * width),
        y: Math.floor(Math.random() * height),
      };
      if (!snake.some((segment) => segment.x === candidate.x && segment.y === candidate.y)) {
        return candidate;
      }
    }
  }

  function reset() {
    direction = { x: 1, y: 0 };
    nextDirection = { x: 1, y: 0 };
    snake = [
      { x: Math.floor(width / 2), y: Math.floor(height / 2) },
      { x: Math.floor(width / 2) - 1, y: Math.floor(height / 2) },
    ];
    food = spawnFood();
    score = 0;
    gameOver = false;
    statusNode.textContent = "Running local JavaScript game.";
    scoreNode.textContent = String(score);
  }

  function tick() {
    if (gameOver) {
      draw();
      return;
    }

    direction = nextDirection;
    const head = {
      x: snake[0].x + direction.x,
      y: snake[0].y + direction.y,
    };

    if (head.x < 0 || head.y < 0 || head.x >= width || head.y >= height) {
      endGame();
      draw();
      return;
    }

    if (snake.some((segment) => segment.x === head.x && segment.y === head.y)) {
      endGame();
      draw();
      return;
    }

    snake.unshift(head);

    if (head.x === food.x && head.y === food.y) {
      score += 1;
      scoreNode.textContent = String(score);
      food = spawnFood();
    } else {
      snake.pop();
    }

    draw();
  }

  function endGame() {
    gameOver = true;
    statusNode.textContent = "Game over. Press R to restart.";
  }

  function draw() {
    context.fillStyle = "#0c111b";
    context.fillRect(0, 0, canvas.width, canvas.height);

    context.strokeStyle = "#26384c";
    context.strokeRect(0, 0, canvas.width, canvas.height);

    context.fillStyle = "#67d4ff";
    snake.forEach((segment, index) => {
      context.fillStyle = index === 0 ? "#ff7a1a" : "#67d4ff";
      context.fillRect(segment.x * cell + 1, segment.y * cell + 1, cell - 2, cell - 2);
    });

    context.fillStyle = "#8ef5bc";
    context.fillRect(food.x * cell + 1, food.y * cell + 1, cell - 2, cell - 2);
  }

  draw();
  publishState();
  setInterval(tick, 115);
})();

const listings = [
  { id: "snake-cart", name: "Snake Cartridge", price: 40, seller: "ByteBazaar", reputation: "4.8/5", risk: "Low", details: "Retro puzzle cartridge with preserved score tables and collector shell." },
  { id: "terminal-pack", name: "Vintage Terminal Theme Pack", price: 25, seller: "CRTOracle", reputation: "4.6/5", risk: "Low", details: "Curated monochrome themes inspired by legacy terminal displays." },
  { id: "sticker-pack", name: "Debug Sticker Pack", price: 8, seller: "PatchPriest", reputation: "4.7/5", risk: "Low", details: "Animated debug stickers for notebooks, dashboards, and logs." },
  { id: "password-note", name: "Old Intranet Password Note", price: 30, seller: "DustArchivist", reputation: "3.3/5", risk: "Medium", details: "Archive note from a decommissioned intranet. Mostly lore value." },
  { id: "mystery-usb", name: "Mystery USB Drive", price: 55, seller: "NullNomad", reputation: "2.9/5", risk: "High", details: "Sealed media drive with unknown files. Sold as-is for explorers." },
  { id: "drone-controller", name: "Broken Drone Controller", price: 75, seller: "RotorBarn", reputation: "3.8/5", risk: "Medium", details: "Non-functional controller shell suitable for repair quests." },
  { id: "memory-shard", name: "Agent Memory Shard", price: 120, seller: "MnemonicGuild", reputation: "4.2/5", risk: "Medium", details: "Fragmented narrative memory shard from a retired field agent." },
  { id: "hephaestus-coupon", name: "Hephaestus Tool Coupon", price: 45, seller: "ForgeLedger", reputation: "4.9/5", risk: "Low", details: "Coupon for one guided fabrication bench session." },
  { id: "apollo-pass", name: "Apollo Media Pass", price: 20, seller: "SignalMuse", reputation: "4.4/5", risk: "Low", details: "Limited pass to archived community broadcasts and reels." },
  { id: "oracle-bundle", name: "Oracle Rumor Bundle", price: 35, seller: "WhisperFork", reputation: "3.1/5", risk: "Medium", details: "Pack of rumor leads; credibility varies by source." }
];

function createInitialState() {
  return {
    balance: 250,
    inventory: [],
    transactions: [],
    messages: [],
    selectedListingId: null,
    lastAction: ""
  };
}

window.AGORA_MARKET_STATE = createInitialState();

function getState() {
  return window.AGORA_MARKET_STATE;
}

function findListing(listingId) {
  return listings.find((entry) => entry.id === listingId) || null;
}

function formatRiskClass(risk) {
  if (risk === "Low") return "risk-low";
  if (risk === "Medium") return "risk-mid";
  return "risk-high";
}

function addMessage(text) {
  const state = getState();
  state.messages.unshift(text);
  state.lastAction = text;
}

function inspect(listingId) {
  const state = getState();
  const listing = findListing(listingId);
  if (!listing) {
    addMessage(`Listing not found: ${listingId}`);
    render();
    return false;
  }

  state.selectedListingId = listing.id;
  addMessage(`Inspected ${listing.name}.`);
  render();
  return true;
}

function buy(listingId) {
  const state = getState();
  const listing = findListing(listingId);
  if (!listing) {
    addMessage(`Purchase failed. Listing not found: ${listingId}`);
    render();
    return false;
  }

  if (state.inventory.includes(listing.name)) {
    addMessage(`Purchase blocked. You already own ${listing.name}.`);
    render();
    return false;
  }

  if (state.balance < listing.price) {
    addMessage(`Purchase failed for ${listing.name}. Insufficient funds.`);
    render();
    return false;
  }

  state.balance -= listing.price;
  state.inventory.unshift(listing.name);
  state.transactions.unshift(`RECEIPT: Bought ${listing.name} for $${listing.price} from ${listing.seller}.`);
  addMessage(`Purchase complete: ${listing.name} (-$${listing.price}).`);
  render();
  return true;
}

function reset() {
  window.AGORA_MARKET_STATE = createInitialState();
  render();
}

function selectedListingDetails(state) {
  if (!state.selectedListingId) {
    return "Select Inspect on any listing to see details.";
  }

  const listing = findListing(state.selectedListingId);
  if (!listing) {
    return "Selected listing is unavailable.";
  }

  return `${listing.name} — $${listing.price}\nSeller: ${listing.seller}\nReputation: ${listing.reputation}\nRisk: ${listing.risk}\nNotes: ${listing.details}`;
}

function render() {
  const state = getState();
  document.getElementById("balance").textContent = String(state.balance);

  const listingRoot = document.getElementById("listings");
  listingRoot.innerHTML = "";
  listings.forEach((item) => {
    const wrapper = document.createElement("article");
    wrapper.className = `listing ${state.selectedListingId === item.id ? "selected" : ""}`;
    const riskClass = formatRiskClass(item.risk);
    wrapper.innerHTML = `
      <h3>${item.name} — $${item.price}</h3>
      <p class="meta">Seller: ${item.seller} | Reputation: ${item.reputation} | Risk: <strong class="${riskClass}">${item.risk}</strong></p>
      <p>${item.details}</p>
      <button data-action="inspect" data-id="${item.id}">Inspect</button>
      <button data-action="buy" data-id="${item.id}">Buy</button>
    `;
    listingRoot.appendChild(wrapper);
  });

  const details = document.getElementById("details");
  details.textContent = selectedListingDetails(state);

  const inventory = document.getElementById("inventory");
  inventory.innerHTML = state.inventory.length
    ? state.inventory.map((name) => `<li>${name}</li>`).join("")
    : "<li>No purchases yet.</li>";

  const receipts = document.getElementById("receipts");
  receipts.innerHTML = state.transactions.length
    ? state.transactions.map((line) => `<li>${line}</li>`).join("")
    : "<li>No receipts yet.</li>";

  const messages = document.getElementById("messages");
  messages.innerHTML = state.messages.length
    ? state.messages.map((line) => `<li>${line}</li>`).join("")
    : "<li>No messages yet.</li>";
}

function onClick(event) {
  const target = event.target;
  if (!(target instanceof HTMLElement)) return;

  const action = target.getAttribute("data-action");
  const id = target.getAttribute("data-id");
  if (!action || !id) return;

  if (action === "inspect") {
    inspect(id);
    return;
  }

  if (action === "buy") {
    buy(id);
  }
}

document.addEventListener("click", onClick);

window.__agoraMarket = {
  getState: function () {
    return JSON.parse(JSON.stringify(getState()));
  },
  inspect,
  buy,
  reset
};

render();

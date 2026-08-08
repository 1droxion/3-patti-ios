import { randomUUID, randomBytes, randomInt, createHash, createHmac, sign as cryptoSign } from 'node:crypto';
import * as store from './store.js';
import { issueSessionToken, requirePlayerAuth, securityStatus, clientFingerprint } from './security.js';

export const rooms = new Map();
const queues = new Map();
const FEE_RATE = 0.05;
const TURN_MS = 60_000;

export function json(res, code, data) {
  const body = JSON.stringify(data);
  res.writeHead(code, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'access-control-allow-origin': '*',
    'access-control-allow-headers': 'content-type, authorization, x-idempotency-key',
    'access-control-allow-methods': 'GET,POST,OPTIONS',
  });
  res.end(body);
}

export function html(res, code, body) {
  res.writeHead(code, {'content-type':'text/html; charset=utf-8','cache-control':'public, max-age=300','x-content-type-options':'nosniff','referrer-policy':'no-referrer'}); res.end(body);
}
const pageStyle=`body{font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;max-width:820px;margin:40px auto;padding:0 20px;line-height:1.55;background:#06110c;color:#f4f0e8}h1,h2{color:#f4c34d}a{color:#7be49a}.card{background:#0a1c14;border:1px solid #705719;border-radius:16px;padding:20px}input,textarea,button{box-sizing:border-box;width:100%;padding:12px;margin:7px 0;border-radius:10px;border:1px solid #705719;background:#0b1f16;color:white}button{background:#a26a08;font-weight:700;cursor:pointer}`;
const privacyPage=`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>3 Patti Social Privacy Policy</title><style>${pageStyle}</style></head><body><h1>3 Patti Social Privacy Policy</h1><div class="card"><p><b>Last updated: August 7, 2026</b></p><h2>Social game only</h2><p>3 Patti Social is a social entertainment card game. Virtual chips have no cash value and cannot be withdrawn or redeemed for money or prizes.</p><h2>Data we process</h2><p>We may process a pseudonymous player ID, display name, selected avatar, social-chip balance, gameplay/table activity, support requests, in-app purchase transaction identifiers, and technical/network information needed to operate, secure, and troubleshoot the service.</p><h2>Data this release does not collect</h2><p>The public social release does not require government-ID numbers, tax identifiers, bank-account details, cash deposits, or cash-withdrawal information.</p><h2>Apple purchases</h2><p>Virtual chip packs and VIP are purchased through Apple In-App Purchase. We receive transaction information needed to validate and deliver digital items. We do not receive your full payment-card number from Apple.</p><h2>Deletion</h2><p>You can delete your account from Settings. Limited anonymized integrity, fraud-prevention, purchase, or security records may be retained where reasonably necessary.</p><h2>Contact</h2><p>Use the in-app Support screen or our <a href="/support">Support page</a>.</p><p><a href="/terms">Terms of Use</a></p></div></body></html>`;
const termsPage=`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>3 Patti Social Terms</title><style>${pageStyle}</style></head><body><h1>3 Patti Social Terms of Use</h1><div class="card"><p><b>Last updated: August 7, 2026</b></p><h2>Social entertainment only</h2><p>Virtual chips are entertainment credits only and cannot be redeemed for cash, prizes, or anything of value.</p><h2>Fair play</h2><p>Do not exploit bugs, automate gameplay, collude, impersonate another player, manipulate network traffic, or attempt to alter balances, cards, or game results.</p><h2>Purchases</h2><p>Chip packs are consumable digital items. VIP Monthly is an auto-renewable subscription billed through Apple and can be managed or canceled through Apple subscription settings. Purchases do not affect card odds.</p><h2>No real-money wagering</h2><p>This public release does not accept cash wagers, award cash winnings, or provide cash withdrawals.</p><p><a href="/privacy">Privacy Policy</a> · <a href="/support">Support</a></p></div></body></html>`;
const supportPage=`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>3 Patti Social Support</title><style>${pageStyle}</style></head><body><h1>3 Patti Social Support</h1><div class="card"><p>Send us a support request. Do not include passwords, full payment-card numbers, or government ID numbers.</p><input id="email" type="email" placeholder="Email for reply (optional)"><textarea id="message" rows="6" maxlength="1200" placeholder="How can we help?"></textarea><button onclick="sendTicket()">Send support request</button><p id="result"></p><p><a href="/privacy">Privacy</a> · <a href="/terms">Terms</a></p></div><script>async function sendTicket(){const r=document.getElementById('result');r.textContent='Sending…';try{const res=await fetch('/public/support-ticket',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email:document.getElementById('email').value,message:document.getElementById('message').value})});const d=await res.json();if(!res.ok)throw new Error(d.error||'Request failed');r.textContent='Ticket '+d.ticketId+' created. Thank you.';document.getElementById('message').value='';}catch(e){r.textContent='Could not send: '+e.message;}}</script></body></html>`;

export function readBody(req) {
  if (req.body !== undefined && req.body !== null) {
    if (typeof req.body === 'object') return Promise.resolve(req.body);
    try {
      return Promise.resolve(req.body ? JSON.parse(req.body) : {});
    } catch {
      return Promise.reject(new Error('Invalid JSON'));
    }
  }
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', chunk => {
      data += chunk;
      if (data.length > 1_000_000) reject(new Error('Body too large'));
    });
    req.on('end', () => {
      try {
        resolve(data ? JSON.parse(data) : {});
      } catch {
        reject(new Error('Invalid JSON'));
      }
    });
    req.on('error', reject);
  });
}

function tableCapFor(playerCount) {
  if (playerCount <= 5) return 5000;
  if (playerCount <= 8) return 20000;
  return 50000;
}

function secureRandomIndex(seed, counterRef, upperExclusive) {
  if (upperExclusive <= 1) return 0;
  const limit = Math.floor(0x100000000 / upperExclusive) * upperExclusive;
  while (true) {
    const counter = Buffer.allocUnsafe(8);
    counter.writeBigUInt64BE(BigInt(counterRef.value++));
    const digest = createHmac('sha256', seed).update(counter).digest();
    for (let offset = 0; offset <= digest.length - 4; offset += 4) {
      const value = digest.readUInt32BE(offset);
      if (value < limit) return value % upperExclusive;
    }
  }
}

function makeDeck() {
  const seed = randomBytes(32);
  const counterRef = { value: 0 };
  const cards = [];
  for (let suit = 0; suit < 4; suit++) {
    for (let rank = 2; rank <= 14; rank++) cards.push({ rank, suit });
  }
  for (let i = cards.length - 1; i > 0; i--) {
    const j = secureRandomIndex(seed, counterRef, i + 1);
    [cards[i], cards[j]] = [cards[j], cards[i]];
  }
  return {
    cards,
    seedHex: seed.toString('hex'),
    commitment: createHash('sha256').update(seed).digest('hex'),
  };
}

function handValue(cards) {
  const ranks = cards.map(c => c.rank).sort((a, b) => a - b);
  const sameSuit = cards.every(c => c.suit === cards[0].suit);
  const counts = new Map();
  for (const rank of ranks) counts.set(rank, (counts.get(rank) || 0) + 1);

  const a23 = ranks[0] === 2 && ranks[1] === 3 && ranks[2] === 14;
  const straight = a23 || (ranks[1] === ranks[0] + 1 && ranks[2] === ranks[1] + 1);
  const straightHigh = a23 ? 3 : ranks[2];

  if ([...counts.values()].includes(3)) return [6, ranks[2]];
  if (straight && sameSuit) return [5, straightHigh];
  if (straight) return [4, straightHigh];
  if (sameSuit) return [3, ...[...ranks].reverse()];

  const pair = [...counts.entries()].find(([, n]) => n === 2);
  if (pair) {
    const kicker = [...counts.entries()].find(([, n]) => n === 1)[0];
    return [2, pair[0], kicker];
  }
  return [1, ...[...ranks].reverse()];
}

function compareHands(a, b) {
  const av = handValue(a);
  const bv = handValue(b);
  const len = Math.max(av.length, bv.length);
  for (let i = 0; i < len; i++) {
    const ai = av[i] || 0;
    const bi = bv[i] || 0;
    if (ai !== bi) return ai - bi;
  }
  return 0;
}

function activePlayers(room) {
  return room.players.filter(p => !p.folded);
}

function setTurn(room, index) {
  if (room.status !== 'playing') return;
  const n = room.players.length;
  if (!n) return;
  let cursor = ((index % n) + n) % n;
  for (let attempts = 0; attempts < n; attempts++) {
    const p = room.players[cursor];
    if (!p.folded) {
      room.turnIndex = cursor;
      room.turnExpiresAt = Date.now() + TURN_MS;
      room.message = `${p.name}'s turn.`;
      return;
    }
    cursor = (cursor + 1) % n;
  }
}

function advanceTurn(room) {
  if (room.status !== 'playing') return;
  const active = activePlayers(room);
  if (active.length <= 1) {
    maybeSettleLastStanding(room);
    return;
  }
  setTurn(room, (room.turnIndex + 1) % room.players.length);
}

function startRound(room) {
  const secureDeck = makeDeck();
  const deck = secureDeck.cards;
  room.handId = randomUUID();
  room.handCommitment = secureDeck.commitment;
  room.handSeed = secureDeck.seedHex;
  room.handReveal = null;
  room.round += 1;
  room.pot = 0;
  room.currentBet = 10;
  room.status = 'playing';
  room.winnerId = null;
  room.revealed = false;
  room.lastFee = 0;
  room.lastPayout = 0;
  room.lastAction = 'deal';
  room.lastActorId = null;
  room.lastTimeoutPlayerId = null;
  room.lastBetAmount = 0;
  room.actionSeq = (room.actionSeq || 0) + 1;

  for (const p of room.players) {
    p.folded = false;
    p.seen = false;
    p.readyNext = false;
    p.cards = [deck.pop(), deck.pop(), deck.pop()];
    const boot = Math.min(10, p.chips);
    p.chips -= boot;
    room.pot += boot;
  }

  room.turnIndex = room.players.length ? randomInt(room.players.length) : 0;
  setTurn(room, room.turnIndex);
}

function payWinner(room, winner, reason = '') {
  const fee = Math.floor(room.pot * FEE_RATE);
  const payout = Math.max(0, room.pot - fee);
  winner.chips += payout;
  room.lastFee = fee;
  room.lastPayout = payout;
  room.handReveal = room.handSeed || null;
  room.rakeReferenceId = room.handId ? `rake:${room.handId}` : `rake:${room.id}:${room.round}`;
  room.winnerId = winner.id;
  room.status = 'showdown';
  room.revealed = true;
  room.turnExpiresAt = 0;
  room.message = `${winner.name} wins ${payout} chips${reason ? ` ${reason}` : '.'}`;
}

function settle(room) {
  const active = activePlayers(room);
  if (!active.length) return;
  let winner = active[0];
  for (const p of active.slice(1)) {
    if (compareHands(p.cards, winner.cards) > 0) winner = p;
  }
  payWinner(room, winner);
}

function maybeSettleLastStanding(room) {
  const active = activePlayers(room);
  if (active.length === 1 && room.status === 'playing') {
    payWinner(room, active[0], 'after everyone else packed.');
  }
}

function tickRoom(room) {
  if (!room || room.status !== 'playing') return;
  if (!room.turnExpiresAt || Date.now() < room.turnExpiresAt) return;
  const current = room.players[room.turnIndex];
  if (!current || current.folded) {
    advanceTurn(room);
    return;
  }
  room.lastTimeoutPlayerId = current.id;
  room.lastBetAmount = 0;
  room.actionSeq = (room.actionSeq || 0) + 1;
  room.lastAction = 'timeout';
  room.lastActorId = current.id;
  room.message = `${current.name} timed out. Turn skipped.`;
  advanceTurn(room);
}

function eligibleSideShowTarget(room, requester) {
  if (!requester.seen) return null;
  const n = room.players.length;
  const requesterIndex = room.players.findIndex(p => p.id === requester.id);
  for (let step = 1; step < n; step++) {
    const index = (requesterIndex - step + n) % n;
    const p = room.players[index];
    if (!p.folded && p.id !== requester.id && p.seen) return p;
  }
  return null;
}

function publicState(room, playerId) {
  tickRoom(room);
  const me = room.players.find(p => p.id === playerId);
  if (!me) return null;
  const current = room.status === 'playing' ? room.players[room.turnIndex] : null;
  const sideShowTarget = eligibleSideShowTarget(room, me);

  return {
    roomId: room.id,
    requestedPlayers: room.playerCount,
    joinedPlayers: room.players.length,
    status: room.status,
    round: room.round,
    pot: room.pot,
    currentBet: room.currentBet,
    cap: room.cap,
    feeRate: FEE_RATE,
    handId: room.handId || null,
    handCommitment: room.handCommitment || null,
    handReveal: room.revealed ? (room.handReveal || null) : null,
    lastFee: room.lastFee || 0,
    lastPayout: room.lastPayout || 0,
    message: room.message,
    winnerId: room.winnerId,
    currentPlayerId: current?.id || null,
    turnExpiresAt: room.turnExpiresAt || 0,
    turnDurationMs: TURN_MS,
    serverNow: Date.now(),
    blindAmount: room.currentBet,
    chaalAmount: Math.min(room.currentBet * 2, Math.max(0, room.cap - room.pot)),
    lastAction: room.lastAction || null,
    lastActorId: room.lastActorId || null,
    lastTimeoutPlayerId: room.lastTimeoutPlayerId || null,
    lastBetAmount: room.lastBetAmount || 0,
    actionSeq: room.actionSeq || 0,
    dealerTipTotal: room.dealerTipTotal || 0,
    lastTipAmount: room.lastTipAmount || 0,
    lastTipPlayerId: room.lastTipPlayerId || null,
    nextRoundReadyCount: room.players.filter(p => p.readyNext).length,
    canSideShow: Boolean(sideShowTarget),
    sideShowTargetId: sideShowTarget?.id || null,
    myId: playerId,
    myCards: (me.seen || room.revealed) ? (me.cards || []) : [{}, {}, {}],
    mySeen: me.seen,
    players: room.players.map(p => ({
      id: p.id,
      name: p.name,
      avatar: p.avatar || 1,
      vip: Boolean(p.vip),
      chips: p.chips,
      folded: p.folded,
      seen: p.seen,
      readyNext: Boolean(p.readyNext),
    })),
    revealedHands: room.revealed
      ? room.players.map(p => ({ id: p.id, name: p.name, folded: p.folded, cards: p.cards }))
      : [],
  };
}

function queueFor(n) {
  if (!queues.has(n)) queues.set(n, []);
  return queues.get(n);
}

async function getRoom(roomId) {
  if (!roomId) return null;
  const cached = rooms.get(String(roomId));
  if (cached) return cached;
  const loaded = await store.loadRoom(String(roomId));
  if (loaded) rooms.set(loaded.id, loaded);
  return loaded;
}

async function persistRoom(room) {
  await store.saveRoom(room);
  rooms.set(room.id, room);
  return room;
}

async function persistFinancialEffects(room) {
  if (room.status === 'showdown') {
    if (room.lastFee > 0 && room.rakeReferenceId) {
      await store.recordRevenue({
        type: 'rake',
        chips: room.lastFee,
        roomId: room.id,
        handId: room.handId || null,
        referenceId: room.rakeReferenceId,
        metadata: { feeRate: FEE_RATE, pot: room.pot, payout: room.lastPayout },
      });
    }
    await store.recordHand(room);
  }
}

function makeRoom(playerCount) {
  return {
    id: randomUUID(),
    _version: 0,
    playerCount,
    players: [],
    status: 'waiting',
    round: 0,
    pot: 0,
    currentBet: 10,
    cap: tableCapFor(playerCount),
    message: 'Waiting for players...',
    winnerId: null,
    revealed: false,
    lastFee: 0,
    lastPayout: 0,
    turnIndex: 0,
    turnExpiresAt: 0,
    lastAction: null,
    lastActorId: null,
    lastTimeoutPlayerId: null,
    lastBetAmount: 0,
    actionSeq: 0,
    dealerTipTotal: 0,
    lastTipAmount: 0,
    lastTipPlayerId: null,
    handId: null,
    handCommitment: null,
    handSeed: null,
    handReveal: null,
    rakeReferenceId: null,
  };
}

async function joinRoom({ playerId, name, avatar, vip = false, playerCount, excludeRoomId = '', accountId }) {
  if (!Number.isInteger(playerCount) || playerCount < 2 || playerCount > 10) {
    throw new Error('playerCount must be 2..10');
  }
  if (!accountId) throw new Error('Authenticated account required');

  for (let attempt = 0; attempt < 3; attempt++) {
    const q = queueFor(playerCount);
    let room = q
      .map(id => rooms.get(id))
      .find(r => r && r.id !== excludeRoomId && r.status === 'waiting' && r.players.length < r.playerCount);
    if (!room) room = await store.findWaitingRoom(playerCount, excludeRoomId);
    if (!room) room = makeRoom(playerCount);

    const existing = room.players.find(p => p.id === playerId);
    let seat = null;
    let reserveApplied = false;
    if (!existing) {
      const wallet = await store.getWallet(accountId);
      const available = Number(wallet?.chip_balance || 0);
      const configuredEntry = Math.max(10, Number(process.env.TABLE_ENTRY_CHIPS || 10000));
      const entryChips = Math.min(available, configuredEntry);
      if (entryChips < 10) throw new Error('Not enough wallet chips to enter a table');
      const seatId = randomUUID();
      const reserveRef = `table-reserve:${seatId}`;
      await store.applyWalletTransaction({
        userId: accountId,
        chipsDelta: -entryChips,
        type: 'table_reserve',
        referenceId: reserveRef,
        metadata: { roomId: room.id, playerCount },
      });
      reserveApplied = true;
      seat = {
        id: playerId,
        accountId,
        seatId,
        reserveRef,
        name: String(name || 'Player').slice(0, 24),
        avatar: Math.max(1, Math.min(8, Number(avatar) || 1)),
        vip: Boolean(vip),
        chips: entryChips,
        folded: false,
        seen: false,
        readyNext: false,
        cards: [],
      };
      room.players.push(seat);
    } else {
      existing.name = String(name || existing.name || 'Player').slice(0, 24);
      existing.avatar = Math.max(1, Math.min(8, Number(avatar) || existing.avatar || 1));
      existing.vip = Boolean(vip);
      existing.accountId = existing.accountId || accountId;
    }

    room.message = `Waiting for players: ${room.players.length}/${room.playerCount}`;
    if (room.players.length === room.playerCount) {
      startRound(room);
      queues.set(playerCount, q.filter(id => id !== room.id));
    } else if (!q.includes(room.id)) {
      q.push(room.id);
    }

    try {
      await persistRoom(room);
      return room;
    } catch (e) {
      if (reserveApplied && seat) {
        await store.applyWalletTransaction({
          userId: accountId,
          chipsDelta: seat.chips,
          type: 'table_reserve_refund',
          referenceId: `reserve-refund:${seat.seatId}`,
          metadata: { roomId: room.id, reason: 'join_conflict' },
        }).catch(() => {});
      }
      rooms.delete(room.id);
      if (e.code !== 'ROOM_VERSION_CONFLICT' || attempt === 2) throw e;
    }
  }
  throw new Error('Could not join table; please retry');
}


function removeFromQueues(roomId) {
  for (const [count, list] of queues.entries()) {
    queues.set(count, list.filter(id => id !== roomId));
  }
}

function addToQueue(room) {
  const q = queueFor(room.playerCount);
  if (!q.includes(room.id)) q.push(room.id);
}

function leaveRoom(room, playerId) {
  const index = room.players.findIndex(p => p.id === playerId);
  if (index < 0) return;
  const leaving = room.players[index];
  const wasCurrent = room.status === 'playing' && room.turnIndex === index;
  room.players.splice(index, 1);
  room.actionSeq = (room.actionSeq || 0) + 1;
  room.lastAction = 'leave';
  room.lastActorId = playerId;
  room.lastBetAmount = 0;

  if (!room.players.length) {
    removeFromQueues(room.id);
    rooms.delete(room.id);
    return;
  }

  if (room.status === 'playing') {
    if (room.turnIndex > index) room.turnIndex -= 1;
    room.turnIndex = Math.min(room.turnIndex, room.players.length - 1);
    if (activePlayers(room).length <= 1) {
      maybeSettleLastStanding(room);
    } else if (wasCurrent) {
      setTurn(room, room.turnIndex % room.players.length);
    }
    room.message = `${leaving.name} left the table.`;
    return;
  }

  // After a completed hand, only reopen matchmaking if the players who remain
  // have explicitly chosen NEW ROUND. Otherwise keep the result screen in place.
  if (room.players.every(p => p.readyNext)) {
    room.status = 'waiting';
    room.winnerId = null;
    room.revealed = false;
    room.pot = 0;
    room.turnExpiresAt = 0;
    room.lastPayout = 0;
    room.lastFee = 0;
    for (const p of room.players) {
      p.folded = false;
      p.seen = false;
      p.cards = [];
    }
    room.message = `Seat open: ${room.players.length}/${room.playerCount}. Waiting for player...`;
    addToQueue(room);
  } else {
    room.message = `${leaving.name} exited. Choose NEW ROUND to wait for a new player, SWITCH TABLE, or EXIT.`;
  }
}

async function lobbyState() {
  const summary = await store.lobbySummary();
  const byCount = new Map(summary.map(row => [Number(row.player_count), row]));
  const tables = [];
  for (let players = 2; players <= 10; players++) {
    const row = byCount.get(players) || {};
    tables.push({
      players,
      waitingPlayers: Number(row.waiting_players || 0),
      activeRooms: Number(row.active_rooms || 0),
    });
  }
  return { tables, serverNow: Date.now() };
}

function paymentReadiness() {
  const persistence = store.persistenceStatus();
  const security = securityStatus();
  const flags = {
    licensed: String(process.env.REAL_MONEY_APPROVED || '').toLowerCase() === 'true',
    identity: String(process.env.IDENTITY_PROVIDER_READY || '').toLowerCase() === 'true',
    kyc: String(process.env.KYC_PROVIDER_READY || '').toLowerCase() === 'true',
    geo: String(process.env.GEOLOCATION_PROVIDER_READY || '').toLowerCase() === 'true',
    provider: String(process.env.PAYMENT_PROVIDER_APPROVED || '').toLowerCase() === 'true',
    persistence: persistence.persistent,
    auth: security.authSecretConfigured && security.authRequired,
  };
  const approvalIds = {
    regulatory: String(process.env.REGULATORY_APPROVAL_ID || '').trim(),
    payments: String(process.env.PAYMENT_APPROVAL_ID || '').trim(),
  };
  flags.regulatoryApprovalId = approvalIds.regulatory.length >= 6;
  flags.paymentApprovalId = approvalIds.payments.length >= 6;
  const requested = String(process.env.CASH_MODE_ENABLED || '').toLowerCase() === 'true';
  const blockers = Object.entries(flags).filter(([, ok]) => !ok).map(([name]) => name);
  return { requested, enabled: requested && blockers.length === 0, blockers, flags, approvalIds, persistence, security };
}

function maskDestination(provider, destination) {
  const value = String(destination || '');
  if (provider === 'paypal' && value.includes('@')) {
    const [left, right] = value.split('@');
    return `${left.slice(0, 2)}***@${right}`;
  }
  return value.length > 4 ? `***${value.slice(-4)}` : value;
}


function calculateAge(dobText) {
  const dob = new Date(String(dobText || ''));
  if (Number.isNaN(dob.getTime())) return null;
  const now = new Date();
  let age = now.getUTCFullYear() - dob.getUTCFullYear();
  const month = now.getUTCMonth() - dob.getUTCMonth();
  if (month < 0 || (month === 0 && now.getUTCDate() < dob.getUTCDate())) age--;
  return age;
}

function cleanLast4(value) {
  const compact = String(value || '').replace(/[^A-Za-z0-9]/g, '');
  return compact ? compact.slice(-4) : null;
}

function approvedCashStates() {
  return String(process.env.APPROVED_CASH_STATES || '')
    .split(',').map(v => v.trim().toUpperCase()).filter(Boolean);
}

function userCashEligibility(user) {
  const readiness = paymentReadiness();
  const states = approvedCashStates();
  const blockers = [];
  if (!readiness.enabled) blockers.push(...readiness.blockers.map(v => `platform:${v}`));
  if (String(user?.kyc_status || '') !== 'verified') blockers.push('user:kyc');
  if (!user?.age_verified) blockers.push('user:age21');
  const state = String(user?.geo_state || '').toUpperCase();
  if (!state || !states.includes(state)) blockers.push('user:approved_state_location');
  if (!user?.cash_eligible) blockers.push('user:cash_eligible');
  return { eligible: blockers.length === 0, blockers, approvedStates: states };
}


const SOCIAL_PRODUCTS = Object.freeze({
  'com.droxion.threepatti.chips25k': { chips: 25000, type: 'chips', label: '25K Social Chips' },
  'com.droxion.threepatti.chips150k': { chips: 150000, type: 'chips', label: '150K Social Chips' },
  'com.droxion.threepatti.chips400k': { chips: 400000, type: 'chips', label: '400K Social Chips' },
  'com.droxion.threepatti.chips1m': { chips: 1000000, type: 'chips', label: '1M Social Chips' },
  'com.droxion.threepatti.vip.monthly': { chips: 0, type: 'vip', vipDays: 31, label: 'VIP Monthly' },
});

function vipActive(user) {
  if (!user?.vip_until) return false;
  const t = new Date(user.vip_until).getTime();
  return Number.isFinite(t) && t > Date.now();
}

function socialIapMode() {
  const mode = String(process.env.SOCIAL_IAP_MODE || 'live').toLowerCase();
  return mode === 'live' ? 'live' : 'sandbox';
}


function base64UrlJson(value) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function appleIapConfigReady() {
  return Boolean(
    process.env.APPLE_IAP_ISSUER_ID &&
    process.env.APPLE_IAP_KEY_ID &&
    process.env.APPLE_IAP_PRIVATE_KEY &&
    process.env.APPLE_BUNDLE_ID
  );
}

function makeAppleServerJwt() {
  if (!appleIapConfigReady()) throw new Error('Apple IAP server credentials are not configured');
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'ES256', kid: String(process.env.APPLE_IAP_KEY_ID), typ: 'JWT' };
  const payload = {
    iss: String(process.env.APPLE_IAP_ISSUER_ID),
    iat: now,
    exp: now + 300,
    aud: 'appstoreconnect-v1',
    bid: String(process.env.APPLE_BUNDLE_ID),
  };
  const input = `${base64UrlJson(header)}.${base64UrlJson(payload)}`;
  const key = String(process.env.APPLE_IAP_PRIVATE_KEY).replace(/\\n/g, '\n');
  const signature = cryptoSign('sha256', Buffer.from(input), { key, dsaEncoding: 'ieee-p1363' }).toString('base64url');
  return `${input}.${signature}`;
}

function decodeJwsPayload(jws) {
  const parts = String(jws || '').split('.');
  if (parts.length !== 3) throw new Error('Invalid Apple signed transaction');
  return JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
}

async function verifyAppleTransaction(transactionId, expectedProductId) {
  const configured=String(process.env.APPLE_IAP_ENV||'auto').toLowerCase(); const envs=configured==='production'?['production']:configured==='sandbox'?['sandbox']:['production','sandbox'];
  const token=makeAppleServerJwt(); let lastError=null;
  for(const environment of envs){const base=environment==='production'?'https://api.storekit.itunes.apple.com':'https://api.storekit-sandbox.itunes.apple.com';try{const response=await fetch(`${base}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`,{headers:{authorization:`Bearer ${token}`,accept:'application/json'}});const data=await response.json().catch(()=>({}));if(!response.ok)throw new Error(data?.errorMessage||`Apple transaction verification failed (${response.status})`);const tx=decodeJwsPayload(data.signedTransactionInfo);if(String(tx.transactionId||'')!==String(transactionId))throw new Error('Apple transaction ID mismatch');if(String(tx.productId||'')!==String(expectedProductId))throw new Error('Apple product ID mismatch');if(String(tx.bundleId||'')!==String(process.env.APPLE_BUNDLE_ID))throw new Error('Apple bundle ID mismatch');if(tx.revocationDate)throw new Error('Apple transaction was revoked');return {...tx,verifiedEnvironment:environment};}catch(e){lastError=e;}}
  throw lastError||new Error('Apple transaction verification failed');
}
function launchReadiness(){const persistence=store.persistenceStatus();const security=securityStatus();const iapLive=socialIapMode()==='live';const apple=appleIapConfigReady();return {ready:persistence.persistent&&security.authSecretConfigured&&security.authRequired&&iapLive&&apple,persistence,security,iapLive,appleIapVerificationConfigured:apple};}



export async function handle(req, res, forcedRoute = '') {
  if (req.method === 'OPTIONS') return json(res, 204, {});
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const route = String(forcedRoute || req.query?.route || url.searchParams.get('route') || url.pathname)
    .replace(/^\/+|\/+$/g, '');

  try {
    if (req.method === 'GET' && (route === '' || route === 'health')) {
      return json(res, 200, {
        ok: true, version: '1.8.2', productMode: 'social-only', virtualChipsCashValue: false, withdrawalsEnabled: false, cachedRooms: rooms.size,
        persistence: store.persistenceStatus(), security: securityStatus(), socialIapMode: socialIapMode(), appleIapVerificationConfigured: appleIapConfigReady(), launchReadiness: launchReadiness(),
      });
    }

    if(req.method==='GET'&&route==='privacy')return html(res,200,privacyPage);
    if(req.method==='GET'&&route==='terms')return html(res,200,termsPage);
    if(req.method==='GET'&&route==='support')return html(res,200,supportPage);
    if(req.method==='POST'&&route==='public/support-ticket'){const body=await readBody(req);const message=String(body.message||'').trim();if(message.length<10)return json(res,400,{error:'Message must be at least 10 characters'});const ticket=await store.createSupportTicket({email:body.email,message});return json(res,200,{ok:true,ticketId:ticket.id});}
    const allowUnsafeDev=String(process.env.ALLOW_UNSAFE_DEVELOPMENT||'').toLowerCase()==='true';const ready=launchReadiness();
    if(!allowUnsafeDev&&!ready.persistence.persistent)return json(res,503,{error:'Service setup incomplete: persistent database is required',launchReadiness:ready});
    if(!allowUnsafeDev&&(!ready.security.authSecretConfigured||!ready.security.authRequired))return json(res,503,{error:'Service setup incomplete: secure authentication is required',launchReadiness:ready});

    if (req.method === 'POST' && route === 'auth/bootstrap') {
      const body = await readBody(req);
      const playerId = String(body.playerId || '').trim();
      if (!playerId) return json(res, 400, { error: 'playerId required' });
      const { user, wallet } = await store.ensureUser({
        externalPlayerId: playerId,
        displayName: body.name,
        avatar: body.avatar,
      });
      const token = issueSessionToken({ playerId, accountId: user.id });
      await store.audit({ actorUserId: user.id, eventType: 'auth_bootstrap', referenceId: playerId, metadata: clientFingerprint(req) });
      return json(res, 200, {
        ok: true,
        token,
        account: {
          id: user.id,
          playerId,
          name: user.display_name,
          avatar: user.avatar,
          vipActive: vipActive(user),
        },
        wallet: {
          chips: Number(wallet?.chip_balance || 0),
        },
      });
    }


    if (req.method === 'GET' && route === 'social/store-config') {
      const playerId = String(url.searchParams.get('playerId') || '');
      const auth = requirePlayerAuth(req, playerId);
      const user = await store.getUserByExternalId(playerId);
      if (!user) return json(res, 404, { error: 'Account not found' });
      if (auth?.aid && String(auth.aid) !== String(user.id)) return json(res, 403, { error: 'Account mismatch' });
      const wallet = await store.getWallet(user.id);
      return json(res, 200, {
        ok: true,
        mode: socialIapMode(),
        cashValue: false,
        withdrawable: false,
        vipActive: vipActive(user),
        vipUntil: user.vip_until || null,
        wallet: { chips: Number(wallet?.chip_balance || 0) },
        repeatConsumablePurchasesAllowed: true,
        appPurchaseLimit: null,
        products: Object.entries(SOCIAL_PRODUCTS).map(([id, v]) => ({ id, ...v })),
      });
    }

    if (req.method === 'POST' && route === 'social/iap/claim') {
      const body = await readBody(req);
      const playerId = String(body.playerId || '').trim();
      const auth = requirePlayerAuth(req, playerId);
      const user = await store.getUserByExternalId(playerId);
      if (!user) return json(res, 404, { error: 'Account not found' });
      if (auth?.aid && String(auth.aid) !== String(user.id)) return json(res, 403, { error: 'Account mismatch' });
      const productId = String(body.productId || '');
      const transactionId = String(body.transactionId || '').trim();
      const product = SOCIAL_PRODUCTS[productId];
      if (!product) return json(res, 400, { error: 'Unknown social product' });
      if (!transactionId || transactionId.length < 3) return json(res, 400, { error: 'Transaction ID required' });

      const mode = socialIapMode();
      if (mode === 'live' && !store.persistenceStatus().persistent) return json(res, 503, { error: 'Live IAP delivery requires persistent storage' });
      let verifiedTransaction = null;
      if (mode === 'live') {
        if (!appleIapConfigReady()) return json(res, 503, { error: 'Live App Store verification credentials are not configured' });
        verifiedTransaction = await verifyAppleTransaction(transactionId, productId);
      } else if (appleIapConfigReady()) {
        try { verifiedTransaction = await verifyAppleTransaction(transactionId, productId); } catch (_) { /* TestFlight/dev can continue in sandbox mode. */ }
      }
      const referenceId = `social-iap:${transactionId}`;
      const walletResult = await store.applyWalletTransaction({
        userId: user.id,
        chipsDelta: Number(product.chips || 0),
        usdCentsDelta: 0,
        type: product.type === 'vip' ? 'social_vip_purchase' : 'social_chip_purchase',
        referenceId,
        metadata: {
          productId,
          transactionId,
          verificationSource: String(body.verificationSource || ''),
          mode,
          appleVerified: Boolean(verifiedTransaction),
          cashValue: false,
          withdrawable: false,
        },
      });

      let updatedUser = user;
      if (product.type === 'vip') {
        let until;
        if (verifiedTransaction?.expiresDate) until = new Date(Number(verifiedTransaction.expiresDate)).toISOString();
        else if (mode === 'live') throw new Error('Verified VIP subscription is missing expiration data');
        else { const current = user.vip_until ? new Date(user.vip_until).getTime() : 0; const base = Math.max(Date.now(), Number.isFinite(current) ? current : 0); until = new Date(base + Number(product.vipDays || 31) * 86400000).toISOString(); }
        updatedUser = await store.setVipUntil({ userId: user.id, vipUntil: until });
      }
      await store.audit({
        actorUserId: user.id,
        eventType: 'social_iap_claim',
        referenceId,
        metadata: { productId, transactionId, idempotent: Boolean(walletResult.idempotent), mode, appleVerified: Boolean(verifiedTransaction) },
      });
      return json(res, 200, {
        ok: true,
        idempotent: Boolean(walletResult.idempotent),
        productId,
        cashValue: false,
        withdrawable: false,
        walletChips: Number(walletResult.chip_balance || 0),
        vipActive: product.type === 'vip' ? vipActive(updatedUser) : vipActive(user),
        message: product.type === 'vip' ? 'VIP activated.' : `${product.label} added.`,
      });
    }

    if(req.method==='POST'&&route==='social/support-ticket'){const body=await readBody(req);const playerId=String(body.playerId||'').trim();const auth=requirePlayerAuth(req,playerId);const user=await store.getUserByExternalId(playerId);if(!user)return json(res,404,{error:'Account not found'});if(auth?.aid&&String(auth.aid)!==String(user.id))return json(res,403,{error:'Account mismatch'});const message=String(body.message||'').trim();if(message.length<10)return json(res,400,{error:'Message must be at least 10 characters'});const ticket=await store.createSupportTicket({userId:user.id,email:body.email,message});await store.audit({actorUserId:user.id,eventType:'support_ticket_created',referenceId:ticket.id,metadata:{}});return json(res,200,{ok:true,ticketId:ticket.id});}
    if(req.method==='POST'&&route==='account/delete'){const body=await readBody(req);const playerId=String(body.playerId||'').trim();const auth=requirePlayerAuth(req,playerId);const user=await store.getUserByExternalId(playerId);if(!user)return json(res,200,{ok:true,alreadyDeleted:true});if(auth?.aid&&String(auth.aid)!==String(user.id))return json(res,403,{error:'Account mismatch'});await store.audit({actorUserId:user.id,eventType:'account_delete_requested',referenceId:user.id,metadata:{}});await store.deleteUserAccount({userId:user.id,externalPlayerId:playerId});return json(res,200,{ok:true,deleted:true});}

    if (req.method === 'GET' && route === 'lobby') {
      return json(res, 200, await lobbyState());
    }

    if (req.method === 'POST' && route === 'join') {
      const body = await readBody(req);
      const playerId = String(body.playerId || '').trim();
      if (!playerId) return json(res, 400, { error: 'playerId required' });
      const auth = requirePlayerAuth(req, playerId);
      const account = await store.ensureUser({ externalPlayerId: playerId, displayName: body.name, avatar: body.avatar });
      if (auth?.aid && String(auth.aid) !== String(account.user.id)) return json(res, 403, { error: 'Account mismatch' });
      const room = await joinRoom({
        playerId, name: body.name, avatar: body.avatar, vip: vipActive(account.user), playerCount: Number(body.playerCount),
        excludeRoomId: String(body.excludeRoomId || ''), accountId: account.user.id,
      });
      return json(res, 200, publicState(room, playerId));
    }

    if (req.method === 'GET' && route === 'state') {
      const roomId = String(url.searchParams.get('roomId') || '');
      const playerId = String(url.searchParams.get('playerId') || '');
      requirePlayerAuth(req, playerId);
      const room = await getRoom(roomId);
      if (!room) return json(res, 404, { error: 'Room not found' });
      const beforeSeq = Number(room.actionSeq || 0);
      const state = publicState(room, playerId);
      if (!state) return json(res, 403, { error: 'Player not in room' });
      if (Number(room.actionSeq || 0) !== beforeSeq) {
        await persistRoom(room);
        await persistFinancialEffects(room);
      }
      return json(res, 200, state);
    }

    if (req.method === 'POST' && route === 'tip-dealer') {
      const body = await readBody(req);
      const room = await getRoom(String(body.roomId || ''));
      const playerId = String(body.playerId || '');
      requirePlayerAuth(req, playerId);
      const chips = Number(body.chips || 0);
      if (!room) return json(res, 404, { error: 'Room not found' });
      const player = room.players.find(p => p.id === playerId);
      if (!player) return json(res, 403, { error: 'Player not in room' });
      if (![10, 25, 50, 100].includes(chips)) return json(res, 400, { error: 'Tip must be 10, 25, 50, or 100 chips' });
      if (player.chips < chips) return json(res, 409, { error: 'Not enough chips' });
      player.chips -= chips;
      room.dealerTipTotal = (room.dealerTipTotal || 0) + chips;
      room.lastTipAmount = chips;
      room.lastTipPlayerId = player.id;
      room.lastTipReferenceId = `tip:${room.id}:${room.round}:${room.actionSeq + 1}:${player.id}`;
      room.actionSeq = (room.actionSeq || 0) + 1;
      room.lastAction = 'tip';
      room.lastActorId = player.id;
      room.lastBetAmount = 0;
      room.message = `${player.name} tipped the dealer ${chips} chips. Thank you!`;
      await persistRoom(room);
      await store.recordRevenue({
        type: 'dealer_tip', chips, roomId: room.id, handId: room.handId || null,
        referenceId: room.lastTipReferenceId, metadata: { playerId },
      });
      return json(res, 200, publicState(room, playerId));
    }

    if (req.method === 'POST' && route === 'leave') {
      const body = await readBody(req);
      const room = await getRoom(String(body.roomId || ''));
      const playerId = String(body.playerId || '');
      const auth = requirePlayerAuth(req, playerId);
      if (!room) return json(res, 200, { ok: true, alreadyGone: true });
      const leaving = room.players.find(p => p.id === playerId);
      if (!leaving) return json(res, 200, { ok: true, alreadyGone: true });
      const accountId = leaving.accountId || auth?.aid;
      const releaseChips = Number(leaving.chips || 0);
      const seatId = leaving.seatId || `${room.id}:${playerId}`;
      leaveRoom(room, playerId);
      if (!room.players.length) {
        rooms.delete(room.id);
        await store.deleteRoom(room.id);
      } else {
        await persistRoom(room);
        await persistFinancialEffects(room);
      }
      let wallet = null;
      if (accountId && releaseChips > 0) {
        wallet = await store.applyWalletTransaction({
          userId: accountId, chipsDelta: releaseChips, type: 'table_release', referenceId: `table-release:${seatId}`,
          metadata: { roomId: room.id, playerId },
        });
      }
      return json(res, 200, { ok: true, walletChips: wallet ? Number(wallet.chip_balance || 0) : null });
    }

    if (req.method === 'POST' && route === 'action') {
      const body = await readBody(req);
      const room = await getRoom(String(body.roomId || ''));
      const playerId = String(body.playerId || '');
      requirePlayerAuth(req, playerId);
      const action = String(body.action || '');
      if (!room) return json(res, 404, { error: 'Room not found' });
      tickRoom(room);
      const player = room.players.find(p => p.id === playerId);
      if (!player) return json(res, 403, { error: 'Player not in room' });

      if (action === 'new') {
        if (room.status !== 'showdown') return json(res, 409, { error: 'Round still active' });
        player.readyNext = true;
        const ready = room.players.filter(p => p.readyNext).length;
        room.actionSeq = (room.actionSeq || 0) + 1;
        room.lastAction = 'ready-next';
        room.lastActorId = player.id;
        room.message = `${ready}/${room.players.length} players ready for the next round.`;
        if (room.players.length === room.playerCount && ready === room.players.length) {
          startRound(room);
        } else if (ready === room.players.length && room.players.length < room.playerCount) {
          room.status = 'waiting';
          room.winnerId = null;
          room.revealed = false;
          room.pot = 0;
          room.turnExpiresAt = 0;
          room.lastPayout = 0;
          room.lastFee = 0;
          for (const p of room.players) { p.folded = false; p.seen = false; p.cards = []; }
          room.message = `Seat open: ${room.players.length}/${room.playerCount}. Waiting for player...`;
          addToQueue(room);
        }
        await persistRoom(room);
        await persistFinancialEffects(room);
        return json(res, 200, publicState(room, playerId));
      }

      if (room.status !== 'playing') return json(res, 409, { error: 'Round is not active' });
      if (player.folded) return json(res, 409, { error: 'Player already packed' });
      const current = room.players[room.turnIndex];
      if (!current || current.id !== playerId) return json(res, 409, { error: 'Wait for your turn' });
      room.lastActorId = player.id;
      room.lastTimeoutPlayerId = null;
      room.lastBetAmount = 0;

      if (action === 'see') {
        if (player.seen) return json(res, 409, { error: 'Cards already seen' });
        player.seen = true;
        room.actionSeq = (room.actionSeq || 0) + 1;
        room.lastAction = 'see';
        room.message = `${player.name} is now SEEN. Their cards are open only to them.`;
      } else if (action === 'blind') {
        if (player.seen) return json(res, 409, { error: 'You are Seen. Use Chaal.' });
        if (room.pot >= room.cap) return json(res, 409, { error: 'Table limit reached. Use Show.' });
        const amount = Math.min(room.currentBet, room.cap - room.pot, player.chips);
        if (amount <= 0) return json(res, 409, { error: 'Not enough chips' });
        player.chips -= amount; room.pot += amount; room.lastBetAmount = amount;
        room.actionSeq = (room.actionSeq || 0) + 1; room.lastAction = 'blind';
        room.message = `${player.name} plays BLIND for ${amount} chips.`; advanceTurn(room);
      } else if (action === 'chaal') {
        if (!player.seen) return json(res, 409, { error: 'See your cards before Chaal' });
        if (room.pot >= room.cap) return json(res, 409, { error: 'Table limit reached. Use Show.' });
        const amount = Math.min(room.currentBet * 2, room.cap - room.pot, player.chips);
        if (amount <= 0) return json(res, 409, { error: 'Not enough chips' });
        player.chips -= amount; room.pot += amount; room.lastBetAmount = amount;
        room.actionSeq = (room.actionSeq || 0) + 1; room.lastAction = 'chaal';
        room.message = `${player.name} plays CHAAL for ${amount} chips.`; advanceTurn(room);
      } else if (action === 'pack') {
        player.folded = true; room.actionSeq = (room.actionSeq || 0) + 1; room.lastAction = 'pack';
        room.message = `${player.name} packed.`; maybeSettleLastStanding(room); if (room.status === 'playing') advanceTurn(room);
      } else if (action === 'show') {
        room.actionSeq = (room.actionSeq || 0) + 1; room.lastAction = 'show'; room.message = `${player.name} called Show.`; settle(room);
      } else if (action === 'sideshow') {
        if (!player.seen) return json(res, 409, { error: 'See your cards before Side Show' });
        const target = eligibleSideShowTarget(room, player);
        if (!target) return json(res, 409, { error: 'No eligible seen player for Side Show' });
        const comparison = compareHands(player.cards, target.cards);
        const loser = comparison > 0 ? target : player;
        loser.folded = true; room.actionSeq = (room.actionSeq || 0) + 1; room.lastAction = 'sideshow';
        room.message = `${player.name} Side Show vs ${target.name}. ${loser.name} packs.`;
        maybeSettleLastStanding(room); if (room.status === 'playing') advanceTurn(room);
      } else {
        return json(res, 400, { error: 'Unknown action' });
      }

      await persistRoom(room);
      await persistFinancialEffects(room);
      return json(res, 200, publicState(room, playerId));
    }

    return json(res, 404, { error: 'Not found' });
  } catch (e) {
    const status = Number(e.statusCode || (e.code === 'ROOM_VERSION_CONFLICT' ? 409 : 400));
    return json(res, status, { error: e.message || 'Request failed', code: e.code || null });
  }
}


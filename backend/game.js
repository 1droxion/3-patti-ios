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
  const mode = String(process.env.SOCIAL_IAP_MODE || 'sandbox').toLowerCase();
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
  const environment = String(process.env.APPLE_IAP_ENV || (socialIapMode() === 'live' ? 'production' : 'sandbox')).toLowerCase();
  const base = environment === 'production'
    ? 'https://api.storekit.itunes.apple.com'
    : 'https://api.storekit-sandbox.itunes.apple.com';
  const token = makeAppleServerJwt();
  const response = await fetch(`${base}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`, {
    headers: { authorization: `Bearer ${token}`, accept: 'application/json' },
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data?.errorMessage || `Apple transaction verification failed (${response.status})`);
  const tx = decodeJwsPayload(data.signedTransactionInfo);
  if (String(tx.transactionId || '') !== String(transactionId)) throw new Error('Apple transaction ID mismatch');
  if (String(tx.productId || '') !== String(expectedProductId)) throw new Error('Apple product ID mismatch');
  if (String(tx.bundleId || '') !== String(process.env.APPLE_BUNDLE_ID)) throw new Error('Apple bundle ID mismatch');
  if (tx.revocationDate) throw new Error('Apple transaction was revoked');
  return tx;
}


export async function handle(req, res, forcedRoute = '') {
  if (req.method === 'OPTIONS') return json(res, 204, {});
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const route = String(forcedRoute || req.query?.route || url.searchParams.get('route') || url.pathname)
    .replace(/^\/+|\/+$/g, '');

  try {
    if (req.method === 'GET' && (route === '' || route === 'health')) {
      const readiness = paymentReadiness();
      return json(res, 200, {
        ok: true,
        version: '1.6.0',
        cachedRooms: rooms.size,
        persistence: readiness.persistence,
        security: readiness.security,
        cashModeRequested: readiness.requested,
        cashModeEnabled: readiness.enabled,
        cashModeBlockers: readiness.blockers,
      });
    }

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
          kycStatus: user.kyc_status,
          ageVerified: Boolean(user.age_verified),
          geoState: user.geo_state,
          cashEligible: Boolean(user.cash_eligible),
        },
        wallet: {
          chips: Number(wallet?.chip_balance || 0),
          usdCents: Number(wallet?.usd_cents || 0),
        },
      });
    }


    if (req.method === 'GET' && route === 'kyc/status') {
      const playerId = String(url.searchParams.get('playerId') || '');
      const auth = requirePlayerAuth(req, playerId);
      const user = await store.getUserByExternalId(playerId);
      if (!user) return json(res, 404, { error: 'Account not found' });
      if (auth?.aid && String(auth.aid) !== String(user.id)) return json(res, 403, { error: 'Account mismatch' });
      const eligibility = userCashEligibility(user);
      return json(res, 200, {
        ok: true,
        profile: {
          legalName: user.legal_name || '',
          email: user.email || '',
          phone: user.phone || '',
          dob: user.dob || '',
          homeAddress: user.home_address || '',
          taxIdType: user.tax_id_type || '',
          taxIdLast4: user.tax_id_last4 || '',
          governmentIdType: user.government_id_type || '',
          governmentIdLast4: user.government_id_last4 || '',
          ageDeclared21: Boolean(user.age_declared_21),
        },
        verification: {
          kycStatus: user.kyc_status || 'unverified',
          ageVerified: Boolean(user.age_verified),
          geoState: user.geo_state || null,
          cashEligible: eligibility.eligible,
          blockers: eligibility.blockers,
        },
      });
    }

    if (req.method === 'POST' && route === 'kyc/profile') {
      const body = await readBody(req);
      const playerId = String(body.playerId || '').trim();
      const auth = requirePlayerAuth(req, playerId);
      const user = await store.getUserByExternalId(playerId);
      if (!user) return json(res, 404, { error: 'Account not found' });
      if (auth?.aid && String(auth.aid) !== String(user.id)) return json(res, 403, { error: 'Account mismatch' });

      const legalName = String(body.legalName || '').trim();
      const email = String(body.email || '').trim().toLowerCase();
      const phone = String(body.phone || '').trim();
      const dob = String(body.dob || '').trim();
      const homeAddress = String(body.homeAddress || '').trim();
      const taxIdType = String(body.taxIdType || '').trim().toLowerCase();
      const taxId = String(body.taxId || '').trim();
      const governmentIdType = String(body.governmentIdType || '').trim().toLowerCase();
      const governmentId = String(body.governmentId || '').trim();
      const ageDeclared21 = body.ageDeclared21 === true;
      const age = calculateAge(dob);

      if (legalName.length < 3) return json(res, 400, { error: 'Full legal name required' });
      if (!email.includes('@') || email.length < 5) return json(res, 400, { error: 'Valid email required' });
      if (phone.replace(/\D/g, '').length < 10) return json(res, 400, { error: 'Valid mobile number required' });
      if (age === null) return json(res, 400, { error: 'Valid date of birth required' });
      if (age < 21 || !ageDeclared21) return json(res, 403, { error: 'Cash gaming verification requires age 21+' });
      if (homeAddress.length < 8) return json(res, 400, { error: 'Home address required' });
      if (!['license', 'passport'].includes(governmentIdType)) return json(res, 400, { error: 'Driver license or passport required' });
      if (governmentId.replace(/[^A-Za-z0-9]/g, '').length < 5) return json(res, 400, { error: 'Government ID number required' });
      if (taxId && !['ssn', 'tin'].includes(taxIdType)) return json(res, 400, { error: 'Choose SSN or TIN for optional tax ID' });

      const taxIdHash = taxId ? createHash('sha256').update(`${process.env.KYC_HASH_PEPPER || process.env.AUTH_SECRET || 'dev'}:${taxId}`).digest('hex') : null;
      const governmentIdHash = createHash('sha256').update(`${process.env.KYC_HASH_PEPPER || process.env.AUTH_SECRET || 'dev'}:${governmentId}`).digest('hex');
      const updated = await store.updateKycProfile({
        userId: user.id,
        legalName,
        email,
        phone,
        dob,
        homeAddress,
        taxIdType: taxId ? taxIdType : null,
        taxIdLast4: cleanLast4(taxId),
        taxIdHash,
        governmentIdType,
        governmentIdLast4: cleanLast4(governmentId),
        governmentIdHash,
        ageDeclared21: true,
      });
      await store.audit({ actorUserId: user.id, eventType: 'kyc_profile_submitted', referenceId: user.id, metadata: { governmentIdType, taxIdProvided: Boolean(taxId), age } });
      return json(res, 200, {
        ok: true,
        status: updated.kyc_status || 'submitted',
        message: 'Identity details saved securely. Verification is pending the approved KYC provider.',
        rawTaxIdStored: false,
        rawGovernmentIdStored: false,
      });
    }

    if (req.method === 'POST' && route === 'kyc/provider-webhook') {
      const expected = String(process.env.KYC_WEBHOOK_SECRET || '');
      const provided = String(req.headers['x-kyc-webhook-secret'] || '');
      if (!expected || provided !== expected) return json(res, 401, { error: 'Invalid KYC webhook secret' });
      const body = await readBody(req);
      const playerId = String(body.playerId || '').trim();
      const status = String(body.status || '').toLowerCase();
      if (!['verified', 'failed', 'pending'].includes(status)) return json(res, 400, { error: 'Invalid KYC status' });
      const user = await store.getUserByExternalId(playerId);
      if (!user) return json(res, 404, { error: 'Account not found' });
      const approvedStates = approvedCashStates();
      const geoState = String(body.geoState || user.geo_state || '').toUpperCase() || null;
      const ageVerified = body.ageVerified === true;
      const cashEligible = status === 'verified' && ageVerified && geoState && approvedStates.includes(geoState);
      const updated = await store.setKycVerification({ userId: user.id, status, ageVerified, geoState, cashEligible });
      await store.audit({ actorUserId: user.id, eventType: 'kyc_provider_result', referenceId: String(body.verificationId || ''), metadata: { status, ageVerified, geoState, cashEligible } });
      return json(res, 200, { ok: true, kycStatus: updated.kyc_status, ageVerified: updated.age_verified, geoState: updated.geo_state, cashEligible: updated.cash_eligible });
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
      if (product.type === 'vip' && !walletResult.idempotent) {
        const current = user.vip_until ? new Date(user.vip_until).getTime() : 0;
        const base = Math.max(Date.now(), Number.isFinite(current) ? current : 0);
        const until = new Date(base + Number(product.vipDays || 31) * 86400000).toISOString();
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

    if (req.method === 'GET' && route === 'lobby') {
      return json(res, 200, await lobbyState());
    }

    if (req.method === 'GET' && route === 'payments-config') {
      const readiness = paymentReadiness();
      const approvedStates = String(process.env.APPROVED_CASH_STATES || '')
        .split(',').map(v => v.trim().toUpperCase()).filter(Boolean);
      return json(res, 200, {
        cashModeEnabled: readiness.enabled,
        cashModeRequested: readiness.requested,
        blockers: readiness.blockers,
        chipsPerUsd: 100,
        mode: readiness.enabled ? 'live_ready' : 'sandbox_locked',
        approvedStates,
        depositMethods: [
          { id: 'apple_pay', label: 'Apple Pay', enabled: readiness.enabled && String(process.env.APPLE_PAY_LIVE || '').toLowerCase() === 'true' },
          { id: 'cash_app', label: 'Cash App Pay', enabled: readiness.enabled && String(process.env.CASH_APP_LIVE || '').toLowerCase() === 'true' },
          { id: 'card', label: 'Debit / credit card', enabled: readiness.enabled && String(process.env.CARD_PAYMENTS_LIVE || '').toLowerCase() === 'true' },
        ],
        withdrawalMethods: [
          { id: 'paypal', label: 'PayPal', enabled: readiness.enabled && String(process.env.PAYPAL_LIVE || '').toLowerCase() === 'true' },
          { id: 'bank', label: 'Bank / ACH', enabled: readiness.enabled && String(process.env.BANK_PAYOUTS_LIVE || '').toLowerCase() === 'true' },
        ],
      });
    }

    if (req.method === 'GET' && route === 'wallet') {
      const playerId = String(url.searchParams.get('playerId') || '');
      const auth = requirePlayerAuth(req, playerId);
      const user = await store.getUserByExternalId(playerId);
      if (!user) return json(res, 404, { error: 'Account not found' });
      if (auth?.aid && String(auth.aid) !== String(user.id)) return json(res, 403, { error: 'Account mismatch' });
      const wallet = await store.getWallet(user.id);
      return json(res, 200, { ok: true, chips: Number(wallet?.chip_balance || 0), usdCents: Number(wallet?.usd_cents || 0) });
    }


    if (req.method === 'POST' && route === 'deposit-live') {
      const body = await readBody(req);
      const playerId = String(body.playerId || '').trim();
      const auth = requirePlayerAuth(req, playerId);
      const user = await store.getUserByExternalId(playerId);
      if (!user) return json(res, 404, { error: 'Account not found' });
      if (auth?.aid && String(auth.aid) !== String(user.id)) return json(res, 403, { error: 'Account mismatch' });
      const eligibility = userCashEligibility(user);
      if (!eligibility.eligible) return json(res, 403, { error: 'Real-money deposit is locked', blockers: eligibility.blockers });
      return json(res, 503, { error: 'Live deposit adapter is not connected. Do not credit money without a signed provider webhook.' });
    }

    if (req.method === 'POST' && route === 'withdraw-live') {
      const body = await readBody(req);
      const playerId = String(body.playerId || '').trim();
      const auth = requirePlayerAuth(req, playerId);
      const user = await store.getUserByExternalId(playerId);
      if (!user) return json(res, 404, { error: 'Account not found' });
      if (auth?.aid && String(auth.aid) !== String(user.id)) return json(res, 403, { error: 'Account mismatch' });
      const eligibility = userCashEligibility(user);
      if (!eligibility.eligible) return json(res, 403, { error: 'Real-money withdrawal is locked', blockers: eligibility.blockers });
      return json(res, 503, { error: 'Live payout adapter is not connected. Do not mark a payout completed without a signed provider webhook.' });
    }

    if (req.method === 'POST' && route === 'deposit-sandbox') {
      const body = await readBody(req);
      const playerId = String(body.playerId || '').trim();
      const auth = requirePlayerAuth(req, playerId);
      const provider = String(body.provider || '').trim();
      const amountUsd = Number(body.amountUsd || 0);
      if (!['apple_pay', 'cash_app', 'card'].includes(provider)) return json(res, 400, { error: 'Unsupported deposit provider' });
      if (![5, 10, 25, 50].includes(amountUsd)) return json(res, 400, { error: 'Sandbox amount must be 5, 10, 25, or 50 USD' });
      const user = await store.getUserByExternalId(playerId);
      if (!user) return json(res, 404, { error: 'Account not found' });
      if (auth?.aid && String(auth.aid) !== String(user.id)) return json(res, 403, { error: 'Account mismatch' });
      const requestId = `DEP-SANDBOX-${randomUUID()}`;
      const chips = Math.round(amountUsd * 100);
      await store.createPaymentRequest({
        userId: user.id, direction: 'deposit', provider, amountUsdCents: Math.round(amountUsd * 100), chips,
        status: 'sandbox_approved', metadata: { cashValue: false },
      });
      const wallet = await store.applyWalletTransaction({
        userId: user.id, chipsDelta: chips, type: 'sandbox_deposit', referenceId: requestId,
        metadata: { provider, amountUsd, cashValue: false },
      });
      await store.audit({ actorUserId: user.id, eventType: 'sandbox_deposit', referenceId: requestId, metadata: { provider, amountUsd, chips } });
      return json(res, 200, {
        ok: true, mode: 'sandbox', provider, status: 'simulated_approved', requestId, amountUsd, chips,
        walletChips: Number(wallet.chip_balance || 0),
      });
    }

    if (req.method === 'POST' && route === 'withdraw-sandbox') {
      const body = await readBody(req);
      const playerId = String(body.playerId || '').trim();
      const auth = requirePlayerAuth(req, playerId);
      const provider = String(body.provider || 'paypal').trim();
      const destination = String(body.destination || body.paypalEmail || '').trim();
      const chips = Number(body.chips || 0);
      if (!['paypal', 'bank'].includes(provider)) return json(res, 400, { error: 'Unsupported withdrawal provider' });
      if (provider === 'paypal' && !destination.includes('@')) return json(res, 400, { error: 'Valid PayPal email required' });
      if (provider === 'bank' && destination.length < 4) return json(res, 400, { error: 'Bank payout reference required' });
      if (!Number.isInteger(chips) || chips <= 0) return json(res, 400, { error: 'Valid chip amount required' });
      const user = await store.getUserByExternalId(playerId);
      if (!user) return json(res, 404, { error: 'Account not found' });
      if (auth?.aid && String(auth.aid) !== String(user.id)) return json(res, 403, { error: 'Account mismatch' });
      const requestId = `WD-SANDBOX-${randomUUID()}`;
      const wallet = await store.applyWalletTransaction({
        userId: user.id, chipsDelta: -chips, type: 'sandbox_withdraw_hold', referenceId: requestId,
        metadata: { provider, cashValue: false },
      });
      await store.createPaymentRequest({
        userId: user.id, direction: 'withdrawal', provider, amountUsdCents: Math.round(chips), chips,
        destinationMasked: maskDestination(provider, destination), status: 'sandbox_held', metadata: { cashValue: false, requestId },
      });
      await store.audit({ actorUserId: user.id, eventType: 'sandbox_withdrawal', referenceId: requestId, metadata: { provider, chips } });
      return json(res, 200, {
        ok: true, mode: 'sandbox', provider, status: 'not_sent', requestId, chips,
        usdPreview: Number((chips / 100).toFixed(2)), walletChips: Number(wallet.chip_balance || 0),
      });
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


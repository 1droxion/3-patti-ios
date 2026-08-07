import { randomUUID, randomInt } from 'node:crypto';

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
    'access-control-allow-headers': 'content-type',
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

function makeDeck() {
  const cards = [];
  for (let suit = 0; suit < 4; suit++) {
    for (let rank = 2; rank <= 14; rank++) cards.push({ rank, suit });
  }
  for (let i = cards.length - 1; i > 0; i--) {
    const j = randomInt(i + 1);
    [cards[i], cards[j]] = [cards[j], cards[i]];
  }
  return cards;
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
  const deck = makeDeck();
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
    canSideShow: Boolean(sideShowTarget),
    sideShowTargetId: sideShowTarget?.id || null,
    myId: playerId,
    myCards: (me.seen || room.revealed) ? (me.cards || []) : [{}, {}, {}],
    mySeen: me.seen,
    players: room.players.map(p => ({
      id: p.id,
      name: p.name,
      chips: p.chips,
      folded: p.folded,
      seen: p.seen,
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

function joinRoom({ playerId, name, playerCount }) {
  if (!Number.isInteger(playerCount) || playerCount < 2 || playerCount > 10) {
    throw new Error('playerCount must be 2..10');
  }

  const q = queueFor(playerCount);
  let room = q
    .map(id => rooms.get(id))
    .find(r => r && r.status === 'waiting' && r.players.length < r.playerCount);

  if (!room) {
    room = {
      id: randomUUID(),
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
    };
    rooms.set(room.id, room);
    q.push(room.id);
  }

  if (!room.players.some(p => p.id === playerId)) {
    room.players.push({
      id: playerId,
      name: String(name || 'Player').slice(0, 24),
      chips: 10000,
      folded: false,
      seen: false,
      cards: [],
    });
  }

  room.message = `Waiting for players: ${room.players.length}/${room.playerCount}`;
  if (room.players.length === room.playerCount) {
    startRound(room);
    queues.set(playerCount, q.filter(id => id !== room.id));
  }
  return room;
}

export async function handle(req, res, forcedRoute = '') {
  if (req.method === 'OPTIONS') return json(res, 204, {});
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const route = String(forcedRoute || req.query?.route || url.searchParams.get('route') || url.pathname)
    .replace(/^\/+|\/+$/g, '');

  if (req.method === 'GET' && (route === '' || route === 'health')) {
    return json(res, 200, { ok: true, rooms: rooms.size, version: '1.0.0' });
  }

  if (req.method === 'POST' && route === 'join') {
    try {
      const body = await readBody(req);
      const playerId = String(body.playerId || '').trim();
      if (!playerId) return json(res, 400, { error: 'playerId required' });
      const room = joinRoom({ playerId, name: body.name, playerCount: Number(body.playerCount) });
      return json(res, 200, publicState(room, playerId));
    } catch (e) {
      return json(res, 400, { error: e.message });
    }
  }

  if (req.method === 'GET' && route === 'state') {
    const room = rooms.get(url.searchParams.get('roomId'));
    const playerId = url.searchParams.get('playerId');
    if (!room) return json(res, 404, { error: 'Room not found' });
    const state = publicState(room, playerId);
    if (!state) return json(res, 403, { error: 'Player not in room' });
    return json(res, 200, state);
  }

  if (req.method === 'POST' && route === 'action') {
    try {
      const body = await readBody(req);
      const room = rooms.get(String(body.roomId || ''));
      const playerId = String(body.playerId || '');
      const action = String(body.action || '');

      if (!room) return json(res, 404, { error: 'Room not found' });
      tickRoom(room);
      const player = room.players.find(p => p.id === playerId);
      if (!player) return json(res, 403, { error: 'Player not in room' });

      if (action === 'new') {
        if (room.status !== 'showdown') return json(res, 409, { error: 'Round still active' });
        startRound(room);
        return json(res, 200, publicState(room, playerId));
      }

      if (room.status !== 'playing') return json(res, 409, { error: 'Round is not active' });
      if (player.folded) return json(res, 409, { error: 'Player already packed' });

      const current = room.players[room.turnIndex];
      if (!current || current.id !== playerId) {
        return json(res, 409, { error: 'Wait for your turn' });
      }

      room.lastActorId = player.id;
      room.lastTimeoutPlayerId = null;
      room.lastBetAmount = 0;

      if (action === 'see') {
        if (player.seen) return json(res, 409, { error: 'Cards already seen' });
        player.seen = true;
        room.actionSeq = (room.actionSeq || 0) + 1;
        room.lastAction = 'see';
        room.message = `${player.name} is now SEEN. Their cards are open only to them.`;
        // Seeing cards does not consume the turn. The active player's server timer keeps running.
      } else if (action === 'blind') {
        if (player.seen) return json(res, 409, { error: 'You are Seen. Use Chaal.' });
        if (room.pot >= room.cap) return json(res, 409, { error: 'Table limit reached. Use Show.' });
        const amount = Math.min(room.currentBet, room.cap - room.pot, player.chips);
        if (amount <= 0) return json(res, 409, { error: 'Not enough chips' });
        player.chips -= amount;
        room.pot += amount;
        room.lastBetAmount = amount;
        room.actionSeq = (room.actionSeq || 0) + 1;
        room.lastAction = 'blind';
        room.message = `${player.name} plays BLIND for ${amount} chips.`;
        // Blind keeps the same base stake. Seen players automatically pay double with Chaal.
        advanceTurn(room);
      } else if (action === 'chaal') {
        if (!player.seen) return json(res, 409, { error: 'See your cards before Chaal' });
        if (room.pot >= room.cap) return json(res, 409, { error: 'Table limit reached. Use Show.' });
        const amount = Math.min(room.currentBet * 2, room.cap - room.pot, player.chips);
        if (amount <= 0) return json(res, 409, { error: 'Not enough chips' });
        player.chips -= amount;
        room.pot += amount;
        room.lastBetAmount = amount;
        room.actionSeq = (room.actionSeq || 0) + 1;
        room.lastAction = 'chaal';
        room.message = `${player.name} plays CHAAL for ${amount} chips.`;
        advanceTurn(room);
      } else if (action === 'pack') {
        player.folded = true;
        room.actionSeq = (room.actionSeq || 0) + 1;
        room.lastAction = 'pack';
        room.message = `${player.name} packed.`;
        maybeSettleLastStanding(room);
        if (room.status === 'playing') advanceTurn(room);
      } else if (action === 'show') {
        room.actionSeq = (room.actionSeq || 0) + 1;
        room.lastAction = 'show';
        room.message = `${player.name} called Show.`;
        settle(room);
      } else if (action === 'sideshow') {
        if (!player.seen) return json(res, 409, { error: 'See your cards before Side Show' });
        const target = eligibleSideShowTarget(room, player);
        if (!target) return json(res, 409, { error: 'No eligible seen player for Side Show' });
        const comparison = compareHands(player.cards, target.cards);
        const loser = comparison > 0 ? target : player; // requester loses ties
        loser.folded = true;
        room.actionSeq = (room.actionSeq || 0) + 1;
        room.lastAction = 'sideshow';
        room.message = `${player.name} Side Show vs ${target.name}. ${loser.name} packs.`;
        maybeSettleLastStanding(room);
        if (room.status === 'playing') advanceTurn(room);
      } else {
        return json(res, 400, { error: 'Unknown action' });
      }

      return json(res, 200, publicState(room, playerId));
    } catch (e) {
      return json(res, 400, { error: e.message });
    }
  }

  return json(res, 404, { error: 'Not found' });
}

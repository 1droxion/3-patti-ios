import { randomUUID } from 'node:crypto';

const memUsers = new Map();
const memWallets = new Map();
const memLedgerRefs = new Map();
const memRooms = new Map();
const memPayments = new Map();
const memRevenueRefs = new Set();
const memHands = new Set();
const memAudit = [];
const memSupport = [];

function supabaseReady() {
  return Boolean(process.env.SUPABASE_URL && (process.env.SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY));
}

export function persistenceStatus() {
  return {
    mode: supabaseReady() ? 'supabase-postgres' : 'memory-development',
    persistent: supabaseReady(),
    supabaseConfigured: supabaseReady(),
  };
}

async function sb(path, { method = 'GET', body, prefer = '', headers = {} } = {}) {
  const base = String(process.env.SUPABASE_URL || '').replace(/\/$/, '');
  const key = String(process.env.SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || '');
  if (!base || !key) throw new Error('Supabase persistence is not configured');
  const response = await fetch(`${base}/rest/v1/${path}`, {
    method,
    headers: {
      apikey: key,
      authorization: `Bearer ${key}`,
      'content-type': 'application/json',
      ...(prefer ? { prefer } : {}),
      ...headers,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  if (!response.ok) {
    const error = new Error(data?.message || data?.error || `Supabase HTTP ${response.status}`);
    error.code = data?.code;
    throw error;
  }
  return data;
}

export async function ensureUser({ externalPlayerId, displayName, avatar }) {
  const external = String(externalPlayerId);
  const cleanName = String(displayName || 'Player').slice(0, 24);
  const cleanAvatar = Math.max(1, Math.min(8, Number(avatar) || 1));
  const initialDemoChips = String(process.env.CASH_MODE_ENABLED || '').toLowerCase() === 'true'
    ? 0
    : Number(process.env.INITIAL_DEMO_CHIPS || 25000);

  if (!supabaseReady()) {
    let user = memUsers.get(external);
    if (!user) {
      user = {
        id: randomUUID(),
        external_player_id: external,
        display_name: cleanName,
        avatar: cleanAvatar,
        kyc_status: 'unverified',
        age_verified: false,
        geo_state: null,
        cash_eligible: false,
        vip_until: null,
      };
      memUsers.set(external, user);
      memWallets.set(user.id, { user_id: user.id, chip_balance: initialDemoChips, usd_cents: 0 });
      memLedgerRefs.set(`account-bootstrap:${user.id}`, true);
    } else {
      user.display_name = cleanName;
      user.avatar = cleanAvatar;
    }
    return { user, wallet: { ...memWallets.get(user.id) } };
  }

  const users = await sb('users?on_conflict=external_player_id', {
    method: 'POST',
    prefer: 'resolution=merge-duplicates,return=representation',
    body: [{ external_player_id: external, display_name: cleanName, avatar: cleanAvatar }],
  });
  const user = Array.isArray(users) ? users[0] : users;
  let wallets = await sb(`wallets?user_id=eq.${encodeURIComponent(user.id)}&select=*`);
  if (!wallets?.length) {
    wallets = await sb('wallets', {
      method: 'POST',
      prefer: 'return=representation',
      body: [{ user_id: user.id, chip_balance: Math.max(0, Math.trunc(initialDemoChips)), usd_cents: 0 }],
    });
    if (initialDemoChips > 0) {
      await sb('ledger_entries', {
        method: 'POST',
        prefer: 'resolution=ignore-duplicates',
        body: [{
          user_id: user.id,
          entry_type: 'demo_bootstrap',
          chips_delta: Math.trunc(initialDemoChips),
          usd_cents_delta: 0,
          reference_id: `account-bootstrap:${user.id}`,
          metadata: { cash_value: false },
        }],
      });
    }
  }
  return { user, wallet: wallets[0] };
}

export async function getUserByExternalId(externalPlayerId) {
  const external = String(externalPlayerId);
  if (!supabaseReady()) return memUsers.get(external) || null;
  const rows = await sb(`users?external_player_id=eq.${encodeURIComponent(external)}&select=*&limit=1`);
  return rows?.[0] || null;
}


export async function updateKycProfile({ userId, legalName, email, phone, dob, homeAddress, taxIdType, taxIdLast4, taxIdHash, governmentIdType, governmentIdLast4, governmentIdHash, ageDeclared21 }) {
  const patch = {
    legal_name: legalName,
    email,
    phone,
    dob,
    home_address: homeAddress,
    tax_id_type: taxIdType,
    tax_id_last4: taxIdLast4,
    tax_id_hash: taxIdHash,
    government_id_type: governmentIdType,
    government_id_last4: governmentIdLast4,
    government_id_hash: governmentIdHash,
    age_declared_21: Boolean(ageDeclared21),
    kyc_status: 'submitted',
    cash_eligible: false,
    updated_at: new Date().toISOString(),
  };
  if (!supabaseReady()) {
    const user = [...memUsers.values()].find(u => String(u.id) === String(userId));
    if (!user) throw new Error('User not found');
    Object.assign(user, patch);
    return { ...user };
  }
  const rows = await sb(`users?id=eq.${encodeURIComponent(userId)}`, { method: 'PATCH', prefer: 'return=representation', body: patch });
  return rows?.[0] || patch;
}

export async function setKycVerification({ userId, status, ageVerified, geoState, cashEligible }) {
  const patch = {
    kyc_status: String(status || 'pending'),
    age_verified: Boolean(ageVerified),
    geo_state: geoState || null,
    cash_eligible: Boolean(cashEligible),
    updated_at: new Date().toISOString(),
  };
  if (!supabaseReady()) {
    const user = [...memUsers.values()].find(u => String(u.id) === String(userId));
    if (!user) throw new Error('User not found');
    Object.assign(user, patch);
    return { ...user };
  }
  const rows = await sb(`users?id=eq.${encodeURIComponent(userId)}`, { method: 'PATCH', prefer: 'return=representation', body: patch });
  return rows?.[0] || patch;
}


export async function setVipUntil({ userId, vipUntil }) {
  const patch = { vip_until: vipUntil || null, updated_at: new Date().toISOString() };
  if (!supabaseReady()) {
    const user = [...memUsers.values()].find(u => String(u.id) === String(userId));
    if (!user) throw new Error('User not found');
    Object.assign(user, patch);
    return { ...user };
  }
  const rows = await sb(`users?id=eq.${encodeURIComponent(userId)}`, {
    method: 'PATCH',
    prefer: 'return=representation',
    body: patch,
  });
  return rows?.[0] || patch;
}

export async function getWallet(userId) {
  if (!userId) return null;
  if (!supabaseReady()) return memWallets.get(String(userId)) ? { ...memWallets.get(String(userId)) } : null;
  const rows = await sb(`wallets?user_id=eq.${encodeURIComponent(userId)}&select=*&limit=1`);
  return rows?.[0] || null;
}

export async function applyWalletTransaction({ userId, chipsDelta = 0, usdCentsDelta = 0, type, referenceId, metadata = {} }) {
  if (!userId) throw new Error('userId required');
  if (!referenceId) throw new Error('referenceId required');
  if (!supabaseReady()) {
    const existing = memLedgerRefs.get(referenceId);
    if (existing) return { ...existing, idempotent: true };
    const wallet = memWallets.get(String(userId));
    if (!wallet) throw new Error('Wallet not found');
    const nextChips = Number(wallet.chip_balance || 0) + Number(chipsDelta || 0);
    const nextUsd = Number(wallet.usd_cents || 0) + Number(usdCentsDelta || 0);
    if (nextChips < 0) throw new Error('Insufficient chips');
    if (nextUsd < 0) throw new Error('Insufficient USD balance');
    wallet.chip_balance = nextChips;
    wallet.usd_cents = nextUsd;
    const result = { chip_balance: nextChips, usd_cents: nextUsd, idempotent: false };
    memLedgerRefs.set(referenceId, result);
    return result;
  }
  const result = await sb('rpc/apply_wallet_transaction', {
    method: 'POST',
    body: {
      p_user_id: userId,
      p_chips_delta: Math.trunc(chipsDelta),
      p_usd_cents_delta: Math.trunc(usdCentsDelta),
      p_entry_type: String(type || 'unknown'),
      p_reference_id: String(referenceId),
      p_metadata: metadata || {},
    },
  });
  return result;
}

function stripPrivateCacheFields(room) {
  const clone = JSON.parse(JSON.stringify(room));
  delete clone._version;
  return clone;
}

export async function saveRoom(room) {
  if (!room?.id) throw new Error('Room id required');
  const expected = Number(room._version || 0);
  if (!supabaseReady()) {
    const current = memRooms.get(room.id);
    if (current && expected && Number(current._version || 0) !== expected) {
      const e = new Error('ROOM_VERSION_CONFLICT');
      e.code = 'ROOM_VERSION_CONFLICT';
      throw e;
    }
    room._version = expected ? expected + 1 : 1;
    memRooms.set(room.id, JSON.parse(JSON.stringify(room)));
    return room._version;
  }
  try {
    const nextVersion = await sb('rpc/save_game_room', {
      method: 'POST',
      body: {
        p_id: room.id,
        p_player_count: room.playerCount,
        p_status: room.status,
        p_state: stripPrivateCacheFields(room),
        p_expected_version: expected,
      },
    });
    room._version = Number(nextVersion);
    return room._version;
  } catch (e) {
    if (String(e.message).includes('ROOM_VERSION_CONFLICT')) e.code = 'ROOM_VERSION_CONFLICT';
    throw e;
  }
}

export async function loadRoom(roomId) {
  if (!roomId) return null;
  if (!supabaseReady()) {
    const room = memRooms.get(String(roomId));
    return room ? JSON.parse(JSON.stringify(room)) : null;
  }
  const rows = await sb(`game_rooms?id=eq.${encodeURIComponent(roomId)}&select=state,version&limit=1`);
  if (!rows?.length) return null;
  const room = rows[0].state;
  room._version = Number(rows[0].version || 0);
  return room;
}

export async function deleteRoom(roomId) {
  if (!roomId) return;
  if (!supabaseReady()) {
    memRooms.delete(String(roomId));
    return;
  }
  await sb(`game_rooms?id=eq.${encodeURIComponent(roomId)}`, { method: 'DELETE' });
}

export async function findWaitingRoom(playerCount, excludeRoomId = '') {
  if (!supabaseReady()) {
    const candidates = [...memRooms.values()]
      .filter(r => r.playerCount === playerCount && r.status === 'waiting' && r.id !== excludeRoomId && r.players.length < r.playerCount)
      .sort((a, b) => String(a.id).localeCompare(String(b.id)));
    return candidates[0] ? JSON.parse(JSON.stringify(candidates[0])) : null;
  }
  let path = `game_rooms?player_count=eq.${playerCount}&status=eq.waiting&select=state,version&order=updated_at.asc&limit=8`;
  if (excludeRoomId) path += `&id=neq.${encodeURIComponent(excludeRoomId)}`;
  const rows = await sb(path);
  for (const row of rows || []) {
    const room = row.state;
    if (Array.isArray(room?.players) && room.players.length < room.playerCount) {
      room._version = Number(row.version || 0);
      return room;
    }
  }
  return null;
}

export async function lobbySummary() {
  if (!supabaseReady()) {
    const out = [];
    for (let n = 2; n <= 10; n++) {
      const matching = [...memRooms.values()].filter(r => r.playerCount === n);
      out.push({
        player_count: n,
        waiting_players: matching.filter(r => r.status === 'waiting').reduce((sum, r) => sum + r.players.length, 0),
        active_rooms: matching.filter(r => r.status === 'playing').length,
      });
    }
    return out;
  }
  return (await sb('rpc/lobby_summary', { method: 'POST', body: {} })) || [];
}

export async function recordRevenue({ type, chips, roomId = null, handId = null, referenceId, metadata = {} }) {
  if (!referenceId || !chips) return;
  if (!supabaseReady()) {
    if (memRevenueRefs.has(referenceId)) return;
    memRevenueRefs.add(referenceId);
    return;
  }
  try {
    await sb('platform_revenue?on_conflict=reference_id', {
      method: 'POST',
      prefer: 'resolution=ignore-duplicates',
      body: [{ revenue_type: type, chips: Math.trunc(chips), usd_cents: 0, room_id: roomId, hand_id: handId, reference_id: referenceId, metadata }],
    });
  } catch (e) {
    if (!String(e.message).toLowerCase().includes('duplicate')) throw e;
  }
}

export async function recordHand(room) {
  if (!room?.id || !room?.round || room.status !== 'showdown') return;
  const key = `${room.id}:${room.round}`;
  if (!supabaseReady()) {
    memHands.add(key);
    return;
  }
  try {
    await sb('hand_history?on_conflict=room_id,round_no', {
      method: 'POST',
      prefer: 'resolution=ignore-duplicates',
      body: [{
        room_id: room.id,
        round_no: room.round,
        hand_id: room.handId || key,
        commitment: room.handCommitment || null,
        reveal_seed: room.handReveal || null,
        result: {
          winnerId: room.winnerId,
          pot: room.pot,
          fee: room.lastFee || 0,
          payout: room.lastPayout || 0,
          players: room.players.map(p => ({ id: p.id, name: p.name, folded: p.folded, seen: p.seen, cards: p.cards })),
        },
      }],
    });
  } catch (e) {
    if (!String(e.message).toLowerCase().includes('duplicate')) throw e;
  }
}

export async function createPaymentRequest({ userId, direction, provider, amountUsdCents = 0, chips = 0, destinationMasked = null, status = 'queued', metadata = {} }) {
  const id = randomUUID();
  const row = {
    id,
    user_id: userId || null,
    direction,
    provider,
    amount_usd_cents: Math.trunc(amountUsdCents),
    chips: Math.trunc(chips),
    destination_masked: destinationMasked,
    status,
    metadata,
  };
  if (!supabaseReady()) {
    memPayments.set(id, row);
    return row;
  }
  const rows = await sb('payment_requests', { method: 'POST', prefer: 'return=representation', body: [row] });
  return rows[0];
}

export async function audit({ actorUserId = null, eventType, referenceId = null, metadata = {} }) {
  const row = { actor_user_id: actorUserId, event_type: eventType, reference_id: referenceId, metadata };
  if (!supabaseReady()) {
    memAudit.push({ id: randomUUID(), ...row, created_at: new Date().toISOString() });
    if (memAudit.length > 1000) memAudit.shift();
    return;
  }
  await sb('audit_logs', { method: 'POST', body: [row] });
}


export async function createSupportTicket({ userId = null, email = '', message }) {
  const cleanEmail=String(email||'').trim().toLowerCase().slice(0,254); const cleanMessage=String(message||'').trim().slice(0,1200);
  if(cleanMessage.length<10) throw new Error('Support message is too short');
  const row={id:randomUUID(),user_id:userId||null,email:cleanEmail||null,message:cleanMessage,status:'open',created_at:new Date().toISOString()};
  if(!supabaseReady()){memSupport.push(row);if(memSupport.length>1000)memSupport.shift();return row;}
  const rows=await sb('support_tickets',{method:'POST',prefer:'return=representation',body:[row]}); return rows?.[0]||row;
}
export async function deleteUserAccount({ userId, externalPlayerId }) {
  if(!userId) throw new Error('userId required');
  if(!supabaseReady()){memWallets.delete(String(userId));if(externalPlayerId)memUsers.delete(String(externalPlayerId));return {ok:true};}
  await sb(`users?id=eq.${encodeURIComponent(userId)}`,{method:'DELETE'}); return {ok:true};
}

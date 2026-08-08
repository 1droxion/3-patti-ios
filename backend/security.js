import { createHmac, timingSafeEqual } from 'node:crypto';

const TOKEN_TTL_MS = 1000 * 60 * 60 * 24 * 30;

function b64url(value) {
  return Buffer.from(value).toString('base64url');
}

function signPart(value, secret) {
  return createHmac('sha256', secret).update(value).digest('base64url');
}

export function securityStatus() {
  const authSecret = String(process.env.AUTH_SECRET || '');
  return {
    authSecretConfigured: authSecret.length >= 32,
    authRequired: String(process.env.AUTH_REQUIRED || '').toLowerCase() === 'true',
  };
}

export function issueSessionToken({ playerId, accountId = null }) {
  const secret = String(process.env.AUTH_SECRET || 'development-only-secret-change-me');
  const now = Date.now();
  const payload = {
    sub: String(playerId),
    aid: accountId ? String(accountId) : null,
    iat: now,
    exp: now + TOKEN_TTL_MS,
    v: 1,
  };
  const encoded = b64url(JSON.stringify(payload));
  const sig = signPart(encoded, secret);
  return `${encoded}.${sig}`;
}

export function verifySessionToken(token) {
  if (!token || typeof token !== 'string' || !token.includes('.')) return null;
  const secret = String(process.env.AUTH_SECRET || 'development-only-secret-change-me');
  const [encoded, supplied] = token.split('.', 2);
  if (!encoded || !supplied) return null;
  const expected = signPart(encoded, secret);
  const a = Buffer.from(supplied);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !timingSafeEqual(a, b)) return null;
  try {
    const payload = JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8'));
    if (!payload?.sub || !payload?.exp || Date.now() >= Number(payload.exp)) return null;
    return payload;
  } catch {
    return null;
  }
}

export function authFromRequest(req) {
  const header = String(req.headers?.authorization || '');
  if (!header.toLowerCase().startsWith('bearer ')) return null;
  return verifySessionToken(header.slice(7).trim());
}

export function requirePlayerAuth(req, playerId = '') {
  const auth = authFromRequest(req);
  const required = String(process.env.AUTH_REQUIRED || '').toLowerCase() === 'true';
  if (!auth) {
    if (required) throw Object.assign(new Error('Authentication required'), { statusCode: 401 });
    return null;
  }
  if (playerId && String(auth.sub) !== String(playerId)) {
    throw Object.assign(new Error('Authenticated player does not match request'), { statusCode: 403 });
  }
  return auth;
}

export function clientFingerprint(req) {
  const forwarded = String(req.headers?.['x-forwarded-for'] || '').split(',')[0].trim();
  const ua = String(req.headers?.['user-agent'] || '').slice(0, 180);
  return { ip: forwarded || 'unknown', userAgent: ua };
}

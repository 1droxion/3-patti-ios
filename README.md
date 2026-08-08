# 3 Patti Social V1.4 — Persistent Backend Foundation

Version: `1.4.0+15`

This is a drop-in update for the existing `3-patti-ios` repo. It does **not** overwrite the existing `ios/` directory, Apple bundle ID, certificates, Codemagic signing, or TestFlight configuration.

## What changed in V1.4

### Server identity/authentication
- The iPhone bootstraps a server session at `/auth/bootstrap`.
- The backend issues a signed bearer token.
- Protected game/wallet endpoints verify the signed player identity.
- `AUTH_REQUIRED=true` can enforce authentication on every protected call.
- The Flutter client automatically re-authenticates if a session expires.

### Persistent Postgres/Supabase foundation
- New `backend/schema.sql` creates:
  - users
  - wallets
  - immutable-style ledger entries
  - persistent game room snapshots
  - hand history
  - platform rake/tip revenue
  - payment request queue
  - audit logs
- The server uses Supabase/Postgres when `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are configured.
- Without those variables it runs in **memory-development mode** so local testing still works.
- Room writes use an optimistic version check to prevent silent concurrent overwrites.

### Permanent wallet + table escrow
- New accounts get demo chips only while cash mode is OFF.
- Joining a table now reserves chips from the server wallet instead of creating a fresh 10,000-chip table balance out of nowhere.
- Leaving a table releases the player's remaining table chips back to their server wallet.
- Dealer tips are removed from table chips and logged separately as platform tip revenue.
- 5% rake is logged separately as platform rake revenue.

### Auditable card generation
- Deck generation is server-only.
- Every hand uses a new 256-bit cryptographic seed.
- A SHA-256 commitment is published at the start of the hand.
- The seed is revealed only after showdown so the hand can be audited/recomputed later.
- Full completed hands can be stored in `hand_history`.

### Payment foundation
- Sandbox deposits now credit the **server wallet ledger**.
- Sandbox withdrawals now create a payout request + hold chips on the **server wallet ledger**.
- PayPal / bank / Apple Pay / Cash App / card remain locked from real money until provider + gaming approvals exist.
- `/payments-config` reports exactly which production safety gates are still blocking cash mode.

### Vercel routing
Vercel now explicitly routes all backend endpoints, including auth, lobby, wallet, deposits, withdrawals, tips, leave, state and actions.

---

# Step 1 — Install the ZIP in Codespaces

```bash
cd /workspaces/3-patti-ios
unzip -o three_patti_v14_persistent_backend.zip
rm three_patti_v14_persistent_backend.zip
flutter pub get
git add .
git commit -m "V1.4 persistent backend wallet auth ledger"
git push
```

# Step 2 — Create the persistent database

Create a Supabase project, open **SQL Editor**, and run the complete contents of:

```text
backend/schema.sql
```

Do not put the Supabase **service role key** in Flutter or in public source code.

# Step 3 — Add these Vercel environment variables

Required for persistent live-game backend:

```text
SUPABASE_URL=<your project URL>
SUPABASE_SERVICE_ROLE_KEY=<server-only service-role key>
AUTH_SECRET=<long random secret>
AUTH_REQUIRED=true
```

Generate a strong auth secret in Codespaces:

```bash
openssl rand -hex 32
```

Copy the generated value into Vercel `AUTH_SECRET`.

Keep these OFF for now:

```text
CASH_MODE_ENABLED=false
REAL_MONEY_APPROVED=false
IDENTITY_PROVIDER_READY=false
KYC_PROVIDER_READY=false
GEOLOCATION_PROVIDER_READY=false
PAYMENT_PROVIDER_APPROVED=false
PAYPAL_LIVE=false
BANK_PAYOUTS_LIVE=false
APPLE_PAY_LIVE=false
CASH_APP_LIVE=false
CARD_PAYMENTS_LIVE=false
```

# Step 4 — Redeploy Vercel

After redeploy, open:

```text
https://3-patti-ios.vercel.app/health
```

For the persistent game backend, look for:

```json
{
  "ok": true,
  "version": "1.4.0",
  "persistence": {
    "mode": "supabase-postgres",
    "persistent": true,
    "supabaseConfigured": true
  },
  "security": {
    "authSecretConfigured": true,
    "authRequired": true
  },
  "cashModeEnabled": false
}
```

Cash mode remaining false is intentional until the real-money regulatory/provider gates are completed.

# Step 5 — Codemagic / TestFlight

Build the `main` branch. It should be:

```text
Version 1.4.0
Build 15
```

## Tested locally in V1.4

- authentication bootstrap + signed bearer token
- persistent-wallet API behavior (memory fallback test)
- 1 VS 1 matchmaking
- wallet-to-table chip reservation
- secure hand commitment
- Blind betting + pot update
- dealer tip accounting
- table exit + remaining chip release to wallet
- sandbox card deposit credit
- sandbox PayPal withdrawal hold
- live lobby summary
- cash-mode readiness blockers

## Important

This V1.4 package builds the production **game/account/wallet foundation**. It does not secretly enable real-money gambling or send actual PayPal/ACH/card transactions. Real payment provider execution stays locked behind server configuration and external approvals.

# 3 Patti Social USA — V0.2

A USA-first, globally usable **social Teen Patti** prototype. This version is intentionally **virtual chips only**: no deposits, no cash wagering, no withdrawals, and no commission on real money.

## What changed from V0.1
- Real server-backed matchmaking for **2 through 10 players**
- Multiple phones can join the same waiting room
- Server controls the deck, private cards, pot, chip balances, and hand winner
- 10-chip boot and 5,000-chip table cap
- Pack / See / Chaal / Show / Play Again
- Device-local store-price example (`$1.99` in the US, `₹99` in India) for non-wagering VIP/cosmetics only
- Stronger USA-first branding while remaining understandable to Indian players worldwide

## 1. Start the multiplayer server
Node.js 18+ is enough. There are no npm dependencies.

```bash
cd backend
npm start
```

The server listens on port `8080`.

Health check:

```bash
curl http://localhost:8080/health
```

## 2. Generate Flutter platform folders
Flutter is not installed in the build environment that created this source archive, so run these locally:

```bash
flutter create . --platforms=android,ios
flutter pub get
```

## 3. Run the app
### Android emulator + server on same computer
The default API address is already:

```text
http://10.0.2.2:8080
```

Then run:

```bash
flutter run
```

### Two real phones on the same Wi-Fi
Find your computer's LAN IP, for example `192.168.1.50`, then run each app with:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8080
```

Your firewall must allow TCP port 8080.

### iOS simulator
Use your Mac server address, for example:

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

For iOS production, use HTTPS rather than plain HTTP.

## Prototype limitations
This is a multiplayer engineering prototype, not yet a production App Store build. Before public release we still need:
- Account/authentication system
- Persistent database
- Reconnect/session recovery
- Turn timers and full Teen Patti betting rules
- Abuse and anti-collusion systems
- Rate limiting and production security
- Push notifications
- Analytics/crash reporting
- Store assets/privacy policy/terms
- Production backend hosting with HTTPS
- App Store / Google Play compliance review

## Important product rule
Keep playable chips non-purchasable and non-withdrawable in the social version. Monetization can be ads, VIP access, cosmetics, avatars, table themes, or other non-wagering features.

## Development-network note
Android 9+ may block local plain-HTTP traffic by default. For local testing only, either use an HTTPS tunnel/server or enable cleartext traffic in the generated Android manifest. Production builds should use HTTPS and should not rely on cleartext HTTP.

## Server privacy detail
When a player is still playing blind, the server sends card backs rather than the private card values. The real card values are returned only after that player chooses **SEE** or after showdown.

# 3 Patti Social V1.2 — Player Profiles + Continuous Live Tables

Drop this ZIP into the root of the existing `3-patti-ios` repository. It intentionally does not overwrite the existing `ios/` signing project.

## V1.2 changes

- Version `1.2.0+13`
- 8 selectable round profile avatar images in Profile
- Player avatar + display name are sent to the multiplayer server
- Every live-table seat shows the player's round avatar, name, chip balance, and Blind/Seen/Packed status
- Each player's 3 cards now sit directly beside that player's profile seat
- Your cards flip face-up beside your own profile after Seen Card
- Opponent cards stay face-down and reveal after showdown
- 60-second active-turn badge remains beside the active player profile
- End-of-round controls: NEW ROUND / SWITCH TABLE / EXIT
- NEW ROUND requires the current players to opt in; if another player exits, the open seat is returned to matchmaking
- SWITCH TABLE excludes the table you just left so it really searches for a different room
- Dynamic matchmaking continues creating additional rooms as demand grows; local backend test created 50 simultaneous 1-vs-1 rooms from 100 joins
- Dealer Tip sandbox: 10 / 25 / 50 / 100 chips with player-to-dealer chip animation and Thank You bubble
- Dealer tips are recorded separately from the game pot; no real-money payout/bank settlement is enabled in this build
- Existing PayPal withdrawal remains sandbox only

## Install in Codespaces

```bash
cd /workspaces/3-patti-ios
unzip -o three_patti_v12_profiles_rounds.zip
rm three_patti_v12_profiles_rounds.zip
flutter pub get
git add .
git commit -m "V1.2 player profiles cards and continuous tables"
git push
```

## Verify after Vercel deploy

Open:

`https://3-patti-ios.vercel.app/health`

Expected backend version: `1.2.0`.

## TestFlight

Codemagic should build:

- Version: `1.2.0`
- Build: `13`

## Suggested test

1. Choose a profile image and display name in Profile.
2. Join 1 VS 1 from two devices/test users.
3. Confirm both round avatars + names show around the table.
4. Confirm 3 cards are beside each player profile.
5. Tap Seen Card and confirm only your own cards reveal.
6. Finish the round and confirm NEW ROUND / SWITCH TABLE / EXIT.
7. Tap NEW ROUND on one device and EXIT on the other; the remaining user should wait for the next matching player.
8. Tap TIP DEALER and confirm colorful chips fly to the dealer and the tip does not enter the pot.

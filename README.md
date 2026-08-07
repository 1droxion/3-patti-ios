
# 3 Patti Social V0.8 — Real Table Game Feel

Drop this ZIP into the root of the existing `3-patti-ios` repo. It does not include or overwrite `ios/`, so the current Apple bundle ID and signing setup stay intact.

## V0.8 table upgrades
- Oval / round green Teen Patti felt table
- Lady dealer at the top-center of the table
- Dealer-to-player card deal animation
- Player profile seats arranged around the table
- Each seat shows name, chips and Blind / Seen / Packed state
- 60-second turn countdown ring on the active player
- Timeout is enforced by the backend; expired turns are skipped automatically
- Center pot uses chip-style graphics
- Winner overlay and chip payout animation feel
- Card sound, chip sound and win jingle assets included
- Settings includes Card & chip sounds + Win music toggles

## Exactly five in-round actions
1. BLIND
2. SEEN CARD
3. PACK
4. SHOW
5. SIDE SHOW

No Chaal / Call / Raise buttons are shown in this build.

## Table limits
- 2–5 players: 5K
- 6–8 players: 20K
- 9–10 players: 50K

## Install patch
```bash
cd /workspaces/3-patti-ios
unzip -o three_patti_v08_real_table.zip
rm three_patti_v08_real_table.zip
flutter pub get
git add .
git commit -m "Real Teen Patti table v0.8"
git push
```

Then rebuild the main branch in Codemagic for TestFlight. Version: `0.8.0+9`.

# 3 Patti Social V0.7 — Round Horizontal Rooms

Drop this ZIP into the root of your existing `3-patti-ios` repository. It does not overwrite your `ios/` signing folder.

## V0.7 changes
- Room lobby is now **one horizontal swipe carousel** — no vertical room scrolling.
- All rooms use **large round casino-style discs** inspired by the room selector reference.
- 2-player room is labeled **1 VS 1**.
- Green rooms: 1 VS 1 / 3 / 4 / 5 → **5K limit**.
- Blue rooms: 6 / 7 / 8 → **20K limit**.
- Gold rooms: 9 / 10 → **50K limit**.
- Room cards do not show a currency symbol.
- Hamburger menu remains the navigation hub; no bottom navigation.
- Backend now enforces the same 5K / 20K / 50K pot limits, not just the UI.
- Version: **0.7.0+8**.

## Install in Codespaces
```bash
cd /workspaces/3-patti-ios
unzip -o three_patti_v07_round_rooms.zip
rm three_patti_v07_round_rooms.zip
flutter pub get
git add .
git commit -m "Round horizontal rooms v0.7"
git push
```

Then build the `main` branch in Codemagic and update the TestFlight build on your iPhone.


# 3 Patti Social V0.6 — Game Lobby Upgrade

This ZIP is a drop-in patch for your existing `3-patti-ios` repo.
It keeps your existing `ios/` signing files untouched.

## What changed
- Home redesigned to feel more like a real game lobby
- No bottom navigation; everything stays in the 3-line menu
- 3 horizontal swipe rows instead of vertical room stacking
- 2-player table renamed to **1 VS 1**
- Table limits updated:
  - 2 / 3 / 4 / 5 players → **5K**
  - 6 / 7 / 8 players → **20K**
  - 9 / 10 players → **50K**
- No currency symbol inside room cards
- Rounder, richer table cards with better glow and depth
- Version bumped to **0.6.0+7**

## Paste into Codespaces
```bash
cd /workspaces/3-patti-ios
unzip -o three_patti_v06_game_lobby.zip
rm three_patti_v06_game_lobby.zip
flutter pub get
git add .
git commit -m "Upgrade game lobby v0.6"
git push
```

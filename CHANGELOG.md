# Changelog

## v0.5.4 - 2026-05-03

- Added the project application version in `project.godot` as `0.5.4`.
- Set Windows export resource versions to `0.5.4.0`.
- Updated the main menu version label to `MVP v0.5.4`.
- Added a switchable top-down / isometric exploration mode, preserving map progress when entering and leaving the codex.
- Reworked isometric ground, wall, player, monster, boss, elite, treasure, shop, rest stop, event, and fragment rendering so positions line up with the top-down collision grid.
- Replaced generic monster visuals with Shan Hai Jing inspired sprite sheets for `hu_diao`, `lu_shu`, `cong_cong`, `lei_beast`, `elite`, BOSS entities, and map facilities in both view modes.
- Improved isometric collision readability, depth sorting, entity anchoring, HP/floating-text placement, and player position halo.
- Added a reset confirmation flow for `R`, and reset run level/EXP when regenerating the map.
- Refined the minimap position and marker readability, especially for the player and the three BOSS locations.
- Removed unused legacy texture folders and unused downloaded/source art assets after the new generated sprite sheets were integrated.
- Synchronized README, GDD and MVP planning documents with the current prototype state and updated the v0.6 planning focus.

## v0.5.3 - 2026-04

- Removed forced full-card exhaustion in BOSS battles.
- Changed normal cards to cycle through the discard pile.
- Added fallback card-pile recovery to prevent long battles from reaching a no-card soft lock.

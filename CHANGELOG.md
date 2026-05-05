## v0.6.5 - 2026-05-05

- Started the v0.6.5 content-rhythm pass focused on event and reward feedback instead of new chapters.
- Updated event result panels to show both narrative outcome text and an explicit actual reward/expense summary.
- Updated treasure result panels to use the same explicit reward summary pattern.
- Updated Boss victory and final purification panels to label reward lines as explicit change summaries.
- Updated shop purchases to keep an explicit latest-change summary in the shop panel.
- Persisted shop inventory and sold state per shop node so reopening the same shop cannot refresh or rebuy sold items.
- Updated rest station result panels to use the same explicit heal summary pattern.
- Expanded the isometric visual ground layer beyond the true map bounds to hide gray edge exposure near camera limits.
- Added non-boss battle reward result panels when returning to the map after normal or elite fights.
- Added regression checks ensuring non-boss battles, event, treasure, rest station, shop, non-final Boss, and final Boss results include reward summaries.
- Updated project/menu version metadata to 0.6.5.

## v0.6.4 - 2026-05-04

- Improved exploration movement with full-step checks, axis sliding, and a small isometric corner nudge to reduce turn/corner sticking without loosening collision.
- Reworked isometric navigation hints to show only the current tile and the tile in front of the player, with blocked tiles using a restrained orange outline.
- Aligned isometric player/entity foot anchors, shadows, and foot halos with the actual collision tile center so movement feedback matches blocked-tile behavior.
- Reduced minimap player/BOSS marker sizes while keeping them readable.
- Kept Chapter 2 minimap terrain colors aligned with the dirt/stone theme.
- Updated project/export/menu version metadata to 0.6.4.
- Re-ran the formal v0.6 Godot regression script successfully.

## v0.6.3 - 2026-05-03

- Fixed several card rule mismatches: school discounts, bonus hits, wet bonus, empty-hand bonus, and self-damage costs.
- Fixed card description placeholder resolution for status stacks.
- Clarified old card descriptions that referenced mechanics not currently implemented.
- Rebalanced status duration rules for player vulnerable, enemy debuffs, enemy strengthen, and persistent root.
- Added fragments/EXP rewards for normal and elite battles with chapter-scaled values.
- Updated enemy intent UI to show actual modified attack damage.
- Added regression checks for card rules, status duration, non-boss rewards, and West Mountain enemy stat ranges.

## v0.6.2 - 2026-05-03

- Fixed headless startup leak by disabling generated audio in automated/headless runs.
- Added UTF-8 no-BOM checks for critical Godot text resources to prevent `.tscn` startup parse crashes.
- Hardened save loading against malformed or old payloads.
- Added developer playtest buttons for fragments, full heal, EXP, and chapter clear flow.
- Kept normal startup and v0.6 regression passing after the stability changes.

## v0.6.1 - 2026-05-03

- Added formal Godot headless regression script for v0.6 content and flow checks.
- Added beast/deity entries to the codex, including classic text, translation, awaken quiz, and reward card display.
- Chapterized shop, rest station, treasure, and event result UI copy for West Mountain.
- Added result text to all Chapter 2 event choices.
- Added Chapter 2 visual asset path regression for top-down and isometric resources.
- Optimized isometric rendering collection with camera-visible world-rect culling.
- Hardened reusable event/shop panel option cleanup.
- Updated project/export/menu version metadata to 0.6.1.
# Changelog

## v0.6 - 2026-05-03

- Added Chapter 2 vertical slice: `西山 · 白虎境`, including chapter switching after clearing Chapter 1 and v0.6 completion after clearing Chapter 2.
- Added chapter state to the run flow, with per-chapter BOSS defeat counting and Chapter 2 transition preserving deck, fragments, level, EXP and max HP while refilling HP/energy.
- Added developer chapter jump controls for debugging Chapter 1 / Chapter 2 without clearing the previous chapter.
- Added Chapter 2 enemies: `zheng_beast`, `tian_gou`, `xuan_gui`, `gu_diao`, elite `elite_yingzhao`, and three Lu Wu BOSS tiers.
- Added six Chapter 2 cards and integrated them into shop, treasure and BOSS reward flows.
- Reworked Chapter 2 terrain readability: top-down dirt floor, isometric dirt blocks, gray stone walls, and brown/gray minimap colors.
- Improved isometric entity readability with adjusted monster/elite/BOSS scale, foot anchors, shadows and floating-text placement.
- Strengthened Chapter 2 reward economy: guaranteed west card in Chapter 2 shops, west cards in treasure pools, and codex unlocks for direct BOSS card rewards.
- Added and synchronized GDD v0.6 planning, MVP/GDD integration rules, long-term 200-page GDD expansion prompt, and implementation records.
- Ran Godot 4.3 headless startup and v0.6 smoke checks covering Chapter 2 generation, debug jump, card/enemy loading, shop guarantee, treasure pool and BOSS reward card flow.

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


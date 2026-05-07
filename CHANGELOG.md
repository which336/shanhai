## v0.8.0 - 2026-05-06

- Added Chapter 5 `中山 · 麒麟台` as an internal development chapter, extending progression through South, West, North, East, and Central.
- Added Central Mountain enemy, elite, and three-tier Qilin Boss pools with theme-first sourcing and real codex/source fields.
- Added 12 Central cards and 8 Central events, expanding loaded content targets to 74 cards, 40 events, and 40 enemies.
- Connected Central shop, treasure, normal/elite battle rewards, Boss rewards, debug jumping, map generation, minimap colors, sprite keys, and battle portraits to dedicated Central pools.
- Added dedicated Central top-down `192x192` and isometric `512x512` PNG atlases generated in a yellow-earth, jade-altar, Qilin-platform visual style.
- Updated project/export/menu version metadata, README, CHANGELOG, and GDD to 0.8.0.
- Follow-up source-stability pass: corrected README/GDD chapter wording so East/Qinglong stays v0.7 Chapter 4 and Central/Qilin stays v0.8 Chapter 5.
- Removed export-unsafe PNG fallback loading from `PixelSprites` and switched regression sprite dimension checks to imported `Texture2D` resources.
- Added `tools/v08_keynode_smoke.gd` for a focused headless check of the v0.8 delivery nodes: menu version, East/Central maps, battle portraits, chapter flow, and five-realm final settlement.

## v0.7.0 - 2026-05-06

- Added Chapter 4 `东山 · 青龙原` as an internal development chapter, extending the playable loop through South, West, North, and East without exporting a demo build.
- Switched chapter ownership wording to a theme-first rule: chapter themes follow the five directions / five elements / emotional arc, while codex entries keep each creature's true textual source.
- Added East Mountain enemy, elite, and three-tier Qinglong Boss pools; `cong_cong` remains treated as already introduced content instead of a new East monster.
- Added 12 East cards and expanded content to 62 loaded cards, 32 events, and 32 enemies, with East shop, treasure, normal/elite battle, and Boss rewards using dedicated East pools.
- Added dedicated East top-down and isometric PNG sprite atlases, registered map sprite keys, and connected battle portraits to the same resources.
- Extended debug chapter jumping, chapter completion flow, and regression coverage for four-chapter progression, East map generation, East assets, rewards, codex unlocks, and the v0.7 four-realm settlement.
- Updated project/export/menu version metadata, README, CHANGELOG, and GDD to 0.7.0.

## v0.6.8 - 2026-05-05

- Added dedicated North chapter pixel sprite atlases for He Luo Fish, Fei Yi, Zhuhuai, Xiao, Xiangliu Shadow, and three Zhulong Boss tiers.
- Registered North top/iso sprite keys and replaced Chapter 3 fallback sprite keys so North map entities no longer reuse South/West monsters.
- Added battle enemy portraits sourced from the same sprite registry without introducing full battle animation playback.
- Improved summon ally readability in shop/battle copy while keeping the single-slot 3-turn ally rules unchanged.
- Extended `tools/v06_regression_check.gd` to verify North sprite dimensions, texture key resolution, map sprite keys, and battle portrait rendering.
- Updated project/export/menu version metadata to 0.6.8.

## v0.6.7 - 2026-05-05

- Added Chapter 3 `北山 · 玄武渊` with north map config, north enemy pool, 3 Zhulong boss tiers, and v0.6.7 three-chapter clear settlement.
- Expanded content to 50 cards, 24 events, and 24 enemies; north cards/enemies include codex and awaken reward coverage.
- Implemented `SUMMON_ALLY` with a single ally slot, 3-turn duration, automatic turn-start actions, replacement behavior, and battle UI status display.
- Added north/global event coverage and north shop/treasure/Boss reward pools while keeping summon cards mostly tied to awaken rewards.
- Extended `tools/v06_regression_check.gd` for north chapter flow, content counts, north map generation, and summon ally behavior.
- Updated project/export/menu version metadata to 0.6.7.

## v0.6.6 - 2026-05-05

- Added a final run settlement summary to the v0.6 full-clear panel after Chapter 2 completion.
- The summary now shows level, EXP, HP, energy, fragments, deck size, codex unlock progress, and cleared chapters.
- Updated main menu codex totals to count both card and beast entries, matching the codex view and final settlement.
- Added regression checks for the full-clear settlement summary and main menu codex total.
- Updated project/export/menu version metadata to 0.6.6.

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
- Added truthful battle reward previews to normal, elite, and Boss confirmation prompts.
- Added regression checks ensuring battle reward previews, non-boss battles, event, treasure, rest station, shop, non-final Boss, and final Boss results include reward summaries.
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


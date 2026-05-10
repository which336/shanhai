## v0.14 - 2026-05-10

- Bumped the project/export/menu metadata to `0.14.0` for the portfolio and GDD baseline.
- Added a portfolio pitch document with demo-video script, resume bullets, GDD excerpt guidance, and delivery checklist.
- Updated README's first screen to present the project as a playable portfolio prototype.
- Deleted the obsolete MVP plan document and made the GDD the long-term design source.
- Integrated the May 9-10 art pass: refreshed top-down/isometric sprites for playable characters, enemies, elites, bosses, and map props such as shop, rest stop, treasure, event, and fragments.
- Fixed returning from the map to the main menu so long-term progress is saved first.
- Updated the CJK font fallback stack to avoid heavy SimHei-style title rendering.

## v0.13 - 2026-05-09

- Added small playtest delivery flow without expanding card, enemy, or event content.
- Added a main-menu tutorial entry and a lightweight tutorial scene covering exploration, dual views, map nodes, card combat, codex learning, event markers, and finale conditions.
- Added a settings scene for BGM volume, SFX volume, fullscreen/windowed mode, and dev-tool visibility.
- Normalized `GameState.settings` defaults for old-save compatibility: `bgm_volume`, `sfx_volume`, `fullscreen`, `show_dev_tools`, and `tutorial_seen`.
- Applied BGM/SFX settings through `AudioEngine`, and made fullscreen/dev-tool settings take effect at runtime.
- Hid obvious dev tools by default: codex unlock-all and map jump/debug controls now follow `show_dev_tools`.
- Updated main-menu info with codex completion, learned codex progress, and best ending.
- Updated version/export metadata to `0.13.0` and playtest export path `山海拾遗录_v0.13.0_playtest.exe`.
- Added `PLAYTEST.md` and `tools/v13_playtest_smoke.gd` for playtest instructions and regression coverage.

## v0.12 - 2026-05-09

- Added the standalone `忘川之心` finale scene after Chapter 5 final clear, with a five-part terminal dialogue flow and return to the Grandfather Study.
- Added event `ending_marker` data for every event option, using the fixed marker set `guard / companion / practical`.
- Added run-scoped ending marker tracking in `RunState`; markers reset on new runs and do not enter long-term save data.
- Added three ending outcomes: `残响未明`, `五境净化`, and `山海重明`, judged by valid codex completion plus guard/companion marker count.
- Added lightweight long-term ending collection fields to `GameState`: seen endings and best ending rank, shown in the Grandfather Study.
- Added `tools/v12_finale_smoke.gd` for marker coverage, marker lifecycle, ending thresholds, save compatibility, and Chapter 5 -> finale -> study-room flow.
- Fixed SceneTree smoke runner startup by using `_initialize()` / `process_frame`, and removed compile-time `GameState`/`RunState` autoload cycles from core state scripts.
- Updated project/export/menu metadata to v0.12 / 0.12.0.
- Removed the intrusive gold guide lines from the finale scene.
- Added codex learning progress: opening unlocked entries marks them as learned, the codex now has learning overview / unlearned review / ending-condition explanation panels, and learned state persists in `GameState`.
- Expanded v0.12 smoke coverage for codex learning persistence and finale judgement explanation.

## v0.11 - 2026-05-08

- Added three playable characters: 阿离（九尾狐裔）, 洛泠（海经行者）, and 桑岐（扶桑守望）, with unlock/activation state in GameState and old-save fallback to 方寻.
- Added 18 character route cards, expanding the card database to 92 cards and the card+enemy codex total to 132.
- Added character-specific starter decks, shop/treasure character card pools, and top-down/isometric placeholder PNG sprite sheets for all three added characters.
- Extended the study room UI to manage playable characters alongside bookmarks.
- Added `tools/v11_character_smoke.gd` and updated v0.6/v0.8/v0.10 checks for v0.11 counts and final-clear copy.
- Updated project/export/menu/final-clear version metadata to v0.11 / 0.11.0.

## v0.10 - 2026-05-08

- Added the first structured deckbuilding keyword pass for all 74 cards through `keywords: Array[String]`.
- Locked six school keywords: Shan `根脉 / 生息`, Hai `潮涌 / 湿润`, and Huang `凶势 / 血祭`.
- Updated card data so school cards expose short keyword tags while keeping neutral cards outside the school keyword system.
- Updated card UI to show keyword tags without covering cost, school mark, card type, or rarity.
- Updated codex UI with keyword colors and detailed keyword rule explanations.
- Changed blood-sacrifice self damage to route through the player damage path, so shield absorbs it before HP loss.
- Fixed codex progress counting so stale or smoke-test keys such as `smoke.codex.*` cannot make progress exceed the real `74 cards + 40 beasts = 114` total.
- Lowered exploration walk speed and added hold-`Shift` sprint; sprint is close to the previous top speed while normal movement is slower.
- Updated project/export/menu/final-clear version metadata to v0.10 / 0.10.0.
- Added `tools/v10_keyword_smoke.gd` for keyword legality, payload consistency, card UI labels, codex rules, codex count pruning, and blood-sacrifice shield behavior.
- Extended existing smoke coverage for valid bookmark/codex unlock data and map movement speed.

## v0.9 - 2026-05-08

- Added the Grandfather Study meta screen and main-menu/stage-clear entry points.
- Added bookmark meta progression with unlock, activation, save/load compatibility, and starter-deck replacement.
- Reworked battle presentation with larger themed backgrounds, full-screen battle staging, enemy detail panel, animated player/enemy sprites, floating damage/block text, and fan-style hand layout.
- Changed battle hand rules to no hand limit, retain hand between turns, draw 4 on the first turn and 2 each later turn, with 10 cards per hand page.
- Added generated background assets for the five chapter battle scenes, main menu, study room, and shared card frame.
- Added codex developer unlock-all support.
- Added `tools/v09_smoke_check.gd` for study room, bookmark flow, starter replacement, save compatibility, final-clear routing, battle presentation, hand rules, and responsive layout.

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


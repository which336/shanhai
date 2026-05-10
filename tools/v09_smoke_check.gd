extends SceneTree

var _errors: Array[String] = []
var _card_db: Node = null
var _enemy_db: Node = null
var _run_state: Node = null
var _game_state: Node = null
var _save_system: Node = null
var _snapshot: Dictionary = {}


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	await process_frame
	_bind_autoloads()
	_snapshot = _game_state.call("to_dict")
	_reload_databases()
	await _check_main_menu_study_entry()
	await _check_study_room_scene()
	await _check_codex_dev_unlock_entry()
	_check_old_save_compatibility()
	_check_bookmark_purchase_activation_and_starter_deck()
	_check_save_roundtrip()
	await _check_final_clear_enters_finale()
	await _check_battle_animation_stage()
	_restore_snapshot()
	_finish()


func _bind_autoloads() -> void:
	_card_db = root.get_node_or_null("CardDatabase")
	_enemy_db = root.get_node_or_null("EnemyDatabase")
	_run_state = root.get_node_or_null("RunState")
	_game_state = root.get_node_or_null("GameState")
	_save_system = root.get_node_or_null("SaveSystem")
	_expect(_card_db != null, "missing CardDatabase autoload")
	_expect(_enemy_db != null, "missing EnemyDatabase autoload")
	_expect(_run_state != null, "missing RunState autoload")
	_expect(_game_state != null, "missing GameState autoload")
	_expect(_save_system != null, "missing SaveSystem autoload")


func _reload_databases() -> void:
	if _card_db != null:
		_card_db.call("reload_all")
	if _enemy_db != null:
		_enemy_db.call("reload_all")


func _check_main_menu_study_entry() -> void:
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	_expect(packed != null, "main menu should load")
	if packed == null:
		return
	var menu = packed.instantiate()
	root.add_child(menu)
	await process_frame
	_expect(menu.get_node_or_null("V/StudyButton") != null, "main menu should expose study room button")
	var info = menu.get("_info_label")
	_expect(info != null, "main menu info label should still exist")
	if info != null:
		_expect(str(info.text).find("当前藏签") >= 0, "main menu should show active bookmark")
	menu.queue_free()


func _check_study_room_scene() -> void:
	var packed: PackedScene = load("res://scenes/meta/study_room.tscn")
	_expect(packed != null, "study room scene should load")
	if packed == null:
		return
	var study = packed.instantiate()
	root.add_child(study)
	await process_frame
	var list = study.get_node_or_null("Root/ListScroll/List")
	_expect(list != null, "study room list should exist")
	if list != null:
		_expect(list.get_child_count() >= 4, "study room should list bookmarks plus optional character rows")
	study.queue_free()


func _check_codex_dev_unlock_entry() -> void:
	var packed: PackedScene = load("res://scenes/codex/codex.tscn")
	_expect(packed != null, "codex scene should load")
	if packed == null:
		return
	var codex = packed.instantiate()
	root.add_child(codex)
	await process_frame
	var unlock_button = codex.get_node_or_null("UnlockAllButton")
	_expect(unlock_button != null and unlock_button is Button, "codex should expose a dev unlock-all button")
	codex.queue_free()


func _check_old_save_compatibility() -> void:
	var payload := {
		"version": 1,
		"timestamp": 0,
		"game_state": {
			"unlocked_codex": ["card.neutral.strike"],
			"fragments": 25,
			"unlocked_characters": ["fang_xun"],
			"settings": {"locale": "zh_CN"},
		}
	}
	var ok: bool = bool(_save_system.call("load_from_text", JSON.stringify(payload), false))
	_expect(ok, "old save payload should load")
	_expect(int(_game_state.fragments) == 25, "old save should keep fragments")
	_expect(_game_state.active_bookmark_id == "", "old save should default to no active bookmark")
	_expect(_game_state.unlocked_bookmarks.is_empty(), "old save should default to no unlocked bookmarks")


func _check_bookmark_purchase_activation_and_starter_deck() -> void:
	_game_state.call("from_dict", {})
	_game_state.fragments = 500
	_unlock_real_codex_entries(16)
	_expect(not bool(_game_state.call("is_bookmark_unlocked", "shan")), "shan bookmark should start locked")
	_expect(bool(_game_state.call("unlock_bookmark", "shan")), "shan bookmark should unlock with enough fragments and codex")
	_expect(bool(_game_state.call("set_active_bookmark", "shan")), "shan bookmark should activate after unlock")
	_run_state.call("reset_for_new_run", "fang_xun")
	var ids: PackedStringArray = _deck_ids()
	_expect(ids.has("shan.fusang"), "active shan bookmark should add shan.fusang")
	_expect(not _contains_nth(ids, "neutral.guard", 3), "active shan bookmark should replace one guard")
	_expect(ids.size() == 8, "bookmark replacement should keep starter deck size")


func _check_save_roundtrip() -> void:
	var payload := {
		"version": 1,
		"timestamp": 0,
		"game_state": _game_state.call("to_dict"),
	}
	_game_state.call("from_dict", {})
	var ok: bool = bool(_save_system.call("load_from_text", JSON.stringify(payload), false))
	_expect(ok, "bookmark save roundtrip should load")
	_expect(_game_state.active_bookmark_id == "shan", "bookmark save roundtrip should preserve active bookmark")
	_expect(bool(_game_state.call("is_bookmark_unlocked", "shan")), "bookmark save roundtrip should preserve unlocked bookmark")


func _check_final_clear_enters_finale() -> void:
	_run_state.call("reset_for_new_run")
	_run_state.current_chapter_index = _run_state.CHAPTER_CENTRAL
	_run_state.current_floor = _run_state.CHAPTER_CENTRAL
	_run_state.bosses_defeated = _run_state.BOSSES_TO_CLEAR
	var packed: PackedScene = load("res://scenes/map/map.tscn")
	_expect(packed != null, "map scene should load for final clear check")
	if packed == null:
		return
	var map = packed.instantiate()
	root.add_child(map)
	await process_frame
	map.call("_show_boss_victory", "boss_hard", "v0.9 smoke")
	var victory_text = map.get("_victory_text")
	_expect(victory_text != null, "final victory text should exist")
	if victory_text != null:
		_expect(str(victory_text.text).find("忘川之心") >= 0, "final clear should mention Wangchuan finale")
	map.call("_on_victory_close")
	await process_frame
	var current = current_scene
	_expect(current != null and current.scene_file_path.ends_with("finale.tscn"), "final clear button should enter finale")
	if current != null:
		current.queue_free()
	map.queue_free()


func _check_battle_animation_stage() -> void:
	_run_state.call("reset_for_new_run")
	_run_state.next_battle_enemy_ids = PackedStringArray(["hu_diao", "boss_qilin"])
	_run_state.seed_value = 9090
	var packed: PackedScene = load("res://scenes/battle/battle.tscn")
	_expect(packed != null, "battle scene should load for animation stage")
	if packed == null:
		return
	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var ui = scene.get_node_or_null("UI")
	_expect(ui != null, "battle UI should exist")
	if ui != null:
		await _check_battle_enemy_details(ui)
		await _check_card_view_styling(ui)
		await _check_unlimited_hand_status(scene, ui)
		await _check_hand_pagination(scene, ui)
		await _check_unlimited_turn_draw(scene)
		await _check_enemy_turn_visible(scene, ui)
	var stage = scene.get_node_or_null("UI/BattleStage")
	_expect(stage != null, "battle stage should exist")
	if stage != null:
		_expect(stage.z_index > 0, "battle stage should render above battle background")
		if ui != null:
			_check_overlay_layers(ui, stage)
		_expect(bool(stage.call("animation_coverage_ok")), "battle stage should expose idle/attack/hit/death/cast/defend animations")
		_expect(not _stage_has_permanent_status_label(stage), "battle stage should not keep permanent status labels over sprites")
		await _check_viewport_layout(stage, Vector2(1280, 720))
		await _check_viewport_layout(stage, Vector2(1600, 900))
		await _check_viewport_layout(stage, Vector2(900, 700))
		await _check_battle_animation_events(scene, stage)
	scene.queue_free()


func _check_overlay_layers(ui: Node, stage: Control) -> void:
	var result_panel = ui.get_node_or_null("ResultPanel")
	_expect(result_panel != null and result_panel.z_index > stage.z_index, "battle reward/result panel should render above sprites")


func _check_battle_enemy_details(ui: Node) -> void:
	var panel = ui.get_node_or_null("EnemiesPanel")
	_expect(panel != null and panel.get_child_count() == 0, "battle enemy target buttons should be removed")
	await process_frame
	var detail = ui.get_node_or_null("EnemyDetailPanel")
	_expect(detail != null and detail.visible, "enemy detail panel should be visible without target buttons")
	if detail == null:
		return
	_expect(detail.position.y <= 100.0, "enemy detail panel should move up into the former target area")
	var body = detail.get_node_or_null("V/Body")
	_expect(body != null, "enemy detail body should exist")
	if body != null:
		var text := str(body.text)
		_expect(text.find("HP") >= 0, "enemy detail should show HP")
		_expect(text.find("意图") >= 0, "enemy detail should show intent")


func _check_card_view_styling(ui: Node) -> void:
	var hand = ui.get_node_or_null("HandArea")
	_expect(hand != null, "battle hand should exist for card style check")
	if hand == null or hand.get_child_count() <= 0:
		return
	_expect(not (hand is FlowContainer), "battle hand should use manual fan layout instead of flow layout")
	var first = hand.get_child(0)
	_expect(first is PanelContainer, "card view should be a panel")
	if first is PanelContainer:
		_expect((first as PanelContainer).get_theme_stylebox("panel") != null, "card view should provide a styled panel")
		_expect(first.size.x <= 150.0 and first.size.y <= 200.0, "card view should be smaller than the old full-size cards")
	var before_y: float = first.position.y if first is Control else 0.0
	ui.call("_layout_hand", 0, false)
	await process_frame
	_expect(first.position.y < before_y, "hovered fan card should expand upward")
	if first.has_method("set_fan_expanded"):
		_expect(first.get_node_or_null("V/Description") != null and first.get_node("V/Description").visible, "expanded fan card should show full details")
	ui.call("_layout_hand", -1, false)


func _check_unlimited_hand_status(scene: Node, ui: Node) -> void:
	var battle = scene.get_node_or_null("Battle")
	_expect(battle != null, "battle node should exist for hand status check")
	if battle == null or battle.deck == null:
		return
	while battle.deck.hand.size() < 9:
		var card: Card = _card_db.call("get_card", "neutral.strike")
		if card == null:
			return
		battle.deck.hand.append(card)
	ui.call("_refresh_hand")
	await process_frame
	var hand_status = ui.get_node_or_null("HandStatus")
	_expect(hand_status != null, "hand status label should exist")
	if hand_status != null:
		_expect(str(hand_status.text).find("无上限") >= 0, "hand status should disclose unlimited hand")
		_expect(str(hand_status.text).find("弃牌阶段") < 0, "hand status should not mention discard phase")
	var turn_label = ui.get_node_or_null("TopBar/Turn")
	_expect(turn_label != null and str(turn_label.text).find("弃牌阶段") < 0, "turn label should not show discard phase")
	var end_button = ui.get_node_or_null("EndTurnButton")
	_expect(end_button != null and not end_button.disabled, "large hand should not disable end turn")
	var first = ui.get_node_or_null("HandArea").get_child(0)
	var before: int = battle.deck.hand.size()
	if first != null and first.has_signal("play_requested"):
		first.emit_signal("play_requested", first)
	await process_frame
	_expect(battle.deck.hand.size() <= before, "clicking a large hand should not enter discard-only mode")


func _check_hand_pagination(scene: Node, ui: Node) -> void:
	var battle = scene.get_node_or_null("Battle")
	_expect(battle != null, "battle node should exist for hand pagination check")
	if battle == null or battle.deck == null:
		return
	battle.deck.hand.clear()
	for i in 20:
		var card: Card = _card_db.call("get_card", "neutral.strike" if i % 2 == 0 else "neutral.guard")
		if card == null:
			return
		battle.deck.hand.append(card)
	ui.set("_hand_page_index", 0)
	ui.call("_refresh_hand")
	await process_frame
	var hand = ui.get_node_or_null("HandArea")
	_expect(hand != null, "hand should exist for pagination")
	if hand == null:
		return
	_expect(hand.get_child_count() == 10, "hand should render 10 cards per page")
	var page_label = ui.get_node_or_null("HandPage")
	_expect(page_label != null and page_label.visible and str(page_label.text) == "1 / 2", "hand page label should show first of two pages")
	var next_button = ui.get_node_or_null("HandNextPage")
	_expect(next_button != null and not next_button.disabled, "hand next page should be available")
	if next_button != null:
		next_button.emit_signal("pressed")
	await process_frame
	_expect(hand.get_child_count() == 10, "second hand page should render remaining cards")
	if hand.get_child_count() > 0:
		var first = hand.get_child(0)
		_expect(first is CardView and int(first.hand_index) == 10, "second page first card should keep global hand index")
	_expect(page_label != null and str(page_label.text) == "2 / 2", "hand page label should show second page")


func _check_unlimited_turn_draw(scene: Node) -> void:
	var battle = scene.get_node_or_null("Battle")
	_expect(battle != null, "battle node should exist for unlimited draw check")
	if battle == null or battle.deck == null:
		return
	battle.deck.init_from_deck(_run_state.run_deck, 9191)
	battle.turn_number = 0
	battle.is_player_turn = false
	battle.call("_start_player_turn")
	await process_frame
	_expect(battle.deck.hand.size() == 4, "first turn should draw 4 starter cards")
	battle.is_player_turn = false
	battle.call("_start_player_turn")
	await process_frame
	_expect(battle.deck.hand.size() == 6, "second turn should retain hand and draw 2")
	battle.is_player_turn = false
	battle.call("_start_player_turn")
	await process_frame
	_expect(battle.deck.hand.size() == 8, "third turn should reach 8 retained cards")
	battle.is_player_turn = false
	battle.call("_start_player_turn")
	await process_frame
	_expect(battle.deck.hand.size() == 10, "fourth turn should draw past 8 with no hand cap")


func _check_enemy_turn_visible(scene: Node, ui: Node) -> void:
	var battle = scene.get_node_or_null("Battle")
	if battle == null:
		return
	battle.end_player_turn()
	await process_frame
	var turn_label = ui.get_node_or_null("TopBar/Turn")
	_expect(not battle.is_player_turn, "ending turn should enter a visible enemy phase")
	_expect(turn_label != null and str(turn_label.text).find("敌方行动") >= 0, "turn label should show enemy action phase")
	await create_timer(1.1).timeout
	_expect(battle.is_player_turn, "enemy phase should return to player turn after actions")


func _check_battle_animation_events(scene: Node, stage: Control) -> void:
	var battle = scene.get_node_or_null("Battle")
	_expect(battle != null, "battle node should exist for animation event check")
	if battle == null:
		return
	var enemy = _first_alive_enemy(battle)
	_expect(enemy != null, "animation event check should find an enemy")
	if enemy == null:
		return
	battle.player.take_damage(2)
	battle.player.gain_block(4)
	enemy.take_damage(3)
	enemy.gain_block(2)
	enemy.acted.emit(EnemyData.IntentKind.ATTACK)
	await process_frame
	_expect(_stage_label_count(stage) >= 4, "battle stage should spawn floating damage and block text")
	await create_timer(0.8).timeout
	_expect(_stage_label_count(stage) == 0, "battle stage floating text should clean itself up")


func _check_viewport_layout(stage: Control, viewport_size: Vector2) -> void:
	root.size = viewport_size
	await process_frame
	_expect(stage.size.x >= 640, "battle stage should keep minimum responsive width at %s" % viewport_size)
	_expect(stage.size.y >= 220, "battle stage should keep minimum responsive height at %s" % viewport_size)
	var player = stage.get_node_or_null("PlayerAnim")
	if player == null:
		return
	for child in stage.get_children():
		if child is AnimatedSprite2D and str(child.name).begins_with("EnemyAnim_"):
			_expect(absf(child.position.y - player.position.y) <= 1.0, "player and enemy sprites should share one baseline at %s" % viewport_size)


func _first_alive_enemy(battle: Node) -> Node:
	for enemy_node in battle.enemies_container.get_children():
		if enemy_node != null and enemy_node.has_method("is_dead") and not enemy_node.call("is_dead"):
			return enemy_node
	return null


func _stage_label_count(stage: Control) -> int:
	return stage.find_children("*", "Label", true, false).size()


func _stage_has_permanent_status_label(stage: Control) -> bool:
	for node in stage.find_children("*", "Label", true, false):
		var text := str(node.text)
		if text.find("HP") >= 0 or text.find("意图") >= 0 or text.find("状态") >= 0 or text.find("护盾") >= 0:
			return true
	return false


func _deck_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for card in _run_state.run_deck:
		if card != null:
			ids.append(card.id)
	return ids


func _unlock_real_codex_entries(count: int) -> void:
	var unlocked := 0
	for card in _card_db.call("all_cards"):
		if unlocked >= count:
			return
		if card is Card and bool(_game_state.call("unlock_codex", "card." + card.id)):
			unlocked += 1
	for enemy in _enemy_db.call("all_enemies"):
		if unlocked >= count:
			return
		if enemy is EnemyData and bool(_game_state.call("unlock_codex", "beast." + enemy.id)):
			unlocked += 1


func _contains_nth(ids: PackedStringArray, card_id: String, required_count: int) -> bool:
	var count := 0
	for id in ids:
		if id == card_id:
			count += 1
	return count >= required_count


func _restore_snapshot() -> void:
	if _game_state != null and not _snapshot.is_empty():
		_game_state.call("from_dict", _snapshot)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error("[v0.9 smoke] " + message)


func _finish() -> void:
	if _errors.is_empty():
		print("[v0.9 smoke] PASS")
		quit(0)
		return
	print("[v0.9 smoke] FAIL: %d issue(s)" % _errors.size())
	for message in _errors:
		print(" - " + message)
	quit(1)

extends SceneTree

const PixelSprites = preload("res://scripts/map/pixel_sprites.gd")

var _errors: Array[String] = []
var _card_db: Node = null
var _enemy_db: Node = null
var _run_state: Node = null
var _game_state: Node = null


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	await process_frame
	_bind_autoloads()
	_reload_databases()
	await _check_main_menu_key_node()
	await _check_map_key_node(_run_state.CHAPTER_EAST, "east", "east_meadow", "east_bamboo", ["boss_qinglong_weak", "boss_qinglong", "boss_qinglong_strong"])
	await _check_map_key_node(_run_state.CHAPTER_CENTRAL, "central", "central_altar", "central_altar", ["boss_qilin_weak", "boss_qilin", "boss_qilin_strong"])
	await _check_battle_portrait_key_node()
	await _check_chapter_flow_key_node()
	_finish()


func _bind_autoloads() -> void:
	_card_db = root.get_node_or_null("CardDatabase")
	_enemy_db = root.get_node_or_null("EnemyDatabase")
	_run_state = root.get_node_or_null("RunState")
	_game_state = root.get_node_or_null("GameState")
	_expect(_card_db != null, "missing autoload: CardDatabase")
	_expect(_enemy_db != null, "missing autoload: EnemyDatabase")
	_expect(_run_state != null, "missing autoload: RunState")
	_expect(_game_state != null, "missing autoload: GameState")


func _reload_databases() -> void:
	if _card_db != null:
		_card_db.call("reload_all")
	if _enemy_db != null:
		_enemy_db.call("reload_all")


func _check_main_menu_key_node() -> void:
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	_expect(packed != null, "main menu scene should load")
	if packed == null:
		return
	var menu = packed.instantiate()
	root.add_child(menu)
	await process_frame
	var footer = menu.get_node_or_null("Footer")
	_expect(footer != null, "main menu footer should exist")
	if footer != null:
		_expect(str(footer.text).find("v0.14") >= 0, "main menu footer should show v0.14")
	var info = menu.get("_info_label")
	_expect(info != null, "main menu info label should exist")
	if info != null:
		var total: int = int(_card_db.call("all_cards").size()) + int(_enemy_db.call("all_enemies").size())
		_expect(str(info.text).find("/ %d" % total) >= 0, "main menu codex total should include cards and enemies")
	menu.queue_free()


func _check_map_key_node(chapter: int, label: String, floor_tileset: String, wall_tileset: String, boss_ids: Array) -> void:
	_run_state.call("reset_for_new_run")
	_run_state.current_chapter_index = chapter
	_run_state.current_floor = chapter
	_run_state.seed_value = 8000 + chapter
	var packed: PackedScene = load("res://scenes/map/map.tscn")
	_expect(packed != null, "%s map scene should load" % label)
	if packed == null:
		return
	var map = packed.instantiate()
	root.add_child(map)
	await process_frame
	_check_map_movement_speed(map)
	var raw_data: Variant = map.get("data")
	var data: Dictionary = raw_data if raw_data is Dictionary else {}
	_expect(int(data.get("chapter_index", -1)) == chapter, "%s map should use requested chapter" % label)
	_expect(str(data.get("top_floor_tileset", "")) == floor_tileset, "%s map should use expected top floor tileset" % label)
	_expect(str(data.get("iso_floor_tileset", "")) == floor_tileset, "%s map should use expected iso floor tileset" % label)
	_expect(str(data.get("iso_wall_tileset", "")) == wall_tileset, "%s map should use expected iso wall tileset" % label)
	var seen_bosses: Dictionary = {}
	var seen_shop: bool = false
	for entity in Array(data.get("entities", [])):
		if not (entity is Dictionary):
			continue
		var kind: String = str(entity.get("kind", ""))
		if kind == "shop":
			seen_shop = true
		if kind.begins_with("boss"):
			var enemy_id: String = str(entity.get("enemy_id", ""))
			seen_bosses[enemy_id] = true
			var sprite_key: String = str(entity.get("sprite_key", ""))
			_expect(PixelSprites.texture(sprite_key, PixelSprites.DIR_DOWN, 0) != null, "%s boss top sprite should resolve: %s" % [label, sprite_key])
			_expect(PixelSprites.iso_enemy_texture(sprite_key, PixelSprites.DIR_DOWN, 0) != null, "%s boss iso sprite should resolve: %s" % [label, sprite_key])
	for boss_id in boss_ids:
		_expect(seen_bosses.has(boss_id), "%s map should include boss enemy %s" % [label, boss_id])
	_expect(seen_shop, "%s map should include a shop key node" % label)
	map.queue_free()


func _check_map_movement_speed(map: Node) -> void:
	_expect(map.has_method("_player_move_speed"), "map should expose player movement speed helper")
	if not map.has_method("_player_move_speed"):
		return
	var walk_speed: float = float(map.call("_player_move_speed", false))
	var sprint_speed: float = float(map.call("_player_move_speed", true))
	_expect(walk_speed < 180.0, "default player walk speed should be slower than the old fast movement")
	_expect(sprint_speed > walk_speed, "shift sprint should be faster than walking")
	_expect(sprint_speed <= 240.0, "shift sprint should stay close to the previous top speed")


func _check_battle_portrait_key_node() -> void:
	_run_state.call("reset_for_new_run")
	_run_state.next_battle_enemy_ids = PackedStringArray(["boss_qinglong", "boss_qilin"])
	_run_state.seed_value = 8088
	var packed: PackedScene = load("res://scenes/battle/battle.tscn")
	_expect(packed != null, "battle scene should load")
	if packed == null:
		return
	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var ui = scene.get_node_or_null("UI")
	_expect(ui != null, "battle UI should exist")
	if ui == null:
		scene.queue_free()
		return
	ui.call("_rebuild_enemy_list")
	await process_frame
	var panel = ui.get_node_or_null("EnemiesPanel")
	_expect(panel != null, "battle enemy panel node should exist")
	if panel != null:
		_expect(panel.get_child_count() == 0, "battle enemy target buttons should be removed")
	var detail = ui.get_node_or_null("EnemyDetailPanel")
	_expect(detail != null and detail.visible, "battle enemy detail panel should replace target buttons")
	scene.queue_free()


func _check_chapter_flow_key_node() -> void:
	_run_state.call("reset_for_new_run")
	var packed: PackedScene = load("res://scenes/map/map.tscn")
	_expect(packed != null, "map scene should load for chapter flow smoke")
	if packed == null:
		return
	var map = packed.instantiate()
	root.add_child(map)
	await process_frame
	var expected_chapters: Array = [
		_run_state.CHAPTER_WEST,
		_run_state.CHAPTER_NORTH,
		_run_state.CHAPTER_EAST,
		_run_state.CHAPTER_CENTRAL,
	]
	for expected in expected_chapters:
		_run_state.bosses_defeated = int(_run_state.BOSSES_TO_CLEAR)
		map.call("_show_boss_victory", "boss_hard", "keynode smoke")
		_expect(bool(map.get("_pending_chapter_advance")), "chapter clear should request next chapter")
		map.call("_on_victory_close")
		await process_frame
		_expect(int(_run_state.current_chapter_index) == int(expected), "chapter continue should advance to expected chapter")
	_run_state.bosses_defeated = int(_run_state.BOSSES_TO_CLEAR)
	map.call("_show_boss_victory", "boss_hard", "keynode smoke")
	_expect(not bool(map.get("_pending_chapter_advance")), "central clear should be final")
	var victory_text = map.get("_victory_text")
	_expect(victory_text != null, "central final text should exist")
	if victory_text != null:
		_expect(str(victory_text.text).find("忘川之心") >= 0, "central final text should mention Wangchuan finale")
	map.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error("[v0.8 keynode smoke] " + message)


func _finish() -> void:
	if _errors.is_empty():
		print("[v0.8 keynode smoke] PASS")
		quit(0)
		return
	print("[v0.8 keynode smoke] FAIL: %d issue(s)" % _errors.size())
	for message in _errors:
		print(" - " + message)
	quit(1)

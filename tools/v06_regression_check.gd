extends SceneTree

const WEST_CARDS: Array[String] = [
	"shan.luwu_gate",
	"shan.yingzhao_patrol",
	"hai.xuan_gui_shell",
	"hai.tiangou_ward",
	"huang.zheng_pounce",
	"huang.gudiao_cry",
]

const WEST_ENEMIES: Array[String] = [
	"zheng_beast",
	"tian_gou",
	"xuan_gui",
	"gu_diao",
	"elite_yingzhao",
	"boss_luwu_weak",
	"boss_luwu",
	"boss_luwu_strong",
]

var _errors: Array[String] = []
var _card_db: Node = null
var _enemy_db: Node = null
var _run_state: Node = null
var _game_state: Node = null
var _save_system: Node = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_bind_autoloads()
	_check_no_bom_files()
	_reload_databases()
	_check_save_payload_guard()
	_check_run_state()
	_check_west_cards()
	_check_card_description_resolution()
	_check_west_enemies()
	_check_enemy_balance_ranges()
	_check_west_events()
	_check_west_visual_assets()
	await _check_chapter_clear_flow()
	await _check_non_boss_reward_scaling()
	await _check_west_map_scene()
	await _check_card_rule_consistency()
	await _check_codex_beast_entries()
	_finish()


func _bind_autoloads() -> void:
	_card_db = root.get_node_or_null("CardDatabase")
	_enemy_db = root.get_node_or_null("EnemyDatabase")
	_run_state = root.get_node_or_null("RunState")
	_game_state = root.get_node_or_null("GameState")
	_save_system = root.get_node_or_null("SaveSystem")
	_expect(_card_db != null, "missing autoload: CardDatabase")
	_expect(_enemy_db != null, "missing autoload: EnemyDatabase")
	_expect(_run_state != null, "missing autoload: RunState")
	_expect(_game_state != null, "missing autoload: GameState")
	_expect(_save_system != null, "missing autoload: SaveSystem")


func _reload_databases() -> void:
	if _card_db != null:
		_card_db.call("reload_all")
	if _enemy_db != null:
		_enemy_db.call("reload_all")


func _check_no_bom_files() -> void:
	var paths: PackedStringArray = PackedStringArray([
		"res://project.godot",
		"res://export_presets.cfg",
		"res://scenes/main_menu.tscn",
		"res://scripts/core/audio_engine.gd",
		"res://scripts/map/map_scene.gd",
		"res://scripts/codex/codex_view.gd",
		"res://data/events/echo_events.json",
	])
	for path in paths:
		var file := FileAccess.open(path, FileAccess.READ)
		_expect(file != null, "missing text resource for BOM check: %s" % path)
		if file == null:
			continue
		var bytes: PackedByteArray = file.get_buffer(3)
		file.close()
		var has_bom: bool = bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF
		_expect(not has_bom, "text resource should be UTF-8 without BOM: %s" % path)


func _check_save_payload_guard() -> void:
	if _save_system == null:
		return
	_expect(not bool(_save_system.call("load_from_text", "[]", false)), "save loader should reject non-dictionary payload")
	_expect(not bool(_save_system.call("load_from_text", "{\"version\":1,\"game_state\":[]}", false)), "save loader should reject non-dictionary game_state")
	_expect(bool(_save_system.call("load_from_text", "{\"version\":1,\"game_state\":{\"unlocked_codex\":[],\"fragments\":0,\"unlocked_characters\":[\"fang_xun\"],\"settings\":{}}}", false)), "save loader should accept valid payload")


func _check_run_state() -> void:
	if _run_state == null:
		return
	_run_state.call("reset_for_new_run")
	_expect(int(_run_state.current_chapter_index) == int(_run_state.CHAPTER_SOUTH), "new run should start at chapter south")
	_expect(int(_run_state.bosses_defeated) == 0, "new run should reset chapter boss count")
	_expect(int(_run_state.level) == 1 and int(_run_state.exp_value) == 0, "new run should reset level and exp")
	_run_state.call("add_exp", 25)
	_run_state.call("advance_to_next_chapter")
	_expect(int(_run_state.current_chapter_index) == int(_run_state.CHAPTER_WEST), "advance_to_next_chapter should enter chapter west")
	_expect(int(_run_state.bosses_defeated) == 0, "chapter advance should reset boss count")
	_expect(int(_run_state.hp) == int(_run_state.max_hp), "chapter advance should fully heal player")
	_run_state.call("reset_map_progress_to_first_chapter")
	_expect(int(_run_state.current_chapter_index) == int(_run_state.CHAPTER_SOUTH), "reset should return to chapter south")
	_expect(int(_run_state.level) == 1 and int(_run_state.exp_value) == 0, "reset should clear level and exp")


func _check_west_cards() -> void:
	if _card_db == null:
		return
	for card_id in WEST_CARDS:
		var card = _card_db.call("get_card", card_id)
		_expect(card != null, "missing west card: %s" % card_id)
		if card == null:
			continue
		_expect(not card.title.is_empty(), "west card has empty title: %s" % card_id)
		_expect(not card.description.is_empty(), "west card has empty description: %s" % card_id)
		_expect(not card.effects.is_empty(), "west card has no effects: %s" % card_id)


func _check_card_description_resolution() -> void:
	if _card_db == null:
		return
	var zheng: Card = _card_db.call("get_card", "huang.zheng_pounce")
	_expect(zheng != null, "zheng card should exist for description check")
	if zheng != null:
		var desc: String = zheng.get_resolved_description()
		_expect(desc.find("1 层易伤") >= 0, "status description should resolve status_stack instead of amount")
		_expect(desc.find("0 层易伤") < 0, "status description should not show 0 layers")
	var luwu: Card = _card_db.call("get_card", "shan.luwu_gate")
	_expect(luwu != null, "luwu gate card should exist for description check")
	if luwu != null:
		var desc2: String = luwu.get_resolved_description()
		_expect(desc2.find("2 层根脉") >= 0, "self status description should resolve root stack")
	var kuafu: Card = _card_db.call("get_card", "huang.kuafu_pursue")
	_expect(kuafu != null, "kuafu card should exist for description check")
	if kuafu != null:
		var desc3: String = kuafu.get_resolved_description()
		_expect(desc3.find("获得 3 层强化") >= 0, "kuafu description should match implemented strengthen effect")
		_expect(desc3.find("翻倍") < 0, "kuafu description should not mention unimplemented double damage")
	var taotie: Card = _card_db.call("get_card", "huang.taotie_devour")
	_expect(taotie != null, "taotie card should exist for description check")
	if taotie != null:
		_expect(taotie.get_resolved_description().find("每弃") < 0, "taotie description should not mention unimplemented discard scaling")


func _check_west_enemies() -> void:
	if _enemy_db == null or _card_db == null:
		return
	for enemy_id in WEST_ENEMIES:
		var enemy = _enemy_db.call("get_enemy", enemy_id)
		_expect(enemy != null, "missing west enemy: %s" % enemy_id)
		if enemy == null:
			continue
		_expect(enemy.max_hp > 0, "west enemy has invalid hp: %s" % enemy_id)
		_expect(not enemy.display_name.is_empty(), "west enemy has empty display name: %s" % enemy_id)
		_expect(not enemy.intent_pattern.is_empty(), "west enemy has empty intent pattern: %s" % enemy_id)
		_expect(not enemy.awaken_options.is_empty(), "west enemy has empty awaken options: %s" % enemy_id)
		_expect(not enemy.awaken_card_id.is_empty(), "west enemy has empty awaken card: %s" % enemy_id)
		_expect(bool(_card_db.call("has_card", enemy.awaken_card_id)), "west enemy awaken card missing: %s -> %s" % [enemy_id, enemy.awaken_card_id])


func _check_enemy_balance_ranges() -> void:
	if _enemy_db == null:
		return
	var west_normals: Dictionary = {
		"zheng_beast": Vector2i(26, 34),
		"tian_gou": Vector2i(30, 38),
		"xuan_gui": Vector2i(34, 42),
		"gu_diao": Vector2i(38, 46),
	}
	for enemy_id in west_normals.keys():
		var enemy = _enemy_db.call("get_enemy", enemy_id)
		if enemy == null:
			continue
		var hp_range: Vector2i = west_normals[enemy_id]
		_expect(int(enemy.max_hp) >= hp_range.x and int(enemy.max_hp) <= hp_range.y, "west normal hp out of expected range: %s" % enemy_id)
	var elite = _enemy_db.call("get_enemy", "elite_yingzhao")
	if elite != null:
		_expect(int(elite.max_hp) >= 70 and int(elite.max_hp) <= 90, "west elite hp should stay in v0.6 range")
	var weak = _enemy_db.call("get_enemy", "boss_luwu_weak")
	var mid = _enemy_db.call("get_enemy", "boss_luwu")
	var strong = _enemy_db.call("get_enemy", "boss_luwu_strong")
	if weak != null and mid != null and strong != null:
		_expect(int(weak.max_hp) < int(mid.max_hp) and int(mid.max_hp) < int(strong.max_hp), "luwu boss hp should scale weak < mid < strong")
		_expect(int(strong.max_hp) <= 220, "luwu strong hp should not exceed v0.6 cap")


func _check_west_events() -> void:
	if _run_state == null:
		return
	var event_db = load("res://scripts/map/event_database.gd")
	var events: Array = event_db.load_all()
	var west_count: int = 0
	for ev in events:
		if not (ev is Dictionary):
			continue
		if int(ev.get("chapter", -1)) != int(_run_state.CHAPTER_WEST):
			continue
		west_count += 1
		_expect(not str(ev.get("id", "")).is_empty(), "west event has empty id")
		_expect(not str(ev.get("name", "")).is_empty(), "west event has empty name")
		_expect(not str(ev.get("story", "")).is_empty(), "west event has empty story")
		var options: Array = Array(ev.get("options", []))
		_expect(not options.is_empty(), "west event has no options: %s" % str(ev.get("id", "")))
		for opt in options:
			if opt is Dictionary:
				_check_reward_reference(opt, "event.%s" % str(ev.get("id", "")))
				_expect(not str(opt.get("result", "")).is_empty(), "west event option has empty result text: %s" % str(ev.get("id", "")))
	_expect(west_count >= 4, "chapter west should have at least 4 events")


func _check_west_visual_assets() -> void:
	var top_paths: PackedStringArray = PackedStringArray([
		"res://assets/textures/top/entities/zheng_beast.png",
		"res://assets/textures/top/entities/tian_gou.png",
		"res://assets/textures/top/entities/xuan_gui.png",
		"res://assets/textures/top/entities/gu_diao.png",
		"res://assets/textures/top/entities/elite_yingzhao.png",
		"res://assets/textures/top/entities/boss_luwu_weak.png",
		"res://assets/textures/top/entities/boss_luwu.png",
		"res://assets/textures/top/entities/boss_luwu_strong.png",
		"res://assets/textures/top/entities/treasure.png",
		"res://assets/textures/top/entities/shop.png",
		"res://assets/textures/top/entities/rest.png",
		"res://assets/textures/top/entities/event.png",
	])
	var iso_paths: PackedStringArray = PackedStringArray([
		"res://assets/textures/iso/enemies/zheng_beast_walk.png",
		"res://assets/textures/iso/enemies/tian_gou_walk.png",
		"res://assets/textures/iso/enemies/xuan_gui_walk.png",
		"res://assets/textures/iso/enemies/gu_diao_walk.png",
		"res://assets/textures/iso/entities/elite_yingzhao_walk.png",
		"res://assets/textures/iso/entities/boss_luwu_weak_walk.png",
		"res://assets/textures/iso/entities/boss_luwu_walk.png",
		"res://assets/textures/iso/entities/boss_luwu_strong_walk.png",
		"res://assets/textures/iso/entities/treasure_idle.png",
		"res://assets/textures/iso/entities/shop_idle.png",
		"res://assets/textures/iso/entities/rest_idle.png",
		"res://assets/textures/iso/entities/event_idle.png",
		"res://assets/textures/iso/tilesheet_forest.png",
		"res://assets/textures/iso/tilesheet_village.png",
	])
	for path in top_paths:
		_expect(ResourceLoader.exists(path), "missing top visual asset: %s" % path)
	for path in iso_paths:
		_expect(ResourceLoader.exists(path), "missing iso visual asset: %s" % path)


func _check_reward_reference(reward: Dictionary, source: String) -> void:
	if _card_db == null:
		return
	var reward_type: String = str(reward.get("type", ""))
	if reward_type == "card" or reward_type == "card_cost" or reward_type == "card_cost_hp" or reward_type == "card_cost_fragments":
		var card_id: String = str(reward.get("card", ""))
		_expect(not card_id.is_empty(), "%s card reward has empty card id" % source)
		_expect(bool(_card_db.call("has_card", card_id)), "%s card reward references missing card: %s" % [source, card_id])


func _check_west_map_scene() -> void:
	if _run_state == null or _game_state == null:
		return
	_run_state.call("reset_for_new_run")
	_run_state.current_chapter_index = _run_state.CHAPTER_WEST
	_run_state.current_floor = _run_state.CHAPTER_WEST
	_run_state.seed_value = 60601
	_game_state.fragments = 999
	var packed: PackedScene = load("res://scenes/map/map.tscn")
	_expect(packed != null, "missing map scene")
	if packed == null:
		return
	var map = packed.instantiate()
	root.add_child(map)
	await process_frame
	var map_data: Dictionary = Dictionary(map.get("data"))
	if map_data.is_empty():
		map_data = Dictionary(map.call("_generate_map"))
	_expect(int(map_data.get("chapter_index", -1)) == int(_run_state.CHAPTER_WEST), "west map should be chapter west")
	_expect(str(map_data.get("top_floor_tileset", "")) == "dirt", "west top floor should use dirt")
	_expect(str(map_data.get("iso_floor_tileset", "")) == "forest", "west iso floor should use forest tilesheet")
	_expect(int(map_data.get("iso_floor_row", -1)) == 1, "west iso floor should use dirt row")
	_check_map_entities(map_data)
	await _check_event_choice_result(map, map_data)
	await _check_treasure_open(map, map_data)
	await _check_rest_use(map, map_data)
	map.call("_enter_shop", {"name": "白石古肆", "story": "虎纹面具老者守着西山旧符。"})
	await process_frame
	_check_shop_copy(map)
	_check_shop_items(Array(map.get("_shop_items")))
	_check_boss_reward(map)
	map.queue_free()


func _check_chapter_clear_flow() -> void:
	if _run_state == null or _game_state == null:
		return
	_run_state.call("reset_for_new_run")
	_run_state.seed_value = 60600
	var packed: PackedScene = load("res://scenes/map/map.tscn")
	_expect(packed != null, "missing map scene for chapter flow")
	if packed == null:
		return
	var map = packed.instantiate()
	root.add_child(map)
	await process_frame
	var before_fragments: int = int(_game_state.fragments)
	map.call("_debug_grant_fragments")
	_expect(int(_game_state.fragments) == before_fragments + 100, "debug fragments tool should add fragments")
	_run_state.hp = maxi(1, int(_run_state.max_hp) - 20)
	map.call("_debug_full_heal")
	_expect(int(_run_state.hp) == int(_run_state.max_hp), "debug heal tool should fully heal")
	var before_level: int = int(_run_state.level)
	var before_exp: int = int(_run_state.exp_value)
	map.call("_debug_grant_exp")
	_expect(int(_run_state.level) > before_level or int(_run_state.exp_value) != before_exp, "debug exp tool should advance exp or level")
	_run_state.bosses_defeated = int(_run_state.BOSSES_TO_CLEAR)
	map.call("_show_boss_victory", "boss_hard", "流程检查")
	var victory_text = map.get("_victory_text")
	var victory_btn = map.get("_victory_btn")
	_expect(bool(map.get("_pending_chapter_advance")), "south clear should request chapter advance")
	if victory_text != null:
		_expect(str(victory_text.text).find("进入下一章") >= 0, "south clear text should mention next chapter")
	if victory_btn != null:
		_expect(str(victory_btn.text).find("进入西山") >= 0, "south clear button should enter west chapter")
	map.call("_on_victory_close")
	await process_frame
	_expect(int(_run_state.current_chapter_index) == int(_run_state.CHAPTER_WEST), "victory continue should advance to west chapter")
	_expect(int(_run_state.bosses_defeated) == 0, "chapter advance should clear chapter boss count")
	_expect(int(_run_state.hp) == int(_run_state.max_hp), "chapter advance from victory should fully heal")
	_run_state.bosses_defeated = int(_run_state.BOSSES_TO_CLEAR)
	map.call("_show_boss_victory", "boss_hard", "流程检查")
	_expect(not bool(map.get("_pending_chapter_advance")), "west clear should not request another chapter")
	if victory_text != null:
		_expect(str(victory_text.text).find("v0.6 全境净化") >= 0, "west clear should show v0.6 clear text")
	if victory_btn != null:
		_expect(str(victory_btn.text).find("回到主菜单") >= 0, "west clear button should return to menu")
	map.queue_free()


func _check_non_boss_reward_scaling() -> void:
	if _run_state == null or _game_state == null:
		return
	var packed: PackedScene = load("res://scenes/map/map.tscn")
	_expect(packed != null, "missing map scene for reward scaling")
	if packed == null:
		return
	_run_state.call("reset_for_new_run")
	_game_state.fragments = 0
	var map = packed.instantiate()
	root.add_child(map)
	await process_frame
	_run_state.current_chapter_index = _run_state.CHAPTER_SOUTH
	var south_enemy: Dictionary = map.call("_grant_non_boss_battle_reward", "enemy", 1)
	_expect(int(south_enemy.get("fragments", 0)) == 5, "south normal enemy should grant 5 fragments")
	_expect(int(south_enemy.get("exp", 0)) == 7, "south normal enemy should grant 7 exp")
	_run_state.current_chapter_index = _run_state.CHAPTER_WEST
	var west_enemy: Dictionary = map.call("_grant_non_boss_battle_reward", "enemy", 2)
	_expect(int(west_enemy.get("fragments", 0)) == 10, "west two-enemy pack should grant 10 fragments")
	_expect(int(west_enemy.get("exp", 0)) == 12, "west two-enemy pack should grant 12 exp")
	var west_elite: Dictionary = map.call("_grant_non_boss_battle_reward", "elite", 1)
	_expect(int(west_elite.get("fragments", 0)) == 32, "west elite should grant 32 fragments")
	_expect(int(west_elite.get("exp", 0)) == 24, "west elite should grant 24 exp")
	map.queue_free()


func _check_map_entities(map_data: Dictionary) -> void:
	var entities: Array = Array(map_data.get("entities", []))
	var boss_count: int = 0
	var enemy_count: int = 0
	var event_count: int = 0
	for entity in entities:
		if not (entity is Dictionary):
			continue
		var kind: String = str(entity.get("kind", ""))
		if kind.begins_with("boss"):
			boss_count += 1
			var boss_enemy: String = str(entity.get("enemy_id", ""))
			_expect(WEST_ENEMIES.has(boss_enemy), "west boss references unexpected enemy: %s" % boss_enemy)
		elif kind == "enemy":
			enemy_count += 1
			var enemies: Array = Array(entity.get("enemies", []))
			_expect(not enemies.is_empty(), "west map enemy entity has empty enemies")
			var sprite_key: String = str(entity.get("sprite_key", ""))
			_expect(sprite_key.begins_with("enemy."), "west top enemy sprite_key should use enemy.<id>: %s" % sprite_key)
		elif kind == "event":
			event_count += 1
	_expect(boss_count == 3, "west map should generate exactly 3 bosses")
	_expect(enemy_count >= 30, "west map should generate enough normal enemies")
	_expect(event_count >= 4, "west map should generate at least 4 events")


func _check_shop_items(items: Array) -> void:
	if _card_db == null:
		return
	var card_count: int = 0
	var west_card_count: int = 0
	var seen_cards: Dictionary = {}
	for item in items:
		if not (item is Dictionary):
			_error("shop item should be dictionary")
			continue
		if str(item.get("type", "")) != "card":
			continue
		card_count += 1
		var card_id: String = str(item.get("card", ""))
		_expect(bool(_card_db.call("has_card", card_id)), "shop references missing card: %s" % card_id)
		_expect(not seen_cards.has(card_id), "shop should not duplicate card offer: %s" % card_id)
		seen_cards[card_id] = true
		if WEST_CARDS.has(card_id):
			west_card_count += 1
	_expect(card_count == 3, "shop should offer exactly 3 cards")
	_expect(west_card_count >= 1, "west shop should guarantee at least 1 west card")


func _check_rest_use(map, map_data: Dictionary) -> void:
	if _run_state == null:
		return
	var rest_entity: Dictionary = {}
	for entity in Array(map_data.get("entities", [])):
		if entity is Dictionary and str(entity.get("kind", "")) == "rest":
			rest_entity = entity
			break
	_expect(not rest_entity.is_empty(), "west map should generate rest station")
	if rest_entity.is_empty():
		return
	_run_state.hp = maxi(1, int(_run_state.max_hp) - 50)
	var before_hp: int = int(_run_state.hp)
	map.call("_use_rest", rest_entity)
	await process_frame
	_expect(int(_run_state.hp) == mini(int(_run_state.max_hp), before_hp + 35), "west rest should heal 35 hp")
	var title_label = map.get("_event_title")
	var body_label = map.get("_event_body")
	_expect(title_label != null, "rest title label should exist")
	_expect(body_label != null, "rest body label should exist")
	if title_label != null:
		_expect(str(title_label.text) == str(rest_entity.get("name", "")), "rest should use entity title")
	if body_label != null:
		_expect(str(body_label.text).find("白羽") >= 0 or str(body_label.text).find("铜铃") >= 0, "west rest should use entity story")


func _check_treasure_open(map, map_data: Dictionary) -> void:
	var treasure_entity: Dictionary = {}
	for entity in Array(map_data.get("entities", [])):
		if entity is Dictionary and str(entity.get("kind", "")) == "treasure":
			treasure_entity = entity
			break
	_expect(not treasure_entity.is_empty(), "west map should generate treasure")
	if treasure_entity.is_empty():
		return
	_expect(str(treasure_entity.get("name", "")) == "白石秘匣", "west treasure should use chapter title")
	_expect(str(treasure_entity.get("story", "")).find("白虎境") >= 0, "west treasure should use chapter story")
	map.call("_open_treasure", treasure_entity)
	await process_frame
	var title_label = map.get("_event_title")
	var body_label = map.get("_event_body")
	_expect(title_label != null, "treasure title label should exist")
	_expect(body_label != null, "treasure body label should exist")
	if title_label != null:
		_expect(str(title_label.text) == "白石秘匣", "west treasure panel should use entity title")
	if body_label != null:
		_expect(str(body_label.text).find("白虎境") >= 0, "west treasure panel should use entity story")
		_expect(str(body_label.text).find("本次变化") >= 0, "west treasure panel should summarize actual reward")


func _check_event_choice_result(map, map_data: Dictionary) -> void:
	var event_entity: Dictionary = {}
	for entity in Array(map_data.get("entities", [])):
		if entity is Dictionary and str(entity.get("kind", "")) == "event":
			event_entity = entity
			break
	_expect(not event_entity.is_empty(), "west map should generate event")
	if event_entity.is_empty():
		return
	var options: Array = Array(event_entity.get("options", []))
	_expect(not options.is_empty(), "west event should have options")
	if options.is_empty():
		return
	map.call("_trigger_event", event_entity)
	await process_frame
	var event_title_label = map.get("_event_title")
	_expect(event_title_label != null, "event title label should exist")
	if event_title_label != null:
		_expect(str(event_title_label.text) == str(event_entity.get("name", "")), "event panel should use entity title")
	map.call("_on_event_choice", Dictionary(options[0]))
	await process_frame
	var title_label = map.get("_event_title")
	var body_label = map.get("_event_body")
	_expect(title_label != null, "event result title label should exist")
	_expect(body_label != null, "event result body label should exist")
	if title_label != null:
		_expect(str(title_label.text) == "回响结果", "event choice should show result panel")
	if body_label != null:
		_expect(not str(body_label.text).is_empty(), "event result panel should not be empty")
		_expect(str(body_label.text).find("本次变化") >= 0, "event result panel should summarize actual reward")


func _check_shop_copy(map) -> void:
	var title_label = map.get("_event_title")
	var body_label = map.get("_event_body")
	_expect(title_label != null, "shop title label should exist")
	_expect(body_label != null, "shop body label should exist")
	if title_label != null:
		_expect(str(title_label.text) == "白石古肆", "west shop should use entity title")
	if body_label != null:
		_expect(str(body_label.text).find("虎纹面具") >= 0, "west shop should use entity story")
	var raw_items: Variant = map.get("_shop_items")
	var items: Array = raw_items if raw_items is Array else []
	var buy_index := -1
	for i in items.size():
		var raw_item: Variant = items[i]
		if raw_item is Dictionary:
			var item_type := str(raw_item.get("type", ""))
			if item_type == "card" or item_type == "heal" or item_type == "max_hp":
				buy_index = i
				break
	_expect(buy_index >= 0, "shop should have purchasable item")
	if buy_index >= 0:
		map.call("_on_shop_buy", buy_index)
		if body_label != null:
			_expect(str(body_label.text).find("本次变化") >= 0, "shop purchase should summarize actual change")


func _check_boss_reward(map) -> void:
	if _run_state == null or _game_state == null:
		return
	var before_deck_size: int = _run_state.run_deck.size()
	var before_fragments: int = int(_game_state.fragments)
	map.call("_grant_boss_reward", "boss_mid")
	_expect(int(_game_state.fragments) > before_fragments, "west boss reward should grant fragments")
	_expect(_run_state.run_deck.size() == before_deck_size + 1, "west boss reward should add reward card")
	_expect(bool(_game_state.call("is_codex_unlocked", "card.shan.luwu_gate")), "west boss reward should unlock codex for reward card")
	_run_state.bosses_defeated = 1
	map.call("_show_boss_victory", "boss_mid", "陆吾")
	var victory_text = map.get("_victory_text")
	_expect(victory_text != null, "boss victory text should exist")
	if victory_text != null:
		_expect(str(victory_text.text).find("本次变化") >= 0, "boss victory should summarize actual reward")


func _check_codex_beast_entries() -> void:
	if _enemy_db == null or _game_state == null:
		return
	var packed: PackedScene = load("res://scenes/codex/codex.tscn")
	_expect(packed != null, "missing codex scene")
	if packed == null:
		return
	_game_state.call("unlock_codex", "beast.boss_luwu")
	_game_state.call("unlock_codex", "card.shan.luwu_gate")
	var codex = packed.instantiate()
	root.add_child(codex)
	await process_frame
	var list = codex.get("_list")
	var found_beast_section: bool = false
	if list != null:
		for child in list.get_children():
			if child is Button and str(child.text).find("异兽") >= 0:
				found_beast_section = true
				break
	_expect(found_beast_section, "codex should include beast section")
	var enemy = _enemy_db.call("get_enemy", "boss_luwu")
	_expect(enemy != null, "codex test enemy should exist")
	if enemy != null:
		codex.call("_show_enemy_detail", enemy, true)
		var detail = codex.get("_detail")
		_expect(detail != null, "codex detail label should exist")
		if detail != null:
			var text: String = str(detail.call("get_parsed_text")) if detail.has_method("get_parsed_text") else str(detail.text)
			_expect(text.find("昆仑司门") >= 0, "codex beast detail should show enemy name")
			_expect(text.find("山海经原文") >= 0, "codex beast detail should show classic quote")
			_expect(text.find("唤醒问答") >= 0, "codex beast detail should show awaken quiz")
			_expect(text.find("陆吾·镇门") >= 0, "codex beast detail should show awaken reward card")
	codex.queue_free()


func _check_card_rule_consistency() -> void:
	if _run_state == null or _card_db == null:
		return
	_run_state.call("reset_for_new_run")
	_run_state.next_battle_enemy_ids = PackedStringArray(["hu_diao"])
	_run_state.seed_value = 60603
	var packed: PackedScene = load("res://scenes/battle/battle.tscn")
	_expect(packed != null, "missing battle scene")
	if packed == null:
		return
	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var battle = scene.get_node_or_null("Battle")
	_expect(battle != null, "battle node should exist")
	if battle == null:
		scene.queue_free()
		return
	var enemy = battle.enemies_container.get_child(0)
	_expect(enemy != null, "card rule test enemy should exist")
	if enemy == null:
		scene.queue_free()
		return
	_check_discount_rule(battle)
	_check_warrior_oath_rule(battle, enemy)
	_check_bifang_wet_rule(battle, enemy)
	_check_xingtian_empty_hand_rule(battle, enemy)
	_check_kuafu_self_damage_rule(battle, enemy)
	_check_status_duration_rules(battle, enemy)
	await _check_enemy_intent_actual_damage(scene, battle, enemy)
	scene.queue_free()


func _set_test_hand(battle, card_id: String) -> Card:
	var card: Card = _card_db.call("get_card", card_id)
	_expect(card != null, "missing card for rule test: %s" % card_id)
	if card == null:
		return null
	battle.deck.hand.clear()
	battle.deck.draw_pile.clear()
	battle.deck.discard_pile.clear()
	battle.deck.exhaust_pile.clear()
	battle.deck.hand.append(card)
	_run_state.energy = 10
	_run_state.max_energy = 10
	battle.is_player_turn = true
	return card


func _reset_enemy_for_rule(enemy, hp_value: int) -> void:
	enemy.hp = hp_value
	enemy.max_hp = hp_value
	enemy.block = 0
	enemy.statuses.clear()


func _check_discount_rule(battle) -> void:
	var card: Card = _set_test_hand(battle, "hai.yinglong_call")
	if card == null:
		return
	battle.player.statuses.clear()
	battle.player.apply_status("resonance_hai", 1)
	_run_state.energy = 0
	_expect(int(battle.call("effective_card_cost", card)) == 0, "resonance_hai should reduce next hai card cost to 0")
	var played: bool = bool(battle.call("play_card_at_index", 0, null))
	_expect(played, "discounted hai card should be playable at 0 energy")
	_expect(not battle.player.statuses.has("resonance_hai"), "school discount should be consumed after use")


func _check_warrior_oath_rule(battle, enemy) -> void:
	var card: Card = _set_test_hand(battle, "neutral.warrior_oath")
	if card == null:
		return
	_reset_enemy_for_rule(enemy, 30)
	battle.player.statuses.clear()
	battle.player.block = 5
	var played: bool = bool(battle.call("play_card_at_index", 0, enemy))
	_expect(played, "warrior oath should be playable")
	_expect(int(enemy.hp) == 12, "warrior oath should hit twice while player has block")


func _check_bifang_wet_rule(battle, enemy) -> void:
	var card: Card = _set_test_hand(battle, "hai.bifang_dance")
	if card == null:
		return
	_reset_enemy_for_rule(enemy, 30)
	battle.player.statuses.clear()
	enemy.apply_status("wet", 1)
	var played: bool = bool(battle.call("play_card_at_index", 0, enemy))
	_expect(played, "bifang dance should be playable")
	_expect(int(enemy.hp) == 15, "bifang dance should add a third hit against wet target")


func _check_xingtian_empty_hand_rule(battle, enemy) -> void:
	var card: Card = _set_test_hand(battle, "huang.xingtian_axe")
	if card == null:
		return
	_reset_enemy_for_rule(enemy, 30)
	battle.player.statuses.clear()
	var played: bool = bool(battle.call("play_card_at_index", 0, enemy))
	_expect(played, "xingtian axe should be playable")
	_expect(int(enemy.hp) == 12, "xingtian axe should add a third hit when hand is empty")


func _check_kuafu_self_damage_rule(battle, enemy) -> void:
	var card: Card = _set_test_hand(battle, "huang.kuafu_pursue")
	if card == null:
		return
	_reset_enemy_for_rule(enemy, 30)
	battle.player.statuses.clear()
	_run_state.hp = _run_state.max_hp
	var before_hp: int = int(_run_state.hp)
	var played: bool = bool(battle.call("play_card_at_index", 0, enemy))
	_expect(played, "kuafu pursue should be playable")
	_expect(int(enemy.hp) == 18, "kuafu pursue should deal target damage")
	_expect(int(_run_state.hp) == before_hp - 3, "kuafu pursue should apply self damage cost")


func _check_status_duration_rules(battle, enemy) -> void:
	battle.player.statuses.clear()
	battle.player.apply_status("vulnerable", 1)
	battle.player.on_turn_end()
	_expect(battle.player.statuses.has("vulnerable"), "player vulnerable should survive player turn end until next incoming hit")
	battle.player.take_damage(1)
	_expect(not battle.player.statuses.has("vulnerable"), "player vulnerable should decay after incoming hit")
	battle.player.statuses.clear()
	battle.player.block = 0
	battle.player.apply_status("root", 2)
	battle.player.on_turn_end()
	_expect(battle.player.statuses.has("root"), "player root should persist across turn end")
	battle.player.on_turn_start()
	_expect(int(battle.player.block) == 2, "player root should grant block at turn start")
	enemy.statuses.clear()
	enemy.apply_status("wet", 1)
	enemy.on_turn_end()
	_expect(not enemy.statuses.has("wet"), "enemy wet should decay at enemy turn end")
	enemy.statuses.clear()
	enemy.current_intent = enemy.data.resolve_intent(0)
	enemy.apply_status("strengthen", 2)
	enemy.act_on(battle.player)
	_expect(not enemy.statuses.has("strengthen"), "enemy strengthen should be consumed by next attack")


func _check_enemy_intent_actual_damage(scene, battle, enemy) -> void:
	var ui = scene.get_node_or_null("UI")
	_expect(ui != null, "battle ui should exist for intent test")
	if ui == null:
		return
	enemy.statuses.clear()
	battle.player.statuses.clear()
	enemy.current_intent = enemy.data.resolve_intent(0)
	enemy.apply_status("strengthen", 2)
	battle.player.apply_status("vulnerable", 1)
	ui.call("_rebuild_enemy_list")
	await process_frame
	var panel = ui.get("_enemies_panel")
	_expect(panel != null, "enemy panel should exist")
	if panel == null or panel.get_child_count() <= 0:
		return
	var row = panel.get_child(0)
	var intent_label = null
	if row.get_child_count() > 0:
		var box = row.get_child(0)
		intent_label = box.get_node_or_null("Intent")
	_expect(intent_label != null, "intent label should exist")
	if intent_label != null:
		_expect(str(intent_label.text).find("6 → 12") >= 0, "enemy intent should show actual modified damage")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)


func _error(message: String) -> void:
	_errors.append(message)
	push_error("[v0.6 regression] " + message)


func _finish() -> void:
	if _errors.is_empty():
		print("[v0.6 regression] PASS")
		quit(0)
	else:
		print("[v0.6 regression] FAIL: %d issue(s)" % _errors.size())
		for message in _errors:
			print(" - " + message)
		quit(1)

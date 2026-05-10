extends SceneTree

const PixelSprites = preload("res://scripts/map/pixel_sprites.gd")

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

const NORTH_CARDS: Array[String] = [
	"hai.heluo_ally",
	"huang.feiyi_ally",
	"shan.zhuhuai_ally",
	"hai.xiao_ally",
	"huang.xiangliu_ally",
	"hai.zhulong_ally",
	"hai.beishan_mist",
	"shan.xuanwu_barrier",
	"hai.cold_current",
	"huang.memory_venom",
	"shan.black_ridge_guard",
	"hai.deep_pool_reflection",
	"neutral.archive_index",
	"neutral.echo_rehearse",
	"shan.rooted_oath",
	"shan.mountain_bell",
	"hai.tide_return",
	"hai.rain_path",
	"huang.bone_whistle",
	"huang.fierce_memory",
]

const NORTH_ENEMIES: Array[String] = [
	"he_luo_fish",
	"fei_yi",
	"zhuhuai",
	"xiao_beast",
	"elite_xiangliu_shadow",
	"boss_zhulong_weak",
	"boss_zhulong",
	"boss_zhulong_strong",
]

const EAST_CARDS: Array[String] = [
	"shan.dangkang_harvest",
	"hai.qiuyu_sleep",
	"huang.lingling_floodcall",
	"huang.zhuru_fright",
	"hai.yinglong_rainpath",
	"hai.qinglong_ally",
	"shan.green_sprout_guard",
	"shan.spring_root",
	"hai.drizzle_rewrite",
	"huang.thunder_seed",
	"neutral.seed_catalog",
	"neutral.field_rehearsal",
]

const EAST_ENEMIES: Array[String] = [
	"dang_kang",
	"qiu_yu",
	"ling_ling",
	"zhu_ru",
	"elite_yinglong_young",
	"boss_qinglong_weak",
	"boss_qinglong",
	"boss_qinglong_strong",
]

const CENTRAL_CARDS: Array[String] = [
	"shan.tulou_guard",
	"shan.qilin_virtue",
	"shan.central_earth_oath",
	"shan.square_altar",
	"hai.jimeng_rain_order",
	"hai.wenlin_path",
	"hai.central_confluence",
	"hai.round_return",
	"huang.kui_thunder_drum",
	"huang.jiao_warning",
	"huang.fivefold_pressure",
	"neutral.five_realm_harmony",
]

const CENTRAL_ENEMIES: Array[String] = [
	"kui",
	"tu_lou",
	"jiao_beast",
	"wen_lin",
	"elite_ji_meng",
	"boss_qilin_weak",
	"boss_qilin",
	"boss_qilin_strong",
]

var _errors: Array[String] = []
var _card_db: Node = null
var _enemy_db: Node = null
var _run_state: Node = null
var _game_state: Node = null
var _save_system: Node = null


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	await process_frame
	_bind_autoloads()
	_check_no_bom_files()
	_reload_databases()
	_check_save_payload_guard()
	_check_run_state()
	await _check_main_menu_codex_total()
	_check_west_cards()
	_check_content_counts()
	_check_north_cards()
	_check_east_cards()
	_check_central_cards()
	_check_card_description_resolution()
	_check_west_enemies()
	_check_north_enemies()
	_check_east_enemies()
	_check_central_enemies()
	_check_enemy_balance_ranges()
	_check_west_events()
	_check_north_events()
	_check_east_events()
	_check_central_events()
	_check_west_visual_assets()
	_check_north_visual_assets()
	_check_east_visual_assets()
	_check_central_visual_assets()
	await _check_chapter_clear_flow()
	await _check_non_boss_reward_scaling()
	await _check_west_map_scene()
	await _check_north_map_scene()
	await _check_east_map_scene()
	await _check_central_map_scene()
	await _check_card_rule_consistency()
	await _check_summon_ally_rule()
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
	_run_state.call("advance_to_next_chapter")
	_expect(int(_run_state.current_chapter_index) == int(_run_state.CHAPTER_NORTH), "advance_to_next_chapter should enter chapter north")
	_expect(bool(_run_state.call("has_next_chapter")), "chapter north should have east chapter in v0.7")
	_run_state.call("advance_to_next_chapter")
	_expect(int(_run_state.current_chapter_index) == int(_run_state.CHAPTER_EAST), "advance_to_next_chapter should enter chapter east")
	_expect(bool(_run_state.call("has_next_chapter")), "chapter east should have central chapter in v0.8")
	_run_state.call("advance_to_next_chapter")
	_expect(int(_run_state.current_chapter_index) == int(_run_state.CHAPTER_CENTRAL), "advance_to_next_chapter should enter chapter central")
	_expect(not bool(_run_state.call("has_next_chapter")), "chapter central should be final chapter in v0.8")
	_run_state.call("reset_map_progress_to_first_chapter")
	_expect(int(_run_state.current_chapter_index) == int(_run_state.CHAPTER_SOUTH), "reset should return to chapter south")
	_expect(int(_run_state.level) == 1 and int(_run_state.exp_value) == 0, "reset should clear level and exp")


func _check_main_menu_codex_total() -> void:
	if _card_db == null or _enemy_db == null or _game_state == null:
		return
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	_expect(packed != null, "missing main menu scene")
	if packed == null:
		return
	var menu = packed.instantiate()
	root.add_child(menu)
	await process_frame
	var info = menu.get("_info_label")
	_expect(info != null, "main menu info label should exist")
	if info != null:
		var total: int = int(_card_db.call("all_cards").size()) + int(_enemy_db.call("all_enemies").size())
		_expect(str(info.text).find("/ %d" % total) >= 0, "main menu codex total should include cards and beasts")
	menu.queue_free()


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


func _check_content_counts() -> void:
	if _card_db == null or _enemy_db == null:
		return
	var event_db = load("res://scripts/map/event_database.gd")
	var events: Array = event_db.load_all()
	_expect(int(_card_db.call("all_cards").size()) == 92, "v0.11 should load exactly 92 cards")
	_expect(int(_enemy_db.call("all_enemies").size()) == 40, "v0.8 should load exactly 40 enemies")
	_expect(events.size() == 40, "v0.8 should load exactly 40 events")


func _check_north_cards() -> void:
	if _card_db == null:
		return
	for card_id in NORTH_CARDS:
		var card = _card_db.call("get_card", card_id)
		_expect(card != null, "missing north card: %s" % card_id)
		if card == null:
			continue
		_expect(not card.title.is_empty(), "north card has empty title: %s" % card_id)
		_expect(not card.description.is_empty(), "north card has empty description: %s" % card_id)
		_expect(not card.classic_quote.is_empty(), "north card has empty classic quote: %s" % card_id)
		_expect(not card.translation.is_empty(), "north card has empty translation: %s" % card_id)
		_expect(not card.alive_today.is_empty(), "north card has empty alive_today: %s" % card_id)
		_expect(not card.effects.is_empty(), "north card has no effects: %s" % card_id)
	var summon: Card = _card_db.call("get_card", "hai.heluo_ally")
	if summon != null:
		_expect(summon.effects[0].kind == CardEffect.Kind.SUMMON_ALLY, "heluo ally card should use SUMMON_ALLY")
		_expect(summon.effects[0].target == CardEffect.Target.NONE, "SUMMON_ALLY target should be NONE")
		_expect(summon.effects[0].status_id == "ally_heluo", "SUMMON_ALLY status_id should carry ally id")
		_expect(summon.effects[0].amount == 3, "SUMMON_ALLY amount should carry duration")


func _check_east_cards() -> void:
	if _card_db == null:
		return
	for card_id in EAST_CARDS:
		var card = _card_db.call("get_card", card_id)
		_expect(card != null, "missing east card: %s" % card_id)
		if card == null:
			continue
		_expect(not card.title.is_empty(), "east card has empty title: %s" % card_id)
		_expect(not card.description.is_empty(), "east card has empty description: %s" % card_id)
		_expect(not card.classic_quote.is_empty(), "east card has empty classic quote: %s" % card_id)
		_expect(not card.translation.is_empty(), "east card has empty translation: %s" % card_id)
		_expect(not card.alive_today.is_empty(), "east card has empty alive_today: %s" % card_id)
		_expect(not card.effects.is_empty(), "east card has no effects: %s" % card_id)
	var summon: Card = _card_db.call("get_card", "hai.qinglong_ally")
	if summon != null:
		_expect(summon.effects[0].kind == CardEffect.Kind.SUMMON_ALLY, "qinglong ally card should use SUMMON_ALLY")
		_expect(summon.effects[0].target == CardEffect.Target.NONE, "qinglong SUMMON_ALLY target should be NONE")
		_expect(summon.effects[0].status_id == "ally_qinglong", "qinglong SUMMON_ALLY status_id should carry ally id")
	var spring_root: Card = _card_db.call("get_card", "shan.spring_root")
	if spring_root != null:
		_expect(spring_root.get_resolved_description().find("根脉") >= 0, "east should reuse root instead of new growth status")


func _check_central_cards() -> void:
	if _card_db == null:
		return
	for card_id in CENTRAL_CARDS:
		var card = _card_db.call("get_card", card_id)
		_expect(card != null, "missing central card: %s" % card_id)
		if card == null:
			continue
		_expect(not card.title.is_empty(), "central card has empty title: %s" % card_id)
		_expect(not card.description.is_empty(), "central card has empty description: %s" % card_id)
		_expect(not card.classic_quote.is_empty(), "central card has empty classic quote: %s" % card_id)
		_expect(not card.translation.is_empty(), "central card has empty translation: %s" % card_id)
		_expect(not card.alive_today.is_empty(), "central card has empty alive_today: %s" % card_id)
		_expect(not card.effects.is_empty(), "central card has no effects: %s" % card_id)


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


func _check_north_enemies() -> void:
	if _enemy_db == null or _card_db == null:
		return
	for enemy_id in NORTH_ENEMIES:
		var enemy = _enemy_db.call("get_enemy", enemy_id)
		_expect(enemy != null, "missing north enemy: %s" % enemy_id)
		if enemy == null:
			continue
		_expect(enemy.max_hp > 0, "north enemy has invalid hp: %s" % enemy_id)
		_expect(not enemy.display_name.is_empty(), "north enemy has empty display name: %s" % enemy_id)
		_expect(not enemy.intent_pattern.is_empty(), "north enemy has empty intent pattern: %s" % enemy_id)
		_expect(not enemy.classic_quote.is_empty(), "north enemy has empty classic quote: %s" % enemy_id)
		_expect(not enemy.translation.is_empty(), "north enemy has empty translation: %s" % enemy_id)
		_expect(not enemy.awaken_options.is_empty(), "north enemy has empty awaken options: %s" % enemy_id)
		_expect(not enemy.awaken_card_id.is_empty(), "north enemy has empty awaken card: %s" % enemy_id)
		_expect(bool(_card_db.call("has_card", enemy.awaken_card_id)), "north enemy awaken card missing: %s -> %s" % [enemy_id, enemy.awaken_card_id])


func _check_east_enemies() -> void:
	if _enemy_db == null or _card_db == null:
		return
	for enemy_id in EAST_ENEMIES:
		var enemy = _enemy_db.call("get_enemy", enemy_id)
		_expect(enemy != null, "missing east enemy: %s" % enemy_id)
		if enemy == null:
			continue
		_expect(enemy.max_hp > 0, "east enemy has invalid hp: %s" % enemy_id)
		_expect(not enemy.display_name.is_empty(), "east enemy has empty display name: %s" % enemy_id)
		_expect(not enemy.intent_pattern.is_empty(), "east enemy has empty intent pattern: %s" % enemy_id)
		_expect(not enemy.classic_quote.is_empty(), "east enemy has empty classic quote: %s" % enemy_id)
		_expect(not enemy.translation.is_empty(), "east enemy has empty translation: %s" % enemy_id)
		_expect(not enemy.awaken_options.is_empty(), "east enemy has empty awaken options: %s" % enemy_id)
		_expect(not enemy.awaken_card_id.is_empty(), "east enemy has empty awaken card: %s" % enemy_id)
		_expect(bool(_card_db.call("has_card", enemy.awaken_card_id)), "east enemy awaken card missing: %s -> %s" % [enemy_id, enemy.awaken_card_id])
	var weak = _enemy_db.call("get_enemy", "boss_qinglong_weak")
	var mid = _enemy_db.call("get_enemy", "boss_qinglong")
	var strong = _enemy_db.call("get_enemy", "boss_qinglong_strong")
	if weak != null and mid != null and strong != null:
		_expect(int(weak.max_hp) < int(mid.max_hp) and int(mid.max_hp) < int(strong.max_hp), "qinglong boss hp should scale weak < mid < strong")
		_expect(int(strong.max_hp) <= 270, "qinglong strong hp should stay inside v0.7 cap")
	var zweak = _enemy_db.call("get_enemy", "boss_zhulong_weak")
	var zmid = _enemy_db.call("get_enemy", "boss_zhulong")
	var zstrong = _enemy_db.call("get_enemy", "boss_zhulong_strong")
	if zweak != null and zmid != null and zstrong != null:
		_expect(int(zweak.max_hp) < int(zmid.max_hp) and int(zmid.max_hp) < int(zstrong.max_hp), "zhulong boss hp should scale weak < mid < strong")


func _check_central_enemies() -> void:
	if _enemy_db == null or _card_db == null:
		return
	for enemy_id in CENTRAL_ENEMIES:
		var enemy = _enemy_db.call("get_enemy", enemy_id)
		_expect(enemy != null, "missing central enemy: %s" % enemy_id)
		if enemy == null:
			continue
		_expect(enemy.max_hp > 0, "central enemy has invalid hp: %s" % enemy_id)
		_expect(not enemy.display_name.is_empty(), "central enemy has empty display name: %s" % enemy_id)
		_expect(not enemy.intent_pattern.is_empty(), "central enemy has empty intent pattern: %s" % enemy_id)
		_expect(not enemy.classic_quote.is_empty(), "central enemy has empty classic quote: %s" % enemy_id)
		_expect(not enemy.translation.is_empty(), "central enemy has empty translation: %s" % enemy_id)
		_expect(not enemy.awaken_options.is_empty(), "central enemy has empty awaken options: %s" % enemy_id)
		_expect(not enemy.awaken_card_id.is_empty(), "central enemy has empty awaken card: %s" % enemy_id)
		_expect(bool(_card_db.call("has_card", enemy.awaken_card_id)), "central enemy awaken card missing: %s -> %s" % [enemy_id, enemy.awaken_card_id])
	var weak = _enemy_db.call("get_enemy", "boss_qilin_weak")
	var mid = _enemy_db.call("get_enemy", "boss_qilin")
	var strong = _enemy_db.call("get_enemy", "boss_qilin_strong")
	if weak != null and mid != null and strong != null:
		_expect(int(weak.max_hp) < int(mid.max_hp) and int(mid.max_hp) < int(strong.max_hp), "qilin boss hp should scale weak < mid < strong")


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


func _check_north_events() -> void:
	if _run_state == null:
		return
	var event_db = load("res://scripts/map/event_database.gd")
	var events: Array = event_db.load_all()
	var north_count: int = 0
	var global_count: int = 0
	for ev in events:
		if not (ev is Dictionary):
			continue
		var ch: int = int(ev.get("chapter", 0))
		if ch == int(_run_state.CHAPTER_NORTH):
			north_count += 1
		elif ch == -1:
			global_count += 1
		else:
			continue
		_expect(not str(ev.get("id", "")).is_empty(), "north/global event has empty id")
		_expect(not str(ev.get("name", "")).is_empty(), "north/global event has empty name")
		_expect(not str(ev.get("story", "")).is_empty(), "north/global event has empty story")
		var options: Array = Array(ev.get("options", []))
		_expect(not options.is_empty(), "north/global event has no options: %s" % str(ev.get("id", "")))
		for opt in options:
			if opt is Dictionary:
				_check_reward_reference(opt, "event.%s" % str(ev.get("id", "")))
				_expect(not str(opt.get("preview", "")).is_empty(), "north/global event option has empty preview: %s" % str(ev.get("id", "")))
				_expect(not str(opt.get("result", "")).is_empty(), "north/global event option has empty result: %s" % str(ev.get("id", "")))
	_expect(north_count == 8, "chapter north should have exactly 8 events")
	_expect(global_count == 4, "v0.7 should keep exactly 4 global events")


func _check_east_events() -> void:
	if _run_state == null:
		return
	var event_db = load("res://scripts/map/event_database.gd")
	var events: Array = event_db.load_all()
	var east_count: int = 0
	for ev in events:
		if not (ev is Dictionary):
			continue
		if int(ev.get("chapter", 0)) != int(_run_state.CHAPTER_EAST):
			continue
		east_count += 1
		_expect(not str(ev.get("id", "")).is_empty(), "east event has empty id")
		_expect(not str(ev.get("name", "")).is_empty(), "east event has empty name")
		_expect(not str(ev.get("story", "")).is_empty(), "east event has empty story")
		var options: Array = Array(ev.get("options", []))
		_expect(not options.is_empty(), "east event has no options: %s" % str(ev.get("id", "")))
		for opt in options:
			if opt is Dictionary:
				_check_reward_reference(opt, "event.%s" % str(ev.get("id", "")))
				_expect(not str(opt.get("preview", "")).is_empty(), "east event option has empty preview: %s" % str(ev.get("id", "")))
				_expect(not str(opt.get("result", "")).is_empty(), "east event option has empty result: %s" % str(ev.get("id", "")))
	_expect(east_count == 8, "chapter east should have exactly 8 events")


func _check_central_events() -> void:
	if _run_state == null:
		return
	var event_db = load("res://scripts/map/event_database.gd")
	var events: Array = event_db.load_all()
	var central_count: int = 0
	for ev in events:
		if not (ev is Dictionary):
			continue
		if int(ev.get("chapter", 0)) != int(_run_state.CHAPTER_CENTRAL):
			continue
		central_count += 1
		_expect(not str(ev.get("id", "")).is_empty(), "central event has empty id")
		_expect(not str(ev.get("name", "")).is_empty(), "central event has empty name")
		_expect(not str(ev.get("story", "")).is_empty(), "central event has empty story")
		var options: Array = Array(ev.get("options", []))
		_expect(not options.is_empty(), "central event has no options: %s" % str(ev.get("id", "")))
		for opt in options:
			if opt is Dictionary:
				_check_reward_reference(opt, "event.%s" % str(ev.get("id", "")))
				_expect(not str(opt.get("preview", "")).is_empty(), "central event option has empty preview: %s" % str(ev.get("id", "")))
				_expect(not str(opt.get("result", "")).is_empty(), "central event option has empty result: %s" % str(ev.get("id", "")))
	_expect(central_count == 8, "chapter central should have exactly 8 events")


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


func _check_north_visual_assets() -> void:
	var specs: Array[Dictionary] = [
		{"id": "he_luo_fish", "top_key": "enemy.he_luo_fish", "iso_key": "he_luo_fish", "top": "res://assets/textures/top/entities/he_luo_fish.png", "iso": "res://assets/textures/iso/enemies/he_luo_fish_walk.png"},
		{"id": "fei_yi", "top_key": "enemy.fei_yi", "iso_key": "fei_yi", "top": "res://assets/textures/top/entities/fei_yi.png", "iso": "res://assets/textures/iso/enemies/fei_yi_walk.png"},
		{"id": "zhuhuai", "top_key": "enemy.zhuhuai", "iso_key": "zhuhuai", "top": "res://assets/textures/top/entities/zhuhuai.png", "iso": "res://assets/textures/iso/enemies/zhuhuai_walk.png"},
		{"id": "xiao_beast", "top_key": "enemy.xiao_beast", "iso_key": "xiao_beast", "top": "res://assets/textures/top/entities/xiao_beast.png", "iso": "res://assets/textures/iso/enemies/xiao_beast_walk.png"},
		{"id": "elite_xiangliu_shadow", "top_key": "elite_xiangliu_shadow", "iso_key": "elite_xiangliu_shadow", "top": "res://assets/textures/top/entities/elite_xiangliu_shadow.png", "iso": "res://assets/textures/iso/entities/elite_xiangliu_shadow_walk.png"},
		{"id": "boss_zhulong_weak", "top_key": "boss_zhulong_weak", "iso_key": "boss_zhulong_weak", "top": "res://assets/textures/top/entities/boss_zhulong_weak.png", "iso": "res://assets/textures/iso/entities/boss_zhulong_weak_walk.png"},
		{"id": "boss_zhulong", "top_key": "boss_zhulong", "iso_key": "boss_zhulong", "top": "res://assets/textures/top/entities/boss_zhulong.png", "iso": "res://assets/textures/iso/entities/boss_zhulong_walk.png"},
		{"id": "boss_zhulong_strong", "top_key": "boss_zhulong_strong", "iso_key": "boss_zhulong_strong", "top": "res://assets/textures/top/entities/boss_zhulong_strong.png", "iso": "res://assets/textures/iso/entities/boss_zhulong_strong_walk.png"},
	]
	for spec in specs:
		_check_png_size(str(spec["top"]), 192, 192, "%s top sprite" % str(spec["id"]))
		_check_png_size(str(spec["iso"]), 512, 512, "%s iso sprite" % str(spec["id"]))
		_expect(PixelSprites.texture(str(spec["top_key"]), PixelSprites.DIR_DOWN, 0) != null, "%s top sprite key should resolve" % str(spec["id"]))
		_expect(PixelSprites.iso_enemy_texture(str(spec["iso_key"]), PixelSprites.DIR_DOWN, 0) != null, "%s iso sprite key should resolve" % str(spec["id"]))


func _check_east_visual_assets() -> void:
	var specs: Array[Dictionary] = [
		{"id": "dang_kang", "top_key": "enemy.dang_kang", "iso_key": "dang_kang", "top": "res://assets/textures/top/entities/dang_kang.png", "iso": "res://assets/textures/iso/enemies/dang_kang_walk.png"},
		{"id": "qiu_yu", "top_key": "enemy.qiu_yu", "iso_key": "qiu_yu", "top": "res://assets/textures/top/entities/qiu_yu.png", "iso": "res://assets/textures/iso/enemies/qiu_yu_walk.png"},
		{"id": "ling_ling", "top_key": "enemy.ling_ling", "iso_key": "ling_ling", "top": "res://assets/textures/top/entities/ling_ling.png", "iso": "res://assets/textures/iso/enemies/ling_ling_walk.png"},
		{"id": "zhu_ru", "top_key": "enemy.zhu_ru", "iso_key": "zhu_ru", "top": "res://assets/textures/top/entities/zhu_ru.png", "iso": "res://assets/textures/iso/enemies/zhu_ru_walk.png"},
		{"id": "elite_yinglong_young", "top_key": "elite_yinglong_young", "iso_key": "elite_yinglong_young", "top": "res://assets/textures/top/entities/elite_yinglong_young.png", "iso": "res://assets/textures/iso/entities/elite_yinglong_young_walk.png"},
		{"id": "boss_qinglong_weak", "top_key": "boss_qinglong_weak", "iso_key": "boss_qinglong_weak", "top": "res://assets/textures/top/entities/boss_qinglong_weak.png", "iso": "res://assets/textures/iso/entities/boss_qinglong_weak_walk.png"},
		{"id": "boss_qinglong", "top_key": "boss_qinglong", "iso_key": "boss_qinglong", "top": "res://assets/textures/top/entities/boss_qinglong.png", "iso": "res://assets/textures/iso/entities/boss_qinglong_walk.png"},
		{"id": "boss_qinglong_strong", "top_key": "boss_qinglong_strong", "iso_key": "boss_qinglong_strong", "top": "res://assets/textures/top/entities/boss_qinglong_strong.png", "iso": "res://assets/textures/iso/entities/boss_qinglong_strong_walk.png"},
	]
	for spec in specs:
		_check_png_size(str(spec["top"]), 192, 192, "%s top sprite" % str(spec["id"]))
		_check_png_size(str(spec["iso"]), 512, 512, "%s iso sprite" % str(spec["id"]))
		_expect(PixelSprites.texture(str(spec["top_key"]), PixelSprites.DIR_DOWN, 0) != null, "%s top sprite key should resolve" % str(spec["id"]))
		_expect(PixelSprites.iso_enemy_texture(str(spec["iso_key"]), PixelSprites.DIR_DOWN, 0) != null, "%s iso sprite key should resolve" % str(spec["id"]))


func _check_central_visual_assets() -> void:
	var specs: Array[Dictionary] = [
		{"id": "kui", "top_key": "enemy.kui", "iso_key": "kui", "top": "res://assets/textures/top/entities/kui.png", "iso": "res://assets/textures/iso/enemies/kui_walk.png"},
		{"id": "tu_lou", "top_key": "enemy.tu_lou", "iso_key": "tu_lou", "top": "res://assets/textures/top/entities/tu_lou.png", "iso": "res://assets/textures/iso/enemies/tu_lou_walk.png"},
		{"id": "jiao_beast", "top_key": "enemy.jiao_beast", "iso_key": "jiao_beast", "top": "res://assets/textures/top/entities/jiao_beast.png", "iso": "res://assets/textures/iso/enemies/jiao_beast_walk.png"},
		{"id": "wen_lin", "top_key": "enemy.wen_lin", "iso_key": "wen_lin", "top": "res://assets/textures/top/entities/wen_lin.png", "iso": "res://assets/textures/iso/enemies/wen_lin_walk.png"},
		{"id": "elite_ji_meng", "top_key": "elite_ji_meng", "iso_key": "elite_ji_meng", "top": "res://assets/textures/top/entities/elite_ji_meng.png", "iso": "res://assets/textures/iso/entities/elite_ji_meng_walk.png"},
		{"id": "boss_qilin_weak", "top_key": "boss_qilin_weak", "iso_key": "boss_qilin_weak", "top": "res://assets/textures/top/entities/boss_qilin_weak.png", "iso": "res://assets/textures/iso/entities/boss_qilin_weak_walk.png"},
		{"id": "boss_qilin", "top_key": "boss_qilin", "iso_key": "boss_qilin", "top": "res://assets/textures/top/entities/boss_qilin.png", "iso": "res://assets/textures/iso/entities/boss_qilin_walk.png"},
		{"id": "boss_qilin_strong", "top_key": "boss_qilin_strong", "iso_key": "boss_qilin_strong", "top": "res://assets/textures/top/entities/boss_qilin_strong.png", "iso": "res://assets/textures/iso/entities/boss_qilin_strong_walk.png"},
	]
	for spec in specs:
		_check_png_size(str(spec["top"]), 192, 192, "%s top sprite" % str(spec["id"]))
		_check_png_size(str(spec["iso"]), 512, 512, "%s iso sprite" % str(spec["id"]))
		_expect(PixelSprites.texture(str(spec["top_key"]), PixelSprites.DIR_DOWN, 0) != null, "%s top sprite key should resolve" % str(spec["id"]))
		_expect(PixelSprites.iso_enemy_texture(str(spec["iso_key"]), PixelSprites.DIR_DOWN, 0) != null, "%s iso sprite key should resolve" % str(spec["id"]))


func _check_png_size(path: String, width: int, height: int, label: String) -> void:
	_expect(ResourceLoader.exists(path), "%s missing imported texture: %s" % [label, path])
	var texture := ResourceLoader.load(path, "Texture2D") if ResourceLoader.exists(path) else null
	_expect(texture is Texture2D, "%s should load as Texture2D: %s" % [label, path])
	if texture is Texture2D:
		_expect(texture.get_width() == width and texture.get_height() == height, "%s should be %dx%d, got %dx%d" % [label, width, height, texture.get_width(), texture.get_height()])


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
	var raw_map_data: Variant = map.get("data")
	var map_data: Dictionary = raw_map_data if raw_map_data is Dictionary else {}
	if map_data.is_empty():
		var generated: Variant = map.call("_generate_map")
		map_data = generated if generated is Dictionary else {}
	_expect(int(map_data.get("chapter_index", -1)) == int(_run_state.CHAPTER_WEST), "west map should be chapter west")
	_expect(str(map_data.get("top_floor_tileset", "")) == "dirt", "west top floor should use dirt")
	_expect(str(map_data.get("iso_floor_tileset", "")) == "forest", "west iso floor should use forest tilesheet")
	_expect(int(map_data.get("iso_floor_row", -1)) == 1, "west iso floor should use dirt row")
	_check_map_entities(map_data)
	await _check_event_choice_result(map, map_data)
	await _check_treasure_open(map, map_data)
	await _check_rest_use(map, map_data)
	var shop_entity: Dictionary = {}
	var live_data_raw: Variant = map.get("data")
	var live_data: Dictionary = live_data_raw if live_data_raw is Dictionary else {}
	for entity in Array(live_data.get("entities", [])):
		if entity is Dictionary and str(entity.get("kind", "")) == "shop":
			shop_entity = entity
			break
	_expect(not shop_entity.is_empty(), "west map should generate shop")
	if not shop_entity.is_empty():
		map.call("_enter_shop", shop_entity)
		await process_frame
		_check_shop_copy(map, shop_entity)
		_check_shop_items(Array(map.get("_shop_items")))
	_check_battle_confirm_reward_preview(map)
	_check_boss_reward(map)
	map.queue_free()


func _check_north_map_scene() -> void:
	if _run_state == null or _game_state == null:
		return
	_run_state.call("reset_for_new_run")
	_run_state.current_chapter_index = _run_state.CHAPTER_NORTH
	_run_state.current_floor = _run_state.CHAPTER_NORTH
	_run_state.seed_value = 60607
	_game_state.fragments = 999
	var packed: PackedScene = load("res://scenes/map/map.tscn")
	_expect(packed != null, "missing map scene")
	if packed == null:
		return
	var map = packed.instantiate()
	root.add_child(map)
	await process_frame
	var raw_map_data: Variant = map.get("data")
	var map_data: Dictionary = raw_map_data if raw_map_data is Dictionary else {}
	if map_data.is_empty():
		var generated: Variant = map.call("_generate_map")
		map_data = generated if generated is Dictionary else {}
	_expect(int(map_data.get("chapter_index", -1)) == int(_run_state.CHAPTER_NORTH), "north map should be chapter north")
	_expect(str(map_data.get("title", "")).find("北山") >= 0, "north map should use north title")
	_expect(str(map_data.get("top_floor_tileset", "")) == "stone_floor", "north top floor should use recolored stone floor")
	_expect(str(map_data.get("iso_floor_tileset", "")) == "dungeon", "north iso floor should use dungeon tilesheet")
	_expect(int(map_data.get("iso_floor_row", -1)) == 0, "north iso floor should use first dungeon row")
	_expect(int(map_data.get("iso_floor_col_offset", -1)) == 2, "north iso floor should use brown dirt block column")
	_expect(str(map_data.get("iso_wall_tileset", "")) == "dungeon", "north iso wall should use dungeon tilesheet")
	_expect(int(map_data.get("iso_wall_col", -1)) == 1, "north iso wall should use grey stone block column")
	_check_map_entities(map_data, NORTH_ENEMIES, "north")
	_check_north_map_sprite_keys(map_data)
	var kinds: Dictionary = {}
	for entity in Array(map_data.get("entities", [])):
		if entity is Dictionary:
			kinds[str(entity.get("kind", ""))] = true
	_expect(kinds.has("elite"), "north map should generate elite")
	_expect(kinds.has("shop"), "north map should generate shop")
	_expect(kinds.has("rest"), "north map should generate rest")
	_expect(kinds.has("treasure"), "north map should generate treasure")
	_expect(kinds.has("event"), "north map should generate event")
	var shop_entity: Dictionary = {}
	var live_data_raw: Variant = map.get("data")
	var live_data: Dictionary = live_data_raw if live_data_raw is Dictionary else {}
	for entity in Array(live_data.get("entities", [])):
		if entity is Dictionary and str(entity.get("kind", "")) == "shop":
			shop_entity = entity
			break
	_expect(not shop_entity.is_empty(), "north map should generate shop")
	if not shop_entity.is_empty():
		map.call("_enter_shop", shop_entity)
		await process_frame
		var north_shop_cards: Array[String] = [
			"hai.heluo_ally",
			"hai.beishan_mist", "shan.xuanwu_barrier", "hai.cold_current",
			"huang.memory_venom", "shan.black_ridge_guard", "hai.deep_pool_reflection",
			"neutral.archive_index", "neutral.echo_rehearse",
		]
		_check_shop_items(Array(map.get("_shop_items")), north_shop_cards, "north")
		_check_shop_contains_card(
			Array(map.get("_shop_items")),
			"hai.heluo_ally",
			"north shop should expose one summon ally card",
			"同伴召唤"
		)
	_check_battle_confirm_reward_preview(map, "烛龙残照", "+13")
	_check_boss_reward(map, "hai.zhulong_ally", "东山")
	map.queue_free()


func _check_east_map_scene() -> void:
	if _run_state == null or _game_state == null:
		return
	_run_state.call("reset_for_new_run")
	_run_state.current_chapter_index = _run_state.CHAPTER_EAST
	_run_state.current_floor = _run_state.CHAPTER_EAST
	_run_state.seed_value = 60700
	_game_state.fragments = 999
	var packed: PackedScene = load("res://scenes/map/map.tscn")
	_expect(packed != null, "missing map scene")
	if packed == null:
		return
	var map = packed.instantiate()
	root.add_child(map)
	await process_frame
	var raw_map_data: Variant = map.get("data")
	var map_data: Dictionary = raw_map_data if raw_map_data is Dictionary else {}
	if map_data.is_empty():
		var generated: Variant = map.call("_generate_map")
		map_data = generated if generated is Dictionary else {}
	_expect(int(map_data.get("chapter_index", -1)) == int(_run_state.CHAPTER_EAST), "east map should be chapter east")
	_expect(str(map_data.get("title", "")).find("东山") >= 0, "east map should use east title")
	_expect(str(map_data.get("top_floor_tileset", "")) == "east_meadow", "east top floor should use distinct east meadow tiles")
	_expect(str(map_data.get("iso_floor_tileset", "")) == "east_meadow", "east iso floor should use distinct east meadow fallback")
	_expect(str(map_data.get("iso_wall_tileset", "")) == "east_bamboo", "east iso walls should use distinct bamboo fallback")
	_check_map_entities(map_data, EAST_ENEMIES, "east")
	_check_east_map_sprite_keys(map_data)
	var shop_entity: Dictionary = {}
	var live_data_raw: Variant = map.get("data")
	var live_data: Dictionary = live_data_raw if live_data_raw is Dictionary else {}
	for entity in Array(live_data.get("entities", [])):
		if entity is Dictionary and str(entity.get("kind", "")) == "shop":
			shop_entity = entity
			break
	_expect(not shop_entity.is_empty(), "east map should generate shop")
	if not shop_entity.is_empty():
		map.call("_enter_shop", shop_entity)
		await process_frame
		var east_shop_cards: Array[String] = [
			"shan.dangkang_harvest", "shan.green_sprout_guard", "shan.spring_root",
			"hai.yinglong_rainpath", "hai.qiuyu_sleep", "hai.qinglong_ally",
			"huang.lingling_floodcall", "huang.zhuru_fright",
			"neutral.seed_catalog", "neutral.field_rehearsal",
		]
		_check_shop_items(Array(map.get("_shop_items")), east_shop_cards, "east")
	_check_battle_confirm_reward_preview(map, "青龙行雨", "+16")
	_check_boss_reward(map, "hai.qinglong_ally", "中山")
	map.queue_free()


func _check_central_map_scene() -> void:
	if _run_state == null or _game_state == null:
		return
	_run_state.call("reset_for_new_run")
	_run_state.current_chapter_index = _run_state.CHAPTER_CENTRAL
	_run_state.current_floor = _run_state.CHAPTER_CENTRAL
	_run_state.seed_value = 60800
	_game_state.fragments = 999
	var packed: PackedScene = load("res://scenes/map/map.tscn")
	_expect(packed != null, "missing map scene")
	if packed == null:
		return
	var map = packed.instantiate()
	root.add_child(map)
	await process_frame
	var raw_map_data: Variant = map.get("data")
	var map_data: Dictionary = raw_map_data if raw_map_data is Dictionary else {}
	if map_data.is_empty():
		var generated: Variant = map.call("_generate_map")
		map_data = generated if generated is Dictionary else {}
	_expect(int(map_data.get("chapter_index", -1)) == int(_run_state.CHAPTER_CENTRAL), "central map should be chapter central")
	_expect(str(map_data.get("title", "")).find("中山") >= 0, "central map should use central title")
	_expect(str(map_data.get("top_floor_tileset", "")) == "central_altar", "central top floor should use altar fallback")
	_expect(str(map_data.get("iso_floor_tileset", "")) == "central_altar", "central iso floor should use altar fallback")
	_expect(str(map_data.get("iso_wall_tileset", "")) == "central_altar", "central iso walls should use altar fallback")
	_check_map_entities(map_data, CENTRAL_ENEMIES, "central")
	_check_central_map_sprite_keys(map_data)
	var shop_entity: Dictionary = {}
	var live_data_raw: Variant = map.get("data")
	var live_data: Dictionary = live_data_raw if live_data_raw is Dictionary else {}
	for entity in Array(live_data.get("entities", [])):
		if entity is Dictionary and str(entity.get("kind", "")) == "shop":
			shop_entity = entity
			break
	_expect(not shop_entity.is_empty(), "central map should generate shop")
	if not shop_entity.is_empty():
		map.call("_enter_shop", shop_entity)
		await process_frame
		_check_shop_items(Array(map.get("_shop_items")), CENTRAL_CARDS, "central")
	_check_battle_confirm_reward_preview(map, "", "+19")
	_check_boss_reward(map, "neutral.five_realm_harmony", "忘川之心")
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
	var expected_chapters: Array = [
		_run_state.CHAPTER_WEST,
		_run_state.CHAPTER_NORTH,
		_run_state.CHAPTER_EAST,
		_run_state.CHAPTER_CENTRAL,
	]
	var expected_names: Array[String] = ["西山", "北山", "东山", "中山"]
	for i in expected_chapters.size():
		_run_state.bosses_defeated = int(_run_state.BOSSES_TO_CLEAR)
		map.call("_show_boss_victory", "boss_hard", "debug boss")
		var victory_text = map.get("_victory_text")
		var victory_btn = map.get("_victory_btn")
		_expect(bool(map.get("_pending_chapter_advance")), "%s clear should request next chapter" % expected_names[i])
		if victory_text != null:
			_expect(str(victory_text.text).find(expected_names[i]) >= 0, "chapter clear text should mention %s" % expected_names[i])
		if victory_btn != null:
			_expect(str(victory_btn.text).find(expected_names[i]) >= 0, "chapter clear button should enter %s" % expected_names[i])
		map.call("_on_victory_close")
		await process_frame
		_expect(int(_run_state.current_chapter_index) == int(expected_chapters[i]), "victory continue should advance to %s" % expected_names[i])
		_expect(int(_run_state.bosses_defeated) == 0, "chapter advance should clear chapter boss count")
		_expect(int(_run_state.hp) == int(_run_state.max_hp), "chapter advance from victory should fully heal")
	_run_state.bosses_defeated = int(_run_state.BOSSES_TO_CLEAR)
	map.call("_show_boss_victory", "boss_hard", "debug boss")
	var final_text = map.get("_victory_text")
	var final_btn = map.get("_victory_btn")
	_expect(not bool(map.get("_pending_chapter_advance")), "central clear should not request another chapter")
	if final_text != null:
		_expect(str(final_text.text).find("忘川之心") >= 0, "central clear should point to Wangchuan finale")
		_expect(str(final_text.text).find("本局结算") >= 0, "central clear should show run settlement summary")
		_expect(str(final_text.text).find("图鉴解锁") >= 0, "central clear summary should include codex completion")
		_expect(str(final_text.text).find("牌组") >= 0, "central clear summary should include deck count")
	if final_btn != null:
		_expect(str(final_btn.text).find("忘川之心") >= 0, "central clear button should enter Wangchuan finale")
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
	_run_state.current_chapter_index = _run_state.CHAPTER_NORTH
	var north_enemy: Dictionary = map.call("_grant_non_boss_battle_reward", "enemy", 2)
	_expect(int(north_enemy.get("fragments", 0)) == 13, "north two-enemy pack should grant 13 fragments")
	_expect(int(north_enemy.get("exp", 0)) == 14, "north two-enemy pack should grant 14 exp")
	var north_elite: Dictionary = map.call("_grant_non_boss_battle_reward", "elite", 1)
	_expect(int(north_elite.get("fragments", 0)) == 42, "north elite should grant 42 fragments")
	_expect(int(north_elite.get("exp", 0)) == 32, "north elite should grant 32 exp")
	_run_state.current_chapter_index = _run_state.CHAPTER_EAST
	var east_enemy: Dictionary = map.call("_grant_non_boss_battle_reward", "enemy", 2)
	_expect(int(east_enemy.get("fragments", 0)) == 16, "east two-enemy pack should grant 16 fragments")
	_expect(int(east_enemy.get("exp", 0)) == 16, "east two-enemy pack should grant 16 exp")
	var east_elite: Dictionary = map.call("_grant_non_boss_battle_reward", "elite", 1)
	_expect(int(east_elite.get("fragments", 0)) == 54, "east elite should grant 54 fragments")
	_expect(int(east_elite.get("exp", 0)) == 42, "east elite should grant 42 exp")
	_run_state.current_chapter_index = _run_state.CHAPTER_CENTRAL
	var central_enemy: Dictionary = map.call("_grant_non_boss_battle_reward", "enemy", 2)
	_expect(int(central_enemy.get("fragments", 0)) == 19, "central two-enemy pack should grant 19 fragments")
	_expect(int(central_enemy.get("exp", 0)) == 19, "central two-enemy pack should grant 19 exp")
	var central_elite: Dictionary = map.call("_grant_non_boss_battle_reward", "elite", 1)
	_expect(int(central_elite.get("fragments", 0)) == 66, "central elite should grant 66 fragments")
	_expect(int(central_elite.get("exp", 0)) == 52, "central elite should grant 52 exp")
	_run_state.current_chapter_index = _run_state.CHAPTER_WEST
	map.call("_show_non_boss_battle_result", "enemy", "狰", west_enemy)
	var title_label = map.get("_event_title")
	var body_label = map.get("_event_body")
	_expect(title_label != null, "non-boss battle result title should exist")
	_expect(body_label != null, "non-boss battle result body should exist")
	if title_label != null:
		_expect(str(title_label.text) == "战斗收益", "normal battle result should use reward title")
	if body_label != null:
		_expect(str(body_label.text).find("本次变化") >= 0, "normal battle result should summarize actual reward")
		_expect(str(body_label.text).find("狰") >= 0, "normal battle result should keep enemy name")
	map.call("_show_non_boss_battle_result", "elite", "英招", west_elite)
	if title_label != null:
		_expect(str(title_label.text) == "精英战收益", "elite battle result should use reward title")
	if body_label != null:
		_expect(str(body_label.text).find("本次变化") >= 0, "elite battle result should summarize actual reward")
	map.queue_free()


func _check_map_entities(map_data: Dictionary, allowed_boss_enemies: Array[String] = WEST_ENEMIES, label: String = "west") -> void:
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
			_expect(allowed_boss_enemies.has(boss_enemy), "%s boss references unexpected enemy: %s" % [label, boss_enemy])
		elif kind == "enemy":
			enemy_count += 1
			var enemies: Array = Array(entity.get("enemies", []))
			_expect(not enemies.is_empty(), "%s map enemy entity has empty enemies" % label)
			var sprite_key: String = str(entity.get("sprite_key", ""))
			_expect(sprite_key.begins_with("enemy."), "%s top enemy sprite_key should use enemy.<id>: %s" % [label, sprite_key])
		elif kind == "event":
			event_count += 1
	_expect(boss_count == 3, "%s map should generate exactly 3 bosses" % label)
	_expect(enemy_count >= 30, "%s map should generate enough normal enemies" % label)
	_expect(event_count >= 4, "%s map should generate at least 4 events" % label)


func _check_north_map_sprite_keys(map_data: Dictionary) -> void:
	var expected: Dictionary = {
		"he_luo_fish": "enemy.he_luo_fish",
		"fei_yi": "enemy.fei_yi",
		"zhuhuai": "enemy.zhuhuai",
		"xiao_beast": "enemy.xiao_beast",
		"elite_xiangliu_shadow": "elite_xiangliu_shadow",
		"boss_zhulong_weak": "boss_zhulong_weak",
		"boss_zhulong": "boss_zhulong",
		"boss_zhulong_strong": "boss_zhulong_strong",
	}
	for entity in Array(map_data.get("entities", [])):
		if not (entity is Dictionary):
			continue
		var enemy_id: String = str(entity.get("enemy_id", ""))
		if enemy_id.is_empty():
			var enemies: Array = Array(entity.get("enemies", []))
			if not enemies.is_empty():
				enemy_id = str(enemies[0])
		if not expected.has(enemy_id):
			continue
		_expect(str(entity.get("sprite_key", "")) == str(expected[enemy_id]), "north %s should use dedicated sprite key %s" % [enemy_id, str(expected[enemy_id])])


func _check_east_map_sprite_keys(map_data: Dictionary) -> void:
	var expected: Dictionary = {
		"dang_kang": "enemy.dang_kang",
		"qiu_yu": "enemy.qiu_yu",
		"ling_ling": "enemy.ling_ling",
		"zhu_ru": "enemy.zhu_ru",
		"elite_yinglong_young": "elite_yinglong_young",
		"boss_qinglong_weak": "boss_qinglong_weak",
		"boss_qinglong": "boss_qinglong",
		"boss_qinglong_strong": "boss_qinglong_strong",
	}
	for entity in Array(map_data.get("entities", [])):
		if not (entity is Dictionary):
			continue
		var enemy_id: String = str(entity.get("enemy_id", ""))
		if enemy_id.is_empty():
			var enemies: Array = Array(entity.get("enemies", []))
			if not enemies.is_empty():
				enemy_id = str(enemies[0])
		if not expected.has(enemy_id):
			continue
		_expect(str(entity.get("sprite_key", "")) == str(expected[enemy_id]), "east %s should use dedicated sprite key %s" % [enemy_id, str(expected[enemy_id])])


func _check_central_map_sprite_keys(map_data: Dictionary) -> void:
	var expected: Dictionary = {
		"kui": "enemy.kui",
		"tu_lou": "enemy.tu_lou",
		"jiao_beast": "enemy.jiao_beast",
		"wen_lin": "enemy.wen_lin",
		"elite_ji_meng": "elite_ji_meng",
		"boss_qilin_weak": "boss_qilin_weak",
		"boss_qilin": "boss_qilin",
		"boss_qilin_strong": "boss_qilin_strong",
	}
	for entity in Array(map_data.get("entities", [])):
		if not (entity is Dictionary):
			continue
		var enemy_id: String = str(entity.get("enemy_id", ""))
		if enemy_id.is_empty():
			var enemies: Array = Array(entity.get("enemies", []))
			if not enemies.is_empty():
				enemy_id = str(enemies[0])
		if not expected.has(enemy_id):
			continue
		_expect(str(entity.get("sprite_key", "")) == str(expected[enemy_id]), "central %s should use dedicated sprite key %s" % [enemy_id, str(expected[enemy_id])])


func _check_shop_items(items: Array, guaranteed_cards: Array[String] = WEST_CARDS, label: String = "west") -> void:
	if _card_db == null:
		return
	var card_count: int = 0
	var chapter_card_count: int = 0
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
		if guaranteed_cards.has(card_id):
			chapter_card_count += 1
	_expect(card_count == 3, "shop should offer exactly 3 cards")
	_expect(chapter_card_count >= 1, "%s shop should guarantee at least 1 chapter card" % label)


func _check_shop_contains_card(items: Array, card_id: String, message: String, label_text: String = "") -> void:
	var found: bool = false
	for item in items:
		if item is Dictionary and str(item.get("type", "")) == "card" and str(item.get("card", "")) == card_id:
			found = true
			if not label_text.is_empty():
				_expect(str(item.get("label", "")).find(label_text) >= 0, "%s label should include %s" % [card_id, label_text])
			break
	_expect(found, message)


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
		_expect(str(body_label.text).find("本次变化") >= 0, "west rest panel should summarize actual heal")


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
	var first_option: Dictionary = options[0]
	map.call("_on_event_choice", first_option)
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


func _check_shop_copy(map, shop_entity: Dictionary) -> void:
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
		var before_fragments: int = int(_game_state.fragments)
		map.call("_on_shop_buy", buy_index)
		if body_label != null:
			_expect(str(body_label.text).find("本次变化") >= 0, "shop purchase should summarize actual change")
		_expect(bool(items[buy_index].get("sold", false)), "shop purchase should mark item sold")
		map.call("_enter_shop", shop_entity)
		var reopened_items: Array = Array(map.get("_shop_items"))
		_expect(buy_index < reopened_items.size() and bool(reopened_items[buy_index].get("sold", false)), "shop should keep sold state after reopening")
		var after_buy_fragments: int = int(_game_state.fragments)
		map.call("_on_shop_buy", buy_index)
		_expect(int(_game_state.fragments) == after_buy_fragments, "reopened sold shop item should not charge fragments again")
		_expect(after_buy_fragments < before_fragments, "shop purchase should charge fragments once")


func _check_battle_confirm_reward_preview(map, expected_boss_card: String = "陆吾镇门", expected_normal_fragments: String = "+10") -> void:
	var confirm_text = map.get("_confirm_text")
	_expect(confirm_text != null, "confirm text label should exist")
	if confirm_text == null:
		return
	map.call("_show_confirm", {"kind": "enemy", "name": "狰", "story": "击石声在山谷中回响。", "enemies": ["zheng_beast", "tian_gou"]})
	_expect(str(confirm_text.text).find("胜利奖励") >= 0, "normal battle confirm should preview reward")
	_expect(str(confirm_text.text).find(expected_normal_fragments) >= 0, "normal battle confirm should preview scaled fragments")
	map.call("_show_confirm", {"kind": "elite", "name": "英招", "story": "白羽精英巡守山门。"})
	_expect(str(confirm_text.text).find("胜利奖励") >= 0, "elite battle confirm should preview reward")
	_expect(str(confirm_text.text).find("唤醒卡") < 0, "elite battle confirm should not promise missing awaken card")
	map.call("_show_confirm", {"kind": "boss_mid", "name": "陆吾", "story": "白石门前的守境者。"})
	_expect(str(confirm_text.text).find("胜利奖励") >= 0, "boss battle confirm should preview reward")
	if not expected_boss_card.is_empty():
		_expect(str(confirm_text.text).find(expected_boss_card) >= 0, "boss battle confirm should preview reward card")


func _check_boss_reward(map, reward_card_id: String = "shan.luwu_gate", final_keyword: String = "北山") -> void:
	if _run_state == null or _game_state == null:
		return
	var before_deck_size: int = _run_state.run_deck.size()
	var before_fragments: int = int(_game_state.fragments)
	map.call("_grant_boss_reward", "boss_mid")
	_expect(int(_game_state.fragments) > before_fragments, "west boss reward should grant fragments")
	_expect(_run_state.run_deck.size() == before_deck_size + 1, "west boss reward should add reward card")
	_expect(bool(_game_state.call("is_codex_unlocked", "card." + reward_card_id)), "boss reward should unlock codex for reward card")
	_run_state.bosses_defeated = 1
	map.call("_show_boss_victory", "boss_mid", "陆吾")
	var victory_text = map.get("_victory_text")
	_expect(victory_text != null, "boss victory text should exist")
	if victory_text != null:
		_expect(str(victory_text.text).find("+") >= 0, "boss victory should summarize actual reward")
	_run_state.bosses_defeated = int(_run_state.BOSSES_TO_CLEAR)
	map.call("_show_boss_victory", "boss_hard", "蛊雕")
	if victory_text != null:
		_expect(str(victory_text.text).find("+") >= 0, "final boss victory should summarize actual reward")
		_expect(str(victory_text.text).find(final_keyword) >= 0, "final boss victory should keep expected completion/next-chapter copy")


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
	battle.player.block = 0
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
	var panel = ui.get_node_or_null("EnemiesPanel")
	_expect(panel != null and panel.get_child_count() == 0, "enemy compact target buttons should be removed")
	var detail_body = ui.get_node_or_null("EnemyDetailPanel/V/Body")
	_expect(detail_body != null, "enemy detail body should exist")
	if detail_body != null:
		_expect(str(detail_body.text).find("将攻击 6 -> 12") >= 0, "enemy detail should show actual modified damage")


func _check_summon_ally_rule() -> void:
	if _run_state == null or _card_db == null:
		return
	_run_state.call("reset_for_new_run")
	_run_state.next_battle_enemy_ids = PackedStringArray(["he_luo_fish"])
	_run_state.seed_value = 60608
	var packed: PackedScene = load("res://scenes/battle/battle.tscn")
	_expect(packed != null, "missing battle scene for summon ally test")
	if packed == null:
		return
	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var battle = scene.get_node_or_null("Battle")
	_expect(battle != null, "battle node should exist for summon ally test")
	if battle == null:
		scene.queue_free()
		return
	var heluo: Card = _card_db.call("get_card", "hai.heluo_ally")
	var zhuhuai: Card = _card_db.call("get_card", "shan.zhuhuai_ally")
	var feiyi: Card = _card_db.call("get_card", "huang.feiyi_ally")
	var qinglong: Card = _card_db.call("get_card", "hai.qinglong_ally")
	_expect(heluo != null and zhuhuai != null and feiyi != null and qinglong != null, "summon ally cards should exist")
	if heluo == null or zhuhuai == null or feiyi == null or qinglong == null:
		scene.queue_free()
		return
	battle.call("_resolve_effect", heluo.effects[0], heluo, null)
	var ally_raw: Variant = battle.get("active_ally")
	var ally: Dictionary = ally_raw if ally_raw is Dictionary else {}
	_expect(str(ally.get("id", "")) == "ally_heluo", "SUMMON_ALLY should create active ally")
	_expect(int(ally.get("turns", 0)) == 3, "summoned ally should last 3 turns")
	battle.call("_resolve_effect", zhuhuai.effects[0], zhuhuai, null)
	ally_raw = battle.get("active_ally")
	ally = ally_raw if ally_raw is Dictionary else {}
	_expect(str(ally.get("id", "")) == "ally_zhuhuai", "second summon should replace old ally")
	var before_block: int = int(battle.player.block)
	battle.call("_tick_ally_turn")
	ally_raw = battle.get("active_ally")
	ally = ally_raw if ally_raw is Dictionary else {}
	_expect(int(battle.player.block) > before_block, "block ally should act at player turn start")
	_expect(int(ally.get("turns", 0)) == 2, "ally action should decrement duration")
	battle.call("_tick_ally_turn")
	battle.call("_tick_ally_turn")
	ally_raw = battle.get("active_ally")
	ally = ally_raw if ally_raw is Dictionary else {}
	_expect(ally.is_empty(), "ally should leave when duration expires")
	var enemy = battle.enemies_container.get_child(0)
	if enemy != null:
		var before_hp: int = int(enemy.hp)
		battle.call("_resolve_effect", feiyi.effects[0], feiyi, null)
		battle.call("_tick_ally_turn")
		_expect(int(enemy.hp) < before_hp, "damage ally should hit lowest-hp enemy")
		before_hp = int(enemy.hp)
		battle.call("_resolve_effect", qinglong.effects[0], qinglong, null)
		battle.call("_tick_ally_turn")
		_expect(int(enemy.hp) < before_hp, "qinglong ally should hit lowest-hp enemy")
	scene.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)


func _error(message: String) -> void:
	_errors.append(message)
	push_error("[v0.8 regression] " + message)


func _finish() -> void:
	if _errors.is_empty():
		print("[v0.8 regression] PASS")
		quit(0)
	else:
		print("[v0.8 regression] FAIL: %d issue(s)" % _errors.size())
		for message in _errors:
			print(" - " + message)
		quit(1)

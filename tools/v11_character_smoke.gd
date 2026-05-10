extends SceneTree

const PixelSprites = preload("res://scripts/map/pixel_sprites.gd")

var _errors: Array[String] = []
var _card_db: Node = null
var _enemy_db: Node = null
var _run_state: Node = null
var _game_state: Node = null
var _snapshot: Dictionary = {}


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	await process_frame
	_bind_autoloads()
	_snapshot = _game_state.call("to_dict")
	_reload_databases()
	_check_content_totals()
	_check_old_save_character_defaults()
	_check_character_unlock_activation_roundtrip()
	_check_character_starter_decks()
	await _check_study_room_character_ui()
	await _check_character_map_rewards()
	_check_character_textures()
	_restore_snapshot()
	_finish()


func _bind_autoloads() -> void:
	_card_db = root.get_node_or_null("CardDatabase")
	_enemy_db = root.get_node_or_null("EnemyDatabase")
	_run_state = root.get_node_or_null("RunState")
	_game_state = root.get_node_or_null("GameState")
	_expect(_card_db != null, "missing CardDatabase autoload")
	_expect(_enemy_db != null, "missing EnemyDatabase autoload")
	_expect(_run_state != null, "missing RunState autoload")
	_expect(_game_state != null, "missing GameState autoload")


func _reload_databases() -> void:
	if _card_db != null:
		_card_db.call("reload_all")
	if _enemy_db != null:
		_enemy_db.call("reload_all")


func _check_content_totals() -> void:
	_expect(int(_card_db.call("all_cards").size()) == 92, "v0.11 should load 92 cards")
	_expect(int(_enemy_db.call("all_enemies").size()) == 40, "v0.11 should keep 40 enemies")
	_expect(int(_game_state.call("codex_total_entries")) == 132, "v0.11 codex total should be 92 cards + 40 enemies")
	for card_id in _ali_cards() + _luoling_cards() + _sangqi_cards():
		var card: Card = _card_db.call("get_card", card_id)
		_expect(card != null, "missing character card: %s" % card_id)
		if card != null:
			_expect(not card.keywords.is_empty(), "%s should carry route keywords" % card_id)


func _check_old_save_character_defaults() -> void:
	_game_state.call("from_dict", {
		"unlocked_codex": [],
		"fragments": 0,
		"unlocked_characters": ["fang_xun"],
		"settings": {"locale": "zh_CN"},
	})
	_expect(str(_game_state.active_character_id) == GameState.CHARACTER_FANG_XUN, "old saves should default active character to Fang Xun")
	_expect(bool(_game_state.call("is_character_unlocked", GameState.CHARACTER_FANG_XUN)), "old saves should keep Fang Xun unlocked")


func _check_character_unlock_activation_roundtrip() -> void:
	_game_state.call("from_dict", {})
	_game_state.fragments = 1000
	_unlock_real_codex_entries(30)
	_expect(bool(_game_state.call("can_unlock_character", GameState.CHARACTER_ALI)), "Ali should unlock with enough fragments and codex")
	_expect(bool(_game_state.call("unlock_character", GameState.CHARACTER_ALI)), "Ali unlock should succeed")
	_expect(str(_game_state.active_character_id) == GameState.CHARACTER_ALI, "unlocking Ali should activate her")
	_expect(bool(_game_state.call("can_unlock_character", GameState.CHARACTER_LUO_LING)), "Luo Ling should unlock with enough fragments and codex")
	_expect(bool(_game_state.call("unlock_character", GameState.CHARACTER_LUO_LING)), "Luo Ling unlock should succeed")
	_expect(bool(_game_state.call("can_unlock_character", GameState.CHARACTER_SANG_QI)), "Sang Qi should unlock with enough fragments and codex")
	_expect(bool(_game_state.call("unlock_character", GameState.CHARACTER_SANG_QI)), "Sang Qi unlock should succeed")
	_expect(bool(_game_state.call("set_active_character", GameState.CHARACTER_ALI)), "active character should switch back to Ali")
	var saved: Dictionary = _game_state.call("to_dict")
	_game_state.call("from_dict", saved)
	_expect(bool(_game_state.call("is_character_unlocked", GameState.CHARACTER_ALI)), "save roundtrip should keep Ali unlocked")
	_expect(bool(_game_state.call("is_character_unlocked", GameState.CHARACTER_LUO_LING)), "save roundtrip should keep Luo Ling unlocked")
	_expect(bool(_game_state.call("is_character_unlocked", GameState.CHARACTER_SANG_QI)), "save roundtrip should keep Sang Qi unlocked")
	_expect(str(_game_state.active_character_id) == GameState.CHARACTER_ALI, "save roundtrip should preserve active character")


func _check_character_starter_decks() -> void:
	_game_state.call("set_active_character", GameState.CHARACTER_ALI)
	_run_state.call("reset_for_new_run", GameState.CHARACTER_ALI)
	var ali_ids := _deck_ids()
	_expect(int(_run_state.max_hp) == 60, "Ali should use 60 max hp")
	_expect(int(_run_state.hand_size) == 4, "Ali should start with 4 cards drawn")
	_expect(ali_ids.has("ali.foxtail_feint"), "Ali starter should include fox feint")
	_expect(ali_ids.has("ali.moonlit_wound"), "Ali starter should include blood sacrifice card")
	_expect(ali_ids.has("huang.qiongqi_lash"), "Ali starter should lean Huang")
	_game_state.call("set_active_character", GameState.CHARACTER_LUO_LING)
	_run_state.call("reset_for_new_run", GameState.CHARACTER_LUO_LING)
	var luo_ids := _deck_ids()
	_expect(int(_run_state.max_hp) == 65, "Luo Ling should use 65 max hp")
	_expect(int(_run_state.hand_size) == 5, "Luo Ling should start with 5 cards drawn")
	_expect(luo_ids.has("hai.yinglong_call"), "Luo Ling starter should include Hai rhythm card")
	_expect(luo_ids.has("hai.tide_return"), "Luo Ling starter should include tide return")
	_game_state.call("set_active_character", GameState.CHARACTER_SANG_QI)
	_run_state.call("reset_for_new_run", GameState.CHARACTER_SANG_QI)
	var sang_ids := _deck_ids()
	_expect(int(_run_state.max_hp) == 78, "Sang Qi should use 78 max hp")
	_expect(int(_run_state.hand_size) == 4, "Sang Qi should start with 4 cards drawn")
	_expect(sang_ids.has("sangqi.root_guard"), "Sang Qi starter should include root guard")
	_expect(sang_ids.has("sangqi.fusang_sprout"), "Sang Qi starter should include Fusang sprout")
	_expect(sang_ids.has("shan.fusang"), "Sang Qi starter should lean Shan")


func _check_study_room_character_ui() -> void:
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
		var has_ali := false
		var has_luo := false
		var has_sang := false
		var has_bookmark_section := false
		for row in list.get_children():
			var text := _collect_text(row)
			has_ali = has_ali or text.find("阿离") >= 0
			has_luo = has_luo or text.find("洛泠") >= 0
			has_sang = has_sang or text.find("桑岐") >= 0
			has_bookmark_section = has_bookmark_section or text.find("藏签") >= 0
		_expect(has_ali, "study room should list Ali")
		_expect(has_luo, "study room should list Luo Ling")
		_expect(has_sang, "study room should list Sang Qi")
		_expect(has_bookmark_section, "study room should still list bookmarks")
	study.queue_free()


func _check_character_map_rewards() -> void:
	var packed: PackedScene = load("res://scenes/map/map.tscn")
	_expect(packed != null, "map scene should load")
	if packed == null:
		return
	var map = packed.instantiate()
	root.add_child(map)
	await process_frame
	_run_state.character_id = GameState.CHARACTER_ALI
	var ali_cards: Array = map.call("_active_character_card_ids")
	_expect(ali_cards.size() == 6 and ali_cards.has("ali.foxfire_oath"), "Ali should expose six character reward cards")
	_run_state.character_id = GameState.CHARACTER_LUO_LING
	var luo_cards: Array = map.call("_active_character_card_ids")
	_expect(luo_cards.size() == 6 and luo_cards.has("luoling.deepsea_confluence"), "Luo Ling should expose six character reward cards")
	_run_state.character_id = GameState.CHARACTER_SANG_QI
	var sang_cards: Array = map.call("_active_character_card_ids")
	_expect(sang_cards.size() == 6 and sang_cards.has("sangqi.ten_thousand_leaves"), "Sang Qi should expose six character reward cards")
	map.queue_free()


func _check_character_textures() -> void:
	_expect(PixelSprites.texture("player_ali", PixelSprites.DIR_DOWN, 0) != null, "Ali top-down texture should load")
	_expect(PixelSprites.texture("player_luoling", PixelSprites.DIR_DOWN, 0) != null, "Luo Ling top-down texture should load")
	_expect(PixelSprites.texture("player_sangqi", PixelSprites.DIR_DOWN, 0) != null, "Sang Qi top-down texture should load")
	_expect(PixelSprites.iso_character_texture(GameState.CHARACTER_ALI, "idle", PixelSprites.DIR_RIGHT, 0) != null, "Ali iso idle should load")
	_expect(PixelSprites.iso_character_texture(GameState.CHARACTER_ALI, "attack", PixelSprites.DIR_RIGHT, 0) != null, "Ali iso attack should load")
	_expect(PixelSprites.iso_character_texture(GameState.CHARACTER_LUO_LING, "idle", PixelSprites.DIR_RIGHT, 0) != null, "Luo Ling iso idle should load")
	_expect(PixelSprites.iso_character_texture(GameState.CHARACTER_LUO_LING, "attack", PixelSprites.DIR_RIGHT, 0) != null, "Luo Ling iso attack should load")
	_expect(PixelSprites.iso_character_texture(GameState.CHARACTER_SANG_QI, "idle", PixelSprites.DIR_RIGHT, 0) != null, "Sang Qi iso idle should load")
	_expect(PixelSprites.iso_character_texture(GameState.CHARACTER_SANG_QI, "attack", PixelSprites.DIR_RIGHT, 0) != null, "Sang Qi iso attack should load")


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


func _collect_text(node: Node) -> String:
	var text := ""
	if node is Label or node is Button:
		text += str(node.text)
	for child in node.get_children():
		text += "\n" + _collect_text(child)
	return text


func _ali_cards() -> Array[String]:
	return [
		"ali.foxtail_feint",
		"ali.moonlit_wound",
		"ali.masked_step",
		"ali.nine_tail_bargain",
		"ali.charm_snare",
		"ali.foxfire_oath",
	]


func _luoling_cards() -> Array[String]:
	return [
		"luoling.rainthread_draw",
		"luoling.tide_mark",
		"luoling.mistwalk",
		"luoling.wavecut",
		"luoling.dragonwell_breath",
		"luoling.deepsea_confluence",
	]


func _sangqi_cards() -> Array[String]:
	return [
		"sangqi.root_guard",
		"sangqi.fusang_sprout",
		"sangqi.wooden_sigil",
		"sangqi.green_breath",
		"sangqi.ridge_bastion",
		"sangqi.ten_thousand_leaves",
	]


func _restore_snapshot() -> void:
	if _game_state != null and not _snapshot.is_empty():
		_game_state.call("from_dict", _snapshot)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error("[v0.11 character smoke] " + message)


func _finish() -> void:
	if _errors.is_empty():
		print("[v0.11 character smoke] PASS")
		quit(0)
		return
	print("[v0.11 character smoke] FAIL: %d issue(s)" % _errors.size())
	for message in _errors:
		print(" - " + message)
	quit(1)

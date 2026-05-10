extends SceneTree

const ALLOWED_KEYWORDS: Array[String] = ["根脉", "生息", "潮涌", "湿润", "凶势", "血祭"]

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
	_check_card_keywords()
	await _check_invalid_codex_entries_do_not_count()
	await _check_card_view_keywords()
	await _check_codex_keyword_rules()
	await _check_blood_sacrifice_respects_block()
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


func _check_card_keywords() -> void:
	var cards: Array = _card_db.call("all_cards")
	_expect(cards.size() == 92, "card database should load 92 cards after v0.11 character cards")
	var route_counts := {
		"山.根脉": 0,
		"山.生息": 0,
		"海.潮涌": 0,
		"海.湿润": 0,
		"荒.凶势": 0,
		"荒.血祭": 0,
	}
	for card in cards:
		_expect(card is Card, "card database should only return Card resources")
		if not (card is Card):
			continue
		_expect(card.keywords != null, "%s should expose keywords array" % card.id)
		for keyword in card.keywords:
			_expect(ALLOWED_KEYWORDS.has(keyword), "%s uses illegal keyword: %s" % [card.id, keyword])
		if card.school == Card.School.NEUTRAL:
			_expect(card.keywords.is_empty(), "%s neutral card should not introduce a fourth keyword system" % card.id)
		if card.school == Card.School.SHAN:
			if card.keywords.has("根脉"):
				route_counts["山.根脉"] += 1
			if card.keywords.has("生息"):
				route_counts["山.生息"] += 1
		if card.school == Card.School.HAI:
			if card.keywords.has("潮涌"):
				route_counts["海.潮涌"] += 1
				_expect(_has_tide_flow_payload(card), "%s 潮涌 should carry draw/energy/flow payload" % card.id)
			if card.keywords.has("湿润"):
				route_counts["海.湿润"] += 1
				_expect(_has_wet_payload(card), "%s 湿润 should apply or reference wet condition" % card.id)
		if card.school == Card.School.HUANG:
			if card.keywords.has("凶势"):
				route_counts["荒.凶势"] += 1
			if card.keywords.has("血祭"):
				route_counts["荒.血祭"] += 1
				_expect(_has_blood_cost(card), "%s 血祭 should have self damage or discard cost" % card.id)
	for key in route_counts.keys():
		_expect(int(route_counts[key]) >= 2, "%s should have at least two cards" % key)


func _check_invalid_codex_entries_do_not_count() -> void:
	var payload := {
		"unlocked_codex": [],
		"fragments": 152,
		"unlocked_characters": ["fang_xun"],
		"settings": {"locale": "zh_CN"},
	}
	for card in _card_db.call("all_cards"):
		if card is Card:
			payload["unlocked_codex"].append("card." + card.id)
	for enemy in _enemy_db.call("all_enemies"):
		if enemy is EnemyData:
			payload["unlocked_codex"].append("beast." + enemy.id)
	for i in 16:
		payload["unlocked_codex"].append("smoke.codex.%02d" % i)
	_game_state.call("from_dict", payload)
	var total: int = int(_game_state.call("codex_total_entries"))
	var unlocked: int = int(_game_state.call("valid_codex_unlocked_count"))
	_expect(total == 132, "codex total should stay at real card+enemy entries")
	_expect(unlocked == total, "invalid smoke codex keys should not count past total")
	_expect(int(_game_state.unlocked_codex.size()) == total, "invalid smoke codex keys should be pruned on load")
	_expect(not bool(_game_state.call("unlock_codex", "smoke.codex.99")), "invalid smoke codex key should not unlock")
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	_expect(packed != null, "main menu scene should load for codex count check")
	if packed == null:
		return
	var menu = packed.instantiate()
	root.add_child(menu)
	await process_frame
	_game_state.call("from_dict", payload)
	menu.call("_refresh_info")
	var info = menu.get_node_or_null("V/Info")
	_expect(info != null, "main menu info should exist for codex count check")
	if info != null:
		var text := str(info.text)
		_expect(text.find("148 / 132") < 0, "main menu should not display invalid codex count")
		_expect(text.find("132 / 132") >= 0, "main menu should display capped valid codex count")
	menu.queue_free()


func _has_tide_flow_payload(card: Card) -> bool:
	for eff in card.effects:
		if eff.kind == CardEffect.Kind.DRAW or eff.kind == CardEffect.Kind.GAIN_ENERGY:
			return true
		if eff.kind == CardEffect.Kind.SELF_STATUS and eff.status_id == StatusEffect.ID_RESONANCE_HAI:
			return true
	var text := _description_without_keyword_rules(card)
	return text.find("抽") >= 0 or text.find("摸") >= 0 or text.find("灵韵") >= 0


func _has_wet_payload(card: Card) -> bool:
	for eff in card.effects:
		if eff.kind == CardEffect.Kind.APPLY_STATUS and eff.status_id == StatusEffect.ID_WET:
			return true
	var text := _description_without_keyword_rules(card)
	return text.find("若目标湿润") >= 0


func _description_without_keyword_rules(card: Card) -> String:
	var text := card.get_resolved_description()
	if text.begins_with("【"):
		var end := text.find("】")
		if end >= 0:
			return text.substr(end + 1)
	return text


func _has_blood_cost(card: Card) -> bool:
	for eff in card.effects:
		if eff.kind == CardEffect.Kind.DAMAGE and (eff.target == CardEffect.Target.SELF or eff.target == CardEffect.Target.NONE):
			return true
		if eff.kind == CardEffect.Kind.DISCARD_RANDOM:
			return true
	return false


func _check_card_view_keywords() -> void:
	var card: Card = _card_db.call("get_card", "shan.jianmu")
	_expect(card != null, "shan.jianmu should exist for card view check")
	if card == null:
		return
	var packed: PackedScene = load("res://scenes/battle/card_view.tscn")
	_expect(packed != null, "card view scene should load")
	if packed == null:
		return
	var view = packed.instantiate()
	root.add_child(view)
	await process_frame
	view.call("setup", card, 0)
	await process_frame
	var header = view.get_node_or_null("V/Header/School")
	var keywords = view.get_node_or_null("V/Keywords")
	var cost = view.get_node_or_null("V/Header/Cost")
	_expect(header != null and str(header.text).find("山") >= 0 and str(header.text).find("技") >= 0, "card header should show school mark and type")
	_expect(header != null and str(header.text).find("费") < 0, "card type header should not be covered by cost text")
	_expect(cost != null and str(cost.text).begins_with("费"), "card cost should stay in its own slot")
	_expect(keywords != null and str(keywords.text).find("根脉") >= 0, "card view should show keyword tags")
	view.call("set_fan_expanded", false)
	await process_frame
	_expect(keywords != null and keywords.visible, "collapsed fan card should still show keyword tags")
	view.queue_free()


func _check_codex_keyword_rules() -> void:
	var card: Card = _card_db.call("get_card", "hai.kun_swift")
	_expect(card != null, "hai.kun_swift should exist for codex keyword check")
	if card == null:
		return
	_game_state.unlock_codex("card." + card.id)
	var packed: PackedScene = load("res://scenes/codex/codex.tscn")
	_expect(packed != null, "codex scene should load")
	if packed == null:
		return
	var codex = packed.instantiate()
	root.add_child(codex)
	await process_frame
	codex.call("_show_detail", card, true)
	await process_frame
	var detail = codex.get_node_or_null("H/Detail")
	_expect(detail != null, "codex detail should exist")
	if detail != null:
		var text := str(detail.call("get_parsed_text"))
		_expect(text.find("关键词") >= 0, "codex detail should show keyword section")
		_expect(text.find("湿润") >= 0, "codex detail should explain wet keyword")
		_expect(text.find("受伤 +1") >= 0, "codex detail should include keyword rule text")
	var unlock_button = codex.get_node_or_null("UnlockAllButton")
	_expect(unlock_button != null, "codex dev unlock-all button should remain available")
	codex.queue_free()


func _check_blood_sacrifice_respects_block() -> void:
	var card: Card = _first_self_damage_blood_card()
	_expect(card != null, "should have at least one self-damage blood sacrifice card")
	if card == null:
		return
	var packed: PackedScene = load("res://scenes/battle/battle.tscn")
	_expect(packed != null, "battle scene should load for blood sacrifice check")
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
	var self_damage: CardEffect = null
	for eff in card.effects:
		if eff.kind == CardEffect.Kind.DAMAGE and (eff.target == CardEffect.Target.SELF or eff.target == CardEffect.Target.NONE):
			self_damage = eff
			break
	_expect(self_damage != null, "%s should have self damage effect for shield rule check" % card.id)
	if self_damage == null:
		scene.queue_free()
		return
	var before_hp: int = int(_run_state.hp)
	battle.player.block = int(self_damage.amount)
	battle.call("_resolve_effect", self_damage, card, null)
	await process_frame
	_expect(int(_run_state.hp) == before_hp, "blood sacrifice self damage should be absorbed by shield")
	_expect(battle.player.block == 0, "blood sacrifice should consume matching shield")
	battle.player.block = 0
	battle.call("_resolve_effect", self_damage, card, null)
	await process_frame
	_expect(int(_run_state.hp) == maxi(0, before_hp - int(self_damage.amount)), "blood sacrifice without shield should reduce hp by effect amount")
	_expect(int(_run_state.hp) >= 0, "blood sacrifice should never create negative hp")
	scene.queue_free()


func _first_self_damage_blood_card() -> Card:
	for card in _card_db.call("all_cards"):
		if card is Card and card.keywords.has("血祭"):
			for eff in card.effects:
				if eff.kind == CardEffect.Kind.DAMAGE and (eff.target == CardEffect.Target.SELF or eff.target == CardEffect.Target.NONE):
					return card
	return null


func _restore_snapshot() -> void:
	if _game_state != null and not _snapshot.is_empty():
		_game_state.call("from_dict", _snapshot)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error("[v0.10 keyword smoke] " + message)


func _finish() -> void:
	if _errors.is_empty():
		print("[v0.10 keyword smoke] PASS")
		quit(0)
		return
	print("[v0.10 keyword smoke] FAIL: %d issue(s)" % _errors.size())
	for message in _errors:
		print(" - " + message)
	quit(1)

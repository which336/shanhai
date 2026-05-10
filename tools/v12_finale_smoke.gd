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
	_check_content_totals()
	_check_event_marker_coverage()
	_check_marker_lifecycle_and_save_boundary()
	_check_ending_thresholds()
	_check_ending_save_compatibility()
	await _check_codex_learning_loop()
	await _check_finale_scene_loads()
	await _check_final_clear_flow()
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


func _check_content_totals() -> void:
	_expect(int(_card_db.call("all_cards").size()) == 92, "v0.12 should keep 92 cards")
	_expect(int(_enemy_db.call("all_enemies").size()) == 40, "v0.12 should keep 40 enemies")
	_expect(int(_game_state.call("codex_total_entries")) == 132, "v0.12 codex total should be 92 cards + 40 enemies")


func _check_event_marker_coverage() -> void:
	var events: Array = EventDatabase.load_all()
	_expect(events.size() == 40, "v0.12 should keep 40 events")
	var option_count := 0
	for event in events:
		_expect(event is Dictionary, "event payload should be a dictionary")
		if not (event is Dictionary):
			continue
		var event_id: String = str(event.get("id", ""))
		var options: Array = Array(event.get("options", []))
		_expect(not options.is_empty(), "%s should have options" % event_id)
		for opt in options:
			option_count += 1
			_expect(opt is Dictionary, "%s option should be a dictionary" % event_id)
			if not (opt is Dictionary):
				continue
			var marker: String = str(opt.get("ending_marker", ""))
			_expect(bool(_run_state.call("is_valid_ending_marker", marker)), "%s option should use legal ending_marker: %s" % [event_id, marker])
	_expect(option_count >= events.size() * 2, "event marker coverage should include all meaningful options")


func _check_marker_lifecycle_and_save_boundary() -> void:
	_run_state.call("reset_for_new_run")
	_expect(int(_run_state.call("meaningful_ending_marker_count")) == 0, "new run should reset meaningful ending markers")
	_expect(bool(_run_state.call("record_ending_marker", RunState.ENDING_MARKER_GUARD)), "guard marker should record")
	_expect(bool(_run_state.call("record_ending_marker", RunState.ENDING_MARKER_COMPANION)), "companion marker should record")
	_expect(bool(_run_state.call("record_ending_marker", RunState.ENDING_MARKER_PRACTICAL)), "practical marker should record")
	_expect(not bool(_run_state.call("record_ending_marker", "selfish")), "invalid marker should be rejected")
	_expect(int(_run_state.call("ending_marker_count", RunState.ENDING_MARKER_GUARD)) == 1, "guard marker count should increment")
	_expect(int(_run_state.call("meaningful_ending_marker_count")) == 2, "guard + companion should be meaningful")
	var saved: Dictionary = _game_state.call("to_dict")
	_expect(not saved.has("ending_markers"), "ending markers should stay out of long-term GameState save")
	_run_state.call("reset_for_new_run")
	_expect(int(_run_state.call("meaningful_ending_marker_count")) == 0, "next run should clear ending markers")


func _check_ending_thresholds() -> void:
	_game_state.call("from_dict", {})
	_run_state.call("reset_for_new_run")
	_expect(str(_game_state.call("evaluate_current_ending").get("id", "")) == GameState.ENDING_CANXIANG, "empty progress should produce low ending")
	_run_state.call("record_ending_marker", RunState.ENDING_MARKER_GUARD)
	_expect(str(_game_state.call("evaluate_current_ending").get("id", "")) == GameState.ENDING_WUJING, "one guard/companion marker should produce mid ending")
	_game_state.call("from_dict", {})
	_run_state.call("reset_for_new_run")
	_unlock_real_codex_entries(40)
	_expect(str(_game_state.call("evaluate_current_ending").get("id", "")) == GameState.ENDING_WUJING, "30 percent codex should produce mid ending")
	_game_state.call("from_dict", {})
	_run_state.call("reset_for_new_run")
	_unlock_real_codex_entries(80)
	_run_state.call("record_ending_marker", RunState.ENDING_MARKER_GUARD)
	_run_state.call("record_ending_marker", RunState.ENDING_MARKER_COMPANION)
	_run_state.call("record_ending_marker", RunState.ENDING_MARKER_GUARD)
	_expect(str(_game_state.call("evaluate_current_ending").get("id", "")) == GameState.ENDING_CHONGMING, "60 percent codex plus 3 meaningful markers should produce true ending")


func _check_ending_save_compatibility() -> void:
	_game_state.call("from_dict", {})
	_expect(_game_state.seen_endings.is_empty(), "old saves should default to no seen endings")
	_expect(str(_game_state.best_ending_id) == "", "old saves should default to no best ending")
	_expect(bool(_game_state.call("record_ending", GameState.ENDING_WUJING)), "mid ending should record")
	_expect(bool(_game_state.call("record_ending", GameState.ENDING_CHONGMING)), "true ending should record")
	var payload := {
		"version": 1,
		"timestamp": 0,
		"game_state": _game_state.call("to_dict"),
	}
	_game_state.call("from_dict", {})
	var ok: bool = bool(_save_system.call("load_from_text", JSON.stringify(payload), false))
	_expect(ok, "ending save payload should load")
	_expect(_game_state.seen_endings.has(GameState.ENDING_WUJING), "seen endings should persist")
	_expect(_game_state.seen_endings.has(GameState.ENDING_CHONGMING), "true ending should persist")
	_expect(str(_game_state.best_ending_id) == GameState.ENDING_CHONGMING, "best ending should preserve highest rank")
	_game_state.call("from_dict", {
		"seen_endings": [GameState.ENDING_CANXIANG, GameState.ENDING_WUJING],
		"best_ending_id": "invalid",
	})
	_expect(str(_game_state.best_ending_id) == GameState.ENDING_WUJING, "invalid best ending should recompute from seen endings")


func _check_codex_learning_loop() -> void:
	_game_state.call("from_dict", {})
	var card: Card = _card_db.call("get_card", "hai.kun_swift")
	_expect(card != null, "codex learning smoke card should exist")
	if card == null:
		return
	_expect(bool(_game_state.call("unlock_codex", "card." + card.id)), "codex learning smoke card should unlock")
	_expect(int(_game_state.call("valid_codex_learned_count")) == 0, "unread unlocked codex should start unlearned")
	var packed: PackedScene = load("res://scenes/codex/codex.tscn")
	_expect(packed != null, "codex scene should load for learning loop")
	if packed == null:
		return
	var codex = packed.instantiate()
	root.add_child(codex)
	await process_frame
	codex.call("_show_learning_overview")
	var detail = codex.get_node_or_null("H/Detail")
	_expect(detail != null, "codex detail should exist for learning loop")
	if detail != null:
		var overview := str(detail.call("get_parsed_text"))
		_expect(overview.find("学习总览") >= 0, "codex should expose learning overview")
		_expect(overview.find("已研读 0 / 1") >= 0, "learning overview should show unread count")
	codex.call("_show_ending_conditions")
	await process_frame
	if detail != null:
		var conditions := str(detail.call("get_parsed_text"))
		_expect(conditions.find("终局条件") >= 0, "codex should explain ending conditions")
		_expect(conditions.find("山海重明") >= 0, "ending explainer should name true ending")
		_expect(conditions.find("守护 + 陪伴") >= 0, "ending explainer should explain meaningful markers")
	codex.call("_show_detail", card, true)
	await process_frame
	_expect(bool(_game_state.call("is_codex_learned", "card." + card.id)), "opening codex detail should mark entry learned")
	_expect(int(_game_state.call("valid_codex_learned_count")) == 1, "learned codex count should increment")
	var payload := {
		"version": 1,
		"timestamp": 0,
		"game_state": _game_state.call("to_dict"),
	}
	_game_state.call("from_dict", {})
	_expect(bool(_save_system.call("load_from_text", JSON.stringify(payload), false)), "learned codex save payload should load")
	_expect(bool(_game_state.call("is_codex_learned", "card." + card.id)), "learned codex state should persist")
	codex.queue_free()


func _check_finale_scene_loads() -> void:
	var packed: PackedScene = load("res://scenes/finale/finale.tscn")
	_expect(packed != null, "finale scene should load")
	if packed == null:
		return
	var finale = packed.instantiate()
	root.add_child(finale)
	await process_frame
	_expect(finale.get_node_or_null("Root/Body") != null, "finale body should exist")
	_expect(finale.get_node_or_null("Root/Choices") != null, "finale choices should exist")
	var text := _collect_text(finale)
	_expect(text.find("忘川之心") >= 0, "finale should show Wangchuan title")
	var explanation := str(finale.call("_judgement_explanation", {
		"id": GameState.ENDING_WUJING,
		"codex_unlocked": 132,
		"codex_total": 132,
		"meaningful_markers": 0,
	}))
	_expect(explanation.find("守护/陪伴 3 次") >= 0, "finale judgement should explain missing true-ending markers")
	finale.queue_free()


func _check_final_clear_flow() -> void:
	_run_state.call("reset_for_new_run")
	_run_state.current_chapter_index = RunState.CHAPTER_CENTRAL
	_run_state.current_floor = RunState.CHAPTER_CENTRAL
	_run_state.bosses_defeated = RunState.BOSSES_TO_CLEAR
	var packed: PackedScene = load("res://scenes/map/map.tscn")
	_expect(packed != null, "map scene should load for final flow")
	if packed == null:
		return
	var map = packed.instantiate()
	root.add_child(map)
	await process_frame
	map.call("_show_boss_victory", "boss_hard", "v0.12 smoke")
	var victory_text = map.get("_victory_text")
	var victory_btn = map.get("_victory_btn")
	_expect(victory_text != null, "final victory text should exist")
	if victory_text != null:
		_expect(str(victory_text.text).find("忘川之心") >= 0, "final clear should point to Wangchuan finale")
	_expect(victory_btn != null and str(victory_btn.text).find("忘川之心") >= 0, "final clear button should enter Wangchuan finale")
	map.call("_on_victory_close")
	await process_frame
	await process_frame
	var current = current_scene
	_expect(current != null and current.scene_file_path.ends_with("finale.tscn"), "final clear should load finale scene")
	if current != null:
		current.call("_finish")
		await process_frame
		await process_frame
		current = current_scene
		_expect(current != null and current.scene_file_path.ends_with("study_room.tscn"), "finale finish should return to study room")
		if current != null:
			current.queue_free()
	map.queue_free()


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
	elif node is RichTextLabel:
		text += str(node.text)
	for child in node.get_children():
		text += "\n" + _collect_text(child)
	return text


func _restore_snapshot() -> void:
	if _game_state != null:
		_game_state.call("from_dict", _snapshot)
	if _run_state != null:
		_run_state.call("reset_for_new_run", _game_state.active_character_id if _game_state != null else "fang_xun")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error("[v0.12 finale smoke] " + message)


func _finish() -> void:
	if _errors.is_empty():
		print("[v0.12 finale smoke] PASS")
		quit(0)
		return
	print("[v0.12 finale smoke] FAIL: %d issue(s)" % _errors.size())
	quit(1)

extends SceneTree

var _errors: Array[String] = []
var _game_state: Node = null
var _run_state: Node = null
var _save_system: Node = null
var _snapshot: Dictionary = {}


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	await process_frame
	_bind_autoloads()
	_snapshot = _game_state.call("to_dict")
	_check_settings_defaults()
	await _check_main_menu_playtest_entries()
	await _check_settings_scene_roundtrip()
	await _check_dev_tools_visibility()
	await _check_character_sprite_regressions()
	await _check_card_view_text_fit()
	await _check_map_hud_and_exit_confirm()
	await _check_map_exit_saves_meta_progress()
	await _check_tutorial_scene_flow()
	_restore_snapshot()
	_finish()


func _bind_autoloads() -> void:
	_game_state = root.get_node_or_null("GameState")
	_run_state = root.get_node_or_null("RunState")
	_save_system = root.get_node_or_null("SaveSystem")
	_expect(_game_state != null, "missing GameState autoload")
	_expect(_run_state != null, "missing RunState autoload")
	_expect(_save_system != null, "missing SaveSystem autoload")


func _check_settings_defaults() -> void:
	_game_state.call("from_dict", {
		"unlocked_codex": [],
		"fragments": 0,
		"unlocked_characters": ["fang_xun"],
		"settings": {"locale": "zh_CN"},
	})
	var settings: Dictionary = _game_state.settings
	for key in ["bgm_volume", "sfx_volume", "fullscreen", "show_dev_tools", "tutorial_seen"]:
		_expect(settings.has(key), "old saves should gain settings key: %s" % key)
	_expect(is_equal_approx(float(settings.get("bgm_volume", -1.0)), 0.6), "old saves should default bgm volume")
	_expect(is_equal_approx(float(settings.get("sfx_volume", -1.0)), 0.8), "old saves should default sfx volume")
	_expect(not bool(settings.get("fullscreen", true)), "old saves should default windowed")
	_expect(not bool(settings.get("show_dev_tools", true)), "old saves should hide dev tools")
	_expect(not bool(settings.get("tutorial_seen", true)), "old saves should mark tutorial unseen")


func _check_main_menu_playtest_entries() -> void:
	_game_state.call("from_dict", {})
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	_expect(packed != null, "main menu should load")
	if packed == null:
		return
	var menu = packed.instantiate()
	root.add_child(menu)
	await process_frame
	_game_state.settings["tutorial_seen"] = false
	_expect(menu.get_node_or_null("V/TutorialButton") != null, "main menu should expose tutorial button")
	_expect(menu.get_node_or_null("V/SettingsButton") != null, "main menu should expose settings button")
	var info = menu.get_node_or_null("V/Info")
	_expect(info != null, "main menu info should exist")
	if info != null:
		var text := str(info.text)
		_expect(text.find("已研读") >= 0, "main menu should show learned codex progress")
		_expect(text.find("最高结局") >= 0, "main menu should show best ending")
	menu.call("_on_start")
	await process_frame
	await process_frame
	var current = current_scene
	_expect(current != null and current.scene_file_path.ends_with("tutorial.tscn"), "first start should open tutorial")
	if current != null:
		current.queue_free()
	menu.queue_free()


func _check_settings_scene_roundtrip() -> void:
	_game_state.call("from_dict", {})
	var packed: PackedScene = load("res://scenes/settings/settings.tscn")
	_expect(packed != null, "settings scene should load")
	if packed == null:
		return
	var settings_view = packed.instantiate()
	root.add_child(settings_view)
	await process_frame
	var bgm = settings_view.get_node_or_null("SettingsPanel/BgmSliderRow/BgmSlider")
	var sfx = settings_view.get_node_or_null("SettingsPanel/SfxSliderRow/SfxSlider")
	var fullscreen = settings_view.get_node_or_null("SettingsPanel/FullscreenCheck")
	var dev_tools = settings_view.get_node_or_null("SettingsPanel/DevToolsCheck")
	var apply = settings_view.get_node_or_null("SettingsPanel/Actions/ApplyButton")
	_expect(bgm != null, "settings should expose BGM slider")
	_expect(sfx != null, "settings should expose SFX slider")
	_expect(fullscreen != null, "settings should expose fullscreen toggle")
	_expect(dev_tools != null, "settings should expose dev-tools toggle")
	_expect(apply != null, "settings should expose apply button")
	if bgm != null:
		bgm.value = 0.25
	if sfx != null:
		sfx.value = 0.35
	if fullscreen != null:
		fullscreen.button_pressed = false
	if dev_tools != null:
		dev_tools.button_pressed = true
	if apply != null:
		apply.emit_signal("pressed")
	await process_frame
	var payload := {
		"version": 1,
		"timestamp": 0,
		"game_state": _game_state.call("to_dict"),
	}
	_game_state.call("from_dict", {})
	_expect(bool(_save_system.call("load_from_text", JSON.stringify(payload), false)), "settings payload should reload")
	_expect(is_equal_approx(float(_game_state.settings.get("bgm_volume", 0.0)), 0.25), "BGM setting should persist")
	_expect(is_equal_approx(float(_game_state.settings.get("sfx_volume", 0.0)), 0.35), "SFX setting should persist")
	_expect(bool(_game_state.settings.get("show_dev_tools", false)), "dev tools setting should persist")
	settings_view.queue_free()


func _check_dev_tools_visibility() -> void:
	_game_state.call("from_dict", {"settings": {"show_dev_tools": false}})
	await _expect_dev_nodes_visible(false)
	_game_state.call("from_dict", {"settings": {"show_dev_tools": true}})
	await _expect_dev_nodes_visible(true)


func _check_character_sprite_regressions() -> void:
	var fang_top_up: Texture2D = PixelSprites.texture("player", PixelSprites.DIR_UP, 0)
	_expect(_atlas_source_ends_with(fang_top_up, "walk_up.png"), "Fang Xun top-down up-facing frame should use walk_up.png")
	_expect(_file_sha256("res://assets/textures/player/walk_up.png") == "CAF0D375A9C7C302E2902F540F59DF3B0289227E3FD2A57964E330C85B400098", "Fang Xun top-down up-facing sheet should be the repaired back-facing sprite")
	_expect(_sprite_sheet_bbox_center_spread("res://assets/textures/player/walk_up.png", 64, 4) <= 1.0, "Fang Xun top-down up-facing frames should stay horizontally aligned")
	var fang_top_down: Texture2D = PixelSprites.texture("player", PixelSprites.DIR_DOWN, 0)
	_expect(_atlas_source_ends_with(fang_top_down, "walk_down.png"), "Fang Xun top-down down-facing frame should use walk_down.png")
	var luoling_top_left: Texture2D = PixelSprites.texture("player_luoling", PixelSprites.DIR_LEFT, 0)
	_expect(_atlas_source_ends_with(luoling_top_left, "luoling_walk_left.png"), "Luoling top-down left-facing frame should use luoling_walk_left.png")
	var luoling_top_right: Texture2D = PixelSprites.texture("player_luoling", PixelSprites.DIR_RIGHT, 0)
	_expect(_atlas_source_ends_with(luoling_top_right, "luoling_walk_right.png"), "Luoling top-down right-facing frame should use luoling_walk_right.png")
	var luoling_iso_right: Texture2D = PixelSprites.iso_character_texture("luo_ling", "idle", PixelSprites.DIR_RIGHT, 0)
	_expect(_atlas_region_y(luoling_iso_right) == 160, "Luoling isometric right-facing frame should read row 1")
	for dir in [PixelSprites.DIR_DOWN, PixelSprites.DIR_UP, PixelSprites.DIR_LEFT, PixelSprites.DIR_RIGHT]:
		for frame in [0, 1]:
			var sangqi_attack: Texture2D = PixelSprites.iso_character_texture("sang_qi", "attack", dir, frame)
			_expect(_atlas_source_ends_with(sangqi_attack, "sangqi_attack.png"), "Sangqi attack should use the Sangqi attack sheet")
			_expect(_atlas_region_x(sangqi_attack) == 0 and _atlas_region_y(sangqi_attack) == 0, "Sangqi attack should reuse the one known-good attack frame for every direction")
			_expect(_atlas_opaque_pixels(sangqi_attack) > 1000, "Sangqi attack frame should not be an almost-empty bad crop")
	var luoling_top_up: Texture2D = PixelSprites.texture("player_luoling", PixelSprites.DIR_UP, 0)
	_expect(luoling_top_up != null and luoling_top_up.get_size().y <= 72.0, "Luoling top-down map frame should stay within the 64px top-down sprite scale")


func _check_card_view_text_fit() -> void:
	var card_db := root.get_node_or_null("CardDatabase")
	_expect(card_db != null, "CardDatabase autoload should exist for text-fit check")
	if card_db == null:
		return
	var card = card_db.call("get_card", "hai.wenyao_evade")
	_expect(card != null, "Wenyao evade card should load for text-fit check")
	if card == null:
		return
	var packed: PackedScene = load("res://scenes/battle/card_view.tscn")
	_expect(packed != null, "card view scene should load for text-fit check")
	if packed == null:
		return
	var view = packed.instantiate()
	root.add_child(view)
	await process_frame
	view.call("setup", card, 0, card.cost)
	view.call("set_fan_expanded", true)
	await process_frame
	var desc: Label = view.get_node_or_null("V/Description")
	var quote: Label = view.get_node_or_null("V/Quote")
	_expect(desc != null, "card view should expose description label")
	if desc != null:
		_expect(str(desc.text).length() <= 30, "expanded battle card description should be compact enough to fit")
		_expect(int(desc.get_theme_font_size("font_size")) <= 12, "expanded battle card description font should shrink for long Chinese text")
	if quote != null:
		_expect(str(quote.text) == "", "battle cards should not render classic quote snippets in hand view")
		_expect(not bool(quote.visible), "battle cards should keep classic quote label hidden")
		_expect(quote.custom_minimum_size.y <= 0.0, "classic quote label should not reserve vertical space")
	view.queue_free()


func _expect_dev_nodes_visible(expected: bool) -> void:
	var codex_packed: PackedScene = load("res://scenes/codex/codex.tscn")
	_expect(codex_packed != null, "codex scene should load for dev visibility")
	if codex_packed != null:
		var codex = codex_packed.instantiate()
		root.add_child(codex)
		await process_frame
		var unlock_button = codex.get_node_or_null("UnlockAllButton")
		_expect(unlock_button != null, "codex dev unlock button should exist")
		if unlock_button != null:
			_expect(bool(unlock_button.visible) == expected, "codex dev unlock visibility should follow setting")
		codex.queue_free()
	var map_packed: PackedScene = load("res://scenes/map/map.tscn")
	_expect(map_packed != null, "map scene should load for dev visibility")
	if map_packed != null:
		_run_state.call("reset_for_new_run")
		var map = map_packed.instantiate()
		root.add_child(map)
		await process_frame
		var debug_controls = map.get_node_or_null("UI/DebugChapterControls")
		_expect(debug_controls != null, "map debug controls should exist")
		if debug_controls != null:
			_expect(bool(debug_controls.visible) == expected, "map dev controls visibility should follow setting")
		map.queue_free()


func _check_map_hud_and_exit_confirm() -> void:
	_game_state.call("from_dict", {"settings": {"show_dev_tools": false}})
	_run_state.call("reset_for_new_run")
	var packed: PackedScene = load("res://scenes/map/map.tscn")
	_expect(packed != null, "map scene should load for HUD checks")
	if packed == null:
		return
	var map = packed.instantiate()
	root.add_child(map)
	await process_frame
	var title: Control = map.get_node_or_null("UI/Title")
	var hint: Control = map.get_node_or_null("UI/Hint")
	var minimap: Control = map.get_node_or_null("UI/MiniMapPanel")
	_expect(title != null, "map title should exist")
	_expect(hint != null, "map hint should exist")
	_expect(minimap != null, "map minimap should exist")
	if title != null and minimap != null:
		var mini_rect: Rect2 = minimap.get_global_rect()
		_expect(not mini_rect.intersects(title.get_global_rect()), "minimap should not overlap map title")
		_expect(absf(mini_rect.position.x - 8.0) <= 1.0 and absf(mini_rect.position.y - 8.0) <= 1.0, "minimap should stay at original top-left position")
	if hint != null:
		_expect(not bool(hint.visible) or str(hint.text).is_empty(), "map top hint should be hidden")
	var status = map.get_node_or_null("UI/Status")
	if status != null:
		var status_text := str(status.text)
		_expect(status_text.find("[K]") >= 0, "map bottom status should mention codex shortcut")
		_expect(status_text.find("[ESC]") >= 0, "map bottom status should mention exit confirmation")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	map.call("_unhandled_input", event)
	await process_frame
	var confirm = map.get_node_or_null("UI/ConfirmPanel")
	var confirm_text = map.get_node_or_null("UI/ConfirmPanel/V/Text")
	_expect(confirm != null and bool(confirm.visible), "map ESC should open exit confirmation")
	if confirm_text != null:
		_expect(str(confirm_text.text).find("返回主菜单") >= 0, "map ESC confirmation should mention main menu")
	var no_button = map.get_node_or_null("UI/ConfirmPanel/V/H/No")
	if no_button != null:
		no_button.emit_signal("pressed")
		await process_frame
		_expect(confirm != null and not bool(confirm.visible), "map exit confirmation should be cancellable")
	var back_button = map.get_node_or_null("UI/BackButton")
	if back_button != null:
		back_button.emit_signal("pressed")
		await process_frame
		_expect(confirm != null and bool(confirm.visible), "map back button should also confirm before main menu")
	map.queue_free()


func _check_map_exit_saves_meta_progress() -> void:
	_game_state.call("from_dict", {
		"unlocked_codex": [],
		"fragments": 0,
		"unlocked_characters": ["fang_xun"],
		"settings": {"tutorial_seen": true},
	})
	_expect(bool(_save_system.call("save")), "baseline save should be writable before map exit check")
	_game_state.call("add_fragments", 7)
	_expect(bool(_game_state.call("unlock_codex", "beast.hu_diao")), "map exit check should unlock a valid codex entry")
	_run_state.call("reset_for_new_run")
	var packed: PackedScene = load("res://scenes/map/map.tscn")
	_expect(packed != null, "map scene should load for exit save check")
	if packed == null:
		return
	var map = packed.instantiate()
	root.add_child(map)
	await process_frame
	map.call("_show_exit_to_menu_confirm")
	map.call("_on_confirm_yes")
	await process_frame
	await process_frame
	_game_state.call("from_dict", {})
	_expect(bool(_save_system.call("load_save")), "saved meta progress should reload after map exit")
	_expect(int(_game_state.fragments) == 7, "map exit should save gained fragments before main menu reloads")
	_expect(bool(_game_state.call("is_codex_unlocked", "beast.hu_diao")), "map exit should save gained codex before main menu reloads")
	var current = current_scene
	if current != null:
		current.queue_free()
	if is_instance_valid(map):
		map.queue_free()


func _check_tutorial_scene_flow() -> void:
	_game_state.call("from_dict", {})
	var packed: PackedScene = load("res://scenes/tutorial/tutorial.tscn")
	_expect(packed != null, "tutorial scene should load")
	if packed == null:
		return
	var tutorial = packed.instantiate()
	root.add_child(tutorial)
	await process_frame
	_expect(tutorial.get_node_or_null("TutorialPanel/Body") != null, "tutorial should expose body")
	var next = tutorial.get_node_or_null("TutorialPanel/Controls/NextButton")
	var back = tutorial.get_node_or_null("TutorialPanel/Controls/BackButton")
	var start = tutorial.get_node_or_null("TutorialPanel/Controls/StartButton")
	_expect(next != null, "tutorial should expose next button")
	_expect(back != null, "tutorial should expose back button")
	_expect(start != null, "tutorial should expose start button")
	if next != null:
		next.emit_signal("pressed")
		await process_frame
		var page_label = tutorial.get_node_or_null("TutorialPanel/PageLabel")
		_expect(page_label != null and str(page_label.text).find("2 /") >= 0, "tutorial next button should advance page")
	if start != null:
		start.emit_signal("pressed")
		await process_frame
		await process_frame
		var current = current_scene
		_expect(current != null and current.scene_file_path.ends_with("map.tscn"), "tutorial start should enter map")
		if current != null:
			current.queue_free()
	tutorial.queue_free()


func _restore_snapshot() -> void:
	if _game_state != null:
		_game_state.call("from_dict", _snapshot)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error("[v0.14 playtest smoke] " + message)


func _atlas_source_ends_with(texture: Texture2D, suffix: String) -> bool:
	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		return str(atlas_texture.atlas.resource_path).ends_with(suffix)
	return false


func _file_sha256(path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode().to_upper()


func _sprite_sheet_bbox_center_spread(path: String, frame_width: int, frame_count: int) -> float:
	var image := Image.new()
	var image_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if image.load(image_path) != OK:
		return 999.0
	var min_center := INF
	var max_center := -INF
	for frame in frame_count:
		var x_min := frame_width
		var x_max := -1
		var start_x := frame * frame_width
		for y in image.get_height():
			for x in frame_width:
				var pixel := image.get_pixel(start_x + x, y)
				if pixel.a > 0.12:
					x_min = mini(x_min, x)
					x_max = maxi(x_max, x)
		if x_max < x_min:
			return 999.0
		var center := (float(x_min) + float(x_max + 1)) * 0.5
		min_center = minf(min_center, center)
		max_center = maxf(max_center, center)
	return max_center - min_center


func _atlas_region_y(texture: Texture2D) -> int:
	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		return int(round(atlas_texture.region.position.y))
	return -1


func _atlas_region_x(texture: Texture2D) -> int:
	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		return int(round(atlas_texture.region.position.x))
	return -1


func _atlas_opaque_pixels(texture: Texture2D) -> int:
	if not texture is AtlasTexture:
		return 0
	var atlas_texture := texture as AtlasTexture
	var image := atlas_texture.atlas.get_image()
	if image == null:
		return 0
	var region := atlas_texture.region
	var count := 0
	for y in int(region.size.y):
		for x in int(region.size.x):
			var pixel := image.get_pixel(int(region.position.x) + x, int(region.position.y) + y)
			if pixel.a > 0.12:
				count += 1
	return count


func _finish() -> void:
	if _errors.is_empty():
		print("[v0.14 playtest smoke] PASS")
		quit(0)
		return
	print("[v0.14 playtest smoke] FAIL: %d issue(s)" % _errors.size())
	for error in _errors:
		print(" - " + error)
	quit(1)

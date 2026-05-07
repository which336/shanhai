## CodexView: 山海图鉴查看界面。
extends Control

const CODEX_BACKGROUND: Texture2D = preload("res://assets/textures/backgrounds/main_menu.png")

@onready var _list: VBoxContainer = $H/Scroll/List
@onready var _detail: RichTextLabel = $H/Detail
@onready var _back_btn: Button = $BackButton
@onready var _title: Label = $Title
@onready var _layout_root: HBoxContainer = $H
@onready var _scroll: ScrollContainer = $H/Scroll

var _is_returning: bool = false
var _unlock_all_btn: Button = null
var _background_image: TextureRect = null
var _shade: ColorRect = null


func _ready() -> void:
	_ensure_background()
	_ensure_dev_unlock_button()
	_apply_scene_style()
	_back_btn.pressed.connect(_on_back)
	_build_list()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_K:
			var viewport: Viewport = get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
			_on_back()


func _ensure_background() -> void:
	var old_bg := get_node_or_null("Background")
	if old_bg is CanvasItem:
		(old_bg as CanvasItem).visible = false
	if _background_image == null:
		_background_image = TextureRect.new()
		_background_image.name = "CodexBackgroundImage"
		_background_image.texture = CODEX_BACKGROUND
		_background_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_background_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_background_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_background_image.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_background_image)
		move_child(_background_image, 0)
	if _shade == null:
		_shade = ColorRect.new()
		_shade.name = "CodexReadabilityShade"
		_shade.color = Color(0.02, 0.025, 0.04, 0.62)
		_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_shade)
		move_child(_shade, 1)


func _ensure_dev_unlock_button() -> void:
	if _unlock_all_btn != null:
		return
	_unlock_all_btn = Button.new()
	_unlock_all_btn.name = "UnlockAllButton"
	_unlock_all_btn.text = "开发：全部解锁"
	_unlock_all_btn.focus_mode = Control.FOCUS_NONE
	_unlock_all_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_unlock_all_btn.offset_left = -184
	_unlock_all_btn.offset_top = 16
	_unlock_all_btn.offset_right = -24
	_unlock_all_btn.offset_bottom = 52
	_unlock_all_btn.pressed.connect(_on_unlock_all_pressed)
	add_child(_unlock_all_btn)


func _apply_scene_style() -> void:
	_title.text = "山海图鉴"
	_title.add_theme_font_size_override("font_size", 36)
	_title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78))
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_title.add_theme_constant_override("shadow_offset_x", 2)
	_title.add_theme_constant_override("shadow_offset_y", 2)
	_layout_root.add_theme_constant_override("separation", 18)
	_scroll.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.04, 0.06, 0.72), Color(0.74, 0.62, 0.42, 0.58)))
	_detail.add_theme_stylebox_override("normal", _panel_style(Color(0.035, 0.04, 0.06, 0.76), Color(0.74, 0.62, 0.42, 0.58)))
	_detail.add_theme_font_size_override("normal_font_size", 20)
	_detail.add_theme_font_size_override("bold_font_size", 22)
	_detail.add_theme_color_override("default_color", Color(0.92, 0.9, 0.82))
	_style_command_button(_back_btn)
	if _unlock_all_btn != null:
		_style_command_button(_unlock_all_btn)


func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _style_command_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.46))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.04, 0.045, 0.06, 0.78), Color(0.72, 0.62, 0.42, 0.72)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.08, 0.065, 0.045, 0.86), Color(1.0, 0.78, 0.34, 0.95)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.08, 0.11, 0.1, 0.86), Color(0.5, 0.95, 0.86, 0.95)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _build_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	_add_section("卡牌")
	var cards: Array = CardDatabase.all_cards()
	cards.sort_custom(func(a, b): return a.school < b.school or (a.school == b.school and a.rarity < b.rarity) or (a.school == b.school and a.rarity == b.rarity and a.id < b.id))
	for c in cards:
		if not (c is Card):
			continue
		var unlocked: bool = GameState.is_codex_unlocked("card." + c.id)
		var btn := Button.new()
		btn.text = "%s · %s · %s%s" % [_school_mark(c), _rarity_name(c), c.title, "" if unlocked else "（未解锁）"]
		btn.custom_minimum_size = Vector2(0, 42)
		_style_entry_button(btn, _rarity_color(c.rarity), unlocked)
		btn.pressed.connect(_show_detail.bind(c, unlocked))
		_list.add_child(btn)
	_add_section("异兽 / 神祇")
	var enemies: Array = EnemyDatabase.all_enemies()
	enemies.sort_custom(func(a, b): return _enemy_sort_key(a) < _enemy_sort_key(b))
	for e in enemies:
		if not (e is EnemyData):
			continue
		var unlocked: bool = GameState.is_codex_unlocked("beast." + e.id)
		var btn := Button.new()
		btn.text = "%s · %s%s" % [_enemy_type_name(e), e.display_name, "" if unlocked else "（未解锁）"]
		btn.custom_minimum_size = Vector2(0, 42)
		_style_entry_button(btn, Color(0.65, 0.86, 1.0), unlocked)
		btn.pressed.connect(_show_enemy_detail.bind(e, unlocked))
		_list.add_child(btn)
	if cards.is_empty():
		_detail.text = "尚未加载到任何卡牌资源。"
	else:
		_show_detail(cards[0], GameState.is_codex_unlocked("card." + cards[0].id))


func _add_section(text: String) -> void:
	var label := Label.new()
	label.text = "—— %s ——" % text
	label.custom_minimum_size = Vector2(0, 34)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.92, 0.82, 0.58))
	_list.add_child(label)


func _style_entry_button(button: Button, color: Color, unlocked: bool) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", color if unlocked else Color(0.48, 0.49, 0.52))
	button.add_theme_color_override("font_hover_color", color.lightened(0.22) if unlocked else Color(0.68, 0.68, 0.7))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.035, 0.04, 0.055, 0.62), Color(color.r, color.g, color.b, 0.24 if unlocked else 0.12)))
	button.add_theme_stylebox_override("hover", _button_style(Color(color.r * 0.12, color.g * 0.12, color.b * 0.12, 0.82), Color(color.r, color.g, color.b, 0.86)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.06, 0.08, 0.08, 0.9), Color(0.5, 0.95, 0.86, 0.9)))
	button.add_theme_stylebox_override("focus", _button_style(Color(0.06, 0.06, 0.07, 0.88), Color(0.92, 0.9, 0.82, 0.9)))


func _on_unlock_all_pressed() -> void:
	var changed := false
	for c in CardDatabase.all_cards():
		if c is Card:
			changed = GameState.unlock_codex("card." + c.id) or changed
	for e in EnemyDatabase.all_enemies():
		if e is EnemyData:
			changed = GameState.unlock_codex("beast." + e.id) or changed
	if changed:
		SaveSystem.save()
	_build_list()
	_detail.clear()
	_detail.append_text("[b][color=#e6c97a]开发测试：图鉴已全部解锁[/color][/b]\n\n")
	_detail.append_text("已解锁所有卡牌与异兽条目，可直接检查卡牌 UI、原文、译注与唤醒内容。")


func _show_detail(card: Card, unlocked: bool) -> void:
	_detail.clear()
	var rarity_color := _rarity_hex(card.rarity)
	if not unlocked:
		_detail.append_text("[b][color=%s]%s · %s[/color][/b]\n\n" % [rarity_color, _school_mark(card), card.title])
		_detail.append_text("[i]尚未在冒险中遇见，原文仍被忘川之雾遮蔽。[/i]\n")
		return
	_detail.append_text("[b][color=%s]%s[/color][/b]  [color=#b0a993](%s · %s)[/color]\n" % [rarity_color, card.title, _school_name(card), _rarity_name(card)])
	_detail.append_text("[color=#c8c0aa]费用 %d  ·  类型 %s[/color]\n\n" % [card.cost, _type_name(card.card_type)])
	_detail.append_text("[b][color=#ffffff]玩法：[/color][/b]%s\n\n" % card.get_resolved_description())
	if card.classic_quote != "":
		_detail.append_text("[b][color=#9bd8ff]山海经原文：[/color][/b]\n[i]%s[/i]\n\n" % card.classic_quote)
	if card.translation != "":
		_detail.append_text("[b][color=#9bd8ff]白话译注：[/color][/b]\n%s\n\n" % card.translation)
	if card.alive_today != "":
		_detail.append_text("[b][color=#d4e28a]今天活在哪里：[/color][/b]\n%s\n" % card.alive_today)


func _show_enemy_detail(enemy: EnemyData, unlocked: bool) -> void:
	_detail.clear()
	if not unlocked:
		_detail.append_text("[b]%s · %s[/b]\n\n" % [_enemy_type_name(enemy), enemy.display_name])
		_detail.append_text("[i]尚未在冒险中击败或唤醒，形貌仍被忘川之雾遮蔽。[/i]\n")
		return
	_detail.append_text("[b][color=#e6c97a]%s[/color][/b]  [color=#b0a993](%s)[/color]\n" % [enemy.display_name, _enemy_type_name(enemy)])
	_detail.append_text("[color=#c8c0aa]气血 %d  ·  行动循环 %d 段[/color]\n\n" % [enemy.max_hp, enemy.intent_pattern.size()])
	if enemy.classic_quote != "":
		_detail.append_text("[b][color=#9bd8ff]山海经原文：[/color][/b]\n[i]%s[/i]\n\n" % enemy.classic_quote)
	if enemy.translation != "":
		_detail.append_text("[b][color=#9bd8ff]白话译注：[/color][/b]\n%s\n\n" % enemy.translation)
	if not enemy.awaken_options.is_empty():
		_detail.append_text("[b][color=#d4e28a]唤醒问答：[/color][/b]\n")
		for i in enemy.awaken_options.size():
			var mark: String = "✓ " if i == enemy.awaken_correct_index else "  "
			_detail.append_text("%s%s\n" % [mark, enemy.awaken_options[i]])
	if enemy.awaken_card_id != "":
		var card: Card = CardDatabase.get_card(enemy.awaken_card_id)
		var title: String = card.title if card != null else enemy.awaken_card_id
		_detail.append_text("\n[b]唤醒奖励：[/b]「%s」\n" % title)


func _school_mark(card: Card) -> String:
	match card.school:
		Card.School.SHAN:
			return "山"
		Card.School.HAI:
			return "海"
		Card.School.HUANG:
			return "荒"
		_:
			return "通"


func _school_name(card: Card) -> String:
	match card.school:
		Card.School.SHAN:
			return "山经"
		Card.School.HAI:
			return "海经"
		Card.School.HUANG:
			return "荒经"
		_:
			return "通用"


func _rarity_name(card: Card) -> String:
	match card.rarity:
		Card.Rarity.RARE:
			return "珍品"
		Card.Rarity.MYTHIC:
			return "神品"
		Card.Rarity.RELIC:
			return "遗珍"
		_:
			return "凡品"


func _rarity_color(rarity: int) -> Color:
	match rarity:
		Card.Rarity.RARE:
			return Color(1.0, 0.78, 0.32)
		Card.Rarity.MYTHIC:
			return Color(0.58, 0.95, 1.0)
		Card.Rarity.RELIC:
			return Color(0.78, 0.48, 1.0)
		_:
			return Color(0.74, 0.62, 0.42)


func _rarity_hex(rarity: int) -> String:
	match rarity:
		Card.Rarity.RARE:
			return "#ffca55"
		Card.Rarity.MYTHIC:
			return "#91f2ff"
		Card.Rarity.RELIC:
			return "#c67bff"
		_:
			return "#bda06d"


func _type_name(t: int) -> String:
	match t:
		Card.CardType.ATTACK:
			return "攻击"
		Card.CardType.SKILL:
			return "法术"
		Card.CardType.POWER:
			return "持续"
	return "未知"


func _enemy_type_name(enemy: EnemyData) -> String:
	if enemy.is_boss:
		return "Boss"
	if enemy.is_elite:
		return "精英"
	return "异兽"


func _enemy_sort_key(enemy: EnemyData) -> String:
	var prefix: String = "1"
	if enemy.is_boss:
		prefix = "3"
	elif enemy.is_elite:
		prefix = "2"
	return "%s.%s" % [prefix, enemy.id]


func _on_back() -> void:
	if _is_returning:
		return
	_is_returning = true
	if RunState.return_after_codex != "":
		var dest: String = RunState.return_after_codex
		RunState.return_after_codex = ""
		get_tree().change_scene_to_file(dest)
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

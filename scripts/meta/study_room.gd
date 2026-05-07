## StudyRoom: meta progression screen for buying and activating starter bookmarks.
extends Control

const STUDY_BACKGROUND: Texture2D = preload("res://assets/textures/backgrounds/study_room.png")

@onready var _root: VBoxContainer = $Root
@onready var _title: Label = $Root/Title
@onready var _header: HBoxContainer = $Root/Header
@onready var _fragments_label: Label = $Root/Header/Fragments
@onready var _active_label: Label = $Root/Header/Active
@onready var _list_scroll: ScrollContainer = $Root/ListScroll
@onready var _list: VBoxContainer = $Root/ListScroll/List
@onready var _footer: HBoxContainer = $Root/Footer
@onready var _back_btn: Button = $Root/Footer/BackButton
@onready var _clear_btn: Button = $Root/Footer/ClearButton
@onready var _message: Label = $Root/Footer/Message

var _background_image: TextureRect = null
var _shade: ColorRect = null
var _panel: PanelContainer = null


func _ready() -> void:
	_ensure_background()
	_apply_scene_style()
	_back_btn.pressed.connect(_on_back)
	_clear_btn.pressed.connect(_on_clear_active)
	GameState.fragments_changed.connect(_on_fragments_changed)
	GameState.bookmarks_changed.connect(_refresh)
	_refresh()
	AudioEngine.play_bgm("menu")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_scene()


func _ensure_background() -> void:
	var old_bg := get_node_or_null("Background")
	if old_bg is CanvasItem:
		(old_bg as CanvasItem).visible = false
	if _background_image == null:
		_background_image = TextureRect.new()
		_background_image.name = "StudyBackgroundImage"
		_background_image.texture = STUDY_BACKGROUND
		_background_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_background_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_background_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_background_image.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_background_image)
		move_child(_background_image, 0)
	if _shade == null:
		_shade = ColorRect.new()
		_shade.name = "StudyReadabilityShade"
		_shade.color = Color(0.035, 0.025, 0.018, 0.34)
		_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_shade)
		move_child(_shade, 1)
	if _panel == null:
		_panel = PanelContainer.new()
		_panel.name = "StudyPanel"
		_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.075, 0.052, 0.032, 0.78), Color(0.78, 0.56, 0.32, 0.68), 2))
		add_child(_panel)
		move_child(_panel, 2)


func _apply_scene_style() -> void:
	_title.text = "祖父书房"
	_title.add_theme_font_size_override("font_size", 36)
	_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.58))
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_title.add_theme_constant_override("shadow_offset_x", 2)
	_title.add_theme_constant_override("shadow_offset_y", 2)
	_root.add_theme_constant_override("separation", 14)
	_header.add_theme_constant_override("separation", 24)
	_footer.add_theme_constant_override("separation", 12)
	_list.add_theme_constant_override("separation", 12)
	_list_scroll.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.035, 0.025, 0.54), Color(0.7, 0.5, 0.28, 0.42), 1))
	for label in [_fragments_label, _active_label, _message]:
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(0.94, 0.86, 0.66))
	_style_button(_back_btn)
	_style_button(_clear_btn)
	_back_btn.text = "返回"
	_clear_btn.text = "停用藏签"
	_layout_scene()


func _layout_scene() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280, 720)
	var panel_w := clampf(viewport_size.x * 0.52, 680.0, 920.0)
	var panel_h := clampf(viewport_size.y - 72.0, 560.0, 820.0)
	var panel_pos := Vector2(maxf(28.0, viewport_size.x - panel_w - 42.0), (viewport_size.y - panel_h) * 0.5)
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.position = panel_pos
	_panel.size = Vector2(panel_w, panel_h)
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.position = panel_pos + Vector2(24, 18)
	_root.size = Vector2(panel_w - 48.0, panel_h - 36.0)


func _refresh() -> void:
	var active: Dictionary = GameState.active_bookmark_def()
	var active_text := "未启用藏签" if active.is_empty() else _bookmark_title(str(active.get("id", "")))
	_fragments_label.text = "典籍碎片：%d" % GameState.fragments
	_active_label.text = "当前藏签：%s" % active_text
	_clear_btn.disabled = active.is_empty()
	for child in _list.get_children():
		child.queue_free()
	for def in GameState.bookmark_defs():
		_list.add_child(_build_bookmark_row(def))


func _build_bookmark_row(def: Dictionary) -> Control:
	var bookmark_id := str(def.get("id", ""))
	var unlocked := GameState.is_bookmark_unlocked(bookmark_id)
	var active := GameState.active_bookmark_id == bookmark_id
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(620, 136)
	row.add_theme_stylebox_override("panel", _panel_style(_school_bg(bookmark_id), _school_color(bookmark_id), 1))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	row.add_child(body)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 6)
	body.add_child(text_box)

	var title := Label.new()
	title.text = "%s  ·  %s" % [_bookmark_title(bookmark_id), _bookmark_school(bookmark_id)]
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", _school_color(bookmark_id).lightened(0.18))
	text_box.add_child(title)

	var desc := Label.new()
	desc.text = _bookmark_description(bookmark_id)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color(0.9, 0.84, 0.68))
	text_box.add_child(desc)

	var req := Label.new()
	req.text = "价格 %d 碎片  ·  图鉴 %d / %d  ·  %s" % [
		int(def.get("cost", 0)),
		GameState.unlocked_codex.size(),
		int(def.get("codex_required", 0)),
		"已启用" if active else ("已解锁" if unlocked else "未解锁"),
	]
	req.add_theme_font_size_override("font_size", 15)
	req.add_theme_color_override("font_color", Color(0.78, 0.72, 0.56))
	text_box.add_child(req)

	var action := Button.new()
	action.custom_minimum_size = Vector2(144, 52)
	_style_button(action)
	if unlocked:
		action.text = "已启用" if active else "启用"
		action.disabled = active
		action.pressed.connect(_activate_bookmark.bind(bookmark_id))
	else:
		action.text = "购买"
		action.disabled = not GameState.can_unlock_bookmark(bookmark_id)
		action.pressed.connect(_buy_bookmark.bind(bookmark_id))
	body.add_child(action)
	return row


func _buy_bookmark(bookmark_id: String) -> void:
	if GameState.unlock_bookmark(bookmark_id):
		SaveSystem.save()
		_message.text = "藏签已收入书房。"
	else:
		_message.text = "碎片或图鉴进度不足。"
	_refresh()


func _activate_bookmark(bookmark_id: String) -> void:
	if GameState.set_active_bookmark(bookmark_id):
		SaveSystem.save()
		_message.text = "藏签已启用，下一局生效。"
	else:
		_message.text = "尚未解锁该藏签。"
	_refresh()


func _on_clear_active() -> void:
	GameState.set_active_bookmark(GameState.BOOKMARK_NONE)
	SaveSystem.save()
	_message.text = "已停用藏签。"
	_refresh()


func _on_fragments_changed(_amount: int) -> void:
	_refresh()


func _on_back() -> void:
	AudioEngine.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _bookmark_title(bookmark_id: String) -> String:
	match bookmark_id:
		GameState.BOOKMARK_RESEARCH:
			return "研读藏签"
		GameState.BOOKMARK_SHAN:
			return "山藏签"
		GameState.BOOKMARK_HAI:
			return "海藏签"
		GameState.BOOKMARK_HUANG:
			return "荒藏签"
		_:
			return "未启用藏签"


func _bookmark_school(bookmark_id: String) -> String:
	match bookmark_id:
		GameState.BOOKMARK_SHAN:
			return "山经"
		GameState.BOOKMARK_HAI:
			return "海经"
		GameState.BOOKMARK_HUANG:
			return "荒经"
		_:
			return "通用"


func _bookmark_description(bookmark_id: String) -> String:
	match bookmark_id:
		GameState.BOOKMARK_RESEARCH:
			return "开局将 1 张「击」替换为「古卷研读」。适合稳定过牌和熟悉图鉴节奏。"
		GameState.BOOKMARK_SHAN:
			return "开局将 1 张「守」替换为「扶桑·朝露」。偏向防御、草木与续航。"
		GameState.BOOKMARK_HAI:
			return "开局将 1 张「守」替换为「文鳐·夕遁」。偏向速度、水族与闪避。"
		GameState.BOOKMARK_HUANG:
			return "开局将 1 张「击」替换为「穷奇·裂风」。偏向爆发、凶兽与压制。"
		_:
			return ""


func _school_color(bookmark_id: String) -> Color:
	match bookmark_id:
		GameState.BOOKMARK_SHAN:
			return Color(0.48, 0.86, 0.48)
		GameState.BOOKMARK_HAI:
			return Color(0.42, 0.78, 1.0)
		GameState.BOOKMARK_HUANG:
			return Color(1.0, 0.52, 0.38)
		_:
			return Color(0.9, 0.72, 0.42)


func _school_bg(bookmark_id: String) -> Color:
	var c := _school_color(bookmark_id)
	return Color(c.r * 0.12, c.g * 0.1, c.b * 0.08, 0.76)


func _panel_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(5)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _style_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color(0.96, 0.87, 0.66))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.76, 0.34))
	button.add_theme_color_override("font_disabled_color", Color(0.52, 0.48, 0.42))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.055, 0.036, 0.82), Color(0.72, 0.52, 0.3, 0.78)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.13, 0.08, 0.04, 0.9), Color(1.0, 0.68, 0.28, 0.95)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.08, 0.12, 0.1, 0.9), Color(0.54, 0.94, 0.82, 0.95)))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.055, 0.045, 0.04, 0.62), Color(0.42, 0.34, 0.24, 0.45)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

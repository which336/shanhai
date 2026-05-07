## MainMenu: main entry for new runs, codex, study room, and quitting.
extends Control

const MENU_BACKGROUND: Texture2D = preload("res://assets/textures/backgrounds/main_menu.png")

@onready var _start_btn: Button = $V/StartButton
@onready var _codex_btn: Button = $V/CodexButton
@onready var _study_btn: Button = $V/StudyButton
@onready var _quit_btn: Button = $V/QuitButton
@onready var _info_label: Label = $V/Info
@onready var _menu: VBoxContainer = $V

var _background_image: TextureRect = null


func _ready() -> void:
	_ensure_background_image()
	_apply_menu_style()
	_layout_menu()
	_start_btn.pressed.connect(_on_start)
	_codex_btn.pressed.connect(_on_codex)
	_study_btn.pressed.connect(_on_study)
	_quit_btn.pressed.connect(_on_quit)

	SaveSystem.load_save()
	_refresh_info()
	AudioEngine.play_bgm("menu")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_menu()


func _ensure_background_image() -> void:
	var old_bg := get_node_or_null("Background")
	if old_bg is CanvasItem:
		(old_bg as CanvasItem).visible = false
	if _background_image != null:
		return
	_background_image = TextureRect.new()
	_background_image.name = "MenuBackgroundImage"
	_background_image.texture = MENU_BACKGROUND
	_background_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background_image)
	move_child(_background_image, 0)


func _apply_menu_style() -> void:
	var title := get_node_or_null("Title")
	if title is CanvasItem:
		(title as CanvasItem).visible = false
	var subtitle := get_node_or_null("Subtitle")
	if subtitle is CanvasItem:
		(subtitle as CanvasItem).visible = false
	var footer := get_node_or_null("Footer")
	if footer is CanvasItem:
		(footer as CanvasItem).visible = false
	_menu.add_theme_constant_override("separation", 10)
	_start_btn.text = "点击开始旅程"
	_codex_btn.text = "山海图鉴"
	_study_btn.text = "祖父书房"
	_quit_btn.text = "离开"
	_menu.move_child(_start_btn, 0)
	_menu.move_child(_codex_btn, 1)
	_menu.move_child(_study_btn, 2)
	_menu.move_child(_quit_btn, 3)
	_menu.move_child(_info_label, 4)
	for button in [_start_btn, _codex_btn, _study_btn, _quit_btn]:
		_style_menu_button(button)
	_info_label.add_theme_font_size_override("font_size", 14)
	_info_label.add_theme_color_override("font_color", Color(0.88, 0.82, 0.7, 0.86))
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _style_menu_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(420, 42)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(0.92, 0.86, 0.74))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.72))
	button.add_theme_color_override("font_pressed_color", Color(0.72, 0.96, 0.9))
	button.add_theme_stylebox_override("normal", _menu_button_style(Color(0.03, 0.04, 0.06, 0.2), Color(0.78, 0.7, 0.55, 0.72), 1))
	button.add_theme_stylebox_override("hover", _menu_button_style(Color(0.05, 0.07, 0.09, 0.36), Color(0.95, 0.82, 0.5, 0.95), 1))
	button.add_theme_stylebox_override("pressed", _menu_button_style(Color(0.04, 0.12, 0.12, 0.42), Color(0.45, 0.95, 0.86, 0.95), 1))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _menu_button_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _layout_menu() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280, 720)
	if _background_image != null:
		_background_image.set_anchors_preset(Control.PRESET_FULL_RECT)
		_background_image.offset_left = 0.0
		_background_image.offset_top = 0.0
		_background_image.offset_right = 0.0
		_background_image.offset_bottom = 0.0
	var menu_width := clampf(viewport_size.x * 0.32, 360.0, 520.0)
	var menu_height := 246.0
	_menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_menu.position = Vector2((viewport_size.x - menu_width) * 0.5, viewport_size.y - menu_height - 34.0)
	_menu.size = Vector2(menu_width, menu_height)
	for button in [_start_btn, _codex_btn, _study_btn, _quit_btn]:
		button.custom_minimum_size = Vector2(menu_width, 42.0)


func _refresh_info() -> void:
	var unlocked: int = GameState.unlocked_codex.size()
	var total: int = max(1, CardDatabase.all_cards().size() + EnemyDatabase.all_enemies().size())
	var bookmark: Dictionary = GameState.active_bookmark_def()
	var bookmark_text: String = str(bookmark.get("title", "未启用藏签")) if not bookmark.is_empty() else "未启用藏签"
	_info_label.text = "山海图鉴：%d / %d  ·  典籍碎片：%d\n当前藏签：%s" % [unlocked, total, GameState.fragments, bookmark_text]


func _on_start() -> void:
	AudioEngine.play_sfx("click")
	RunState.reset_for_new_run("fang_xun")
	randomize()
	RunState.seed_value = randi()
	RunState.map_data = {}
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")


func _on_codex() -> void:
	AudioEngine.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/codex/codex.tscn")


func _on_study() -> void:
	AudioEngine.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/meta/study_room.tscn")


func _on_quit() -> void:
	AudioEngine.play_sfx("click")
	get_tree().quit()

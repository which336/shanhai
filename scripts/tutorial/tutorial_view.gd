## TutorialView: v0.13 小范围外测的轻量新手教程。
extends Control

const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"
const MAP_SCENE: String = "res://scenes/map/map.tscn"

const PAGES: Array[Dictionary] = [
	{
		"title": "探索移动",
		"body": "WASD / 方向键移动，Shift 加速，Tab 切换小地图，K 打开山海图鉴。\n\n地图是连续探索，不是节点列表。靠近事件、宝箱、商店、驿站、敌人或 Boss 会自动触发交互。"
	},
	{
		"title": "双视角与地图节点",
		"body": "按 V 可在顶距和等距视角之间切换。两种视角共用同一张地图和碰撞。\n\n普通敌人用于积累经验；精英和 Boss 会进入卡牌战斗；事件选择会留下终局伏笔。"
	},
	{
		"title": "卡牌战斗",
		"body": "精英和 Boss 使用回合制卡牌战斗。每回合有灵韵，点击手牌即可出牌。\n\n手牌会保留到下回合，抽牌堆用完后弃牌堆会洗回。等级会提高灵韵和摸牌。"
	},
	{
		"title": "图鉴学习",
		"body": "获得或使用卡牌、击败或唤醒异兽会解锁图鉴条目。\n\n打开已解锁条目的详情会标记为已研读。图鉴里的「学习总览」「未研读条目」「终局条件」用于复盘。"
	},
	{
		"title": "事件伏笔与终局",
		"body": "回响事件的选择带有守护、陪伴、实用三类伏笔。\n\n终局固定三档：残响未明、五境净化、山海重明。真结局需要图鉴完成度 >= 60%，且守护 + 陪伴 >= 3。"
	},
]

var _page_index: int = 0
var _root_box: VBoxContainer = null
var _title: Label = null
var _body: RichTextLabel = null
var _page_label: Label = null
var _prev_btn: Button = null
var _next_btn: Button = null
var _start_btn: Button = null
var _back_btn: Button = null


func _ready() -> void:
	GameState.mark_tutorial_seen(false)
	_build_ui()
	_show_page(0)
	AudioEngine.play_bgm("menu")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_back()
		elif event.keycode == KEY_RIGHT:
			_on_next()
		elif event.keycode == KEY_LEFT:
			_on_prev()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.018, 0.028, 0.034, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_root_box = VBoxContainer.new()
	_root_box.name = "TutorialPanel"
	_root_box.set_anchors_preset(Control.PRESET_CENTER)
	_root_box.offset_left = -430
	_root_box.offset_top = -270
	_root_box.offset_right = 430
	_root_box.offset_bottom = 270
	_root_box.add_theme_constant_override("separation", 14)
	add_child(_root_box)

	_title = Label.new()
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	_root_box.add_child(_title)

	_page_label = Label.new()
	_page_label.name = "PageLabel"
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.add_theme_font_size_override("font_size", 16)
	_page_label.add_theme_color_override("font_color", Color(0.72, 0.86, 0.86))
	_root_box.add_child(_page_label)

	_body = RichTextLabel.new()
	_body.name = "Body"
	_body.bbcode_enabled = true
	_body.scroll_active = false
	_body.fit_content = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", 22)
	_body.add_theme_color_override("default_color", Color(0.92, 0.88, 0.75))
	_body.add_theme_stylebox_override("normal", _panel_style())
	_root_box.add_child(_body)

	var controls := HBoxContainer.new()
	controls.name = "Controls"
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	_root_box.add_child(controls)

	_prev_btn = _make_button("上一页")
	_prev_btn.name = "PrevButton"
	_prev_btn.pressed.connect(_on_prev)
	controls.add_child(_prev_btn)

	_next_btn = _make_button("下一页")
	_next_btn.name = "NextButton"
	_next_btn.pressed.connect(_on_next)
	controls.add_child(_next_btn)

	_start_btn = _make_button("开始冒险")
	_start_btn.name = "StartButton"
	_start_btn.pressed.connect(_on_start)
	controls.add_child(_start_btn)

	_back_btn = _make_button("返回主菜单")
	_back_btn.name = "BackButton"
	_back_btn.pressed.connect(_on_back)
	controls.add_child(_back_btn)


func _show_page(index: int) -> void:
	_page_index = clampi(index, 0, PAGES.size() - 1)
	var page: Dictionary = PAGES[_page_index]
	_title.text = str(page.get("title", "新手教程"))
	_page_label.text = "新手教程  %d / %d" % [_page_index + 1, PAGES.size()]
	_body.text = str(page.get("body", ""))
	_prev_btn.disabled = _page_index <= 0
	_next_btn.disabled = _page_index >= PAGES.size() - 1


func _on_prev() -> void:
	if _page_index > 0:
		AudioEngine.play_sfx("click")
		_show_page(_page_index - 1)


func _on_next() -> void:
	if _page_index < PAGES.size() - 1:
		AudioEngine.play_sfx("click")
		_show_page(_page_index + 1)


func _on_start() -> void:
	AudioEngine.play_sfx("click")
	GameState.mark_tutorial_seen()
	RunState.reset_for_new_run(GameState.active_character_id)
	randomize()
	RunState.seed_value = randi()
	RunState.map_data = {}
	get_tree().change_scene_to_file(MAP_SCENE)


func _on_back() -> void:
	AudioEngine.play_sfx("click")
	GameState.mark_tutorial_seen()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(132, 42)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.96, 0.88, 0.64))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.04, 0.08, 0.09, 0.88), Color(0.74, 0.58, 0.32, 0.72)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.07, 0.14, 0.14, 0.94), Color(0.95, 0.78, 0.42, 0.92)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.03, 0.08, 0.09, 0.96), Color(0.98, 0.88, 0.48, 1.0)))
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.028, 0.043, 0.046, 0.84)
	style.border_color = Color(0.65, 0.54, 0.34, 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

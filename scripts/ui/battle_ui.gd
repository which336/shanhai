## BattleUI: 把 BattleManager 的状态绑到屏幕上
## 包含：玩家 HP、灵韵、护盾、手牌、敌人状态、日志、结束回合按钮
extends Control

const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/battle/card_view.tscn")
const AWAKEN_SCENE: PackedScene = preload("res://scenes/awaken/awaken.tscn")
const PixelSprites = preload("res://scripts/map/pixel_sprites.gd")
const BG_ZHUQUE: Texture2D = preload("res://assets/textures/backgrounds/zhuque.png")
const BG_BAIHU: Texture2D = preload("res://assets/textures/backgrounds/baihu.png")
const BG_XUANWU: Texture2D = preload("res://assets/textures/backgrounds/xuanwu.png")
const BG_QINGLONG: Texture2D = preload("res://assets/textures/backgrounds/qinglong.png")
const BG_QILIN: Texture2D = preload("res://assets/textures/backgrounds/qilin.png")

@onready var _battle: Node2D = get_node("../Battle")
@onready var _stage: Control = $BattleStage
@onready var _hp: Label = $TopBar/HP
@onready var _energy: Label = $TopBar/Energy
@onready var _block: Label = $TopBar/Block
@onready var _turn: Label = $TopBar/Turn
@onready var _hand: Control = $HandArea
@onready var _log: RichTextLabel = $LogArea
@onready var _end_turn_btn: Button = $EndTurnButton
@onready var _back_btn: Button = $BackButton
@onready var _result_panel: PanelContainer = $ResultPanel
@onready var _result_label: Label = $ResultPanel/V/ResultLabel
@onready var _result_button: Button = $ResultPanel/V/ResultButton

var _selected_enemy: BattleEnemy = null
var _last_play_time_ms: int = 0     # 防止快速重建 UI 时同一鼠标按下事件触发多次出牌
var _ally_label: Label = null
var _enemy_detail_panel: PanelContainer = null
var _enemy_detail_title: Label = null
var _enemy_detail_body: Label = null
var _hand_status_label: Label = null
var _hand_page_label: Label = null
var _hand_prev_button: Button = null
var _hand_next_button: Button = null
var _hovered_hand_index: int = -1
var _hand_page_index: int = 0
var _hand_tweens: Dictionary = {}
const PLAY_CLICK_THROTTLE_MS: int = 80
const HAND_PAGE_SIZE: int = 10


func _ready() -> void:
	z_index = 100
	_ensure_ally_label()
	_ensure_enemy_detail_panel()
	_ensure_hand_status_label()
	_ensure_hand_page_controls()
	# 兜底：用代码固定关键 UI 区域，避免手写 .tscn 的布局属性在不同窗口/DPI 下失效。
	_fix_runtime_layout()
	# 初始隐藏结果面板
	_result_panel.visible = false
	_result_panel.z_index = 350
	if _stage != null and _stage.has_method("bind_battle"):
		_stage.call("bind_battle", _battle)
	_fix_runtime_layout()
	# 绑信号
	_battle.battle_started.connect(_on_battle_started)
	_battle.turn_changed.connect(_on_turn_changed)
	_battle.battle_won.connect(_on_battle_won)
	_battle.battle_lost.connect(_on_battle_lost)
	_battle.log_message.connect(_append_log)
	_battle.card_played.connect(_on_card_played)
	if _battle.has_signal("ally_changed"):
		_battle.ally_changed.connect(_on_ally_changed)

	RunState.hp_changed.connect(_on_hp_changed)
	RunState.energy_changed.connect(_on_energy_changed)
	_battle.player.block_changed.connect(_on_block_changed)

	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	_back_btn.pressed.connect(_on_back_pressed)
	_result_button.pressed.connect(_on_result_button)

	_refresh_top()
	_rebuild_enemy_list()
	_refresh_hand()
	_refresh_top()
	_on_ally_changed(_battle.get("active_ally"))
	_wait_for_battle_ready()


func _ensure_ally_label() -> void:
	if _ally_label != null:
		return
	_ally_label = Label.new()
	_ally_label.name = "AllyStatus"
	_ally_label.visible = false
	_ally_label.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	_ally_label.add_theme_font_size_override("font_size", 16)
	add_child(_ally_label)


func _ensure_enemy_detail_panel() -> void:
	if _enemy_detail_panel != null:
		return
	_enemy_detail_panel = PanelContainer.new()
	_enemy_detail_panel.name = "EnemyDetailPanel"
	_enemy_detail_panel.visible = false
	_enemy_detail_panel.z_index = 45
	_enemy_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.07, 0.11, 0.92)
	panel_style.border_color = Color(0.52, 0.62, 0.76, 0.85)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	_enemy_detail_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_enemy_detail_panel)

	var v := VBoxContainer.new()
	v.name = "V"
	v.add_theme_constant_override("separation", 4)
	_enemy_detail_panel.add_child(v)

	_enemy_detail_title = Label.new()
	_enemy_detail_title.name = "Title"
	_enemy_detail_title.add_theme_font_size_override("font_size", 16)
	_enemy_detail_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54))
	_enemy_detail_title.clip_text = true
	_enemy_detail_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(_enemy_detail_title)

	_enemy_detail_body = Label.new()
	_enemy_detail_body.name = "Body"
	_enemy_detail_body.add_theme_font_size_override("font_size", 14)
	_enemy_detail_body.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0))
	_enemy_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_enemy_detail_body)


func _ensure_hand_status_label() -> void:
	if _hand_status_label != null:
		return
	_hand_status_label = Label.new()
	_hand_status_label.name = "HandStatus"
	_hand_status_label.z_index = 80
	_hand_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hand_status_label.add_theme_font_size_override("font_size", 15)
	_hand_status_label.add_theme_color_override("font_color", Color(0.94, 0.86, 0.56))
	add_child(_hand_status_label)


func _ensure_hand_page_controls() -> void:
	if _hand_page_label != null:
		return
	_hand_prev_button = Button.new()
	_hand_prev_button.name = "HandPrevPage"
	_hand_prev_button.text = "<"
	_hand_prev_button.focus_mode = Control.FOCUS_NONE
	_hand_prev_button.z_index = 90
	_hand_prev_button.pressed.connect(_on_hand_prev_page)
	add_child(_hand_prev_button)

	_hand_next_button = Button.new()
	_hand_next_button.name = "HandNextPage"
	_hand_next_button.text = ">"
	_hand_next_button.focus_mode = Control.FOCUS_NONE
	_hand_next_button.z_index = 90
	_hand_next_button.pressed.connect(_on_hand_next_page)
	add_child(_hand_next_button)

	_hand_page_label = Label.new()
	_hand_page_label.name = "HandPage"
	_hand_page_label.z_index = 90
	_hand_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hand_page_label.add_theme_font_size_override("font_size", 15)
	_hand_page_label.add_theme_color_override("font_color", Color(0.94, 0.86, 0.56))
	add_child(_hand_page_label)


func _on_ally_changed(ally: Variant) -> void:
	if _ally_label == null:
		return
	if not (ally is Dictionary):
		_ally_label.visible = false
		_ally_label.text = ""
		return
	var d: Dictionary = ally
	if d.is_empty():
		_ally_label.visible = false
		_ally_label.text = ""
		return
	_ally_label.visible = true
	var action: String = str(d.get("last_action", "等待行动"))
	_ally_label.text = "同伴：%s（%d 回合）  %s" % [str(d.get("display_name", "同伴")), int(d.get("turns", 0)), action]


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_fix_runtime_layout()


func _draw() -> void:
	var viewport_size := size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return
	var hand_top := _hand.position.y if _hand != null else viewport_size.y * 0.6
	_draw_chapter_background(viewport_size, 0.0, viewport_size.y)
	_draw_battle_readability_overlays(viewport_size, hand_top)


func _draw_chapter_background(viewport_size: Vector2, stage_top: float, hand_top: float) -> void:
	var chapter := int(RunState.current_chapter_index)
	var bg := _chapter_background_texture(chapter)
	if bg != null:
		var stage_rect := Rect2(Vector2.ZERO, viewport_size)
		_draw_cover_texture(bg, stage_rect, _chapter_background_focus(chapter))
		return
	match chapter:
		RunState.CHAPTER_WEST:
			_draw_west_cliffs(viewport_size, stage_top, hand_top)
		RunState.CHAPTER_NORTH:
			_draw_north_water(viewport_size, stage_top, hand_top)
		RunState.CHAPTER_EAST:
			_draw_east_bamboo(viewport_size, stage_top, hand_top)
		RunState.CHAPTER_CENTRAL:
			_draw_central_altar(viewport_size, stage_top, hand_top)
		_:
			_draw_south_forest(viewport_size, stage_top, hand_top)


func _draw_battle_readability_overlays(viewport_size: Vector2, hand_top: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.0, 0.0, 0.0, 0.22))
	draw_rect(Rect2(0, 0, viewport_size.x, 64.0), Color(0.015, 0.018, 0.03, 0.58))
	draw_rect(Rect2(0, 64.0, viewport_size.x, 92.0), Color(0.0, 0.0, 0.0, 0.18))
	draw_rect(Rect2(0, hand_top - 96.0, viewport_size.x, 96.0), Color(0.0, 0.0, 0.0, 0.18))
	draw_rect(Rect2(0, hand_top, viewport_size.x, viewport_size.y - hand_top), Color(0.025, 0.028, 0.045, 0.62))


func _chapter_background_texture(chapter: int) -> Texture2D:
	match chapter:
		RunState.CHAPTER_WEST:
			return BG_BAIHU
		RunState.CHAPTER_NORTH:
			return BG_XUANWU
		RunState.CHAPTER_EAST:
			return BG_QINGLONG
		RunState.CHAPTER_CENTRAL:
			return BG_QILIN
		_:
			return BG_ZHUQUE


func _chapter_background_focus(chapter: int) -> Vector2:
	match chapter:
		RunState.CHAPTER_WEST:
			return Vector2(0.5, 0.56)
		RunState.CHAPTER_NORTH:
			return Vector2(0.5, 0.5)
		RunState.CHAPTER_EAST:
			return Vector2(0.5, 0.58)
		RunState.CHAPTER_CENTRAL:
			return Vector2(0.5, 0.6)
		_:
			return Vector2(0.5, 0.59)


func _draw_cover_texture(texture: Texture2D, dest: Rect2, focus: Vector2) -> void:
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0 or dest.size.x <= 0.0 or dest.size.y <= 0.0:
		return
	var dest_aspect := dest.size.x / dest.size.y
	var tex_aspect := tex_size.x / tex_size.y
	var source := Rect2(Vector2.ZERO, tex_size)
	if tex_aspect > dest_aspect:
		source.size.x = tex_size.y * dest_aspect
		source.position.x = clampf(tex_size.x * focus.x - source.size.x * 0.5, 0.0, tex_size.x - source.size.x)
	else:
		source.size.y = tex_size.x / dest_aspect
		source.position.y = clampf(tex_size.y * focus.y - source.size.y * 0.5, 0.0, tex_size.y - source.size.y)
	draw_texture_rect_region(texture, dest, source)


func _draw_south_forest(viewport_size: Vector2, stage_top: float, hand_top: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.025, 0.045, 0.055, 1.0))
	draw_rect(Rect2(0, stage_top, viewport_size.x, hand_top - stage_top), Color(0.035, 0.08, 0.065, 0.72))
	draw_circle(Vector2(viewport_size.x * 0.82, stage_top + 52.0), 24.0, Color(0.95, 0.82, 0.48, 0.2))
	_draw_forest_layer(viewport_size, hand_top - 172.0, Color(0.035, 0.105, 0.075, 0.92), 78.0, 54.0)
	_draw_forest_layer(viewport_size, hand_top - 118.0, Color(0.025, 0.08, 0.06, 0.98), 62.0, 68.0)
	_draw_ground_band(viewport_size, hand_top, Color(0.07, 0.105, 0.065, 1.0), Color(0.15, 0.22, 0.13, 0.75))
	for i in 10:
		var x := fposmod(float(i) * 137.0 + 43.0, viewport_size.x)
		var y := stage_top + 86.0 + float(i % 4) * 34.0
		draw_circle(Vector2(x, y), 1.6, Color(0.95, 0.78, 0.38, 0.32))


func _draw_west_cliffs(viewport_size: Vector2, _stage_top: float, hand_top: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.05, 0.045, 0.05, 1.0))
	var horizon := hand_top - 172.0
	_draw_ridge(viewport_size, horizon - 58.0, Color(0.12, 0.1, 0.12, 0.95), 90.0)
	_draw_ridge(viewport_size, horizon + 12.0, Color(0.17, 0.13, 0.11, 0.98), 64.0)
	_draw_ground_band(viewport_size, hand_top, Color(0.16, 0.12, 0.09, 1.0), Color(0.55, 0.36, 0.18, 0.55))


func _draw_north_water(viewport_size: Vector2, _stage_top: float, hand_top: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.025, 0.055, 0.09, 1.0))
	var water_top := hand_top - 154.0
	_draw_ridge(viewport_size, water_top - 54.0, Color(0.055, 0.09, 0.13, 0.92), 74.0)
	draw_rect(Rect2(0, water_top, viewport_size.x, hand_top - water_top), Color(0.04, 0.12, 0.16, 0.9))
	for i in 9:
		var y := water_top + 20.0 + float(i) * 18.0
		draw_line(Vector2(40.0 + float(i % 2) * 32.0, y), Vector2(viewport_size.x - 70.0, y + 4.0), Color(0.28, 0.56, 0.62, 0.18), 2.0)
	_draw_ground_band(viewport_size, hand_top, Color(0.045, 0.08, 0.095, 1.0), Color(0.26, 0.58, 0.66, 0.42))


func _draw_east_bamboo(viewport_size: Vector2, stage_top: float, hand_top: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.045, 0.065, 0.07, 1.0))
	_draw_bamboo_layer(viewport_size, stage_top + 46.0, hand_top - 34.0, Color(0.08, 0.18, 0.11, 0.7))
	_draw_ridge(viewport_size, hand_top - 185.0, Color(0.08, 0.14, 0.1, 0.9), 54.0)
	_draw_ground_band(viewport_size, hand_top, Color(0.08, 0.17, 0.08, 1.0), Color(0.48, 0.67, 0.23, 0.45))


func _draw_central_altar(viewport_size: Vector2, _stage_top: float, hand_top: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.045, 0.042, 0.06, 1.0))
	var center := Vector2(viewport_size.x * 0.5, hand_top - 112.0)
	draw_circle(center, 150.0, Color(0.16, 0.13, 0.18, 0.65))
	draw_circle(center, 90.0, Color(0.24, 0.2, 0.16, 0.5))
	_draw_ridge(viewport_size, hand_top - 208.0, Color(0.08, 0.075, 0.095, 0.9), 78.0)
	_draw_ground_band(viewport_size, hand_top, Color(0.095, 0.08, 0.105, 1.0), Color(0.62, 0.5, 0.2, 0.5))


func _draw_forest_layer(viewport_size: Vector2, base_y: float, color: Color, step: float, height: float) -> void:
	var x := -step
	while x < viewport_size.x + step:
		var top := base_y - height - fposmod(x * 0.37, 28.0)
		draw_rect(Rect2(x + step * 0.42, top + height * 0.45, 6.0, height * 0.7), color.darkened(0.32))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, base_y), Vector2(x + step * 0.5, top), Vector2(x + step, base_y)
		]), color)
		x += step


func _draw_bamboo_layer(viewport_size: Vector2, top_y: float, bottom_y: float, color: Color) -> void:
	var x := 24.0
	while x < viewport_size.x:
		draw_line(Vector2(x, bottom_y), Vector2(x + 18.0, top_y), color, 3.0)
		draw_line(Vector2(x + 12.0, bottom_y - 58.0), Vector2(x + 48.0, bottom_y - 96.0), color.lightened(0.12), 2.0)
		x += 54.0


func _draw_ridge(viewport_size: Vector2, base_y: float, color: Color, height: float) -> void:
	var points := PackedVector2Array()
	points.append(Vector2(0, base_y + height))
	for i in 7:
		var x := viewport_size.x * float(i) / 6.0
		var y := base_y - (height * (0.35 + 0.55 * absf(sin(float(i) * 1.47))))
		points.append(Vector2(x, y))
	points.append(Vector2(viewport_size.x, base_y + height))
	draw_colored_polygon(points, color)


func _draw_ground_band(viewport_size: Vector2, hand_top: float, fill: Color, line: Color) -> void:
	draw_rect(Rect2(0, hand_top - 70.0, viewport_size.x, 70.0), fill)
	draw_line(Vector2(0, hand_top - 10.0), Vector2(viewport_size.x, hand_top - 10.0), line, 2.0)


func _fix_runtime_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = Vector2(1280, 720)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = viewport_size
	offset_left = 0
	offset_top = 0
	offset_right = viewport_size.x
	offset_bottom = viewport_size.y

	var hand_h: float = clampf(viewport_size.y * 0.24, 150.0, 220.0)
	var stage_top: float = 56.0
	var stage_h: float = maxf(220.0, viewport_size.y - hand_h - 88.0)

	if _stage != null:
		_stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_stage.position = Vector2(16, stage_top)
		_stage.size = Vector2(maxf(640.0, viewport_size.x - 32.0), stage_h)
		_stage.z_index = 10

	$TopBar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	$TopBar.position = Vector2(16, 12)
	$TopBar.size = Vector2(maxf(760, viewport_size.x - 180), 36)

	_hand.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hand.position = Vector2(16, viewport_size.y - hand_h - 16.0)
	_hand.size = Vector2(maxf(640, viewport_size.x - 32), hand_h)
	_hand.clip_contents = false
	_hand.z_index = 30

	var info_h: float = minf(176.0, maxf(128.0, stage_h - 52.0))

	_log.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_log.position = Vector2(16, 64)
	_log.size = Vector2(clampf(viewport_size.x * 0.22, 260.0, 340.0), info_h)

	if _ally_label != null:
		_ally_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_ally_label.position = Vector2(16, 42)
		_ally_label.size = Vector2(maxf(520, viewport_size.x - 420), 24)

	if _enemy_detail_panel != null:
		var detail_y: float = 92.0
		var detail_h: float = clampf(stage_top + stage_h - detail_y - 12.0, 104.0, 176.0)
		_enemy_detail_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_enemy_detail_panel.position = Vector2(maxf(520, viewport_size.x - 300), detail_y)
		_enemy_detail_panel.size = Vector2(284, detail_h)

	if _hand_status_label != null:
		_hand_status_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_hand_status_label.position = Vector2(16, _hand.position.y - 28.0)
		_hand_status_label.size = Vector2(maxf(520, viewport_size.x - 380), 24)

	if _hand_page_label != null:
		var page_x: float = maxf(640.0, viewport_size.x - 196.0)
		var page_y: float = _hand.position.y - 14.0
		_hand_prev_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_hand_prev_button.position = Vector2(page_x, page_y)
		_hand_prev_button.size = Vector2(34, 26)
		_hand_page_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_hand_page_label.position = Vector2(page_x + 38.0, page_y + 2.0)
		_hand_page_label.size = Vector2(68, 22)
		_hand_next_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_hand_next_button.position = Vector2(page_x + 110.0, page_y)
		_hand_next_button.size = Vector2(34, 26)

	_end_turn_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_end_turn_btn.position = Vector2(maxf(520, viewport_size.x - 208), _hand.position.y - 58.0)
	_end_turn_btn.size = Vector2(180, 42)

	_back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_back_btn.position = Vector2(maxf(640, viewport_size.x - 140), 12)
	_back_btn.size = Vector2(124, 34)
	_layout_hand(_hovered_hand_index, false)
	queue_redraw()


# ========== 信号回调 ==========

func _on_battle_started() -> void:
	_rebuild_enemy_list()
	_refresh_hand()
	_refresh_top()
	_on_ally_changed(_battle.get("active_ally"))


## BattleManager 使用 call_deferred 初始化；如果 UI 的 _ready 先跑完，
## 第一次刷新会拿不到 deck/enemies。这里主动等到战斗数据就绪后再刷新一次。
func _wait_for_battle_ready() -> void:
	for i in 30:
		if _battle.deck != null and _battle.enemies_container.get_child_count() > 0:
			_rebuild_enemy_list()
			_refresh_hand()
			_refresh_top()
			_append_log("[color=#9bd]战斗界面已就绪：点击下方卡牌即可出牌，右上角可返回。[/color]")
			if RunState.last_battle_was_boss:
				_append_log("[color=#e6c97a][b]BOSS 战：[/b]普通卡会进入弃牌堆并循环；只有写明“消耗”的卡才会临时进入消耗堆。[/color]")
			return
		await get_tree().process_frame
	_append_log("[color=#e99]战斗初始化超时，请查看输出面板。[/color]")


func _on_turn_changed(is_player: bool, turn_no: int) -> void:
	_turn.text = "第 %d 回合 · %s" % [turn_no, "你的回合" if is_player else "对手回合"]
	_end_turn_btn.disabled = not is_player
	_rebuild_enemy_list()
	_refresh_hand()
	_refresh_top()
	_refresh_hand_status()
	_on_ally_changed(_battle.get("active_ally"))


func _on_card_played(_card: Card, _target: BattleEnemy) -> void:
	_refresh_hand()
	_refresh_top()
	_rebuild_enemy_list()
	_refresh_hand_status()
	_on_ally_changed(_battle.get("active_ally"))


func _on_hp_changed(hp: int, mx: int) -> void:
	_hp.text = "气血 %d / %d" % [hp, mx]


func _on_energy_changed(en: int, mx: int) -> void:
	_energy.text = "灵韵 %d / %d" % [en, mx]


func _on_block_changed(b: int) -> void:
	_block.text = "护盾 %d" % b


func _on_battle_won() -> void:
	# 寻找有 awaken_options 的敌人，依次进入"唤醒"小游戏
	var awakable: Array[BattleEnemy] = []
	for c in _battle.enemies_container.get_children():
		if c is BattleEnemy and c.data != null and c.data.awaken_options.size() > 0:
			awakable.append(c)
	if awakable.is_empty():
		_show_result(true)
		return
	_run_awaken_chain(awakable, 0)


func _run_awaken_chain(list: Array[BattleEnemy], idx: int) -> void:
	if idx >= list.size():
		_show_result(true)
		return
	var aw: AwakenView = AWAKEN_SCENE.instantiate()
	aw.z_index = 400
	aw.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(aw)
	aw.setup(list[idx].data)
	aw.closed.connect(func ():
		aw.queue_free()
		_run_awaken_chain(list, idx + 1)
	)


func _on_battle_lost() -> void:
	_show_result(false)


func _show_result(win: bool) -> void:
	_result_panel.visible = true
	RunState.last_battle_won = win
	if win:
		_result_label.text = "胜利！\n你又唤醒了一缕被遗忘的灵韵。"
		_result_button.text = "返回地图"
		AudioEngine.play_sfx("battle_win")
		SaveSystem.save()
	else:
		_result_label.text = "你被忘川带回了……\n但你拾到的图鉴页都已留下。"
		_result_button.text = "返回主菜单"
		AudioEngine.play_sfx("die")
		# 失败：清空 map_data，下次再来重新生成
		RunState.map_data = {}
		SaveSystem.save()


func _on_result_button() -> void:
	# 失败时回主菜单（map_data 已被 _show_result 清空）；胜利回地图
	if RunState.is_dead():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/map/map.tscn")


func _on_end_turn_pressed() -> void:
	_battle.end_player_turn()


func _on_back_pressed() -> void:
	# 主动放弃这场战斗：不算胜利，节点保留
	RunState.last_battle_won = false
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")


# ========== 刷新 ==========

func _refresh_top() -> void:
	_hp.text = "气血 %d / %d" % [RunState.hp, RunState.max_hp]
	_energy.text = "灵韵 %d / %d" % [RunState.energy, RunState.max_energy]
	_block.text = "护盾 %d" % _battle.player.block
	_turn.text = "第 %d 回合 · %s" % [_battle.turn_number, "你的回合" if _battle.is_player_turn else "对手回合"]
	if not _battle.is_player_turn:
		_turn.text = "第 %d 回合 · 敌方行动" % _battle.turn_number
	_end_turn_btn.disabled = not _battle.is_player_turn


func _refresh_hand() -> void:
	# 清空当前的卡视图。用 queue_free 避免在卡牌自己的点击回调栈里立即 free 自己。
	for c in _hand.get_children():
		if c is Control:
			var old_view: Control = c
			old_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			old_view.visible = false
		c.queue_free()
	_hand_tweens.clear()
	_hovered_hand_index = -1
	if _battle.deck == null:
		return
	_clamp_hand_page()
	var start_index: int = _hand_page_index * HAND_PAGE_SIZE
	var end_index: int = mini(start_index + HAND_PAGE_SIZE, _battle.deck.hand.size())
	for i in range(start_index, end_index):
		var local_index: int = i - start_index
		var card: Card = _battle.deck.hand[i]
		var view: CardView = CARD_VIEW_SCENE.instantiate()
		_hand.add_child(view)
		view.setup(card, i, _battle.effective_card_cost(card))
		view.set_fan_expanded(false)
		view.play_requested.connect(_on_card_view_play_requested)
		view.mouse_entered.connect(_on_hand_card_hovered.bind(local_index))
		view.mouse_exited.connect(_on_hand_card_unhovered.bind(local_index))
	_layout_hand(_hovered_hand_index, false)
	_refresh_hand_status()
	_refresh_top()


func _refresh_hand_status() -> void:
	if _hand_status_label == null:
		return
	var hand_count: int = _battle.deck.hand.size() if _battle != null and _battle.deck != null else 0
	var page_suffix := ""
	if _hand_page_count() > 1:
		page_suffix = " · 当前显示 %d-%d" % [_hand_page_index * HAND_PAGE_SIZE + 1, mini((_hand_page_index + 1) * HAND_PAGE_SIZE, hand_count)]
	_hand_status_label.text = "手牌 %d · 无上限，回合间保留%s" % [hand_count, page_suffix]
	_hand_status_label.add_theme_color_override("font_color", Color(0.94, 0.86, 0.56))
	_refresh_hand_page_controls()


func _hand_page_count() -> int:
	var hand_count: int = _battle.deck.hand.size() if _battle != null and _battle.deck != null else 0
	return maxi(1, int(ceil(float(hand_count) / float(HAND_PAGE_SIZE))))


func _clamp_hand_page() -> void:
	_hand_page_index = clampi(_hand_page_index, 0, _hand_page_count() - 1)


func _refresh_hand_page_controls() -> void:
	if _hand_page_label == null:
		return
	_clamp_hand_page()
	var page_count := _hand_page_count()
	var show_pages := page_count > 1
	_hand_prev_button.visible = show_pages
	_hand_next_button.visible = show_pages
	_hand_page_label.visible = show_pages
	_hand_page_label.text = "%d / %d" % [_hand_page_index + 1, page_count]
	_hand_prev_button.disabled = _hand_page_index <= 0
	_hand_next_button.disabled = _hand_page_index >= page_count - 1


func _on_hand_prev_page() -> void:
	_hand_page_index = maxi(0, _hand_page_index - 1)
	_refresh_hand()


func _on_hand_next_page() -> void:
	_hand_page_index = mini(_hand_page_count() - 1, _hand_page_index + 1)
	_refresh_hand()


func _on_hand_card_hovered(index: int) -> void:
	_hovered_hand_index = index
	_layout_hand(index, true)


func _on_hand_card_unhovered(index: int) -> void:
	if _hovered_hand_index != index:
		return
	_hovered_hand_index = -1
	_layout_hand(-1, true)


func _layout_hand(focused_index: int = -1, animate: bool = true) -> void:
	if _hand == null:
		return
	var cards: Array[CardView] = []
	for child in _hand.get_children():
		if child is CardView:
			cards.append(child)
	var count := cards.size()
	if count <= 0:
		return
	var collapsed := CardView.FAN_COLLAPSED_SIZE
	var expanded := CardView.FAN_EXPANDED_SIZE
	var center_x := _hand.size.x * 0.5
	var base_y := maxf(4.0, _hand.size.y - collapsed.y + 64.0)
	var spread := clampf(_hand.size.x / maxf(1.0, float(count)) * 0.42, 38.0, 74.0)
	if focused_index >= 0:
		spread = maxf(spread, expanded.x * 0.48)
	for i in count:
		var card := cards[i]
		var rel := float(i) - float(count - 1) * 0.5
		var expanded_now := i == focused_index
		var x := center_x + rel * spread - collapsed.x * 0.5
		var y := base_y + absf(rel) * 5.0
		var rot := deg_to_rad(rel * 3.2)
		if focused_index >= 0:
			var direction := 0
			if i < focused_index:
				direction = -1
			elif i > focused_index:
				direction = 1
			if direction != 0:
				x += float(direction) * expanded.x * 0.44
			if expanded_now:
				x = clampf(center_x + rel * spread - expanded.x * 0.5, 12.0, _hand.size.x - expanded.x - 12.0)
				y = maxf(0.0, _hand.size.y - expanded.y - 2.0)
				rot = 0.0
			else:
				y += 44.0
		card.set_fan_expanded(expanded_now)
		card.pivot_offset = card.size * 0.5
		card.z_index = 100 + i + (100 if expanded_now else 0)
		_move_hand_card(card, Vector2(x, y), rot, animate)


func _move_hand_card(card: CardView, target_pos: Vector2, target_rot: float, animate: bool) -> void:
	if card == null or not is_instance_valid(card):
		return
	if _hand_tweens.has(card):
		var old: Tween = _hand_tweens[card]
		if old != null:
			old.kill()
	if not animate:
		card.position = target_pos
		card.rotation = target_rot
		return
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hand_tweens[card] = tw
	tw.tween_property(card, "position", target_pos, 0.12)
	tw.tween_property(card, "rotation", target_rot, 0.12)


func _on_card_view_play_requested(view: CardView) -> void:
	# 防护 1：view 必须仍然有效
	if view == null or not is_instance_valid(view):
		return
	if view.card == null:
		return
	var card: Card = view.card
	var hand_index: int = view.hand_index
	# 防护 2：手牌下标必须仍然有效，且该位置仍是这张卡
	if _battle.deck == null or hand_index < 0 or hand_index >= _battle.deck.hand.size():
		return
	if _battle.deck.hand[hand_index] != card:
		return
	# 防护 3：必须是玩家回合
	if not _battle.is_player_turn:
		return
	# 防护 4：节流，避免在 UI 重建瞬间被同一次鼠标按下触发多次。
	# 放在有效性检查之后，避免旧 view 的无效信号吞掉下一次正常点击。
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_play_time_ms < PLAY_CLICK_THROTTLE_MS:
		return
	_last_play_time_ms = now_ms
	# 灵韵不足：日志 + 屏幕中央醒目提示
	var effective_cost: int = _battle.effective_card_cost(card)
	if RunState.energy < effective_cost:
		_append_log("[color=#e8a060][b]灵韵不足[/b]：吟咏 [color=#e6c97a]%s[/color] 需要 %d 灵韵，当前 %d。[/color]" % [card.title, effective_cost, RunState.energy])
		_show_toast("灵韵不足！(%d / %d)" % [RunState.energy, effective_cost])
		return
	# 选目标
	var target: BattleEnemy = null
	if card.requires_target:
		target = _selected_enemy
		if target == null or target.is_dead():
			for c in _battle.enemies_container.get_children():
				if c is BattleEnemy and not c.is_dead():
					target = c
					break
	_battle.play_card_at_index(hand_index, target)


func _rebuild_enemy_list() -> void:
	if _selected_enemy == null or _selected_enemy.is_dead():
		_selected_enemy = _first_alive_enemy()
	_refresh_enemy_detail()


func _first_alive_enemy() -> BattleEnemy:
	if _battle == null or _battle.enemies_container == null:
		return null
	for enemy_node in _battle.enemies_container.get_children():
		if enemy_node is BattleEnemy and not enemy_node.is_dead():
			return enemy_node
	return null


func _enemy_intent_tag(enemy: BattleEnemy) -> String:
	var it: EnemyData.Intent = enemy.current_intent
	if it == null or enemy.is_dead():
		return ""
	match it.kind:
		EnemyData.IntentKind.ATTACK:
			var actual: int = StatusEffect.calc_damage_modifier(enemy.statuses, _battle.player.statuses, it.amount)
			if actual != it.amount:
				return " · 将攻击 %d->%d" % [it.amount, actual]
			return " · 将攻击 %d" % it.amount
		EnemyData.IntentKind.BLOCK:
			return " · 守护 %d" % it.amount
		EnemyData.IntentKind.BUFF:
			return " · 强化"
		EnemyData.IntentKind.DEBUFF:
			return " · 施加易伤"
		_:
			return ""


func _refresh_enemy_detail() -> void:
	if _enemy_detail_panel == null or _enemy_detail_title == null or _enemy_detail_body == null:
		return
	if _selected_enemy == null or _selected_enemy.data == null:
		_enemy_detail_panel.visible = false
		return
	var enemy := _selected_enemy
	_enemy_detail_panel.visible = true
	var tags: PackedStringArray = PackedStringArray()
	if enemy.data.is_boss:
		tags.append("BOSS")
	if enemy.data.is_elite:
		tags.append("精英")
	if enemy.is_dead():
		tags.append("已化散")
	_enemy_detail_title.text = enemy.data.display_name + (" · " + " / ".join(tags) if not tags.is_empty() else "")
	var statuses: PackedStringArray = PackedStringArray()
	for sid in enemy.statuses.keys():
		var sid_str: String = sid
		statuses.append("%s x%d" % [StatusEffect.display_name(sid_str), int(enemy.statuses[sid_str])])
	_enemy_detail_body.text = "HP %d / %d    护盾 %d\n意图：%s\n状态：%s" % [
		enemy.hp,
		enemy.max_hp,
		enemy.block,
		_enemy_intent_detail(enemy),
		"、".join(statuses) if statuses.size() > 0 else "—",
	]


func _enemy_intent_detail(enemy: BattleEnemy) -> String:
	var it: EnemyData.Intent = enemy.current_intent
	if it == null or enemy.is_dead():
		return "—"
	match it.kind:
		EnemyData.IntentKind.ATTACK:
			var actual: int = StatusEffect.calc_damage_modifier(enemy.statuses, _battle.player.statuses, it.amount)
			if actual != it.amount:
				return "将攻击 %d -> %d" % [it.amount, actual]
			return "将攻击 %d" % it.amount
		EnemyData.IntentKind.BLOCK:
			return "自我守护 %d" % it.amount
		EnemyData.IntentKind.BUFF:
			return "自我强化"
		EnemyData.IntentKind.DEBUFF:
			return "施加易伤"
		_:
			return "踟蹰"


func _on_enemy_row_input(event: InputEvent, enemy: BattleEnemy) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selected_enemy = enemy
		_rebuild_enemy_list()


func _enemy_portrait_texture(enemy: BattleEnemy) -> Texture2D:
	if enemy == null or enemy.data == null:
		return null
	var key: String = _enemy_portrait_key(enemy)
	if key.is_empty():
		return null
	return PixelSprites.texture(key, PixelSprites.DIR_DOWN, 0)


func _enemy_portrait_key(enemy: BattleEnemy) -> String:
	var enemy_id: String = enemy.data.id
	match enemy_id:
		"he_luo_fish":
			return "enemy.he_luo_fish"
		"fei_yi":
			return "enemy.fei_yi"
		"zhuhuai":
			return "enemy.zhuhuai"
		"xiao_beast":
			return "enemy.xiao_beast"
		"dang_kang":
			return "enemy.dang_kang"
		"qiu_yu":
			return "enemy.qiu_yu"
		"ling_ling":
			return "enemy.ling_ling"
		"zhu_ru":
			return "enemy.zhu_ru"
		"kui":
			return "enemy.kui"
		"tu_lou":
			return "enemy.tu_lou"
		"jiao_beast":
			return "enemy.jiao_beast"
		"wen_lin":
			return "enemy.wen_lin"
		"elite_xiangliu_shadow":
			return "elite_xiangliu_shadow"
		"elite_yinglong_young":
			return "elite_yinglong_young"
		"elite_ji_meng":
			return "elite_ji_meng"
		"boss_zhulong_weak", "boss_zhulong", "boss_zhulong_strong":
			return enemy_id
		"boss_qinglong_weak", "boss_qinglong", "boss_qinglong_strong":
			return enemy_id
		"boss_qilin_weak", "boss_qilin", "boss_qilin_strong":
			return enemy_id
		"boss_bifang_weak":
			return "boss_weak"
		"boss_bifang":
			return "boss_mid"
		"boss_bifang_strong":
			return "boss_hard"
		_:
			if enemy.data.is_boss:
				return enemy_id
			if enemy.data.is_elite:
				return "elite_yingzhao" if enemy_id == "elite_yingzhao" else "elite"
			return "enemy." + enemy_id


func _append_log(text: String) -> void:
	_log.append_text(text + "\n")


## 屏幕中央短暂提示，1 秒后消失
func _show_toast(text: String) -> void:
	var toast := Label.new()
	toast.text = text
	toast.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	toast.add_theme_font_size_override("font_size", 32)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	toast.size = Vector2(400, 60)
	toast.position = -toast.size * 0.5 + Vector2(0, -40)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.z_index = 200
	add_child(toast)
	var tw := create_tween()
	tw.tween_property(toast, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.tween_callback(toast.queue_free)

## Roguelike 探索地图（大地图 + 相机跟随 + 小地图）
## - 96 × 60 网格（约当前 20 倍），玩家用 WASD/方向键自由探索
## - Camera2D 跟随玩家，自动 clamp 在地图边界内；只渲染视野内格子，性能稳定
## - 左上角小地图实时显示玩家与实体位置；Tab 键切换显隐
## - 每次开局随机生成：岩石分布、敌人位置、3 个 BOSS 强弱不同
## - 等距素材 (2DPIXX): Jana Ochse, www.2dpixx.de, CC BY 4.0
extends Node2D

# ===== 地图尺寸（约当前 20 倍）=====
const TILE_SIZE: int = 48
const WORLD_W: int = 96
const WORLD_H: int = 60
const WORLD_PIXEL_W: int = TILE_SIZE * WORLD_W   # 4608
const WORLD_PIXEL_H: int = TILE_SIZE * WORLD_H   # 2880

const VIEWPORT_W: int = 1280
const VIEWPORT_H: int = 720

# ===== 颜色板 =====
const COLOR_BG: Color = Color(0.06, 0.075, 0.12)
const COLOR_GRASS_A: Color = Color(0.16, 0.30, 0.18)
const COLOR_GRASS_B: Color = Color(0.13, 0.26, 0.15)
const COLOR_GRASS_DARK: Color = Color(0.10, 0.20, 0.12)
const COLOR_ROCK: Color = Color(0.32, 0.28, 0.24)
const COLOR_ROCK_HI: Color = Color(0.45, 0.40, 0.34)
const COLOR_FLOWER: Color = Color(0.78, 0.62, 0.30)   # 暗金黄，避免视觉刺激
const COLOR_BORDER: Color = Color(0.45, 0.36, 0.20, 0.35)

const COLOR_PLAYER: Color = Color(1.00, 0.85, 0.40)
const COLOR_ENEMY: Color = Color(0.85, 0.40, 0.40)
const COLOR_ELITE: Color = Color(0.95, 0.55, 0.25)
const COLOR_BOSS_WEAK: Color = Color(0.60, 0.30, 0.65)
const COLOR_BOSS_MID: Color = Color(0.78, 0.30, 0.78)
const COLOR_BOSS_HARD: Color = Color(0.95, 0.20, 0.55)
const COLOR_SHOP: Color = Color(0.40, 0.78, 0.70)
const COLOR_REST: Color = Color(0.55, 0.65, 0.92)
const COLOR_TREASURE: Color = Color(0.95, 0.78, 0.30)
const COLOR_EVENT: Color = Color(0.85, 0.55, 0.25)
const COLOR_FRAGMENT: Color = Color(1.0, 0.95, 0.55)

var data: Dictionary = {}
var pending_entity: Dictionary = {}
var _decoration_seed: int = 0
var _camera: Camera2D = null
var _font: Font = null
var _minimap_visible: bool = true
var _palette: Dictionary = {}
var _time_acc: float = 0.0

# === 连续移动 ===
const PLAYER_SPEED: float = 220.0   # 像素 / 秒
const ENEMY_SPEED: float = 90.0     # 像素 / 秒（小怪比玩家慢）
const PLAYER_ATTACK_RANGE: float = 38.0
const PLAYER_ATTACK_RATE: float = 0.45  # 秒
const PLAYER_BASE_DAMAGE: int = 3
const ENEMY_ATTACK_RATE: float = 0.65
const ENEMY_HP_DEFAULT: int = 8
const ENEMY_ATK_DEFAULT: int = 2
const ENEMY_AGGRO_RANGE: int = 7        # 格

const PLAYER_COLLISION_RADIUS_TOP: float = TILE_SIZE * 0.36
const PLAYER_COLLISION_RADIUS_ISO: float = TILE_SIZE * 0.34

var _player_pixel: Vector2 = Vector2.ZERO
var _last_grid: Vector2i = Vector2i(-1, -1)
var _last_safe_grid: Vector2i = Vector2i.ZERO
var _facing: Vector2i = Vector2i(1, 0)
var _player_attack_cd: float = 0.0
var _hit_flash: float = 0.0      # 玩家受击红屏 alpha
var _floating_texts: Array = []  # [{text, color, world_pos, age}]

# === 像素动画 ===
const ANIM_INTERVAL: float = 0.28
var _anim_timer: float = 0.0
var _anim_frame: int = 0
var _was_moving: bool = false
var _enemy_facing: Dictionary = {}  # enemy_id -> Vector2i

# === 双视角模式 ===
enum ViewMode { TOP_DOWN, ISOMETRIC }
var _view_mode: ViewMode = ViewMode.TOP_DOWN
# 等距 tile 尺寸（1:1 宽高比，匹配 tilesheet 128×128 菱形）
const ISO_TILE_W: int = 128
const ISO_TILE_H: int = 128
const ISO_HALF_W: int = 64
const ISO_HALF_H: int = 32
const ISO_FLOOR_H: int = 64
const ISO_CAMERA_ZOOM: float = 1.55
const ISO_ENEMY_SPRITE_SCALE: float = 1.42
const WARRIOR_TOP_SCALE: float = 0.52
const WARRIOR_ISO_SCALE: float = 0.72
const ISO_VISUAL_GROUND_PADDING: int = 8
const ISO_FLOOR_TILESET_NAME: String = "forest"
const ISO_WALL_TILESET_NAME: String = "village"
# 等距世界像素边界（动态计算）
var _iso_world_w: int = 0
var _iso_world_h: int = 0
var _iso_smooth_pos: Vector2 = Vector2.ZERO  # 等距平滑移动位置

# === 商店运行时状态 ===
var _shop_items: Array = []
var _shop_buttons: Array = []
var _shop_title: String = "古玩铺"
var _shop_story: String = "店主戴狐面具，玻璃柜中陈列着几样东西。"
var _shop_last_result: String = ""
var _shop_entity: Dictionary = {}
var _shop_entity_id: String = ""
var _shop_items_by_entity_id: Dictionary = {}
var _pending_reset_map: bool = false
var _pending_chapter_advance: bool = false
var _debug_chapter_toggle: Button = null
var _debug_chapter_picker: HBoxContainer = null
var _debug_tool_picker: HBoxContainer = null

@onready var _title: Label = $UI/Title
@onready var _hint: Label = $UI/Hint
@onready var _status: Label = $UI/Status
@onready var _back_btn: Button = $UI/BackButton
@onready var _confirm: PanelContainer = $UI/ConfirmPanel
@onready var _confirm_text: Label = $UI/ConfirmPanel/V/Text
@onready var _confirm_yes: Button = $UI/ConfirmPanel/V/H/Yes
@onready var _confirm_no: Button = $UI/ConfirmPanel/V/H/No
@onready var _victory: PanelContainer = $UI/VictoryPanel
@onready var _victory_text: Label = $UI/VictoryPanel/V/Text
@onready var _victory_btn: Button = $UI/VictoryPanel/V/Button
@onready var _minimap_panel: PanelContainer = $UI/MiniMapPanel
@onready var _minimap: Control = $UI/MiniMapPanel/MiniMap
@onready var _hit_flash_ui: ColorRect = $UI/HitFlash
@onready var _event_panel: PanelContainer = $UI/EventPanel
@onready var _event_title: Label = $UI/EventPanel/V/Title
@onready var _event_body: Label = $UI/EventPanel/V/Body
@onready var _event_options: VBoxContainer = $UI/EventPanel/V/Options


func _ready() -> void:
	position = Vector2.ZERO
	_palette = PixelSprites.palette()
	_setup_font()
	_setup_camera()
	AudioEngine.play_bgm("map")
	_back_btn.pressed.connect(_on_back)
	_confirm_yes.pressed.connect(_on_confirm_yes)
	_confirm_no.pressed.connect(_on_confirm_no)
	_victory_btn.pressed.connect(_on_victory_close)
	_setup_debug_chapter_controls()
	_confirm.visible = false
	_victory.visible = false

	if RunState.map_data.is_empty():
		data = _generate_map()
		RunState.map_data = data
	else:
		data = RunState.map_data
		_apply_chapter_visual_overrides()
		RunState.map_data = data

	if RunState.last_entity_id != "":
		var was_boss: bool = RunState.last_battle_was_boss
		# 在移除 entity 前先记下 kind / name 用于后续奖励和文案
		var beaten_kind: String = ""
		var beaten_name: String = ""
		var beaten_enemy_count: int = 1
		for e in data["entities"]:
			if str(e["id"]) == RunState.last_entity_id:
				beaten_kind = str(e["kind"])
				beaten_name = str(e.get("name", ""))
				beaten_enemy_count = maxi(1, Array(e.get("enemies", [])).size())
				break
		if RunState.last_battle_won:
			_remove_entity(RunState.last_entity_id)
			if was_boss:
				RunState.bosses_defeated += 1
				_grant_boss_reward(beaten_kind)
				_show_boss_victory(beaten_kind, beaten_name)
			else:
				var reward: Dictionary = _grant_non_boss_battle_reward(beaten_kind, beaten_enemy_count)
				if not reward.is_empty():
					_add_floating_text(_player_pixel + Vector2(0, -50), str(reward.get("text", "")), Color(1.0, 0.95, 0.55))
					_show_non_boss_battle_result(beaten_kind, beaten_name, reward)
		RunState.last_entity_id = ""
		RunState.last_battle_was_boss = false
		RunState.last_battle_won = false

	_title.text = _chapter_title()
	_minimap.draw.connect(_draw_minimap)
	_minimap_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_minimap_panel.position = Vector2(8, 8)
	RunState.hp_changed.connect(func(_a, _b): _update_status())
	RunState.exp_changed.connect(func(_a, _b): _update_status())
	RunState.level_up.connect(func(_lv): _update_status())

	# 把玩家放在格子中心，开启连续移动
	_player_pixel = _grid_center_pixel(Vector2i(data["player"]))
	_last_grid = Vector2i(data["player"])
	_last_safe_grid = _last_grid
	_view_mode = ViewMode.ISOMETRIC if RunState.map_view_mode == 1 else ViewMode.TOP_DOWN
	if _view_mode == ViewMode.ISOMETRIC:
		_update_iso_world_bounds()
		_iso_smooth_pos = _top_down_pixel_to_iso(_player_pixel)

	# 给所有小怪补齐运行时字段（hp / pixel_pos / ai 等）
	for e in data["entities"]:
		if str(e["kind"]) == "enemy":
			_init_enemy_runtime(e)

	_update_camera()
	_update_status()
	queue_redraw()
	_minimap.queue_redraw()


func _init_enemy_runtime(e: Dictionary) -> void:
	var p: Vector2i = Vector2i(e["pos"])
	if not e.has("pixel_pos"):
		e["pixel_pos"] = _grid_center_pixel(p)
	if not e.has("hp"):
		e["hp"] = ENEMY_HP_DEFAULT
	if not e.has("max_hp"):
		e["max_hp"] = ENEMY_HP_DEFAULT
	if not e.has("atk"):
		e["atk"] = ENEMY_ATK_DEFAULT
	if not e.has("target_grid"):
		e["target_grid"] = p
	if not e.has("ai_timer"):
		e["ai_timer"] = randf() * 1.6
	if not e.has("attack_cd"):
		e["attack_cd"] = randf() * 0.4
	if not e.has("hit_flash"):
		e["hit_flash"] = 0.0
	# 初始化默认朝向（朝下）
	if not _enemy_facing.has(str(e["id"])):
		_enemy_facing[str(e["id"])] = Vector2i(0, 1)


func _non_boss_battle_reward_values(beaten_kind: String, enemy_count: int = 1) -> Dictionary:
	var fragments_gain: int = 0
	var exp_gain: int = 0
	var text: String = ""
	if beaten_kind == "elite":
		if RunState.current_chapter_index == RunState.CHAPTER_CENTRAL:
			fragments_gain = 66
			exp_gain = 52
		elif RunState.current_chapter_index == RunState.CHAPTER_EAST:
			fragments_gain = 54
			exp_gain = 42
		elif RunState.current_chapter_index == RunState.CHAPTER_NORTH:
			fragments_gain = 42
			exp_gain = 32
		elif RunState.current_chapter_index == RunState.CHAPTER_WEST:
			fragments_gain = 32
			exp_gain = 24
		else:
			fragments_gain = 20
			exp_gain = 15
		text = "精英已唤醒  +%d 碎片  +%d EXP" % [fragments_gain, exp_gain]
	elif beaten_kind == "enemy":
		var base_fragments: int = 5
		var base_exp: int = 5
		if RunState.current_chapter_index == RunState.CHAPTER_CENTRAL:
			base_fragments = 17
			base_exp = 15
		elif RunState.current_chapter_index == RunState.CHAPTER_EAST:
			base_fragments = 14
			base_exp = 12
		elif RunState.current_chapter_index == RunState.CHAPTER_NORTH:
			base_fragments = 11
			base_exp = 10
		elif RunState.current_chapter_index == RunState.CHAPTER_WEST:
			base_fragments = 8
			base_exp = 8
		fragments_gain = base_fragments + maxi(0, enemy_count - 1) * 2
		exp_gain = base_exp + maxi(1, enemy_count) * 2
		text = "+%d 碎片  +%d EXP" % [fragments_gain, exp_gain]
	else:
		return {}
	return {"fragments": fragments_gain, "exp": exp_gain, "text": text}


func _non_boss_battle_reward_text(beaten_kind: String, enemy_count: int = 1) -> String:
	return str(_non_boss_battle_reward_values(beaten_kind, enemy_count).get("text", ""))


func _grant_non_boss_battle_reward(beaten_kind: String, enemy_count: int = 1) -> Dictionary:
	var reward := _non_boss_battle_reward_values(beaten_kind, enemy_count)
	if reward.is_empty():
		return {}
	var fragments_gain: int = int(reward.get("fragments", 0))
	var exp_gain: int = int(reward.get("exp", 0))
	GameState.add_fragments(fragments_gain)
	RunState.add_exp(exp_gain)
	return reward


func _non_boss_battle_result_body(beaten_kind: String, beaten_name: String, reward: Dictionary) -> String:
	var name: String = beaten_name
	if name.is_empty():
		name = "精英异兽" if beaten_kind == "elite" else "异兽"
	var story: String = "你击退了被忘川扰乱的异兽：[ %s ]。" % name
	if beaten_kind == "elite":
		story = "你唤醒了被深度侵蚀的精英：[ %s ]。" % name
	return _result_body_with_change(story, str(reward.get("text", "")))


func _show_non_boss_battle_result(beaten_kind: String, beaten_name: String, reward: Dictionary) -> void:
	var title: String = "精英战收益" if beaten_kind == "elite" else "战斗收益"
	var body: String = _non_boss_battle_result_body(beaten_kind, beaten_name, reward)
	_show_event_panel(title, body, [{"label": "继续探索", "callback": Callable(self, "_close_event_panel")}])


func _grid_center_pixel(g: Vector2i) -> Vector2:
	return Vector2(g.x * TILE_SIZE + TILE_SIZE * 0.5, g.y * TILE_SIZE + TILE_SIZE * 0.5)


func _is_blocked_grid(g: Vector2i) -> bool:
	if g.x < 0 or g.y < 0 or g.x >= WORLD_W or g.y >= WORLD_H:
		return true
	return int(data["tiles"][g.y][g.x]) == 1


func _can_stand_at(pixel_pos: Vector2, radius: float) -> bool:
	var probes := [
		pixel_pos,
		pixel_pos + Vector2(-radius, 0),
		pixel_pos + Vector2(radius, 0),
		pixel_pos + Vector2(0, -radius),
		pixel_pos + Vector2(0, radius),
	]
	for p in probes:
		if _is_blocked_grid(Vector2i(int(p.x / TILE_SIZE), int(p.y / TILE_SIZE))):
			return false
	return true


func _try_move_player_with_slide(step: Vector2, radius: float) -> bool:
	if step == Vector2.ZERO:
		return false
	var start: Vector2 = _player_pixel
	var target: Vector2 = start + step
	if _can_stand_at(target, radius):
		_player_pixel = target
		return true
	if absf(step.x) >= absf(step.y):
		if _try_move_player_axis(Vector2(step.x, 0.0), radius):
			return true
		return _try_move_player_axis(Vector2(0.0, step.y), radius)
	if _try_move_player_axis(Vector2(0.0, step.y), radius):
		return true
	return _try_move_player_axis(Vector2(step.x, 0.0), radius)


func _try_move_player_axis(axis_step: Vector2, radius: float) -> bool:
	if axis_step == Vector2.ZERO:
		return false
	var target: Vector2 = _player_pixel + axis_step
	if _can_stand_at(target, radius):
		_player_pixel = target
		return true
	return false


func _process(delta: float) -> void:
	_time_acc += delta
	_player_attack_cd = maxf(0.0, _player_attack_cd - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta * 1.5)
	if _hit_flash_ui != null:
		_hit_flash_ui.color = Color(0.95, 0.18, 0.18, _hit_flash * 0.45)
	_process_movement(delta)
	_process_enemies(delta)
	_update_floating_texts(delta)
	# 更新动画帧
	_anim_timer += delta
	if _anim_timer >= ANIM_INTERVAL:
		_anim_timer = 0.0
		_anim_frame = (_anim_frame + 1) % 4
	# 等距平滑移动：直接从 _player_pixel（每帧连续更新）计算等距坐标
	if _view_mode == ViewMode.ISOMETRIC:
		_iso_smooth_pos = _top_down_pixel_to_iso(_player_pixel)
	queue_redraw()


## 小怪 AI 移动 + 玩家与小怪即时战斗
func _process_enemies(delta: float) -> void:
	if _victory.visible or _event_panel.visible:
		return
	# 收集本帧死亡的怪，循环结束后统一移除
	var dead: Array = []
	for e in data["entities"]:
		if str(e["kind"]) != "enemy":
			continue
		_ensure_enemy_runtime(e)
		_tick_enemy_ai(e, delta)
		_tick_enemy_combat(e, delta)
		if int(e["hp"]) <= 0:
			dead.append(e)
	for d in dead:
		_on_enemy_killed(d)


func _ensure_enemy_runtime(e: Dictionary) -> void:
	if not e.has("pixel_pos"):
		_init_enemy_runtime(e)


func _tick_enemy_ai(e: Dictionary, delta: float) -> void:
	# 减计时，到点做新决策
	e["ai_timer"] = float(e["ai_timer"]) - delta
	if e["ai_timer"] <= 0.0:
		e["ai_timer"] = randf_range(0.9, 1.8)
		var here: Vector2i = Vector2i(e["pos"])
		var pp: Vector2i = Vector2i(data["player"])
		var diff: Vector2i = pp - here
		var d2: int = abs(diff.x) + abs(diff.y)
		var target: Vector2i = here
		if d2 <= ENEMY_AGGRO_RANGE and d2 > 0:
			# 追击：朝玩家长轴走一格
			if abs(diff.x) >= abs(diff.y):
				target = here + Vector2i(int(sign(diff.x)), 0)
			else:
				target = here + Vector2i(0, int(sign(diff.y)))
		else:
			# 漫游：50% 待机 / 50% 随机一格
			if randf() < 0.5:
				var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
				target = here + dirs[randi() % 4]
		# 校验目标格可行（不是岩石、不与其它实体重合、不出界）
		if _is_blocked_grid(target) or _grid_occupied_by_other(target, e):
			target = here
		e["target_grid"] = target

	# 朝 target_grid 中心连续移动
	var target_grid: Vector2i = Vector2i(e["target_grid"])
	var goal: Vector2 = _grid_center_pixel(target_grid)
	var cur_pixel: Vector2 = e["pixel_pos"]
	var diff_v: Vector2 = goal - cur_pixel
	var dist: float = diff_v.length()
	var prev_pos: Vector2i = Vector2i(e["pos"])
	if dist < 1.0:
		e["pixel_pos"] = goal
		e["pos"] = target_grid
	else:
		var step: float = ENEMY_SPEED * delta
		if step >= dist:
			e["pixel_pos"] = goal
			e["pos"] = target_grid
		else:
			e["pixel_pos"] = cur_pixel + diff_v / dist * step
	# 更新小怪朝向（基于实际移动方向）
	var new_pos: Vector2i = Vector2i(e["pos"])
	var move_dir: Vector2i = new_pos - prev_pos
	if move_dir != Vector2i.ZERO:
		_enemy_facing[str(e["id"])] = move_dir
	# 闪红衰减
	e["hit_flash"] = maxf(0.0, float(e["hit_flash"]) - delta * 1.5)


func _tick_enemy_combat(e: Dictionary, delta: float) -> void:
	var dist: float = _player_pixel.distance_to(e["pixel_pos"])
	# 玩家自动攻击：只攻击离自己最近的怪
	if dist <= PLAYER_ATTACK_RANGE and _player_attack_cd <= 0.0:
		_player_attack_cd = PLAYER_ATTACK_RATE
		var dmg: int = PLAYER_BASE_DAMAGE + int(floor(RunState.level / 2.0))
		e["hp"] = int(e["hp"]) - dmg
		e["hit_flash"] = 0.55
		_add_floating_text(e["pixel_pos"] + Vector2(0, -10), "-%d" % dmg, Color(1.0, 0.85, 0.4))
		AudioEngine.play_sfx("attack")
	# 怪攻击玩家
	e["attack_cd"] = float(e["attack_cd"]) - delta
	if dist <= PLAYER_ATTACK_RANGE and float(e["attack_cd"]) <= 0.0 and int(e["hp"]) > 0:
		e["attack_cd"] = ENEMY_ATTACK_RATE
		var dmg2: int = int(e.get("atk", ENEMY_ATK_DEFAULT))
		RunState.take_damage(dmg2)
		_hit_flash = 0.6
		_add_floating_text(_player_pixel + Vector2(0, -28), "-%d" % dmg2, Color(1.0, 0.4, 0.4))
		AudioEngine.play_sfx("hit")
		if RunState.is_dead():
			AudioEngine.play_sfx("die")
			_show_game_over()


func _on_enemy_killed(e: Dictionary) -> void:
	GameState.add_fragments(2)
	if e.has("enemies") and not Array(e["enemies"]).is_empty():
		GameState.unlock_codex("beast." + str(Array(e["enemies"])[0]))
	# 经验奖励：基础 5 + 每只怪 1
	var gained: int = 5 + int(Array(e.get("enemies", [])).size())
	var leveled: bool = RunState.add_exp(gained)
	_add_floating_text(e["pixel_pos"], "+%d EXP" % gained, Color(0.6, 1.0, 0.7))
	if leveled:
		_add_floating_text(_player_pixel + Vector2(0, -50), "升级! Lv.%d" % RunState.level, Color(1.0, 0.95, 0.4))
		AudioEngine.play_sfx("levelup")
	data["entities"].erase(e)
	_minimap.queue_redraw()
	_update_status()


func _grid_occupied_by_other(g: Vector2i, self_e: Dictionary) -> bool:
	for e in data["entities"]:
		if e == self_e:
			continue
		if Vector2i(e["pos"]) == g:
			return true
	return false


# ====== 飘字 ======

func _add_floating_text(pos: Vector2, text: String, color: Color) -> void:
	_floating_texts.append({"text": text, "color": color, "pos": pos, "age": 0.0})


func _update_floating_texts(delta: float) -> void:
	var alive: Array = []
	for ft in _floating_texts:
		ft["age"] = float(ft["age"]) + delta
		ft["pos"] = Vector2(ft["pos"]).lerp(Vector2(ft["pos"]) + Vector2(0, -28), delta)
		if float(ft["age"]) < 1.0:
			alive.append(ft)
	_floating_texts = alive


# ====== 死亡 ======

func _show_game_over() -> void:
	if _victory.visible:
		return
	_victory.visible = true
	_victory_text.text = "你被忘川带回了……\n通关进度：%d / %d\n这一次的地图与等级会散去。\n\n（按下方按钮回主菜单。）" % [
		RunState.bosses_defeated, RunState.BOSSES_TO_CLEAR
	]
	_victory_btn.text = "回主菜单"
	# 失败：清空 map_data，下次重新生成
	RunState.map_data = {}


func _setup_font() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei",
		"PingFang SC", "Hiragino Sans GB",
		"Noto Sans CJK SC", "WenQuanYi Micro Hei",
		"SimHei", "SimSun", "Sans-Serif",
	])
	sf.allow_system_fallback = true
	_font = sf


func _setup_camera() -> void:
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 12.0
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = WORLD_PIXEL_W
	_camera.limit_bottom = WORLD_PIXEL_H
	_camera.zoom = Vector2.ONE
	add_child(_camera)
	_camera.make_current()


# ============== 地图生成 ==============


func _chapter_config() -> Dictionary:
	if RunState.current_chapter_index == RunState.CHAPTER_CENTRAL:
		return {
			"chapter_index": RunState.CHAPTER_CENTRAL,
			"title": "中山 · 麒麟台",
			"top_floor_tileset": "central_altar",
			"iso_floor_tileset": "central_altar",
			"iso_wall_tileset": "central_altar",
			"cluster_min": 175,
			"cluster_max": 220,
			"enemy_min": 40,
			"enemy_max": 52,
			"elite_count": 4,
			"treasure_min": 9,
			"treasure_max": 11,
			"treasure_name": "麒麟台玉匣",
			"treasure_story": "黄土台阶收束五方灵韵，玉匣上刻着方圆相抱的纹路。",
			"shop_name": "中土玉市",
			"shop_story": "商旅在祭坛外铺开玉片、陶符和旧简，专收五境余响。",
			"rest_name": "方圆息台",
			"rest_story": "土坛中央微微发暖，五方风声在这里归于平稳。",
			"bosses": [
				{"id": "boss_weak", "kind": "boss_weak", "label": "弱", "name": "玉角·麒麟", "story": "麒麟幼影踏上黄土祭台，玉角尚未完全凝光。", "enemy_id": "boss_qilin_weak", "sprite_key": "boss_qilin_weak"},
				{"id": "boss_mid", "kind": "boss_mid", "label": "中", "name": "土德·麒麟", "story": "麒麟以土德调停五方，方圆纹随其步伐一圈圈亮起。", "enemy_id": "boss_qilin", "sprite_key": "boss_qilin"},
				{"id": "boss_hard", "kind": "boss_hard", "label": "强", "name": "五境归一·麒麟", "story": "五境余响汇入中央，麒麟台上只剩归一的沉稳光焰。", "enemy_id": "boss_qilin_strong", "sprite_key": "boss_qilin_strong"},
			],
			"elite": {"kind": "elite", "label": "精", "name": "雨师·计蒙", "story": "龙首人身的雨师立在玉台边缘，雨令与土气相互调和。", "enemies": ["elite_ji_meng"], "sprite_key": "elite_ji_meng"},
			"enemy_packs": [
				_enemy_pack("kui", "夔", "一足如鼓，雷声在中土祭坛下回荡。", 62, 10),
				_enemy_pack("tu_lou", "土蝼", "四角兽影守着黄土台阶，饥意与土气一同翻涌。", 58, 9),
				_enemy_pack("jiao_beast", "狡", "豹文犬身、牛角高举，所过之处五谷先有异兆。", 54, 9),
				_enemy_pack("wen_lin", "闻獜", "鳞光贴地而行，像是在替归一路径辨认方向。", 50, 8),
			],
		}
	if RunState.current_chapter_index == RunState.CHAPTER_EAST:
		return {
			"chapter_index": RunState.CHAPTER_EAST,
			"title": "东山 · 青龙原",
			"top_floor_tileset": "east_meadow",
			"iso_floor_tileset": "east_meadow",
			"iso_floor_row": 0,
			"iso_floor_col_offset": 0,
			"iso_floor_col_count": 4,
			"iso_wall_tileset": "east_bamboo",
			"cluster_min": 150,
			"cluster_max": 210,
			"enemy_min": 38,
			"enemy_max": 50,
			"elite_count": 4,
			"treasure_min": 8,
			"treasure_max": 10,
			"treasure_name": "青木秘匣",
			"treasure_story": "木匣藏在新生藤蔓之间，匣面刻着青龙鳞纹与雨后芽痕。",
			"shop_name": "青芽市集",
			"shop_story": "竹帘后传来雨声，摊上摆着春木符、青玉种和东山旧简。",
			"rest_name": "青原驿亭",
			"rest_story": "驿亭立在风雨刚停的坡地上，檐角有细小新芽探出。",
			"bosses": [
				{"id": "boss_weak", "kind": "boss_weak", "label": "弱", "name": "初鳞·青龙", "story": "青鳞尚未连成完整龙影，春雷只在云后轻响。", "enemy_id": "boss_qinglong_weak", "sprite_key": "boss_qinglong_weak"},
				{"id": "boss_mid", "kind": "boss_mid", "label": "中", "name": "雨令·青龙", "story": "掌雨与生发的东方龙影在青原上盘旋，草木随其呼吸伏起。", "enemy_id": "boss_qinglong", "sprite_key": "boss_qinglong"},
				{"id": "boss_hard", "kind": "boss_hard", "label": "强", "name": "春雷镇原·青龙", "story": "完整醒来的东方青龙，雷雨、木气与希望同时汇聚。", "enemy_id": "boss_qinglong_strong", "sprite_key": "boss_qinglong_strong"},
			],
			"elite": {"kind": "elite", "label": "英", "name": "应龙幼影", "story": "有翼的龙影在雨后低空巡游，仍记得替万物开路的本能。", "enemies": ["elite_yinglong_young"], "sprite_key": "elite_yinglong_young"},
			"enemy_packs": [
				_enemy_pack("dang_kang", "当康", "豚形有牙的丰穰瑞兽，被忘川扰乱后只剩躁动的鸣叫。", 48, 8),
				_enemy_pack("qiu_yu", "犰狳", "兔形鸟喙、鸱目蛇尾，见人则眠，惊醒时引来虫鸣。", 44, 7),
				_enemy_pack("ling_ling", "軨軨", "牛形虎文，鸣声低沉如钦，影子里带着大水的预兆。", 58, 9),
				_enemy_pack("zhu_ru", "朱獳", "狐形而有鱼翼，出没处常让人心生惊惧。", 50, 8),
			],
		}
	if RunState.current_chapter_index == RunState.CHAPTER_NORTH:
		return {
			"chapter_index": RunState.CHAPTER_NORTH,
			"title": "北山 · 玄武渊",
			"top_floor_tileset": "stone_floor",
			"iso_floor_tileset": "dungeon",
			"iso_floor_row": 0,
			"iso_floor_col_offset": 2,
			"iso_floor_col_count": 1,
			"iso_wall_tileset": "dungeon",
			"iso_wall_col": 1,
			"cluster_min": 170,
			"cluster_max": 235,
			"enemy_min": 36,
			"enemy_max": 48,
			"elite_count": 4,
			"treasure_min": 7,
			"treasure_max": 9,
			"treasure_name": "玄冰秘匣",
			"treasure_story": "冰匣半沉在寒水边，匣面浮着龟蛇相缠的旧纹。",
			"shop_name": "寒市旧肆",
			"shop_story": "无人的摊位亮着青白灯火，骨哨、冻墨和北山残简静静排开。",
			"rest_name": "玄渊驿亭",
			"rest_story": "驿亭背靠黑水，檐下铜铃随寒雾轻响，暂时压住了深渊里的回声。",
			"bosses": [
				{"id": "boss_weak", "kind": "boss_weak", "label": "弱", "name": "微明·烛龙", "story": "刚从玄渊里睁开半只眼的烛龙，昼夜之力仍不稳定。", "enemy_id": "boss_zhulong_weak", "sprite_key": "boss_zhulong_weak"},
				{"id": "boss_mid", "kind": "boss_mid", "label": "中", "name": "玄渊·烛龙", "story": "烛龙呼吸牵动寒暑，黑水随它的眼睑开合而明灭。", "enemy_id": "boss_zhulong", "sprite_key": "boss_zhulong"},
				{"id": "boss_hard", "kind": "boss_hard", "label": "强", "name": "昼夜镇渊·烛龙", "story": "完整醒来的北方神影，视为昼、瞑为夜，建议带足第三章卡组优势再挑战。", "enemy_id": "boss_zhulong_strong", "sprite_key": "boss_zhulong_strong"},
			],
			"elite": {"kind": "elite", "label": "精", "name": "相柳毒影", "story": "九首毒影伏在黑水边，所触之处都留下难以清除的湿毒。", "enemies": ["elite_xiangliu_shadow"], "sprite_key": "elite_xiangliu_shadow"},
			"enemy_packs": [
				{"name": "河罗鱼", "story": "一首十身的寒水异鱼，犬吠般的声音在潭底来回折返。", "enemies": ["he_luo_fish"], "enemy_id": "he_luo_fish", "sprite_key": "enemy.he_luo_fish", "hp": 42, "max_hp": 42, "atk": 7},
				{"name": "肥遗", "story": "一首两身的蛇影横过雪泥，尾迹指向两个不同方向。", "enemies": ["fei_yi"], "enemy_id": "fei_yi", "sprite_key": "enemy.fei_yi", "hp": 46, "max_hp": 46, "atk": 8},
				{"name": "诸怀", "story": "四角猛兽守在黑水岸边，人目安静地盯着每个靠近者。", "enemies": ["zhuhuai"], "enemy_id": "zhuhuai", "sprite_key": "enemy.zhuhuai", "hp": 54, "max_hp": 54, "atk": 9},
				{"name": "嚣", "story": "四翼一目的异鸟掠过寒雾，犬尾扫乱水面倒影。", "enemies": ["xiao_beast"], "enemy_id": "xiao_beast", "sprite_key": "enemy.xiao_beast", "hp": 40, "max_hp": 40, "atk": 6},
			],
		}
	if RunState.current_chapter_index == RunState.CHAPTER_WEST:
		return {
			"chapter_index": RunState.CHAPTER_WEST,
			"title": "西山 · 白虎境",
			"top_floor_tileset": "dirt",
			"iso_floor_tileset": "forest",
			"iso_floor_row": 1,
			"iso_floor_col_offset": 1,
			"iso_floor_col_count": 5,
			"iso_wall_tileset": "village",
			"cluster_min": 165,
			"cluster_max": 225,
			"enemy_min": 34,
			"enemy_max": 44,
			"elite_count": 4,
			"treasure_min": 6,
			"treasure_max": 8,
			"shop_name": "白石古肆",
			"shop_story": "石灯后坐着一位戴虎纹面具的老者，柜上摆着西山旧符。",
			"rest_name": "昆仑驿亭",
			"rest_story": "驿亭悬着白羽和铜铃，可以在这里歇脚、听守山人的传闻。",
			"bosses": [
				{"id": "boss_weak", "kind": "boss_weak", "label": "弱", "name": "少司·陆吾", "story": "初醒的昆仑山神，虎身人面，九尾尚未完全舒展。", "enemy_id": "boss_luwu_weak", "sprite_key": "boss_luwu_weak"},
				{"id": "boss_mid", "kind": "boss_mid", "label": "中", "name": "昆仑司门·陆吾", "story": "掌九部与天帝苑囿的山神，守在白虎境的石门前。", "enemy_id": "boss_luwu", "sprite_key": "boss_luwu"},
				{"id": "boss_hard", "kind": "boss_hard", "label": "强", "name": "九尾镇岳·陆吾", "story": "九尾如旌、虎爪裂石的古老陆吾，建议先积累第二章卡组优势。", "enemy_id": "boss_luwu_strong", "sprite_key": "boss_luwu_strong"},
			],
			"elite": {"kind": "elite", "label": "英", "name": "山巡·英招", "story": "马身人面、虎文鸟翼的守山神使。", "enemies": ["elite_yingzhao"], "sprite_key": "elite_yingzhao"},
			"enemy_packs": [
				_enemy_pack("zheng_beast", "狰", "赤豹五尾，头生独角，声如击石。", 28, 4),
				_enemy_pack("tian_gou", "天狗", "白首犬形，夜行山脊，能以吠声惊散雾魇。", 32, 5),
				_enemy_pack("xuan_gui", "旋龟", "鸟首龟身、蛇尾盘石，壳纹如回旋水纹。", 36, 4),
				_enemy_pack("gu_diao", "蛊雕", "似雕而有角，声如婴啼，盘旋于西山裂谷。", 40, 6),
			],
		}
	return {
		"chapter_index": RunState.CHAPTER_SOUTH,
		"top_floor_tileset": "grass",
		"title": "南山 · 朱雀庭",
		"iso_floor_tileset": "forest",
		"iso_wall_tileset": "village",
		"cluster_min": 140,
		"cluster_max": 200,
		"enemy_min": 30,
		"enemy_max": 40,
		"elite_count": 4,
		"treasure_min": 5,
		"treasure_max": 7,
		"shop_name": "古玩铺",
		"shop_story": "店主是一位戴狐面具的老者。",
		"rest_name": "讲古驿站",
		"rest_story": "可以在这里休整、读古卷。",
		"bosses": [
			{"id": "boss_weak", "kind": "boss_weak", "label": "弱", "name": "雏火·毕方", "story": "刚被忘川扰动、力量尚弱的雏鸟。是 3 个 BOSS 中相对易战的。", "enemy_id": "boss_bifang_weak", "sprite_key": "boss_weak"},
			{"id": "boss_mid", "kind": "boss_mid", "label": "中", "name": "讹火·毕方", "story": "山经记载的独足神鸟，被忘川驱使后散布讹火。", "enemy_id": "boss_bifang", "sprite_key": "boss_mid"},
			{"id": "boss_hard", "kind": "boss_hard", "label": "强", "name": "焚岭古毕方", "story": "栖息在岭脊深处千年的古毕方。建议先打小怪与精英、积累优势再来。", "enemy_id": "boss_bifang_strong", "sprite_key": "boss_hard"},
		],
		"elite": {"kind": "elite", "label": "奇", "name": "迷误·穷奇", "story": "虎形有翼的凶兽，守在山径要冲。", "enemies": ["elite_qiongqi"], "sprite_key": "elite"},
		"enemy_packs": [
			_enemy_pack("hu_diao", "迷雾狐裔", "赤狐状的雾中小妖，行动轻快。", 22, 2),
			_enemy_pack("lu_shu", "鹿蜀", "白首马身、虎文赤尾的山兽。", 26, 3),
			_enemy_pack("cong_cong", "从从", "六足犬形之兽，叫声像在自呼其名。", 18, 2),
			_enemy_pack("lei_beast", "类", "似狸而有灵性的山兽，被忘川扰乱。", 30, 3),
		],
	}


func _enemy_pack(enemy_id: String, name: String, story: String, hp: int, atk: int) -> Dictionary:
	return {"name": name, "story": story, "enemies": [enemy_id], "enemy_id": enemy_id, "sprite_key": "enemy." + enemy_id, "hp": hp, "max_hp": hp, "atk": atk}


func _chapter_title() -> String:
	var title: String = str(data.get("title", _chapter_config().get("title", "南山 · 朱雀庭")))
	return "%s   (第 %d 章)" % [title, RunState.current_chapter_index + 1]


func _apply_chapter_visual_overrides() -> void:
	if data.is_empty():
		return
	var cfg: Dictionary = _chapter_config()
	data["top_floor_tileset"] = str(cfg.get("top_floor_tileset", data.get("top_floor_tileset", "grass")))
	data["iso_floor_tileset"] = str(cfg.get("iso_floor_tileset", data.get("iso_floor_tileset", "forest")))
	data["iso_floor_row"] = int(cfg.get("iso_floor_row", data.get("iso_floor_row", 0)))
	data["iso_floor_col_offset"] = int(cfg.get("iso_floor_col_offset", data.get("iso_floor_col_offset", 0)))
	data["iso_floor_col_count"] = int(cfg.get("iso_floor_col_count", data.get("iso_floor_col_count", 2)))
	data["iso_wall_tileset"] = str(cfg.get("iso_wall_tileset", data.get("iso_wall_tileset", "village")))
	data["iso_wall_col"] = int(cfg.get("iso_wall_col", data.get("iso_wall_col", -1)))


func _chapter_event_pool(cfg: Dictionary) -> Array:
	var chapter: int = int(cfg.get("chapter_index", 0))
	var result: Array = []
	var events: Array = EventDatabase.load_all()
	for ev in events:
		var event_chapter: int = int(ev.get("chapter", 0))
		if event_chapter == chapter or event_chapter == -1:
			result.append(ev)
	return result


func _generate_map() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	var s: int = RunState.seed_value
	if s == 0:
		s = randi()
		RunState.seed_value = s
	rng.seed = s + RunState.current_chapter_index * 9173
	_decoration_seed = s + RunState.current_chapter_index * 4099
	var cfg: Dictionary = _chapter_config()

	var tiles: Array = []
	for y in WORLD_H:
		var row: Array = []
		for x in WORLD_W:
			row.append(0)
		tiles.append(row)

	for x in WORLD_W:
		tiles[0][x] = 1
		tiles[WORLD_H - 1][x] = 1
	for y in WORLD_H:
		tiles[y][0] = 1
		tiles[y][WORLD_W - 1] = 1

	for cluster in range(rng.randi_range(int(cfg.get("cluster_min", 140)), int(cfg.get("cluster_max", 200)))):
		var cx: int = rng.randi_range(2, WORLD_W - 3)
		var cy: int = rng.randi_range(2, WORLD_H - 3)
		var sz: int = rng.randi_range(1, 4)
		for dx in range(-sz, sz + 1):
			for dy in range(-sz, sz + 1):
				var x: int = cx + dx
				var y: int = cy + dy
				if x <= 1 or y <= 1 or x >= WORLD_W - 2 or y >= WORLD_H - 2:
					continue
				var density: float = 0.45 if RunState.current_chapter_index == RunState.CHAPTER_SOUTH else 0.50
				if rng.randf() < density:
					tiles[y][x] = 1

	var player := Vector2i(2, WORLD_H / 2)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			tiles[player.y + dy][player.x + dx] = 0

	for x in range(1, WORLD_W - 1):
		tiles[player.y][x] = 0
	var lane_top: int = max(3, WORLD_H / 4)
	var lane_bot: int = min(WORLD_H - 4, WORLD_H * 3 / 4)
	for x in range(1, WORLD_W - 1):
		if rng.randf() < 0.92:
			tiles[lane_top][x] = 0
		if rng.randf() < 0.92:
			tiles[lane_bot][x] = 0
	for i in 5:
		var lx: int = (WORLD_W * (i + 1)) / 6
		for y in range(1, WORLD_H - 1):
			if rng.randf() < 0.92:
				tiles[y][lx] = 0

	var entities: Array = []
	var occupied: Dictionary = {}
	occupied[player] = true

	var boss_pool: Array = Array(cfg.get("bosses", [])).duplicate(true)
	boss_pool.shuffle()
	var boss_x_zones: Array = [
		[int(WORLD_W * 0.30), int(WORLD_W * 0.45)],
		[int(WORLD_W * 0.55), int(WORLD_W * 0.70)],
		[int(WORLD_W * 0.80), int(WORLD_W * 0.92)],
	]
	for i in 3:
		var zone: Array = boss_x_zones[i]
		var p: Vector2i = _pick_free_pos(rng, zone[0], zone[1], 3, WORLD_H - 4, tiles, occupied)
		if p == Vector2i(-1, -1):
			continue
		var b: Dictionary = boss_pool[i].duplicate(true)
		b["pos"] = p
		entities.append(b)
		occupied[p] = true

	var elite_template: Dictionary = cfg.get("elite", {})
	for i in int(cfg.get("elite_count", 4)):
		var p: Vector2i = _pick_free_pos(rng, int(WORLD_W * 0.20), int(WORLD_W * 0.88), 3, WORLD_H - 4, tiles, occupied)
		if p != Vector2i(-1, -1):
			var elite: Dictionary = elite_template.duplicate(true)
			elite["id"] = "elite_%d" % i
			elite["pos"] = p
			entities.append(elite)
			occupied[p] = true

	var enemy_packs: Array = Array(cfg.get("enemy_packs", []))
	var enemy_count: int = rng.randi_range(int(cfg.get("enemy_min", 30)), int(cfg.get("enemy_max", 40)))
	for i in enemy_count:
		if enemy_packs.is_empty():
			break
		var pack: Dictionary = enemy_packs[rng.randi() % enemy_packs.size()].duplicate(true)
		var p: Vector2i = _pick_free_pos(rng, 4, WORLD_W - 4, 3, WORLD_H - 4, tiles, occupied)
		if p == Vector2i(-1, -1):
			continue
		pack["id"] = "enemy_%d" % i
		pack["kind"] = "enemy"
		pack["pos"] = p
		entities.append(pack)
		occupied[p] = true

	for i in 3:
		var p: Vector2i = _pick_free_pos(rng, 8, WORLD_W - 8, 4, WORLD_H - 5, tiles, occupied)
		if p != Vector2i(-1, -1):
			entities.append({"id": "shop_%d" % i, "kind": "shop", "pos": p, "label": "市", "name": str(cfg.get("shop_name", "古玩铺")), "story": str(cfg.get("shop_story", ""))})
			occupied[p] = true
	for i in 3:
		var p: Vector2i = _pick_free_pos(rng, 8, WORLD_W - 8, 4, WORLD_H - 5, tiles, occupied)
		if p != Vector2i(-1, -1):
			entities.append({"id": "rest_%d" % i, "kind": "rest", "pos": p, "label": "歇", "name": str(cfg.get("rest_name", "讲古驿站")), "story": str(cfg.get("rest_story", ""))})
			occupied[p] = true

	var treasure_count: int = rng.randi_range(int(cfg.get("treasure_min", 5)), int(cfg.get("treasure_max", 7)))
	for i in treasure_count:
		var p: Vector2i = _pick_free_pos(rng, 4, WORLD_W - 4, 3, WORLD_H - 4, tiles, occupied)
		if p != Vector2i(-1, -1):
			var loot: Dictionary = _roll_treasure_loot(rng)
			var treasure_name: String = str(cfg.get("treasure_name", "白石秘匣" if RunState.current_chapter_index >= RunState.CHAPTER_WEST else "山海宝匣"))
			var treasure_story: String = str(cfg.get("treasure_story", "石匣半埋在褐土与灰岩之间，匣面刻着白虎境的旧纹。" if RunState.current_chapter_index >= RunState.CHAPTER_WEST else "匣中收着被山风吹散的灵韵。"))
			entities.append({"id": "treasure_%d" % i, "kind": "treasure", "pos": p, "label": "宝", "name": treasure_name, "story": treasure_story, "loot": loot})
			occupied[p] = true

	var events: Array = _chapter_event_pool(cfg)
	events.shuffle()
	var event_count: int = mini(4, events.size())
	for i in event_count:
		var p: Vector2i = _pick_free_pos(rng, 4, WORLD_W - 4, 3, WORLD_H - 4, tiles, occupied)
		if p != Vector2i(-1, -1):
			var ev: Dictionary = events[i]
			entities.append({"id": "event_%d" % i, "kind": "event", "pos": p, "label": "录", "name": ev.get("name", "回响事件"), "story": ev.get("story", ""), "options": ev.get("options", [])})
			occupied[p] = true

	for i in 20:
		var p: Vector2i = _pick_free_pos(rng, 4, WORLD_W - 4, 3, WORLD_H - 4, tiles, occupied)
		if p != Vector2i(-1, -1):
			entities.append({"id": "fragment_%d" % i, "kind": "fragment", "pos": p, "label": "片", "name": "文化片段"})
			occupied[p] = true

	_ensure_reachability(tiles, player, entities)
	return {
		"chapter_index": int(cfg.get("chapter_index", RunState.current_chapter_index)),
		"title": str(cfg.get("title", "南山 · 朱雀庭")),
		"top_floor_tileset": str(cfg.get("top_floor_tileset", "grass")),
		"iso_floor_row": int(cfg.get("iso_floor_row", 0)),
		"iso_floor_col_offset": int(cfg.get("iso_floor_col_offset", 0)),
		"iso_floor_col_count": int(cfg.get("iso_floor_col_count", 2)),
		"iso_floor_tileset": str(cfg.get("iso_floor_tileset", "forest")),
		"iso_wall_tileset": str(cfg.get("iso_wall_tileset", "village")),
		"iso_wall_col": int(cfg.get("iso_wall_col", -1)),
		"tiles": tiles,
		"player": player,
		"entities": entities,
	}


func _roll_treasure_loot(rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array = [
		{"type": "fragments", "amount": 30, "text": "灵韵碎片 +30"},
		{"type": "fragments", "amount": 50, "text": "灵韵碎片 +50"},
		{"type": "exp", "amount": 30, "text": "EXP +30"},
		{"type": "exp", "amount": 50, "text": "EXP +50"},
		{"type": "max_hp", "amount": 6, "text": "永久最大气血 +6"},
		{"type": "max_hp", "amount": 10, "text": "永久最大气血 +10"},
		{"type": "heal", "amount": 40, "text": "气血 +40"},
		{"type": "card", "card": "neutral.scroll_study", "text": "卡牌：《古卷研读》"},
		{"type": "card", "card": "neutral.qi_gather", "text": "卡牌：《凝灵韵》"},
		{"type": "card", "card": "neutral.warrior_oath", "text": "卡牌：《侠者誓》"},
	]
	if RunState.current_chapter_index >= RunState.CHAPTER_WEST:
		pool.append_array([
			{"type": "fragments", "amount": 65, "text": "灵韵碎片 +65"},
			{"type": "exp", "amount": 70, "text": "EXP +70"},
			{"type": "heal", "amount": 55, "text": "气血 +55"},
			{"type": "max_hp", "amount": 12, "text": "永久最大气血 +12"},
			{"type": "card", "card": "shan.luwu_gate", "text": "卡牌：《陆吾镇门》"},
			{"type": "card", "card": "shan.yingzhao_patrol", "text": "卡牌：《英招巡山》"},
			{"type": "card", "card": "hai.xuan_gui_shell", "text": "卡牌：《旋龟甲》"},
			{"type": "card", "card": "hai.tiangou_ward", "text": "卡牌：《天狗辟邪》"},
			{"type": "card", "card": "huang.zheng_pounce", "text": "卡牌：《狰的扑击》"},
			{"type": "card", "card": "huang.gudiao_cry", "text": "卡牌：《蛊雕夜啼》"},
		])
	if RunState.current_chapter_index == RunState.CHAPTER_NORTH:
		pool.append_array([
			{"type": "fragments", "amount": 85, "text": "灵韵碎片 +85"},
			{"type": "exp", "amount": 90, "text": "EXP +90"},
			{"type": "heal", "amount": 65, "text": "HP +65"},
			{"type": "max_hp", "amount": 14, "text": "最大 HP +14"},
			{"type": "card", "card": "hai.beishan_mist", "text": "获得卡牌：《北渊寒雾》"},
			{"type": "card", "card": "shan.black_ridge_guard", "text": "获得卡牌：《玄岭守势》"},
			{"type": "card", "card": "hai.cold_current", "text": "获得卡牌：《伏流击石》"},
			{"type": "card", "card": "huang.memory_venom", "text": "获得卡牌：《记忆余毒》"},
			{"type": "card", "card": "hai.deep_pool_reflection", "text": "获得卡牌：《深潭返照》"},
		])
	elif RunState.current_chapter_index == RunState.CHAPTER_EAST:
		pool.append_array([
			{"type": "fragments", "amount": 105, "text": "灵韵碎片 +105"},
			{"type": "exp", "amount": 115, "text": "EXP +115"},
			{"type": "heal", "amount": 76, "text": "HP +76"},
			{"type": "max_hp", "amount": 16, "text": "最大 HP +16"},
			{"type": "card", "card": "shan.dangkang_harvest", "text": "获得卡牌：《当康鸣穰》"},
			{"type": "card", "card": "shan.spring_root", "text": "获得卡牌：《春根复萌》"},
			{"type": "card", "card": "hai.yinglong_rainpath", "text": "获得卡牌：《应龙开泽》"},
			{"type": "card", "card": "huang.lingling_floodcall", "text": "获得卡牌：《軨軨水兆》"},
			{"type": "card", "card": "neutral.seed_catalog", "text": "获得卡牌：《青简种录》"},
		])
	elif RunState.current_chapter_index == RunState.CHAPTER_CENTRAL:
		pool.append_array([
			{"type": "fragments", "amount": 130, "text": "碎片 +130"},
			{"type": "exp", "amount": 140, "text": "EXP +140"},
			{"type": "heal", "amount": 88, "text": "HP +88"},
			{"type": "max_hp", "amount": 18, "text": "最大 HP +18"},
			{"type": "card", "card": "shan.qilin_virtue", "text": "获得卡牌：麒麟德音"},
			{"type": "card", "card": "shan.square_altar", "text": "获得卡牌：方坛守势"},
			{"type": "card", "card": "hai.central_confluence", "text": "获得卡牌：中流会同"},
			{"type": "card", "card": "huang.kui_thunder_drum", "text": "获得卡牌：夔鼓震台"},
			{"type": "card", "card": "neutral.five_realm_harmony", "text": "获得卡牌：五境调和"},
		])
	return pool[rng.randi() % pool.size()].duplicate(true)


func _pick_free_pos(rng: RandomNumberGenerator, x_min: int, x_max: int, y_min: int, y_max: int, tiles: Array, occupied: Dictionary) -> Vector2i:
	for attempt in 200:
		var x: int = rng.randi_range(x_min, x_max)
		var y: int = rng.randi_range(y_min, y_max)
		var p := Vector2i(x, y)
		if int(tiles[y][x]) == 1:
			continue
		if occupied.has(p):
			continue
		# 至少有一个相邻空地
		if int(tiles[y][maxi(0, x - 1)]) == 0 or int(tiles[y][mini(WORLD_W - 1, x + 1)]) == 0 \
			or int(tiles[maxi(0, y - 1)][x]) == 0 or int(tiles[mini(WORLD_H - 1, y + 1)][x]) == 0:
			return p
	return Vector2i(-1, -1)


func _ensure_reachability(tiles: Array, start: Vector2i, entities: Array) -> void:
	# 简易 BFS 标记可达；不可达的实体用直线走廊打通到最近可达点
	var reach: Array = []
	for y in WORLD_H:
		var row: Array = []
		for x in WORLD_W:
			row.append(false)
		reach.append(row)
	var queue: Array = [start]
	reach[start.y][start.x] = true
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n: Vector2i = p + d
			if n.x < 0 or n.y < 0 or n.x >= WORLD_W or n.y >= WORLD_H:
				continue
			if reach[n.y][n.x]:
				continue
			if int(tiles[n.y][n.x]) == 1:
				continue
			reach[n.y][n.x] = true
			queue.push_back(n)

	for e in entities:
		var p: Vector2i = e["pos"]
		if reach[p.y][p.x]:
			continue
		# 从该实体直线打通到 start：先 x 后 y
		var cur: Vector2i = p
		while cur.x != start.x:
			tiles[cur.y][cur.x] = 0
			reach[cur.y][cur.x] = true
			cur.x += sign(start.x - cur.x)
		while cur.y != start.y:
			tiles[cur.y][cur.x] = 0
			reach[cur.y][cur.x] = true
			cur.y += sign(start.y - cur.y)


# ============== 输入与移动 ==============

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo:
		return
	# Tab：随时切小地图（包括对话框打开时）
	if event.keycode == KEY_TAB:
		_toggle_minimap()
		_mark_input_handled()
		return
	# 其它快捷键在对话框打开时不响应
	if _confirm.visible or _victory.visible:
		return
	if event.keycode == KEY_R:
		_mark_input_handled()
		_show_reset_confirm()
		return
	if event.keycode == KEY_K:
		_mark_input_handled()
		RunState.map_view_mode = 1 if _view_mode == ViewMode.ISOMETRIC else 0
		RunState.return_after_codex = "res://scenes/map/map.tscn"
		get_tree().change_scene_to_file("res://scenes/codex/codex.tscn")
	# V：切换视角（顶视角 ⟷ 等距）
	if event.keycode == KEY_V:
		_toggle_view_mode()
		_mark_input_handled()
		return


func _mark_input_handled() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _reload_current_scene_deferred() -> void:
	if is_inside_tree():
		get_tree().reload_current_scene()


func _show_reset_confirm() -> void:
	_pending_reset_map = true
	pending_entity = {}
	_confirm.visible = true
	_confirm_text.text = "确认重置本层地图？\n\n会重新生成地图，并清空本局等级、经验和当前战斗进度。"
	_confirm_yes.text = "确认重置"
	_confirm_no.text = "取消"
	_confirm_yes.grab_focus()



func _reset_current_run_map() -> void:
	RunState.reset_map_progress_to_first_chapter()
	data = _generate_map()
	RunState.map_data = data
	_enemy_facing.clear()
	for e in data["entities"]:
		if str(e["kind"]) == "enemy":
			_init_enemy_runtime(e)
	_player_pixel = _grid_center_pixel(Vector2i(data["player"]))
	_last_grid = Vector2i(data["player"])
	_last_safe_grid = _last_grid
	_title.text = _chapter_title()
	if _view_mode == ViewMode.ISOMETRIC:
		_update_iso_world_bounds()
		_iso_smooth_pos = _top_down_pixel_to_iso(_player_pixel)
	_update_camera()
	_update_status()
	queue_redraw()
	_minimap.queue_redraw()


func _setup_debug_chapter_controls() -> void:
	var ui_parent: Node = _back_btn.get_parent()
	var wrap := VBoxContainer.new()
	wrap.name = "DebugChapterControls"
	wrap.anchor_left = 1.0
	wrap.anchor_right = 1.0
	wrap.anchor_top = 0.0
	wrap.anchor_bottom = 0.0
	wrap.offset_left = -310.0
	wrap.offset_right = -10.0
	wrap.offset_top = 48.0
	wrap.offset_bottom = 180.0
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP

	_debug_chapter_toggle = Button.new()
	_debug_chapter_toggle.text = "开发跳关：关"
	_debug_chapter_toggle.toggle_mode = true
	_debug_chapter_toggle.custom_minimum_size = Vector2(132, 32)
	_debug_chapter_toggle.toggled.connect(_on_debug_chapter_toggle)
	wrap.add_child(_debug_chapter_toggle)

	_debug_chapter_picker = HBoxContainer.new()
	_debug_chapter_picker.visible = false
	_debug_chapter_picker.alignment = BoxContainer.ALIGNMENT_CENTER
	var south_btn := Button.new()
	south_btn.text = "南山"
	south_btn.custom_minimum_size = Vector2(50, 30)
	south_btn.pressed.connect(Callable(self, "_debug_jump_to_chapter").bind(RunState.CHAPTER_SOUTH))
	var west_btn := Button.new()
	west_btn.text = "西山"
	west_btn.custom_minimum_size = Vector2(50, 30)
	west_btn.pressed.connect(Callable(self, "_debug_jump_to_chapter").bind(RunState.CHAPTER_WEST))
	var north_btn := Button.new()
	north_btn.text = "北山"
	north_btn.custom_minimum_size = Vector2(50, 30)
	north_btn.pressed.connect(Callable(self, "_debug_jump_to_chapter").bind(RunState.CHAPTER_NORTH))
	var east_btn := Button.new()
	east_btn.text = "东山"
	east_btn.custom_minimum_size = Vector2(50, 30)
	east_btn.pressed.connect(Callable(self, "_debug_jump_to_chapter").bind(RunState.CHAPTER_EAST))
	var central_btn := Button.new()
	central_btn.text = "中山"
	central_btn.custom_minimum_size = Vector2(50, 30)
	central_btn.pressed.connect(Callable(self, "_debug_jump_to_chapter").bind(RunState.CHAPTER_CENTRAL))
	_debug_chapter_picker.add_child(south_btn)
	_debug_chapter_picker.add_child(west_btn)
	_debug_chapter_picker.add_child(north_btn)
	_debug_chapter_picker.add_child(east_btn)
	_debug_chapter_picker.add_child(central_btn)
	wrap.add_child(_debug_chapter_picker)

	_debug_tool_picker = HBoxContainer.new()
	_debug_tool_picker.visible = false
	_debug_tool_picker.alignment = BoxContainer.ALIGNMENT_CENTER
	var fragments_btn := Button.new()
	fragments_btn.text = "+碎片"
	fragments_btn.custom_minimum_size = Vector2(48, 28)
	fragments_btn.pressed.connect(_debug_grant_fragments)
	var heal_btn := Button.new()
	heal_btn.text = "满血"
	heal_btn.custom_minimum_size = Vector2(48, 28)
	heal_btn.pressed.connect(_debug_full_heal)
	var exp_btn := Button.new()
	exp_btn.text = "+EXP"
	exp_btn.custom_minimum_size = Vector2(48, 28)
	exp_btn.pressed.connect(_debug_grant_exp)
	var clear_btn := Button.new()
	clear_btn.text = "章结算"
	clear_btn.custom_minimum_size = Vector2(60, 28)
	clear_btn.pressed.connect(_debug_finish_chapter)
	_debug_tool_picker.add_child(fragments_btn)
	_debug_tool_picker.add_child(heal_btn)
	_debug_tool_picker.add_child(exp_btn)
	_debug_tool_picker.add_child(clear_btn)
	wrap.add_child(_debug_tool_picker)
	ui_parent.add_child(wrap)


func _on_debug_chapter_toggle(enabled: bool) -> void:
	if _debug_chapter_toggle != null:
		_debug_chapter_toggle.text = "开发跳关：开" if enabled else "开发跳关：关"
	if _debug_chapter_picker != null:
		_debug_chapter_picker.visible = enabled
	if _debug_tool_picker != null:
		_debug_tool_picker.visible = enabled


func _debug_grant_fragments() -> void:
	GameState.add_fragments(100)
	_add_floating_text(_player_pixel + Vector2(0, -36), "+100 碎片", Color(1.0, 0.95, 0.55))
	_update_status()


func _debug_full_heal() -> void:
	RunState.heal(RunState.max_hp)
	_add_floating_text(_player_pixel + Vector2(0, -36), "气血回满", Color(0.7, 1.0, 0.7))
	_update_status()


func _debug_grant_exp() -> void:
	RunState.add_exp(50)
	_add_floating_text(_player_pixel + Vector2(0, -36), "+50 EXP", Color(0.7, 1.0, 1.0))
	_update_status()


func _debug_finish_chapter() -> void:
	RunState.bosses_defeated = RunState.BOSSES_TO_CLEAR
	_show_boss_victory("boss_hard", "开发调试")


func _debug_jump_to_chapter(chapter_index: int) -> void:
	chapter_index = clampi(chapter_index, RunState.CHAPTER_SOUTH, RunState.CHAPTER_CENTRAL)
	RunState.current_chapter_index = chapter_index
	RunState.current_floor = chapter_index
	RunState.bosses_defeated = 0
	RunState.map_data = {}
	RunState.last_entity_id = ""
	RunState.last_battle_was_boss = false
	RunState.last_battle_won = false
	RunState.hp = RunState.max_hp
	RunState.energy = RunState.max_energy
	if chapter_index == RunState.CHAPTER_CENTRAL:
		RunState.next_battle_enemy_ids = PackedStringArray(["kui", "tu_lou"])
	elif chapter_index == RunState.CHAPTER_EAST:
		RunState.next_battle_enemy_ids = PackedStringArray(["dang_kang", "qiu_yu"])
	elif chapter_index == RunState.CHAPTER_NORTH:
		RunState.next_battle_enemy_ids = PackedStringArray(["he_luo_fish", "fei_yi"])
	elif chapter_index == RunState.CHAPTER_WEST:
		RunState.next_battle_enemy_ids = PackedStringArray(["zheng_beast", "tian_gou"])
	else:
		RunState.next_battle_enemy_ids = PackedStringArray(["hu_diao", "lu_shu"])
	RunState.seed_value = randi()
	RunState.hp_changed.emit(RunState.hp, RunState.max_hp)
	RunState.energy_changed.emit(RunState.energy, RunState.max_energy)

	data = _generate_map()
	RunState.map_data = data
	_enemy_facing.clear()
	for e in data["entities"]:
		if str(e["kind"]) == "enemy":
			_init_enemy_runtime(e)
	_player_pixel = _grid_center_pixel(Vector2i(data["player"]))
	_last_grid = Vector2i(data["player"])
	_last_safe_grid = _last_grid
	_title.text = _chapter_title()
	if _view_mode == ViewMode.ISOMETRIC:
		_update_iso_world_bounds()
		_iso_smooth_pos = _top_down_pixel_to_iso(_player_pixel)
	_update_camera()
	_update_status()
	queue_redraw()
	_minimap.queue_redraw()

func _process_movement(delta: float) -> void:
	if _confirm.visible or _victory.visible or _event_panel.visible:
		_was_moving = false
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	_was_moving = dir != Vector2.ZERO
	if dir == Vector2.ZERO:
		return
	dir = dir.normalized()
	var step: Vector2 = dir * PLAYER_SPEED * delta
	var radius: float = PLAYER_COLLISION_RADIUS_ISO if _view_mode == ViewMode.ISOMETRIC else PLAYER_COLLISION_RADIUS_TOP
	_try_move_player_with_slide(step, radius)
	# 边界 clamp
	_player_pixel.x = clampf(_player_pixel.x, TILE_SIZE * 0.5, WORLD_PIXEL_W - TILE_SIZE * 0.5)
	_player_pixel.y = clampf(_player_pixel.y, TILE_SIZE * 0.5, WORLD_PIXEL_H - TILE_SIZE * 0.5)
	# 朝向用于 idle 动画相位
	if abs(dir.x) > abs(dir.y):
		_facing = Vector2i(int(sign(dir.x)), 0)
	else:
		_facing = Vector2i(0, int(sign(dir.y)))
	# 检查格子变化
	var cur_grid := Vector2i(int(_player_pixel.x / TILE_SIZE), int(_player_pixel.y / TILE_SIZE))
	if cur_grid != _last_grid:
		_last_grid = cur_grid
		data["player"] = cur_grid
		var on_dialog_entity := false
		# 找到 cur_grid 上的 entity 并按规则处理
		var target_e: Dictionary = {}
		for e in data["entities"]:
			if Vector2i(e["pos"]) == cur_grid:
				target_e = e
				break
		if not target_e.is_empty():
			var k: String = str(target_e["kind"])
			match k:
				"elite", "boss_weak", "boss_mid", "boss_hard", "shop", "rest":
					pending_entity = target_e
					_show_confirm(target_e)
					on_dialog_entity = true
				"event":
					_trigger_event(target_e)
					on_dialog_entity = true
				"treasure":
					_open_treasure(target_e)
					# 不阻塞，玩家可继续走
				"fragment":
					_pickup_fragment(target_e)
				_:
					pass
		if not on_dialog_entity:
			_last_safe_grid = cur_grid
		_update_status()
		_minimap.queue_redraw()
	_update_camera()


# ===== 双视角：切换 + 坐标映射 =====

func _toggle_view_mode() -> void:
	if _view_mode == ViewMode.TOP_DOWN:
		_view_mode = ViewMode.ISOMETRIC
		_update_iso_world_bounds()
		_iso_smooth_pos = _top_down_pixel_to_iso(_player_pixel)
	else:
		_view_mode = ViewMode.TOP_DOWN
	RunState.map_view_mode = 1 if _view_mode == ViewMode.ISOMETRIC else 0
	_update_iso_world_bounds()
	_update_camera()
	queue_redraw()
	_minimap.queue_redraw()


func _update_iso_world_bounds() -> void:
	_iso_world_w = (WORLD_W + WORLD_H) * ISO_HALF_W + ISO_TILE_W
	_iso_world_h = (WORLD_W + WORLD_H) * ISO_HALF_H + ISO_TILE_H + ISO_FLOOR_H


## 格点 → 屏幕像素（根据当前视角）
func _grid_to_pixel(g: Vector2i) -> Vector2:
	if _view_mode == ViewMode.ISOMETRIC:
		# 等距: 菱形网格映射，原点为左上角最远格子
		return Vector2(
			(g.x - g.y) * ISO_HALF_W + _iso_world_w * 0.5 - ISO_HALF_W * WORLD_W * 0.5,
			(g.x + g.y) * ISO_HALF_H + ISO_HALF_H
		)
	return Vector2(g.x * TILE_SIZE + TILE_SIZE * 0.5, g.y * TILE_SIZE + TILE_SIZE * 0.5)


## 顶视图连续像素坐标 → 等距像素坐标。
## _grid_to_pixel(Vector2i) 表示格子中心；这里先减去半格，避免玩家中心点在等距模式下重复偏移半个 tile。
func _top_down_pixel_to_iso(pixel: Vector2) -> Vector2:
	var gx: float = pixel.x / float(TILE_SIZE) - 0.5
	var gy: float = pixel.y / float(TILE_SIZE) - 0.5
	return Vector2(
		(gx - gy) * ISO_HALF_W + _iso_world_w * 0.5 - ISO_HALF_W * WORLD_W * 0.5,
		(gx + gy) * ISO_HALF_H + ISO_HALF_H
	)


## 屏幕像素 → 格点（等距，用于点击/碰撞检测）
func _iso_screen_to_grid(screen: Vector2) -> Vector2i:
	var sx := screen.x + ISO_HALF_W * WORLD_W * 0.5 - _iso_world_w * 0.5
	var sy := screen.y - ISO_HALF_H
	var gx := int(floor((sx / ISO_HALF_W + sy / ISO_HALF_H) / 2.0))
	var gy := int(floor((sy / ISO_HALF_H - sx / ISO_HALF_W) / 2.0))
	return Vector2i(gx, gy)


func _camera_visible_world_rect(margin: float = 0.0) -> Rect2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var zoom_x: float = maxf(0.01, _camera.zoom.x)
	var zoom_y: float = maxf(0.01, _camera.zoom.y)
	var half_size := Vector2(viewport_size.x / (2.0 * zoom_x), viewport_size.y / (2.0 * zoom_y)) + Vector2(margin, margin)
	var center: Vector2 = _camera.get_screen_center_position()
	return Rect2(center - half_size, half_size * 2.0)


func _update_camera() -> void:
	if _camera == null:
		return
	if _view_mode == ViewMode.ISOMETRIC:
		_update_iso_world_bounds()
		var tgt := _top_down_pixel_to_iso(_player_pixel)
		_iso_smooth_pos = tgt
		_camera.position = tgt
		_camera.zoom = Vector2(ISO_CAMERA_ZOOM, ISO_CAMERA_ZOOM)
		# 等距摄像机边界
		_camera.limit_left = -ISO_HALF_W * WORLD_H - 200
		_camera.limit_top = -200
		_camera.limit_right = _iso_world_w + 200
		_camera.limit_bottom = _iso_world_h + 200
	else:
		_camera.position = _player_pixel
		_camera.zoom = Vector2.ONE
		_camera.limit_left = 0
		_camera.limit_top = 0
		_camera.limit_right = WORLD_PIXEL_W
		_camera.limit_bottom = WORLD_PIXEL_H


# ============== 询问对话 ==============

func _show_confirm(e: Dictionary) -> void:
	_confirm.visible = true
	_confirm_yes.grab_focus()
	var kind: String = e["kind"]
	var name: String = e.get("name", "?")
	var story: String = e.get("story", "")
	match kind:
		"enemy":
			var enemy_count: int = maxi(1, Array(e.get("enemies", [])).size())
			_confirm_text.text = "前方传来低吼，是被忘川扰乱的异兽：\n[ %s ]\n%s\n胜利奖励：%s\n是否进入战斗？" % [name, story, _non_boss_battle_reward_text(kind, enemy_count)]
			_confirm_yes.text = "迎战"
		"elite":
			_confirm_text.text = "前方是被深度侵蚀的精英：\n[ %s ]\n%s\n胜利奖励：%s" % [name, story, _non_boss_battle_reward_text(kind, 1)]
			_confirm_yes.text = "挑战"
		"boss_weak", "boss_mid", "boss_hard":
			var diff_word: String = {"boss_weak": "（弱）", "boss_mid": "（中等）", "boss_hard": "（强，谨慎）"}[kind]
			var lv: int = RunState.level
			var energy_b: int = (1 if lv >= 4 else 0) + (1 if lv >= 8 else 0)
			var hand_b: int = 1 if lv >= 6 else 0
			var buff: String = ""
			if energy_b > 0 or hand_b > 0:
				buff = "\n[等级 Lv.%d 卡牌战斗加成：每回合 +%d 灵韵，起手 +%d 抽牌]" % [lv, energy_b, hand_b]
			_confirm_text.text = "BOSS%s：\n[ %s ]\n%s%s\n胜利奖励：%s\n是否决战？" % [diff_word, name, story, buff, _boss_reward_line(kind)]
			_confirm_yes.text = "决战"
		"shop":
			_confirm_text.text = "[ %s ]\n%s\n用灵韵碎片可在此购买卡牌、回血、永久增益。" % [name, story]
			_confirm_yes.text = "进店"
		"rest":
			_confirm_text.text = "[ %s ]\n%s\n恢复 %d 点气血。" % [name, story, _rest_heal_amount()]
			_confirm_yes.text = "歇脚"


func _on_confirm_yes() -> void:
	_confirm.visible = false
	if _pending_reset_map:
		_pending_reset_map = false
		_reset_current_run_map()
		return
	if pending_entity.is_empty():
		return
	var e: Dictionary = pending_entity
	var kind: String = e["kind"]
	pending_entity = {}
	data["player"] = Vector2i(e["pos"])
	_update_camera()
	match kind:
		"enemy", "elite":
			_enter_battle(e, false)
		"boss_weak", "boss_mid", "boss_hard":
			var copy := e.duplicate(true)
			copy["enemies"] = [e.get("enemy_id", "boss_bifang")]
			_enter_battle(copy, true)
		"shop":
			_enter_shop(e)
		"rest":
			_use_rest(e)


func _rest_heal_amount() -> int:
	return 35 if RunState.current_chapter_index >= RunState.CHAPTER_WEST else 25


func _use_rest(e: Dictionary) -> void:
	var amount: int = _rest_heal_amount()
	RunState.heal(amount)
	data["entities"].erase(e)
	queue_redraw()
	_minimap.queue_redraw()
	_update_status()
	var name: String = str(e.get("name", "昆仑驿亭" if RunState.current_chapter_index >= RunState.CHAPTER_WEST else "讲古驿站"))
	var story: String = str(e.get("story", ""))
	if story.is_empty():
		story = "白羽与铜铃在山风中轻响，守山人的旧闻暂时压住了疲惫。" if RunState.current_chapter_index >= RunState.CHAPTER_WEST else "你在驿站休整片刻，翻读古卷，气息逐渐平稳。"
	var result_text := _result_body_with_change(story, "恢复 %d HP" % amount)
	_show_event_panel(name, result_text, [{"label": "继续", "callback": Callable(self, "_close_event_panel")}])


func _on_confirm_no() -> void:
	_confirm.visible = false
	if _pending_reset_map:
		_pending_reset_map = false
		return
	pending_entity = {}
	# 把玩家弹回上一个安全格中心，避免对话框关掉后立刻再次触发
	_player_pixel = _grid_center_pixel(_last_safe_grid)
	data["player"] = _last_safe_grid
	_last_grid = _last_safe_grid
	_update_camera()
	_minimap.queue_redraw()


func _enter_battle(e: Dictionary, is_boss: bool) -> void:
	var ids := PackedStringArray()
	for x in e.get("enemies", []):
		ids.append(str(x))
	if ids.is_empty():
		return
	RunState.next_battle_enemy_ids = ids
	RunState.last_entity_id = e["id"]
	RunState.last_battle_was_boss = is_boss
	RunState.last_battle_won = false
	RunState.map_data = data
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")


func _remove_entity(eid: String) -> void:
	for i in data["entities"].size():
		if str(data["entities"][i]["id"]) == eid:
			data["entities"].remove_at(i)
			break
	queue_redraw()
	if _minimap:
		_minimap.queue_redraw()


# ============== 状态 / 通关 / 返回 ==============

func _update_status() -> void:
	var bosses_left: int = 0
	var enemies_left: int = 0
	for e in data["entities"]:
		var k: String = str(e["kind"])
		if k == "boss_weak" or k == "boss_mid" or k == "boss_hard":
			bosses_left += 1
		elif k == "enemy":
			enemies_left += 1
	_status.text = "Lv.%d  EXP %d/%d   ·   气血 %d/%d   ·   小怪 %d   ·   BOSS %d/%d   ·   碎片 %d   ·   [Tab] 小地图  [R] 重生" % [
		RunState.level, RunState.exp_value, RunState.exp_to_next,
		RunState.hp, RunState.max_hp,
		enemies_left,
		RunState.bosses_defeated, RunState.BOSSES_TO_CLEAR,
		GameState.fragments,
	]


func _toggle_minimap() -> void:
	_minimap_visible = not _minimap_visible
	_minimap_panel.visible = _minimap_visible


# ============== 宝物 / 事件 / 文化片段 ==============

func _pickup_fragment(e: Dictionary) -> void:
	GameState.add_fragments(1)
	RunState.add_exp(5)
	_add_floating_text(_player_pixel + Vector2(0, -36), "+5 EXP  +1 碎片", Color(1.0, 0.95, 0.55))
	AudioEngine.play_sfx("pickup")
	data["entities"].erase(e)
	_minimap.queue_redraw()
	_update_status()


func _open_treasure(e: Dictionary) -> void:
	var loot: Dictionary = e.get("loot", {})
	var story: String = str(e.get("story", ""))
	if story.is_empty():
		story = "石匣半埋在褐土与灰岩之间，匣面刻着白虎境的旧纹。" if RunState.current_chapter_index >= RunState.CHAPTER_WEST else "你打开了一只布满苔藓的山海宝匣。"
	var reward_text: String = _apply_reward(loot)
	if reward_text.is_empty():
		reward_text = str(loot.get("text", "（空）"))
	var text: String = _result_body_with_change(story, reward_text)
	AudioEngine.play_sfx("pickup")
	data["entities"].erase(e)
	_minimap.queue_redraw()
	_update_status()
	_show_event_panel(str(e.get("name", "白石秘匣" if RunState.current_chapter_index >= RunState.CHAPTER_WEST else "山海宝匣")), text, [{"label": "继续", "callback": Callable(self, "_close_event_panel")}])


func _trigger_event(e: Dictionary) -> void:
	pending_entity = e
	var opts: Array = e.get("options", [])
	var ui_options: Array = []
	for opt in opts:
		var o: Dictionary = opt
		var label: String = "%s\n→ %s" % [str(o.get("label", "?")), str(o.get("preview", ""))]
		ui_options.append({"label": label, "callback": Callable(self, "_on_event_choice").bind(o)})
	if ui_options.is_empty():
		ui_options.append({"label": "[离开]", "callback": Callable(self, "_close_event_panel")})
	_show_event_panel(str(e.get("name", "回响事件")), str(e.get("story", "")), ui_options)


func _on_event_choice(opt: Dictionary) -> void:
	_close_event_panel()
	# 应用 effect
	var msg: String = _apply_reward(opt)
	if pending_entity != null and not pending_entity.is_empty():
		# 事件触发后该节点消失（不论选哪个）
		var eid: String = str(pending_entity.get("id", ""))
		if eid != "":
			for i in data["entities"].size():
				if str(data["entities"][i].get("id", "")) == eid:
					data["entities"].remove_at(i)
					break
		_minimap.queue_redraw()
	pending_entity = {}
	# 玩家停在事件格上是空地，不必弹回
	_last_safe_grid = Vector2i(data["player"])
	if msg != "":
		_add_floating_text(_player_pixel + Vector2(0, -36), msg, Color(0.7, 1.0, 0.7))
	var result_text: String = str(opt.get("result", ""))
	if result_text.is_empty():
		result_text = msg if msg != "" else "回响渐渐散去，没有发生额外变化。"
	result_text = _result_body_with_change(result_text, msg)
	_show_event_panel("回响结果", result_text, [{"label": "继续", "callback": Callable(self, "_close_event_panel")}])


func _result_body_with_change(result_text: String, reward_text: String) -> String:
	if reward_text.is_empty():
		return result_text
	if result_text.is_empty() or result_text == reward_text:
		return "本次变化：%s" % reward_text
	return "%s\n\n本次变化：%s" % [result_text, reward_text]


## 把奖励 dict 应用到玩家。返回简短反馈文字
func _apply_reward(reward: Dictionary) -> String:
	var t: String = str(reward.get("type", ""))
	match t:
		"fragments":
			var amt: int = int(reward.get("amount", 0))
			GameState.add_fragments(amt)
			return "+%d 碎片" % amt
		"exp":
			var amt2: int = int(reward.get("amount", 0))
			RunState.add_exp(amt2)
			return "+%d EXP" % amt2
		"max_hp":
			var amt3: int = int(reward.get("amount", 0))
			RunState.max_hp += amt3
			RunState.hp = mini(RunState.max_hp, RunState.hp + amt3)
			RunState.hp_changed.emit(RunState.hp, RunState.max_hp)
			return "最大气血 +%d" % amt3
		"heal":
			var amt4: int = int(reward.get("amount", 0))
			RunState.heal(amt4)
			return "+%d 气血" % amt4
		"heal_full_cost":
			var cost: int = int(reward.get("cost", 0))
			if GameState.fragments < cost:
				return "碎片不足，作罢"
			GameState.add_fragments(-cost)
			RunState.heal(RunState.max_hp)
			return "气血已满"
		"max_hp_cost":
			var cost2: int = int(reward.get("cost", 0))
			var amt5: int = int(reward.get("amount", 0))
			if GameState.fragments < cost2:
				return "碎片不足，作罢"
			GameState.add_fragments(-cost2)
			RunState.max_hp += amt5
			RunState.hp = mini(RunState.max_hp, RunState.hp + amt5)
			RunState.hp_changed.emit(RunState.hp, RunState.max_hp)
			return "最大气血 +%d" % amt5
		"card":
			var cid: String = str(reward.get("card", ""))
			var card: Card = CardDatabase.get_card(cid)
			if card != null:
				RunState.add_card_to_deck(card)
				GameState.unlock_codex("card." + cid)
				return "+%s 入卡组" % card.title
			return ""
		"card_cost":
			var cost3: int = int(reward.get("cost", 0))
			if GameState.fragments < cost3:
				return "碎片不足，作罢"
			var cid2: String = str(reward.get("card", ""))
			var card2: Card = CardDatabase.get_card(cid2)
			if card2 != null:
				GameState.add_fragments(-cost3)
				RunState.add_card_to_deck(card2)
				GameState.unlock_codex("card." + cid2)
				return "+%s 入卡组" % card2.title
			return ""
	return ""


# ============== 古玩铺 ==============

const SHOP_CARD_PRICE: int = 35
const SHOP_HEAL_PRICE: int = 15
const SHOP_HEAL_AMOUNT: int = 30
const SHOP_MAXHP_PRICE: int = 30
const SHOP_MAXHP_AMOUNT: int = 5



func _append_shop_card(cid: String, west_cards: Array, offered_cards: Dictionary) -> bool:
	if cid.is_empty() or offered_cards.has(cid):
		return false
	var card: Card = CardDatabase.get_card(cid)
	if card == null:
		return false
	var price: int = 18 + card.rarity * 12
	if RunState.current_chapter_index >= RunState.CHAPTER_WEST and west_cards.has(cid):
		price += 6
	_shop_items.append({"type": "card", "label": _shop_card_label(card, price), "price": price, "card": cid})
	offered_cards[cid] = true
	return true


func _shop_card_label(card: Card, price: int) -> String:
	var tag: String = "【同伴召唤】" if _is_summon_card(card) else ""
	return "购买%s《%s》  %d 碎片" % [tag, card.title, price]


func _refresh_saved_shop_card_labels() -> void:
	for i in _shop_items.size():
		var raw_item: Variant = _shop_items[i]
		if not (raw_item is Dictionary):
			continue
		var item: Dictionary = raw_item
		if str(item.get("type", "")) != "card":
			continue
		var card: Card = _get_shop_card(item)
		if card == null:
			continue
		item["label"] = _shop_card_label(card, int(item.get("price", 0)))
		_shop_items[i] = item


func _is_summon_card(card: Card) -> bool:
	if card == null:
		return false
	for eff in card.effects:
		if eff.kind == CardEffect.Kind.SUMMON_ALLY:
			return true
	return false


func _shop_entity_index() -> int:
	if _shop_entity_id.is_empty():
		return -1
	for i in data["entities"].size():
		if str(data["entities"][i].get("id", "")) == _shop_entity_id:
			return i
	return -1


func _sync_shop_items_to_entity() -> void:
	var saved_items := _shop_items.duplicate(true)
	_shop_entity["shop_items"] = saved_items
	if not _shop_entity_id.is_empty():
		_shop_items_by_entity_id[_shop_entity_id] = saved_items
	var entity_index := _shop_entity_index()
	if entity_index < 0:
		return
	var entity: Dictionary = data["entities"][entity_index]
	entity["shop_items"] = saved_items
	data["entities"][entity_index] = entity


func _enter_shop(e: Dictionary) -> void:
	_shop_items = []
	_shop_buttons.clear()
	_shop_last_result = ""
	_shop_entity = e
	_shop_entity_id = str(e.get("id", ""))
	_shop_title = str(e.get("name", _default_shop_name()))
	_shop_story = str(e.get("story", ""))
	if _shop_story.is_empty():
		_shop_story = _default_shop_story()
	var saved_items: Variant = e.get("shop_items", null)
	if not _shop_entity_id.is_empty() and _shop_items_by_entity_id.has(_shop_entity_id):
		saved_items = _shop_items_by_entity_id[_shop_entity_id]
	var entity_index := _shop_entity_index()
	if entity_index >= 0:
		var entity: Dictionary = data["entities"][entity_index]
		if not (saved_items is Array and not Array(saved_items).is_empty()):
			saved_items = entity.get("shop_items", saved_items)
	if saved_items is Array and not Array(saved_items).is_empty():
		_shop_items = Array(saved_items).duplicate(true)
		_refresh_saved_shop_card_labels()
		_sync_shop_items_to_entity()
		_show_shop_panel()
		return
	var base_cards: Array = [
		"shan.jianmu", "shan.fusang", "shan.ruomu", "shan.luwu",
		"hai.yinglong_call", "hai.wenyao_evade", "hai.kun_swift", "hai.heluo_dive",
		"huang.qiongqi_lash", "huang.taotie_devour", "huang.kuafu_pursue", "huang.jingwei_fill",
		"neutral.scroll_study", "neutral.qi_gather", "neutral.warrior_oath",
	]
	var west_cards: Array = [
		"shan.luwu_gate", "shan.yingzhao_patrol", "hai.xuan_gui_shell",
		"hai.tiangou_ward", "huang.zheng_pounce", "huang.gudiao_cry",
	]
	var north_shop_cards: Array = [
		"hai.heluo_ally",
		"hai.beishan_mist", "shan.xuanwu_barrier", "hai.cold_current",
		"huang.memory_venom", "shan.black_ridge_guard", "hai.deep_pool_reflection",
		"neutral.archive_index", "neutral.echo_rehearse",
	]
	var east_shop_cards: Array = [
		"shan.dangkang_harvest",
		"shan.green_sprout_guard",
		"shan.spring_root",
		"hai.yinglong_rainpath",
		"hai.qiuyu_sleep",
		"hai.qinglong_ally",
		"huang.lingling_floodcall",
		"huang.zhuru_fright",
		"neutral.seed_catalog",
		"neutral.field_rehearsal",
	]
	var central_shop_cards: Array = [
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
		"neutral.five_realm_harmony",
	]
	var chapter_shop_cards: Array = west_cards.duplicate()
	if RunState.current_chapter_index == RunState.CHAPTER_CENTRAL:
		chapter_shop_cards = central_shop_cards.duplicate()
	elif RunState.current_chapter_index == RunState.CHAPTER_EAST:
		chapter_shop_cards = east_shop_cards.duplicate()
	elif RunState.current_chapter_index == RunState.CHAPTER_NORTH:
		chapter_shop_cards = north_shop_cards.duplicate()
	var pool: Array = base_cards.duplicate()
	var guaranteed_cards: Array = []
	if RunState.current_chapter_index >= RunState.CHAPTER_WEST:
		guaranteed_cards = west_cards.duplicate()
		pool.append_array(west_cards)
		pool.append_array(west_cards)
		pool.append_array(west_cards)
	if RunState.current_chapter_index == RunState.CHAPTER_NORTH:
		guaranteed_cards = ["hai.heluo_ally"]
		pool.append_array(north_shop_cards)
		pool.append_array(north_shop_cards)
		pool.append_array(north_shop_cards)
	elif RunState.current_chapter_index == RunState.CHAPTER_EAST:
		guaranteed_cards = ["shan.dangkang_harvest", "hai.yinglong_rainpath"]
		pool.append_array(east_shop_cards)
		pool.append_array(east_shop_cards)
		pool.append_array(east_shop_cards)
	elif RunState.current_chapter_index == RunState.CHAPTER_CENTRAL:
		guaranteed_cards = ["shan.qilin_virtue", "neutral.five_realm_harmony"]
		pool.append_array(central_shop_cards)
		pool.append_array(central_shop_cards)
		pool.append_array(central_shop_cards)
	pool.shuffle()
	var offered_cards: Dictionary = {}
	var added: int = 0
	if RunState.current_chapter_index >= RunState.CHAPTER_WEST:
		guaranteed_cards.shuffle()
		for cid in guaranteed_cards:
			if _append_shop_card(str(cid), chapter_shop_cards, offered_cards):
				added += 1
				break
	for cid in pool:
		if added >= 3:
			break
		if _append_shop_card(str(cid), chapter_shop_cards, offered_cards):
			added += 1
	if RunState.current_chapter_index == RunState.CHAPTER_CENTRAL:
		_shop_items.append({"type": "heal", "label": "中土玉露：恢复 44 HP  20 碎片", "price": 20, "amount": 44})
		_shop_items.append({"type": "max_hp", "label": "麒麟台玉符：最大 HP +12  42 碎片", "price": 42, "amount": 12})
	elif RunState.current_chapter_index == RunState.CHAPTER_EAST:
		_shop_items.append({"type": "heal", "label": "青芽露：恢复 36 HP  16 碎片", "price": 16, "amount": 36})
		_shop_items.append({"type": "max_hp", "label": "春木护符：最大 HP +10  34 碎片", "price": 34, "amount": 10})
	elif RunState.current_chapter_index >= RunState.CHAPTER_WEST:
		_shop_items.append({"type": "heal", "label": "白石药草：恢复 25 HP  12 碎片", "price": 12, "amount": 25})
		_shop_items.append({"type": "max_hp", "label": "山骨护符：最大 HP +8  28 碎片", "price": 28, "amount": 8})
	else:
		_shop_items.append({"type": "heal", "label": "灵芝散：恢复 %d HP  %d 碎片" % [SHOP_HEAL_AMOUNT, SHOP_HEAL_PRICE], "price": SHOP_HEAL_PRICE, "amount": SHOP_HEAL_AMOUNT})
		_shop_items.append({"type": "max_hp", "label": "古玉护符：最大 HP +%d  %d 碎片" % [SHOP_MAXHP_AMOUNT, SHOP_MAXHP_PRICE], "price": SHOP_MAXHP_PRICE, "amount": SHOP_MAXHP_AMOUNT})
	_shop_items.append({"type": "leave", "label": "[离开]", "price": 0})
	_sync_shop_items_to_entity()
	_show_shop_panel()


func _default_shop_name() -> String:
	match RunState.current_chapter_index:
		RunState.CHAPTER_CENTRAL:
			return "中土玉市"
		RunState.CHAPTER_EAST:
			return "青芽市集"
		RunState.CHAPTER_NORTH:
			return "寒市旧肆"
		RunState.CHAPTER_WEST:
			return "白石古肆"
	return "古玩铺"


func _default_shop_story() -> String:
	match RunState.current_chapter_index:
		RunState.CHAPTER_CENTRAL:
			return "商旅在祭坛外铺开玉片、陶符和旧简，专收五境余响。"
		RunState.CHAPTER_EAST:
			return "竹帘后传来雨声，摊上摆着春木符、青玉种和东山旧简。"
		RunState.CHAPTER_NORTH:
			return "无人的摊位亮着青白灯火，骨哨、冻墨和北山残简静静排开。"
		RunState.CHAPTER_WEST:
			return "石灯后坐着一位戴虎纹面具的老者，柜上摆着西山旧符。"
	return "店主戴狐面具，玻璃柜中陈列着几样东西。"


func _show_shop_panel() -> void:
	_event_panel.visible = true
	_event_title.text = _shop_title
	_refresh_shop_body()
	_clear_event_options()
	_shop_buttons.clear()
	for i in _shop_items.size():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(460, 44)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(Callable(self, "_on_shop_buy").bind(i))
		_event_options.add_child(btn)
		_shop_buttons.append(btn)
	_refresh_shop_buttons()


func _refresh_shop_body() -> void:
	var body := "%s\n\n你的灵韵碎片：%d" % [_shop_story, GameState.fragments]
	if not _shop_last_result.is_empty():
		body += "\n\n本次变化：%s" % _shop_last_result
	_event_body.text = body


func _refresh_shop_buttons() -> void:
	for i in _shop_buttons.size():
		var btn: Button = _shop_buttons[i]
		if i < 0 or i >= _shop_items.size():
			btn.text = "—— 商品异常 ——"
			btn.disabled = true
			continue
		var raw_item: Variant = _shop_items[i]
		if not (raw_item is Dictionary):
			btn.text = "—— 商品异常 ——"
			btn.disabled = true
			continue
		var item: Dictionary = raw_item
		var label: String = str(item.get("label", "—— 商品异常 ——"))
		if bool(item.get("sold", false)):
			btn.text = "—— 已售出 ——"
			btn.disabled = true
			continue
		if str(item.get("type", "")) == "leave":
			btn.text = label
			btn.disabled = false
			continue
		var price: int = int(item.get("price", 0))
		if GameState.fragments < price:
			btn.text = label + "   碎片不足"
			btn.disabled = true
		else:
			btn.text = label
			btn.disabled = false


func _get_shop_card(item: Dictionary) -> Card:
	var raw_card: Variant = item.get("card", null)
	if raw_card is Card:
		return raw_card
	var card_id: String = ""
	if item.has("card_id"):
		card_id = str(item["card_id"])
	elif raw_card != null:
		card_id = str(raw_card)
	if card_id.is_empty():
		return null
	return CardDatabase.get_card(card_id)


func _on_shop_buy(idx: int) -> void:
	if idx < 0 or idx >= _shop_items.size():
		return
	var raw_item: Variant = _shop_items[idx]
	if not (raw_item is Dictionary):
		return
	var item: Dictionary = raw_item
	var item_type: String = str(item.get("type", ""))
	if item_type == "leave":
		_close_event_panel()
		if not pending_entity.is_empty():
			var eid: String = str(pending_entity.get("id", ""))
			for j in data["entities"].size():
				if str(data["entities"][j].get("id", "")) == eid:
					data["entities"].remove_at(j)
					break
			_minimap.queue_redraw()
		pending_entity = {}
		_last_safe_grid = Vector2i(data["player"])
		_update_status()
		return
	if bool(item.get("sold", false)):
		return
	if item_type != "card" and item_type != "heal" and item_type != "max_hp":
		return
	var card_to_buy: Card = null
	if item_type == "card":
		card_to_buy = _get_shop_card(item)
		if card_to_buy == null:
			item["sold"] = true
			item["label"] = "—— 商品异常 ——"
			_shop_items[idx] = item
			_sync_shop_items_to_entity()
			_refresh_shop_body()
			_refresh_shop_buttons()
			return
	var price: int = int(item.get("price", 0))
	if GameState.fragments < price:
		return
	GameState.add_fragments(-price)
	item["sold"] = true
	AudioEngine.play_sfx("shop_buy")
	match item_type:
		"card":
			var card: Card = card_to_buy
			RunState.add_card_to_deck(card)
			GameState.unlock_codex("card." + card.id)
			_add_floating_text(_player_pixel + Vector2(0, -36), "+" + card.title, Color(1.0, 0.85, 0.4))
			_shop_last_result = "购买《%s》  -%d 碎片" % [card.title, price]
		"heal":
			var amount: int = int(item.get("amount", 0))
			RunState.heal(amount)
			_shop_last_result = "恢复 %d HP  -%d 碎片" % [amount, price]
		"max_hp":
			var amt: int = int(item.get("amount", 0))
			RunState.max_hp += amt
			RunState.hp = mini(RunState.max_hp, RunState.hp + amt)
			RunState.hp_changed.emit(RunState.hp, RunState.max_hp)
			_shop_last_result = "最大 HP +%d  -%d 碎片" % [amt, price]
	_shop_items[idx] = item
	_sync_shop_items_to_entity()
	_refresh_shop_body()
	_refresh_shop_buttons()
	_update_status()


# ============== 通用面板 ==============

func _clear_event_options() -> void:
	for c in _event_options.get_children():
		_event_options.remove_child(c)
		c.queue_free()


func _show_event_panel(title: String, body: String, options: Array) -> void:
	_event_panel.visible = true
	_event_title.text = title
	_event_body.text = body
	_clear_event_options()
	for opt in options:
		var btn := Button.new()
		btn.text = str(opt["label"])
		btn.custom_minimum_size = Vector2(420, 50)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.autowrap_mode = TextServer.AUTOWRAP_OFF
		btn.pressed.connect(opt["callback"])
		_event_options.add_child(btn)


func _close_event_panel() -> void:
	_event_panel.visible = false
	_clear_event_options()
	_update_status()


# ============== BOSS 奖励 ==============



func _grant_boss_reward(kind: String) -> void:
	var fragments: int = 20
	var exp_gain: int = 15
	var hp_bonus: int = 10
	var card_id: String = ""
	if RunState.current_chapter_index == RunState.CHAPTER_CENTRAL:
		match kind:
			"boss_weak":
				fragments = 105; exp_gain = 80; hp_bonus = 45; card_id = "shan.qilin_virtue"
			"boss_mid":
				fragments = 165; exp_gain = 120; hp_bonus = 65; card_id = "neutral.five_realm_harmony"
			"boss_hard":
				fragments = 260; exp_gain = 180; hp_bonus = 95; card_id = "hai.central_confluence"
			_:
				fragments = 105; exp_gain = 80; hp_bonus = 45
	elif RunState.current_chapter_index == RunState.CHAPTER_EAST:
		match kind:
			"boss_weak":
				fragments = 80; exp_gain = 60; hp_bonus = 35; card_id = "shan.spring_root"
			"boss_mid":
				fragments = 130; exp_gain = 95; hp_bonus = 55; card_id = "hai.qinglong_ally"
			"boss_hard":
				fragments = 220; exp_gain = 150; hp_bonus = 85; card_id = "hai.yinglong_rainpath"
			_:
				fragments = 80; exp_gain = 60; hp_bonus = 35
	elif RunState.current_chapter_index == RunState.CHAPTER_NORTH:
		match kind:
			"boss_weak":
				fragments = 60; exp_gain = 45; hp_bonus = 30; card_id = "shan.black_ridge_guard"
			"boss_mid":
				fragments = 105; exp_gain = 75; hp_bonus = 45; card_id = "hai.zhulong_ally"
			"boss_hard":
				fragments = 180; exp_gain = 120; hp_bonus = 70; card_id = "hai.deep_pool_reflection"
			_:
				fragments = 60; exp_gain = 45; hp_bonus = 30
	elif RunState.current_chapter_index >= RunState.CHAPTER_WEST:
		match kind:
			"boss_weak":
				fragments = 45; exp_gain = 35; hp_bonus = 25; card_id = "shan.yingzhao_patrol"
			"boss_mid":
				fragments = 85; exp_gain = 60; hp_bonus = 40; card_id = "shan.luwu_gate"
			"boss_hard":
				fragments = 150; exp_gain = 100; hp_bonus = 60; card_id = "huang.gudiao_cry"
			_:
				fragments = 45; exp_gain = 35; hp_bonus = 25
	else:
		match kind:
			"boss_weak":
				fragments = 30; exp_gain = 20; hp_bonus = 20
			"boss_mid":
				fragments = 60; exp_gain = 40; hp_bonus = 35
			"boss_hard":
				fragments = 120; exp_gain = 80; hp_bonus = 50
			_:
				fragments = 20; exp_gain = 15; hp_bonus = 10
	GameState.add_fragments(fragments)
	RunState.add_exp(exp_gain)
	RunState.max_hp += hp_bonus
	RunState.heal(hp_bonus)
	if card_id != "":
		var c: Card = CardDatabase.get_card(card_id)
		if c != null:
			RunState.add_card_to_deck(c)
			GameState.unlock_codex("card." + card_id)


func _boss_reward_line(kind: String) -> String:
	if RunState.current_chapter_index == RunState.CHAPTER_CENTRAL:
		match kind:
			"boss_weak": return "+105 碎片  +80 EXP  +45 HP  +麒麟德音"
			"boss_mid":  return "+165 碎片  +120 EXP  +65 HP  +五境调和"
			"boss_hard": return "+260 碎片  +180 EXP  +95 HP  +中流会同"
			_: return "+105 碎片  +80 EXP  +45 HP"
	if RunState.current_chapter_index == RunState.CHAPTER_EAST:
		match kind:
			"boss_weak": return "+80 灵韵碎片  +60 EXP  +35 HP  +《春根复萌》"
			"boss_mid":  return "+130 灵韵碎片  +95 EXP  +55 HP  +《青龙行雨》"
			"boss_hard": return "+220 灵韵碎片  +150 EXP  +85 HP  +《应龙开泽》"
			_: return "+80 灵韵碎片  +60 EXP  +35 HP"
	if RunState.current_chapter_index == RunState.CHAPTER_NORTH:
		match kind:
			"boss_weak": return "+60 灵韵碎片  +45 EXP  +30 HP  +《玄岭守势》"
			"boss_mid":  return "+105 灵韵碎片  +75 EXP  +45 HP  +《烛龙残照》"
			"boss_hard": return "+180 灵韵碎片  +120 EXP  +70 HP  +《深潭返照》"
			_: return "+60 灵韵碎片  +45 EXP  +30 HP"
	if RunState.current_chapter_index >= RunState.CHAPTER_WEST:
		match kind:
			"boss_weak": return "+45 碎片  +35 EXP  +25 HP  +《英招巡山》"
			"boss_mid":  return "+85 碎片  +60 EXP  +40 HP  +《陆吾镇门》"
			"boss_hard": return "+150 碎片  +100 EXP  +60 HP  +《蛊雕夜啼》"
			_: return "+45 碎片  +35 EXP  +25 HP"
	match kind:
		"boss_weak": return "+30 碎片  +20 EXP  +20 HP"
		"boss_mid":  return "+60 碎片  +40 EXP  +35 HP"
		"boss_hard": return "+120 碎片  +80 EXP  +50 HP"
		_: return "+20 碎片  +15 EXP  +10 HP"


func _codex_total_entries() -> int:
	return CardDatabase.all_cards().size() + EnemyDatabase.all_enemies().size()


func _final_clear_summary() -> String:
	var codex_total: int = max(1, _codex_total_entries())
	var codex_unlocked: int = GameState.unlocked_codex.size()
	var codex_percent: int = int(round(float(codex_unlocked) * 100.0 / float(codex_total)))
	var chapters: String = "南山 / 西山 / 北山"
	if RunState.current_chapter_index >= RunState.CHAPTER_EAST:
		chapters += " / 东山"
	if RunState.current_chapter_index >= RunState.CHAPTER_CENTRAL:
		chapters += " / 中山"
	return "本局结算：Lv.%d  EXP %d / %d\nHP %d / %d  灵韵 %d / %d\n碎片 %d  牌组 %d 张\n图鉴解锁 %d / %d（%d%%）\n完成章节：%s" % [
		RunState.level,
		RunState.exp_value,
		RunState.exp_to_next,
		RunState.hp,
		RunState.max_hp,
		RunState.energy,
		RunState.max_energy,
		GameState.fragments,
		RunState.run_deck.size(),
		codex_unlocked,
		codex_total,
		codex_percent,
		chapters,
	]

func _show_boss_victory(kind: String, name: String) -> void:
	_victory.visible = true
	var defeated: int = RunState.bosses_defeated
	var total: int = RunState.BOSSES_TO_CLEAR
	var chapter_name: String = str(data.get("title", _chapter_config().get("title", "南山 · 朱雀庭")))
	var reward_line: String = _boss_reward_line(kind)
	if defeated >= total:
		if RunState.has_next_chapter():
			_pending_chapter_advance = true
			var next_chapter_name: String = "西山 · 白虎境"
			var next_gate_text: String = "南山余火收束，西山白虎境已经开门。"
			if RunState.current_chapter_index == RunState.CHAPTER_WEST:
				next_chapter_name = "北山 · 玄武渊"
				next_gate_text = "西山金声沉入寒渊，北山玄武渊已经开门。"
			elif RunState.current_chapter_index == RunState.CHAPTER_NORTH:
				next_chapter_name = "东山 · 青龙原"
				next_gate_text = "北山寒雾退去，东山青龙原已经开门。"
			elif RunState.current_chapter_index == RunState.CHAPTER_EAST:
				next_chapter_name = "中山 · 麒麟台"
				next_gate_text = "东山青龙余雨归入中央土坛，麒麟台已显出方圆纹路。"
			_victory_text.text = "%s 已完成\n你净化了本章全部 %d 个 BOSS。\n%s\n\n本次变化：%s\n\n下一章：%s" % [chapter_name, total, next_gate_text, reward_line, next_chapter_name]
			_victory_btn.text = "进入%s" % next_chapter_name
		else:
			_pending_chapter_advance = false
			_victory_text.text = "v0.8 五境净化！\n你已连续完成「南山 · 朱雀庭」「西山 · 白虎境」「北山 · 玄武渊」「东山 · 青龙原」与「中山 · 麒麟台」。\n五方灵韵在麒麟台归一，祖父书房已经打开，可用典籍碎片启用下一局藏签。\n\n本次变化：%s\n\n%s\n\n（按下方按钮进入祖父书房。）" % [reward_line, _final_clear_summary()]
			_victory_btn.text = "进入祖父书房"
		return
	_pending_chapter_advance = false
	_victory_text.text = "击败 BOSS：%s\n本次变化：%s\n\n本章进度：%d / %d\n继续探索并完成剩余 BOSS。" % [name, reward_line, defeated, total]
	_victory_btn.text = "继续探索"
func _show_victory() -> void:
	# 兼容老调用：直接用进度感知版本（无 kind 时用占位）
	_show_boss_victory("", "BOSS")



func _on_victory_close() -> void:
	if _pending_chapter_advance:
		_pending_chapter_advance = false
		_victory.visible = false
		RunState.advance_to_next_chapter()
		data = _generate_map()
		RunState.map_data = data
		_enemy_facing.clear()
		for e in data["entities"]:
			if str(e["kind"]) == "enemy":
				_init_enemy_runtime(e)
		_player_pixel = _grid_center_pixel(Vector2i(data["player"]))
		_last_grid = Vector2i(data["player"])
		_last_safe_grid = _last_grid
		_title.text = _chapter_title()
		if _view_mode == ViewMode.ISOMETRIC:
			_update_iso_world_bounds()
			_iso_smooth_pos = _top_down_pixel_to_iso(_player_pixel)
		_update_camera()
		_update_status()
		queue_redraw()
		_minimap.queue_redraw()
		return
	if RunState.is_dead():
		RunState.reset_for_new_run()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	if RunState.bosses_defeated >= RunState.BOSSES_TO_CLEAR and not RunState.has_next_chapter():
		RunState.reset_for_new_run()
		get_tree().change_scene_to_file("res://scenes/meta/study_room.tscn")
		return
	_victory.visible = false
	_update_status()
	queue_redraw()
	_minimap.queue_redraw()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _color_for_kind(kind: String) -> Color:
	match kind:
		"enemy":     return COLOR_ENEMY
		"elite":     return COLOR_ELITE
		"boss_weak": return COLOR_BOSS_WEAK
		"boss_mid":  return COLOR_BOSS_MID
		"boss_hard": return COLOR_BOSS_HARD
		"shop":      return COLOR_SHOP
		"rest":      return COLOR_REST
		"treasure":  return COLOR_TREASURE
		"event":     return COLOR_EVENT
		"fragment":  return COLOR_FRAGMENT
	return Color.GRAY


# ============== 视野渲染（_draw 只画相机能看到的） ==============

func _draw() -> void:
	if _camera == null:
		return
	if _view_mode == ViewMode.ISOMETRIC:
		_draw_isometric()
		return
	# 相机实际中心（受 limit clamp 后）
	var center: Vector2 = _camera.get_screen_center_position()
	var top_left: Vector2 = center - Vector2(VIEWPORT_W, VIEWPORT_H) * 0.5
	var x_min: int = clampi(int(floor(top_left.x / TILE_SIZE)) - 1, 0, WORLD_W - 1)
	var y_min: int = clampi(int(floor(top_left.y / TILE_SIZE)) - 1, 0, WORLD_H - 1)
	var x_max: int = clampi(int(ceil((top_left.x + VIEWPORT_W) / TILE_SIZE)) + 1, 0, WORLD_W - 1)
	var y_max: int = clampi(int(ceil((top_left.y + VIEWPORT_H) / TILE_SIZE)) + 1, 0, WORLD_H - 1)

	# 1) 网格底色 + 像素纹理
	for y in range(y_min, y_max + 1):
		for x in range(x_min, x_max + 1):
			var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var v: int = int(data["tiles"][y][x])
			if v == 1:
				_draw_rock_tile(rect)
			else:
				_draw_ground_tile(rect, x, y)

	# 2) 实体（视野内）+ idle 浮动动画 + 方向动画
	var sprite_half: float = PixelSprites.PIXEL * PixelSprites.SIZE * 0.5
	for e in data["entities"]:
		var p: Vector2i = e["pos"]
		if p.x < x_min or p.x > x_max or p.y < y_min or p.y > y_max:
			continue
		var entity_pixel: Vector2
		if str(e["kind"]) == "enemy" and e.has("pixel_pos"):
			entity_pixel = e["pixel_pos"]
		else:
			entity_pixel = _grid_center_pixel(p)
		var bob: float = sin(_time_acc * 2.6 + (p.x + p.y) * 0.45) * 1.5
		var origin := Vector2(entity_pixel.x - sprite_half, entity_pixel.y - sprite_half + bob)
		_draw_entity_shadow_at(entity_pixel)
		# 根据朝向选择动画帧
		var e_key: String = _sprite_key_for_entity(e)
		var e_facing: String = PixelSprites.DIR_DOWN
		if str(e["kind"]) == "enemy":
			var eid: String = str(e["id"])
			if _enemy_facing.has(eid):
				e_facing = PixelSprites.facing_to_dir(_enemy_facing[eid])
		var e_frame: int = _anim_frame
		_draw_pixel_sprite_animated(origin, e_key, e_facing, e_frame)
		# 受击闪烁：在 sprite 上叠一层红色
		var flash: float = float(e.get("hit_flash", 0.0))
		if flash > 0.0:
			var rect := Rect2(origin.x, origin.y, PixelSprites.PIXEL * PixelSprites.SIZE, PixelSprites.PIXEL * PixelSprites.SIZE)
			draw_rect(rect, Color(1.0, 0.2, 0.2, clampf(flash, 0.0, 0.6)), true)
		# 小怪 HP 血条
		if str(e["kind"]) == "enemy" and e.has("max_hp"):
			_draw_hp_bar(entity_pixel + Vector2(0, -sprite_half - 10), int(e["hp"]), int(e["max_hp"]))

	# 3) 玩家（连续位置 + 方向动画）
	var pbob: float = sin(_time_acc * 3.2) * 1.2
	_draw_entity_shadow_at(_player_pixel)
	_draw_player_halo_top(_player_pixel, PLAYER_COLLISION_RADIUS_TOP)
	var player_facing: String = PixelSprites.facing_to_dir(_facing)
	# 攻击动画：攻击 CD 中显示剑击帧
	var is_attacking: bool = _player_attack_cd > PLAYER_ATTACK_RATE * 0.3
	var foot_pos := _player_pixel + Vector2(0, TILE_SIZE * 0.42 + pbob)
	_draw_warrior_player(foot_pos, player_facing, is_attacking, WARRIOR_TOP_SCALE)
	# 玩家头顶 HP 血条
	_draw_hp_bar(foot_pos + Vector2(0, -150.0 * WARRIOR_TOP_SCALE), RunState.hp, RunState.max_hp)

	# 4) 飘字
	if _font:
		var fs: int = 18
		for ft in _floating_texts:
			var age: float = ft["age"]
			var alpha: float = clampf(1.0 - age, 0.0, 1.0)
			var col: Color = ft["color"]
			col.a = alpha
			var pos: Vector2 = ft["pos"]
			draw_string(_font, pos, str(ft["text"]), HORIZONTAL_ALIGNMENT_CENTER, -1, fs, col)


# ============== 等距模式渲染 ==============

func _draw_isometric() -> void:
	var visible_rect: Rect2 = _camera_visible_world_rect(220.0)
	var corners: Array[Vector2] = [
		visible_rect.position,
		visible_rect.position + Vector2(visible_rect.size.x, 0),
		visible_rect.position + Vector2(0, visible_rect.size.y),
		visible_rect.position + visible_rect.size,
	]
	var view_x_min: int = WORLD_W - 1
	var view_x_max: int = 0
	var view_y_min: int = WORLD_H - 1
	var view_y_max: int = 0
	for corner in corners:
		var g: Vector2i = _iso_screen_to_grid(corner)
		view_x_min = mini(view_x_min, g.x)
		view_x_max = maxi(view_x_max, g.x)
		view_y_min = mini(view_y_min, g.y)
		view_y_max = maxi(view_y_max, g.y)
	var floor_x_min: int = view_x_min - 6 - ISO_VISUAL_GROUND_PADDING
	var floor_x_max: int = view_x_max + 6 + ISO_VISUAL_GROUND_PADDING
	var floor_y_min: int = view_y_min - 6 - ISO_VISUAL_GROUND_PADDING
	var floor_y_max: int = view_y_max + 6 + ISO_VISUAL_GROUND_PADDING
	var x_min: int = clampi(view_x_min - 6, 0, WORLD_W - 1)
	var x_max: int = clampi(view_x_max + 6, 0, WORLD_W - 1)
	var y_min: int = clampi(view_y_min - 6, 0, WORLD_H - 1)
	var y_max: int = clampi(view_y_max + 6, 0, WORLD_H - 1)

	# 收集视野内所有内容，分 4 层绘制
	var floor_list: Array = []
	var tile_list: Array = []
	var tree_list: Array = []
	var entity_list: Array = []
	var player_item: Dictionary = {}

	for y in range(floor_y_min, floor_y_max + 1):
		for x in range(floor_x_min, floor_x_max + 1):
			var floor_center: Vector2 = _grid_to_pixel(Vector2i(x, y))
			if not visible_rect.has_point(floor_center):
				continue
			floor_list.append({"x": x, "y": y, "center": floor_center})

	for y in range(y_min, y_max + 1):
		for x in range(x_min, x_max + 1):
			var g := Vector2i(x, y)
			var center: Vector2 = _grid_to_pixel(g)
			if not visible_rect.has_point(center):
				continue
			var is_wall := int(data["tiles"][y][x]) == 1
			var z := x + y
			tile_list.append({"x": x, "y": y, "center": center, "z": z, "wall": is_wall})
			if is_wall:
				tree_list.append({"x": x, "y": y, "center": center, "z": z})

	for e in data["entities"]:
		var p: Vector2i = e["pos"]
		if p.x < x_min or p.x > x_max or p.y < y_min or p.y > y_max:
			continue
		var iso_pos: Vector2 = _top_down_pixel_to_iso(e["pixel_pos"]) if str(e["kind"]) == "enemy" and e.has("pixel_pos") else _grid_to_pixel(p)
		if not visible_rect.has_point(iso_pos):
			continue
		entity_list.append({"pos": p, "center": iso_pos, "data": e, "z": p.x + p.y})

	player_item = {"center": _top_down_pixel_to_iso(_player_pixel), "z": data["player"].x + data["player"].y}

	# 同层内按 z 排序（后方先画）
	# ---- 第1层：所有草方块（地板） ----
	var floor_tileset_name: String = str(data.get("iso_floor_tileset", ISO_FLOOR_TILESET_NAME))
	if RunState.current_chapter_index == RunState.CHAPTER_WEST:
		floor_tileset_name = "forest"
	var td: Dictionary = PixelSprites.iso_tile_texture(floor_tileset_name)
	var wall_td: Dictionary = PixelSprites.iso_tile_texture(str(data.get("iso_wall_tileset", ISO_WALL_TILESET_NAME)))
	var has_tex := not td.is_empty() and td.has("tex")
	var has_wall_tex := not wall_td.is_empty() and wall_td.has("tex")
	var ts := int(td.get("ts", 128))
	var cols := int(max(1, int(td.get("cols", 5))))
	var floor_row: int = max(0, int(data.get("iso_floor_row", 0)))
	var floor_col_offset: int = clampi(int(data.get("iso_floor_col_offset", 0)), 0, cols - 1)
	var floor_col_count: int = clampi(int(data.get("iso_floor_col_count", 2)), 1, cols)
	if RunState.current_chapter_index == RunState.CHAPTER_WEST:
		floor_row = 1
		floor_col_offset = clampi(1, 0, cols - 1)
		floor_col_count = max(1, cols - floor_col_offset)
	var is_west_floor: bool = RunState.current_chapter_index == RunState.CHAPTER_WEST
	var is_north_floor: bool = RunState.current_chapter_index == RunState.CHAPTER_NORTH
	var is_east_floor: bool = RunState.current_chapter_index == RunState.CHAPTER_EAST
	var is_central_floor: bool = RunState.current_chapter_index == RunState.CHAPTER_CENTRAL
	for t in floor_list:
		var center: Vector2 = t.center
		var r := Rect2(center.x - ISO_HALF_W, center.y - ISO_HALF_H, ISO_TILE_W, ISO_FLOOR_H)
		if is_central_floor:
			_draw_iso_central_floor(center, int(t.x), int(t.y))
		elif is_north_floor and not has_tex:
			var ice_color: Color = Color("#294b63") if (int(t.x) + int(t.y)) % 2 == 0 else Color("#223f54")
			_draw_iso_floor_diamond(center, ice_color)
		elif is_west_floor:
			var dirt_color: Color = Color("#7a4d24") if (int(t.x) + int(t.y)) % 2 == 0 else Color("#6a411f")
			_draw_iso_floor_diamond(center, dirt_color)
		elif is_east_floor and not has_tex:
			_draw_iso_east_floor(center, int(t.x), int(t.y))
		if has_tex:
			var local_col: int = posmod(int(t.x) * 7 + int(t.y) * 3, floor_col_count)
			var gcol: int = clampi(floor_col_offset + local_col, 0, cols - 1)
			draw_texture_rect_region(td.tex, r, Rect2(gcol * ts, floor_row * ts, ts, ISO_FLOOR_H))
		else:
			if not is_west_floor and not is_north_floor and not is_east_floor and not is_central_floor:
				_draw_iso_floor_diamond(center, COLOR_GRASS_A if (int(t.x) + int(t.y)) % 2 == 0 else COLOR_GRASS_B)

	_draw_iso_navigation_context(visible_rect)

	var object_list: Array = []
	for t in tree_list:
		object_list.append({"kind": "wall", "center": t.center, "x": t.x, "y": t.y, "z": float(t.z) + 0.65, "order": 3})
	for e_item in entity_list:
		object_list.append({"kind": "entity", "center": e_item.center, "data": e_item.data, "z": e_item.z, "order": 2})
	object_list.append({"kind": "player", "center": player_item.center, "z": player_item.z, "order": 2})
	object_list.sort_custom(func(a, b):
		if a.z == b.z:
			return a.order < b.order
		return a.z < b.z
	)

	for item in object_list:
		match str(item.kind):
			"wall":
				_draw_iso_wall(item, has_wall_tex, wall_td, int(wall_td.get("ts", 128)), int(data.get("iso_wall_col", -1)))
			"entity":
				_draw_iso_entity(item)
			"player":
				_draw_iso_player(item.center)

	# ---- 飘字 ----
	if _font:
		for ft in _floating_texts:
			var age: float = ft["age"]
			var col: Color = ft["color"]
			col.a = clampf(1.0 - age, 0.0, 1.0)
			var pos: Vector2 = _top_down_pixel_to_iso(Vector2(ft["pos"])) + Vector2(0, -42)
			draw_string(_font, pos, str(ft["text"]), HORIZONTAL_ALIGNMENT_CENTER, -1, 18, col)


func _draw_iso_walkable_marker(center: Vector2, is_current: bool) -> void:
	var pts := _iso_walkable_pts(center)
	var fill_alpha: float = 0.12 if is_current else 0.06
	var line_alpha: float = 0.78 if is_current else 0.34
	draw_colored_polygon(pts, Color(0.32, 0.78, 1.0, fill_alpha))
	var closed := PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]])
	draw_polyline(closed, Color(0.62, 0.92, 1.0, line_alpha), 2.5 if is_current else 1.25)


func _draw_iso_blocked_marker(center: Vector2) -> void:
	var pts := _iso_walkable_pts(center)
	draw_colored_polygon(pts, Color(0.12, 0.05, 0.02, 0.20))
	var closed := PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]])
	draw_polyline(closed, Color(1.0, 0.58, 0.22, 0.72), 2.0)


func _draw_iso_navigation_context(visible_rect: Rect2) -> void:
	var current := _player_indicator_grid()
	if _is_blocked_grid(current):
		return
	var current_center: Vector2 = _grid_to_pixel(current)
	if visible_rect.has_point(current_center):
		_draw_iso_walkable_marker(current_center, true)
	if _facing == Vector2i.ZERO:
		return
	var front := current + _facing
	if front.x < 0 or front.y < 0 or front.x >= WORLD_W or front.y >= WORLD_H:
		return
	var front_center: Vector2 = _grid_to_pixel(front)
	if not visible_rect.has_point(front_center):
		return
	if _is_blocked_grid(front):
		_draw_iso_blocked_marker(front_center)
	else:
		_draw_iso_walkable_marker(front_center, false)


func _player_indicator_grid() -> Vector2i:
	var current := Vector2i(int(_player_pixel.x / TILE_SIZE), int(_player_pixel.y / TILE_SIZE))
	if not _is_blocked_grid(current):
		return current
	if not _is_blocked_grid(_last_safe_grid):
		return _last_safe_grid
	return current


func _draw_iso_wall(item: Dictionary, has_tex: bool, td: Dictionary, ts: int, fixed_col: int = -1) -> void:
	var center: Vector2 = item.center
	if has_tex:
		var tcol: int = fixed_col if fixed_col >= 0 else int((int(item.x) * 3 + int(item.y)) % 5)
		var tr := Rect2(center.x - ISO_HALF_W, center.y + ISO_HALF_H - ISO_TILE_H, ISO_TILE_W, ISO_TILE_H)
		draw_texture_rect_region(td.tex, tr, Rect2(tcol * ts, 0, ts, ts))
	else:
		if RunState.current_chapter_index == RunState.CHAPTER_CENTRAL:
			_draw_iso_central_wall(center, int(item.x), int(item.y))
		elif RunState.current_chapter_index == RunState.CHAPTER_EAST:
			_draw_iso_bamboo_wall(center, int(item.x), int(item.y))
		else:
			_draw_iso_tree_fallback(center)


func _draw_iso_entity(item: Dictionary) -> void:
	var e: Dictionary = item.data
	var iso_pos: Vector2 = item.center
	var sprite_size: float = PixelSprites.PIXEL * PixelSprites.SIZE * ISO_ENEMY_SPRITE_SCALE
	var sprite_half: float = sprite_size * 0.5
	var foot_pos := iso_pos
	var origin := Vector2(foot_pos.x - sprite_half, foot_pos.y - sprite_size)
	var e_key := _sprite_key_for_entity(e)
	var e_facing: String = PixelSprites.DIR_DOWN
	var enemy_id := ""
	if str(e["kind"]) == "enemy":
		var eid2: String = str(e["id"])
		if _enemy_facing.has(eid2):
			e_facing = PixelSprites.facing_to_dir(_enemy_facing[eid2])
		var enemy_ids: Array = e.get("enemies", [])
		if not enemy_ids.is_empty():
			enemy_id = str(enemy_ids[0])
	var iso_key: String = enemy_id if enemy_id != "" else e_key
	_draw_iso_entity_shadow(iso_pos, clampf(_iso_entity_scale_for_key(iso_key), 0.75, 1.35))
	var sprite_rect := Rect2(origin.x, origin.y, sprite_half * 2, sprite_half * 2)
	var e_frame: int = _anim_frame
	var iso_tex: Texture2D = PixelSprites.iso_enemy_texture(iso_key, e_facing, e_frame)
	if iso_tex != null:
		var tex_scale: float = _iso_entity_scale_for_key(iso_key)
		var tex_size := iso_tex.get_size() * tex_scale
		var anchor_y: float = _iso_entity_anchor_ratio_for_key(iso_key)
		sprite_rect = Rect2(foot_pos.x - tex_size.x * 0.5, foot_pos.y - tex_size.y * anchor_y, tex_size.x, tex_size.y)
		draw_texture_rect(iso_tex, sprite_rect, false)
	else:
		_draw_pixel_sprite_animated(origin, e_key, e_facing, e_frame, ISO_ENEMY_SPRITE_SCALE)
	var flash: float = float(e.get("hit_flash", 0.0))
	if flash > 0.0:
		draw_rect(sprite_rect, Color(1.0, 0.2, 0.2, clampf(flash, 0.0, 0.6)), true)
	if str(e["kind"]) == "enemy" and e.has("max_hp"):
		_draw_hp_bar(Vector2(foot_pos.x, sprite_rect.position.y - 8), int(e["hp"]), int(e["max_hp"]))



func _iso_entity_scale_for_key(key: String) -> float:
	if key.begins_with("boss"):
		return 1.12
	match key:
		"elite", "elite_yingzhao", "elite_xiangliu_shadow", "elite_yinglong_young", "elite_ji_meng":
			return 1.00
		"kui":
			return 1.02
		"tu_lou", "jiao_beast", "wen_lin":
			return 0.94
		"ling_ling":
			return 0.98
		"dang_kang", "qiu_yu", "zhu_ru":
			return 0.92
		"zhuhuai":
			return 0.96
		"he_luo_fish", "fei_yi", "xiao_beast":
			return 0.92
		"zheng_beast", "tian_gou", "xuan_gui", "gu_diao":
			return 0.92
		"hu_diao", "lu_shu", "cong_cong", "lei_beast":
			return 0.86
		"treasure":
			return 0.66
		"shop", "rest", "event":
			return 0.72
		"fragment":
			return 0.52
		_:
			return 0.84


func _iso_entity_anchor_ratio_for_key(key: String) -> float:
	if key.begins_with("boss"):
		return 0.92
	match key:
		"elite", "elite_yingzhao", "elite_xiangliu_shadow", "elite_yinglong_young", "elite_ji_meng":
			return 0.90
		"zheng_beast", "tian_gou", "xuan_gui", "gu_diao", "hu_diao", "lu_shu", "cong_cong", "lei_beast", "he_luo_fish", "fei_yi", "zhuhuai", "xiao_beast", "dang_kang", "qiu_yu", "ling_ling", "zhu_ru", "kui", "tu_lou", "jiao_beast", "wen_lin":
			return 0.88
		"treasure", "shop", "rest", "event", "fragment":
			return 0.86
		_:
			return 0.84

func _draw_warrior_player(foot_pos: Vector2, facing: String, is_attacking: bool, scale: float) -> void:
	var anim := "idle"
	var frame := _anim_frame % 4
	if is_attacking:
		anim = "attack"
		frame = 0 if _player_attack_cd > PLAYER_ATTACK_RATE * 0.6 else 1
	elif _was_moving:
		anim = "walk"
	var tex: Texture2D = PixelSprites.iso_player_texture(anim, facing, frame)
	if tex == null:
		_draw_pixel_sprite_animated(foot_pos - Vector2(PixelSprites.PIXEL * PixelSprites.SIZE * 0.5, PixelSprites.PIXEL * PixelSprites.SIZE), "player", facing, frame)
		return
	var size := tex.get_size() * scale
	var rect := Rect2(foot_pos.x - size.x * 0.5, foot_pos.y - size.y, size.x, size.y)
	draw_texture_rect(tex, rect, false)


func _draw_iso_player(ppos: Vector2) -> void:
	var player_facing: String = PixelSprites.facing_to_dir(_facing)
	var is_attacking: bool = _player_attack_cd > PLAYER_ATTACK_RATE * 0.3
	var foot_pos := ppos
	_draw_iso_entity_shadow(ppos)
	_draw_player_halo_iso(ppos, PLAYER_COLLISION_RADIUS_ISO)
	_draw_warrior_player(foot_pos, player_facing, is_attacking, WARRIOR_ISO_SCALE)
	_draw_hp_bar(foot_pos + Vector2(0, -150.0 * WARRIOR_ISO_SCALE), RunState.hp, RunState.max_hp)


## 降级：纯色菱形 + 简单树
func _draw_iso_tree_fallback(center: Vector2) -> void:
	var trunk := Rect2(center.x - 4, center.y - ISO_HALF_H - 24, 8, 24)
	draw_rect(trunk, Color("#5a3a22"), true)
	var crown_cy := center.y - ISO_HALF_H - 32
	draw_circle(Vector2(center.x, crown_cy), 12, Color("#2a5a2a"))
	draw_circle(Vector2(center.x - 4, crown_cy + 4), 9, Color("#3a6a3a"))


func _draw_iso_east_floor(center: Vector2, x: int, y: int) -> void:
	var h: int = ((x * 73856093) ^ (y * 19349663)) & 0xFFFFFF
	var base: Color = Color("#2f8065") if (x + y) % 2 == 0 else Color("#246d5a")
	var pts: PackedVector2Array = _iso_walkable_pts(center)
	draw_colored_polygon(pts, base)
	var inner: PackedVector2Array = PackedVector2Array([
		lerp(pts[0], center, 0.32),
		lerp(pts[1], center, 0.32),
		lerp(pts[2], center, 0.32),
		lerp(pts[3], center, 0.32),
	])
	draw_colored_polygon(inner, Color("#3a9b72") if (h & 1) == 0 else Color("#2d8a75"))
	if (h % 100) < 44:
		var stream_y := center.y + float((h >> 5) % 9 - 4)
		draw_line(Vector2(center.x - 36, stream_y), Vector2(center.x + 36, stream_y - 12), Color(0.43, 0.85, 0.88, 0.42), 2.0)
		draw_line(Vector2(center.x - 18, stream_y + 8), Vector2(center.x + 24, stream_y + 1), Color(0.70, 0.95, 0.88, 0.25), 1.0)
	if ((h >> 8) % 100) < 38:
		var sprout: Vector2 = Vector2(center.x + float((h >> 13) % 42 - 21), center.y + float((h >> 18) % 22 - 6))
		draw_line(sprout, sprout + Vector2(-4, -9), Color("#12392f"), 2.0)
		draw_line(sprout + Vector2(-1, -5), sprout + Vector2(7, -13), Color("#95d771"), 2.0)
		draw_line(sprout + Vector2(1, -3), sprout + Vector2(-8, -10), Color("#5db86e"), 1.5)
	if ((h >> 3) % 100) < 18:
		var scale_pos: Vector2 = Vector2(center.x + float((h >> 9) % 38 - 19), center.y + float((h >> 15) % 18 - 4))
		draw_colored_polygon(PackedVector2Array([
			scale_pos + Vector2(0, -6),
			scale_pos + Vector2(8, 0),
			scale_pos + Vector2(0, 5),
			scale_pos + Vector2(-8, 0),
		]), Color("#8bd0b0"))


func _draw_iso_central_floor(center: Vector2, x: int, y: int) -> void:
	var h: int = ((x * 83492791) ^ (y * 297121507)) & 0xFFFFFF
	var base: Color = Color("#9a7441") if (x + y) % 2 == 0 else Color("#86643a")
	var pts: PackedVector2Array = _iso_walkable_pts(center)
	draw_colored_polygon(pts, base)
	var inner: PackedVector2Array = PackedVector2Array([
		lerp(pts[0], center, 0.28),
		lerp(pts[1], center, 0.28),
		lerp(pts[2], center, 0.28),
		lerp(pts[3], center, 0.28),
	])
	draw_colored_polygon(inner, Color("#b58e55") if (h & 1) == 0 else Color("#7f9a75"))
	if (h % 100) < 46:
		var ring_alpha: float = 0.24 if (h & 2) == 0 else 0.16
		draw_arc(center, 22.0, 0.0, TAU, 20, Color(0.86, 0.74, 0.46, ring_alpha), 2.0)
	if ((h >> 7) % 100) < 36:
		var a: Vector2 = center + Vector2(-34, -4 + float((h >> 12) % 7))
		var b: Vector2 = center + Vector2(34, 6 - float((h >> 17) % 7))
		draw_line(a, b, Color(0.52, 0.40, 0.23, 0.32), 2.0)
		draw_line(Vector2(center.x - 20, center.y + 11), Vector2(center.x + 18, center.y - 10), Color(0.92, 0.78, 0.45, 0.18), 1.0)
	if ((h >> 3) % 100) < 18:
		var jade: Vector2 = center + Vector2(float((h >> 9) % 34 - 17), float((h >> 15) % 16 - 5))
		draw_colored_polygon(PackedVector2Array([
			jade + Vector2(0, -5),
			jade + Vector2(7, 0),
			jade + Vector2(0, 5),
			jade + Vector2(-7, 0),
		]), Color("#b6d3aa"))


func _draw_iso_central_wall(center: Vector2, x: int, y: int) -> void:
	var h: int = ((x * 92837111) ^ (y * 689287499)) & 0xFFFFFF
	var base: Vector2 = center + Vector2(0, ISO_HALF_H * 0.42)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-34, -1),
		base + Vector2(0, -15),
		base + Vector2(34, -1),
		base + Vector2(0, 12),
	]), Color(0.18, 0.11, 0.05, 0.42))
	var top: Vector2 = base + Vector2(0, -30 - float(h & 7))
	draw_line(base + Vector2(-24, -1), top + Vector2(-16, 0), Color("#5f4528"), 7.0)
	draw_line(base + Vector2(24, -1), top + Vector2(16, 0), Color("#5f4528"), 7.0)
	draw_line(top + Vector2(-16, 0), top + Vector2(16, 0), Color("#c6a267"), 8.0)
	draw_line(top + Vector2(-10, -8), top + Vector2(10, -8), Color("#e0c37b"), 4.0)
	draw_circle(top + Vector2(0, -14), 7.0, Color("#b9d0a4"))
	if (h % 100) < 38:
		draw_line(base + Vector2(-28, 5), base + Vector2(28, 5), Color("#d3ad62"), 2.0)


func _draw_iso_bamboo_wall(center: Vector2, x: int, y: int) -> void:
	var h: int = ((x * 92837111) ^ (y * 689287499)) & 0xFFFFFF
	var base: Vector2 = center + Vector2(0, ISO_HALF_H * 0.42)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-28, -2),
		base + Vector2(0, -13),
		base + Vector2(28, -2),
		base + Vector2(0, 9),
	]), Color(0.03, 0.13, 0.10, 0.48))
	for i in 4:
		var ox: float = float(-13 + i * 8 + int((h >> (i * 3)) & 3) - 1)
		var height: float = float(50 + int((h >> (i * 4 + 2)) & 11))
		var root: Vector2 = base + Vector2(ox, float(i % 2) * 2.5)
		var top: Vector2 = root + Vector2(float((i % 3) - 1) * 1.4, -height)
		draw_line(root, top, Color("#10372f"), 5.0)
		draw_line(root + Vector2(1, 0), top + Vector2(1, 0), Color("#4e9c68"), 2.2)
		for n in 3:
			var node_y: float = lerp(root.y, top.y, float(n + 1) / 4.0)
			draw_line(Vector2(root.x - 2, node_y), Vector2(root.x + 3, node_y - 1), Color("#8fc274"), 1.1)
		var leaf_dir: float = -1.0 if i % 2 == 0 else 1.0
		draw_line(top + Vector2(0, 5), top + Vector2(leaf_dir * 13, -4), Color("#5fa96b"), 2.2)
		draw_line(top + Vector2(0, 8), top + Vector2(-leaf_dir * 10, -1), Color("#2c7658"), 1.6)


func _draw_iso_diamond(center: Vector2, color: Color) -> void:
	draw_colored_polygon(_iso_diamond_pts(center), color)


func _draw_iso_floor_diamond(center: Vector2, color: Color) -> void:
	draw_colored_polygon(_iso_walkable_pts(center), color)


func _iso_diamond_pts(center: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(center.x, center.y - ISO_HALF_H),           # top
		Vector2(center.x + ISO_HALF_W, center.y),            # right
		Vector2(center.x, center.y + ISO_HALF_H),            # bottom
		Vector2(center.x - ISO_HALF_W, center.y),            # left
	])


func _iso_walkable_pts(center: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(center.x, center.y - ISO_HALF_H),
		Vector2(center.x + ISO_HALF_W, center.y),
		Vector2(center.x, center.y + ISO_HALF_H),
		Vector2(center.x - ISO_HALF_W, center.y),
	])


func _draw_iso_entity_shadow(pos: Vector2, scale: float = 1.0) -> void:
	# 简化的椭圆阴影（用多边形近似）
	var pts: PackedVector2Array = PackedVector2Array()
	var center := pos + Vector2(0, 4.0 * scale)
	var seg: int = 16
	for i in seg:
		var a: float = TAU * i / seg
		pts.append(Vector2(center.x + cos(a) * 14 * scale, center.y + sin(a) * 3.5 * scale))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.35))


func _draw_player_halo_top(center: Vector2, radius: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time_acc * 5.0)
	var rx: float = radius * (1.0 + pulse * 0.08)
	var ry: float = radius * 0.45 * (1.0 + pulse * 0.08)
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 32:
		var a: float = TAU * i / 32.0
		pts.append(Vector2(center.x + cos(a) * rx, center.y + TILE_SIZE * 0.36 + sin(a) * ry))
	draw_colored_polygon(pts, Color(0.12, 0.56, 1.0, 0.16 + pulse * 0.08))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.38, 0.78, 1.0, 0.65 + pulse * 0.25), 2.0)


func _draw_player_halo_iso(center: Vector2, radius: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time_acc * 5.0)
	var rx: float = radius * 1.75 * (1.0 + pulse * 0.08)
	var ry: float = radius * 0.88 * (1.0 + pulse * 0.08)
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 32:
		var a: float = TAU * i / 32.0
		pts.append(Vector2(center.x + cos(a) * rx, center.y + sin(a) * ry))
	draw_colored_polygon(pts, Color(0.12, 0.56, 1.0, 0.16 + pulse * 0.08))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.38, 0.78, 1.0, 0.65 + pulse * 0.25), 2.0)


func _top_floor_tileset_name() -> String:
	if data.has("top_floor_tileset"):
		return str(data.get("top_floor_tileset", "grass"))
	return "dirt" if RunState.current_chapter_index >= RunState.CHAPTER_WEST else "grass"


func _draw_ground_tile(rect: Rect2, x: int, y: int) -> void:
	var tile_name: String = _top_floor_tileset_name()
	var td: Dictionary = PixelSprites.tile_texture(tile_name)
	if td.has("tex") and td.tex != null:
		draw_texture_rect_region(td.tex, rect, td.region)
		return

	var checker: bool = (x + y) % 2 == 0
	var base: Color = COLOR_GRASS_A if checker else COLOR_GRASS_B
	var dark: Color = COLOR_GRASS_DARK
	if tile_name == "dirt":
		base = Color("#7b5732") if checker else Color("#6c4a2a")
		dark = Color("#4a311d")
	elif tile_name == "stone_floor":
		base = Color("#33556a") if checker else Color("#29495d")
		dark = Color("#1c3344")
	elif tile_name == "east_meadow":
		base = Color("#2e8066") if checker else Color("#236f5d")
		dark = Color("#123d34")
	elif tile_name == "central_altar":
		base = Color("#9a7441") if checker else Color("#846139")
		dark = Color("#55391e")

	var sub: float = TILE_SIZE / 8.0
	var tile_h: int = ((x * 73856093) ^ (y * 19349663)) & 0xFFFFFF
	var is_stone_floor: bool = tile_name == "stone_floor"
	var is_east_meadow: bool = tile_name == "east_meadow"
	var is_central_altar: bool = tile_name == "central_altar"
	var has_flower: bool = tile_name != "dirt" and not is_stone_floor and not is_east_meadow and (tile_h % 100) < 6
	var flower_pos: Vector2i = Vector2i((tile_h >> 8) % 6 + 1, (tile_h >> 16) % 6 + 1)
	var has_moss: bool = tile_name != "dirt" and not is_stone_floor and ((tile_h >> 4) % 100) < (28 if is_east_meadow else 12) and not checker
	var has_pebble: bool = ((tile_h >> 2) % 100) < (14 if is_stone_floor else (10 if tile_name == "dirt" else 4))
	var pebble_pos: Vector2i = Vector2i((tile_h >> 10) % 5 + 1, (tile_h >> 18) % 5 + 1)
	var grass_density: int = 0 if tile_name == "dirt" or is_stone_floor else ((tile_h >> 5) % 5 if is_east_meadow else (tile_h >> 5) % 4)
	if is_east_meadow:
		_draw_east_meadow_top_tile(rect, checker, tile_h)
		return
	if is_central_altar:
		_draw_central_altar_top_tile(rect, checker, tile_h)
		return
	for sy in 8:
		for sx in 8:
			var h: int = ((x * 73856093) ^ (y * 19349663) ^ (sx * 83492791) ^ (sy * 12289)) & 0xFFFFFF
			var c: Color = base
			var v: int = h % 64
			var sub_h: int = (h >> 8) % 100
			if is_east_meadow and (sx == ((tile_h >> 7) % 6 + 1) or sy == ((tile_h >> 12) % 6 + 1)) and sub_h < 10:
				c = Color("#6fc9a5") if sub_h < 6 else Color("#9bd56f")
			elif is_east_meadow and sx >= 1 and sx <= 6 and sy == ((tile_h >> 18) % 5 + 1) and sub_h < 18:
				c = Color("#5fb7b4") if (sx + sy + tile_h) % 2 == 0 else Color("#b8e7ca")
			elif is_east_meadow and sx == 6 and sy == 2 and sub_h < 45:
				c = Color("#bddf8a")
			elif has_flower and sx == flower_pos.x and sy == flower_pos.y:
				c = COLOR_FLOWER
			elif has_pebble and sx >= pebble_pos.x and sx <= pebble_pos.x + 1 and sy >= pebble_pos.y and sy <= pebble_pos.y + 1:
				var pc: Color = Color("#5a4e42") if sub_h < 50 else Color("#706050")
				c = pc if v < 30 else pc.darkened(0.1)
			elif grass_density > 1 and v < 3 + grass_density * 2:
				c = base.lightened(0.08 + grass_density * 0.03)
			elif v < 3:
				c = base.lightened(0.14)
			elif v < 10 - grass_density:
				c = dark
			elif has_moss and v < 14:
				c = Color("#3a4a2a")
			elif v < 16 and not checker:
				c = base.darkened(0.06)
			draw_rect(Rect2(rect.position.x + sx * sub, rect.position.y + sy * sub, sub + 0.5, sub + 0.5), c, true)


func _draw_east_meadow_top_tile(rect: Rect2, checker: bool, tile_h: int) -> void:
	var base: Color = Color("#2d765f") if checker else Color("#286d59")
	draw_rect(rect, base, true)
	var sub: float = TILE_SIZE / 8.0
	if (tile_h % 100) < 28:
		var band_y: float = rect.position.y + sub * float(2 + ((tile_h >> 7) % 3))
		draw_rect(Rect2(rect.position.x, band_y, rect.size.x, sub * 1.2), Color(0.34, 0.68, 0.66, 0.28), true)
		draw_rect(Rect2(rect.position.x + sub * 2.0, band_y + sub * 0.35, rect.size.x - sub * 4.0, sub * 0.35), Color(0.55, 0.83, 0.76, 0.18), true)
	if ((tile_h >> 4) % 100) < 22:
		var patch_x: float = rect.position.x + sub * float(1 + ((tile_h >> 10) % 4))
		var patch_y: float = rect.position.y + sub * float(1 + ((tile_h >> 15) % 5))
		draw_rect(Rect2(patch_x, patch_y, sub * 2.0, sub * 1.4), Color(0.18, 0.45, 0.35, 0.34), true)
	if ((tile_h >> 8) % 100) < 18:
		var sx0: float = rect.position.x + sub * float(2 + ((tile_h >> 12) % 4))
		var sy0: float = rect.position.y + sub * float(3 + ((tile_h >> 17) % 3))
		draw_rect(Rect2(sx0, sy0, sub * 0.45, sub * 1.6), Color("#143d34"), true)
		draw_rect(Rect2(sx0 + sub * 0.35, sy0 - sub * 0.35, sub * 1.1, sub * 0.45), Color("#76b875"), true)
	if ((tile_h >> 2) % 100) < 7:
		var scale_pos: Vector2 = rect.position + Vector2(sub * float(2 + ((tile_h >> 9) % 4)), sub * float(2 + ((tile_h >> 14) % 4)))
		draw_rect(Rect2(scale_pos.x, scale_pos.y, sub * 0.8, sub * 0.8), Color(0.66, 0.86, 0.72, 0.42), true)


func _draw_central_altar_top_tile(rect: Rect2, checker: bool, tile_h: int) -> void:
	var base: Color = Color("#9a7441") if checker else Color("#846139")
	draw_rect(rect, base, true)
	var sub: float = TILE_SIZE / 8.0
	draw_rect(Rect2(rect.position.x + sub, rect.position.y + sub, sub * 6.0, sub * 6.0), Color("#b08952") if checker else Color("#8e7047"), true)
	draw_rect(Rect2(rect.position.x + sub * 2.0, rect.position.y + sub * 2.0, sub * 4.0, sub * 4.0), Color("#78946d") if (tile_h & 1) == 0 else Color("#a78955"), true)
	if (tile_h % 100) < 42:
		draw_rect(Rect2(rect.position.x + sub * 1.0, rect.position.y + sub * 3.4, sub * 6.0, sub * 0.35), Color(0.48, 0.31, 0.15, 0.35), true)
		draw_rect(Rect2(rect.position.x + sub * 3.4, rect.position.y + sub * 1.0, sub * 0.35, sub * 6.0), Color(0.48, 0.31, 0.15, 0.28), true)
	if ((tile_h >> 6) % 100) < 24:
		var jade_pos: Vector2 = rect.position + Vector2(sub * float(2 + ((tile_h >> 10) % 4)), sub * float(2 + ((tile_h >> 15) % 4)))
		draw_rect(Rect2(jade_pos.x, jade_pos.y, sub * 1.0, sub * 1.0), Color("#b6d3aa"), true)


func _draw_rock_tile(rect: Rect2) -> void:
	if RunState.current_chapter_index == RunState.CHAPTER_CENTRAL:
		_draw_central_altar_wall_top_tile(rect)
		return
	if RunState.current_chapter_index == RunState.CHAPTER_EAST:
		_draw_east_bamboo_top_tile(rect)
		return
	# 尝试纹理（用 stone_wall 贴图集）
	var td: Dictionary = PixelSprites.tile_texture("stone_wall")
	if td.has("tex") and td.tex != null:
		draw_texture_rect_region(td.tex, rect, td.region)
		return
	# 底层用深草色（让岩石坐落感更真实）
	draw_rect(rect, COLOR_GRASS_DARK, true)
	# 像素化岩石本体：8x8 子格按 mask 描绘
	# 增强版：更丰富的灰阶过渡 + 裂纹 + 草地边缘
	var rock_mask: PackedStringArray = PackedStringArray([
		"  KKKK  ",
		" KkkkkK ",
		"KkkRRkkK",
		"KkRRRRkK",
		"KkRRRRkK",
		"KkkRRkkK",
		" KkkkkK ",
		"  KKKK  ",
	])
	var sub: float = TILE_SIZE / 8.0
	# 先画阴影过渡（岩石周围的深色地面）
	var edge: Color = Color("#1a2214")
	for ry in 8:
		for rx in 8:
			var is_border: bool = ry == 0 or ry == 7 or rx == 0 or rx == 7
			if is_border:
				draw_rect(Rect2(rect.position.x + rx * sub, rect.position.y + ry * sub, sub + 0.5, sub + 0.5), edge, true)
	for ry in 8:
		var row: String = rock_mask[ry]
		for rx in 8:
			var ch: String = row[rx]
			var c: Color
			match ch:
				"K": c = Color("#1a1410")     # 最深岩缝
				"k": c = Color("#3a2c22")     # 岩体暗面
				"R": c = Color("#564335")     # 岩体主色
				_: continue
			# 子像素级 hash 加裂纹
			var rh: int = ((rx * 17) ^ (ry * 31)) & 3
			if rh == 1 and (rx > 1 and rx < 6 and ry > 1 and ry < 6):
				c = c.darkened(0.15)          # 随机裂纹
			elif rh == 2 and (rx > 2 and rx < 5 and ry > 2 and ry < 5):
				c = c.lightened(0.10)         # 随机石面高光
			draw_rect(Rect2(rect.position.x + rx * sub, rect.position.y + ry * sub, sub + 0.5, sub + 0.5), c, true)
	# 顶部高光（略偏移增加立体感）
	var hl_y: float = rect.position.y + sub * 2
	draw_rect(Rect2(rect.position.x + sub * 2, hl_y, sub * 1.5, sub), Color("#7a6452"), true)
	draw_rect(Rect2(rect.position.x + sub * 3, hl_y + sub * 0.3, sub, sub * 0.6), Color("#8a7460"), true)
	# 底部草芽细节
	var grass_edge: Color = Color("#2a4a28")
	draw_rect(Rect2(rect.position.x + sub, rect.position.y + sub * 7, sub, sub), grass_edge, true)
	draw_rect(Rect2(rect.position.x + sub * 6, rect.position.y + sub * 7, sub, sub), grass_edge, true)


func _draw_east_bamboo_top_tile(rect: Rect2) -> void:
	draw_rect(rect, Color("#163f33"), true)
	var sub: float = TILE_SIZE / 8.0
	for ry in 8:
		for rx in 8:
			var edge: bool = rx == 0 or ry == 0 or rx == 7 or ry == 7
			var c: Color = Color("#12362d") if edge else Color("#1c503f")
			if (rx + ry) % 5 == 0:
				c = c.lightened(0.04)
			draw_rect(Rect2(rect.position.x + rx * sub, rect.position.y + ry * sub, sub + 0.5, sub + 0.5), c, true)
	for i in 3:
		var bx: float = rect.position.x + sub * float(2 + i * 1.6)
		draw_rect(Rect2(bx, rect.position.y + sub * 0.75, sub * 0.65, sub * 6.15), Color("#0f332b"), true)
		draw_rect(Rect2(bx + sub * 0.18, rect.position.y + sub * 0.75, sub * 0.22, sub * 6.15), Color("#5a9660"), true)
		for n in 2:
			draw_rect(Rect2(bx - sub * 0.10, rect.position.y + sub * float(2.0 + n * 2.2), sub * 0.8, sub * 0.14), Color("#94bd76"), true)
	draw_rect(Rect2(rect.position.x + sub * 1.2, rect.position.y + sub * 5.7, sub * 2.6, sub * 0.45), Color("#5aa875"), true)
	draw_rect(Rect2(rect.position.x + sub * 4.3, rect.position.y + sub * 2.9, sub * 1.9, sub * 0.45), Color("#78bd75"), true)


func _draw_central_altar_wall_top_tile(rect: Rect2) -> void:
	draw_rect(rect, Color("#5a3a21"), true)
	var sub: float = TILE_SIZE / 8.0
	for ry in 8:
		for rx in 8:
			var edge: bool = rx == 0 or ry == 0 or rx == 7 or ry == 7
			var c: Color = Color("#3c2718") if edge else Color("#76512e")
			if rx >= 2 and rx <= 5 and ry >= 2 and ry <= 5:
				c = Color("#9c7441")
			if (rx == 3 or rx == 4) and ry >= 1 and ry <= 6:
				c = Color("#c09a5b")
			draw_rect(Rect2(rect.position.x + rx * sub, rect.position.y + ry * sub, sub + 0.5, sub + 0.5), c, true)
	draw_rect(Rect2(rect.position.x + sub * 2.0, rect.position.y + sub * 1.0, sub * 4.0, sub * 0.75), Color("#d6bb76"), true)
	draw_rect(Rect2(rect.position.x + sub * 3.0, rect.position.y + sub * 3.0, sub * 2.0, sub * 2.0), Color("#b6d3aa"), true)


func _draw_entity_shadow_at(pixel_pos: Vector2) -> void:
	var rx: float = TILE_SIZE * 0.32
	var ry: float = TILE_SIZE * 0.10
	var pts: PackedVector2Array = PackedVector2Array()
	var seg: int = 16
	for i in seg:
		var a: float = TAU * i / seg
		pts.append(Vector2(pixel_pos.x + cos(a) * rx, pixel_pos.y + TILE_SIZE * 0.32 + sin(a) * ry))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.42))


func _draw_hp_bar(center_pos: Vector2, hp: int, max_hp: int) -> void:
	var w: float = 36.0
	var h: float = 5.0
	var bg := Rect2(center_pos.x - w * 0.5, center_pos.y - h, w, h)
	draw_rect(bg, Color(0, 0, 0, 0.7), true)
	var ratio: float = clampf(float(hp) / max_hp, 0.0, 1.0)
	var fg := Rect2(bg.position.x + 1, bg.position.y + 1, (w - 2) * ratio, h - 2)
	draw_rect(fg, Color(0.9, 0.35, 0.35), true)



func _sprite_key_for_entity(e: Dictionary) -> String:
	var k: String = str(e["kind"])
	if e.has("sprite_key"):
		var key: String = str(e["sprite_key"])
		if k == "enemy" and not key.begins_with("enemy."):
			return "enemy." + key
		return key
	if k == "enemy":
		var enemies: Array = e.get("enemies", [])
		if not enemies.is_empty():
			return "enemy." + str(enemies[0])
	return k

func _draw_pixel_sprite(origin: Vector2, key: String) -> void:
	var sp: PackedStringArray = PixelSprites.sprite(key)
	if sp.is_empty():
		# 退化：画一个色块加文字
		draw_rect(Rect2(origin.x, origin.y, PixelSprites.PIXEL * PixelSprites.SIZE, PixelSprites.PIXEL * PixelSprites.SIZE), Color(0.5, 0.5, 0.5), true)
		return
	_draw_pixel_sprite_data(origin, sp)


## 绘制带方向的动画精灵（kind + facing + frame）
## 优先使用 SVG 纹理，没有则降级到像素绘制
func _draw_pixel_sprite_animated(origin: Vector2, kind: String, facing: String, frame: int, scale: float = 1.0) -> void:
	var tex: Texture2D = PixelSprites.texture(kind, facing, frame)
	if tex != null:
		var cell_sz: float = PixelSprites.PIXEL * PixelSprites.SIZE * scale
		var tex_sz: Vector2 = tex.get_size() * scale
		if tex_sz.x > cell_sz or tex_sz.y > cell_sz:
			var ox: float = (tex_sz.x - cell_sz) * 0.5
			var oy: float = (tex_sz.y - cell_sz) * 0.5
			draw_texture_rect(tex, Rect2(origin.x - ox, origin.y - oy, tex_sz.x, tex_sz.y), false)
		else:
			draw_texture_rect(tex, Rect2(origin.x, origin.y, cell_sz, cell_sz), false)
		return

	# 降级：像素绘制
	var sp: PackedStringArray = PixelSprites.sprite_animated(kind, facing, frame)
	if sp.is_empty():
		draw_rect(Rect2(origin.x, origin.y, PixelSprites.PIXEL * PixelSprites.SIZE * scale, PixelSprites.PIXEL * PixelSprites.SIZE * scale), Color(0.5, 0.5, 0.5), true)
		return
	if is_equal_approx(scale, 1.0):
		_draw_pixel_sprite_data(origin, sp)
	else:
		draw_set_transform(origin, 0.0, Vector2(scale, scale))
		_draw_pixel_sprite_data(Vector2.ZERO, sp)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 共用绘制核心
func _draw_pixel_sprite_data(origin: Vector2, sp: PackedStringArray) -> void:
	var px: int = PixelSprites.PIXEL
	for ry in PixelSprites.SIZE:
		var row: String = sp[ry]
		for rx in PixelSprites.SIZE:
			if rx >= row.length():
				break
			var ch: String = row.substr(rx, 1)
			if ch == " ":
				continue
			var c: Color = _palette.get(ch, Color(1, 0, 1))
			if c.a <= 0.0:
				continue
			draw_rect(Rect2(origin.x + rx * px, origin.y + ry * px, px, px), c, true)


# ============== 小地图绘制（在 _minimap.draw 信号中调用） ==============

func _draw_minimap() -> void:
	if _minimap == null:
		return
	var w: float = _minimap.size.x
	var h: float = _minimap.size.y
	var sx: float = w / WORLD_W
	var sy: float = h / WORLD_H
	var is_north_map: bool = RunState.current_chapter_index == RunState.CHAPTER_NORTH
	var is_west_map: bool = RunState.current_chapter_index == RunState.CHAPTER_WEST
	var is_east_map: bool = RunState.current_chapter_index == RunState.CHAPTER_EAST
	var is_central_map: bool = RunState.current_chapter_index == RunState.CHAPTER_CENTRAL
	var walkable_color: Color = Color("#9a7441") if is_central_map else (Color("#2d765f") if is_east_map else (Color("#7c4035") if is_north_map else (Color("#7a4d24") if is_west_map else COLOR_GRASS_A)))
	var blocked_color: Color = Color("#5a3a21") if is_central_map else (Color("#163f33") if is_east_map else (Color("#8aa0a3") if is_north_map else (Color("#7f8b86") if is_west_map else COLOR_ROCK)))
	# 整张地图（小尺度）
	for y in WORLD_H:
		for x in WORLD_W:
			var v: int = int(data["tiles"][y][x])
			var c: Color = walkable_color if v == 0 else blocked_color
			_minimap.draw_rect(Rect2(x * sx, y * sy, sx + 0.5, sy + 0.5), c, true)
	# 实体
	for e in data["entities"]:
		var p: Vector2i = e["pos"]
		var ec: Color = _color_for_kind(str(e["kind"]))
		# BOSS 用更大的点
		var k: String = str(e["kind"])
		var center := Vector2((p.x + 0.5) * sx, (p.y + 0.5) * sy)
		if k.begins_with("boss"):
			var boss_r: float = max(2.4, sx * 1.35)
			_minimap.draw_circle(center, boss_r + 1.0, Color(0.05, 0.02, 0.02, 0.82))
			_minimap.draw_circle(center, boss_r, ec)
			_minimap.draw_arc(center, boss_r + 1.35, 0.0, TAU, 18, Color(1.0, 0.92, 0.25, 0.88), 1.0)
		else:
			var size_mul: float = 1.65 if k == "elite" else 1.2
			var dot := Rect2(p.x * sx - sx * (size_mul - 1) * 0.5, p.y * sy - sy * (size_mul - 1) * 0.5, sx * size_mul, sy * size_mul)
			_minimap.draw_rect(dot, ec, true)
	# 玩家
	var pp: Vector2i = data["player"]
	var player_center := Vector2((pp.x + 0.5) * sx, (pp.y + 0.5) * sy)
	var psize: float = max(2.8, sx * 1.6)
	_minimap.draw_circle(player_center, psize + 1.0, Color(0.05, 0.04, 0.0, 0.84))
	_minimap.draw_circle(player_center, psize, COLOR_PLAYER)
	_minimap.draw_arc(player_center, psize + 1.35, 0.0, TAU, 18, Color(0.30, 0.82, 1.0, 0.88), 1.0)
	# 视野框（等距模式用玩家格点反算）
	var vc: Vector2
	if _view_mode == ViewMode.ISOMETRIC:
		vc = Vector2(data["player"])
	else:
		vc = (_camera.get_screen_center_position() if _camera else Vector2.ZERO) / TILE_SIZE
	var view_rect := Rect2(
		(vc.x - VIEWPORT_W / TILE_SIZE * 0.5) * sx,
		(vc.y - VIEWPORT_H / TILE_SIZE * 0.5) * sy,
		VIEWPORT_W / TILE_SIZE * sx,
		VIEWPORT_H / TILE_SIZE * sy,
	)
	_minimap.draw_rect(view_rect, Color(1, 1, 1, 0.85), false, 1.5)

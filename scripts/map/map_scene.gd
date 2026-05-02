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
const ISO_ENEMY_SPRITE_SCALE: float = 1.35
const WARRIOR_TOP_SCALE: float = 0.52
const WARRIOR_ISO_SCALE: float = 0.72
const ISO_FLOOR_TILESET_NAME: String = "forest"
const ISO_WALL_TILESET_NAME: String = "village"
# 等距世界像素边界（动态计算）
var _iso_world_w: int = 0
var _iso_world_h: int = 0
var _iso_smooth_pos: Vector2 = Vector2.ZERO  # 等距平滑移动位置

# === 商店运行时状态 ===
var _shop_items: Array = []
var _shop_buttons: Array = []
var _pending_reset_map: bool = false

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
	_confirm.visible = false
	_victory.visible = false

	if RunState.map_data.is_empty():
		data = _generate_map()
		RunState.map_data = data
	else:
		data = RunState.map_data

	if RunState.last_entity_id != "":
		var was_boss: bool = RunState.last_battle_was_boss
		# 在移除 entity 前先记下 kind / name 用于后续奖励和文案
		var beaten_kind: String = ""
		var beaten_name: String = ""
		for e in data["entities"]:
			if str(e["id"]) == RunState.last_entity_id:
				beaten_kind = str(e["kind"])
				beaten_name = str(e.get("name", ""))
				break
		if RunState.last_battle_won:
			_remove_entity(RunState.last_entity_id)
			if was_boss:
				RunState.bosses_defeated += 1
				_grant_boss_reward(beaten_kind)
				_show_boss_victory(beaten_kind, beaten_name)
			elif beaten_kind == "elite":
				_add_floating_text(_player_pixel + Vector2(0, -50), "精英已唤醒  +20 碎片", Color(1.0, 0.85, 0.4))
				GameState.add_fragments(20)
				RunState.add_exp(15)
		RunState.last_entity_id = ""
		RunState.last_battle_was_boss = false
		RunState.last_battle_won = false

	_title.text = "南山 · 朱雀庭   (第 %d 层)" % (RunState.current_floor + 1)
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

func _generate_map() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	var s: int = RunState.seed_value
	if s == 0:
		s = randi()
		RunState.seed_value = s
	rng.seed = s
	_decoration_seed = s

	# 1) 全空地
	var tiles: Array = []
	for y in WORLD_H:
		var row: Array = []
		for x in WORLD_W:
			row.append(0)
		tiles.append(row)

	# 2) 边框岩石
	for x in WORLD_W:
		tiles[0][x] = 1
		tiles[WORLD_H - 1][x] = 1
	for y in WORLD_H:
		tiles[y][0] = 1
		tiles[y][WORLD_W - 1] = 1

	# 3) 大量随机岩石簇
	for cluster in range(rng.randi_range(140, 200)):
		var cx: int = rng.randi_range(2, WORLD_W - 3)
		var cy: int = rng.randi_range(2, WORLD_H - 3)
		var sz: int = rng.randi_range(1, 4)
		for dx in range(-sz, sz + 1):
			for dy in range(-sz, sz + 1):
				var x: int = cx + dx
				var y: int = cy + dy
				if x <= 1 or y <= 1 or x >= WORLD_W - 2 or y >= WORLD_H - 2:
					continue
				if rng.randf() < 0.45:
					tiles[y][x] = 1

	# 4) 玩家位置（左中部）；强制周围一片空地，避免出生即卡
	var player := Vector2i(2, WORLD_H / 2)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			tiles[player.y + dy][player.x + dx] = 0

	# 5) 用 BFS 找到所有从玩家可达的格子，把不可达的格子改为可达岩石（让世界连通）
	#    简化：我们直接随机放实体后做 BFS 检查，若不可达则把途中岩石打通若干
	#    本步：每条横向走廊随机打通一条以保证大致连通
	# 5.1 三条主走廊（保证从左到右总能走通）
	for x in range(1, WORLD_W - 1):
		tiles[player.y][x] = 0     # 中线
	# 上下两条干道
	var lane_top: int = max(3, WORLD_H / 4)
	var lane_bot: int = min(WORLD_H - 4, WORLD_H * 3 / 4)
	for x in range(1, WORLD_W - 1):
		if rng.randf() < 0.92:
			tiles[lane_top][x] = 0
		if rng.randf() < 0.92:
			tiles[lane_bot][x] = 0
	# 5 条纵向干道
	for i in 5:
		var lx: int = (WORLD_W * (i + 1)) / 6
		for y in range(1, WORLD_H - 1):
			if rng.randf() < 0.92:
				tiles[y][lx] = 0

	# 6) 实体生成
	var entities: Array = []
	var occupied: Dictionary = {}
	occupied[player] = true

	# 6.1 三个 BOSS（强弱不同），分别放在大地图的 1/3、2/3、4/5 列附近
	var boss_pool: Array = [
		{"id": "boss_weak",  "kind": "boss_weak",  "label": "弱", "name": "雏火·毕方",
		 "story": "刚被忘川扰动、力量尚弱的雏鸟。是 3 个 BOSS 中相对易战的。",
		 "enemy_id": "boss_bifang_weak"},
		{"id": "boss_mid",   "kind": "boss_mid",   "label": "中", "name": "讹火·毕方",
		 "story": "山经记载的独足神鸟，被忘川驱使后散布讹火。",
		 "enemy_id": "boss_bifang"},
		{"id": "boss_hard",  "kind": "boss_hard",  "label": "强", "name": "焚岭古毕方",
		 "story": "栖息在岭脊深处千年的古毕方。建议先打小怪与精英、积累优势再来。",
		 "enemy_id": "boss_bifang_strong"},
	]
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

	# 6.2 4 个精英（穷奇）
	for i in 4:
		var p: Vector2i = _pick_free_pos(rng, int(WORLD_W * 0.20), int(WORLD_W * 0.85), 2, WORLD_H - 3, tiles, occupied)
		if p == Vector2i(-1, -1):
			continue
		entities.append({
			"id": "elite_%d" % i, "kind": "elite", "pos": p, "label": "奇",
			"name": "迷误·穷奇 (精英)",
			"story": "穷奇本是守山兽，被忘川扭曲为见人即攻的迷误之兽。",
			"enemies": ["elite_qiongqi"],
		})
		occupied[p] = true

	# 6.3 30~40 只小怪
	var enemy_packs: Array = [
		{"label": "兽", "name": "迷雾狐裔",       "enemies": ["hu_diao"]},
		{"label": "兽", "name": "鹿蜀",           "enemies": ["lu_shu"]},
		{"label": "兽", "name": "从从",           "enemies": ["cong_cong"]},
		{"label": "兽", "name": "类",             "enemies": ["lei_beast"]},
		{"label": "兽", "name": "迷雾狐裔+鹿蜀",  "enemies": ["hu_diao", "lu_shu"]},
		{"label": "兽", "name": "从从+类",        "enemies": ["cong_cong", "lei_beast"]},
		{"label": "兽", "name": "类+鹿蜀",        "enemies": ["lei_beast", "lu_shu"]},
	]
	var enemy_count: int = rng.randi_range(30, 40)
	for i in enemy_count:
		var pack: Dictionary = enemy_packs[rng.randi() % enemy_packs.size()].duplicate(true)
		var p: Vector2i = _pick_free_pos(rng, 3, WORLD_W - 3, 2, WORLD_H - 3, tiles, occupied)
		if p == Vector2i(-1, -1):
			continue
		pack["id"] = "enemy_%d" % i
		pack["kind"] = "enemy"
		pack["pos"] = p
		entities.append(pack)
		occupied[p] = true

	# 6.4 商铺与驿站
	for i in 4:
		var p: Vector2i = _pick_free_pos(rng, 4, WORLD_W - 4, 2, WORLD_H - 3, tiles, occupied)
		if p != Vector2i(-1, -1):
			entities.append({"id": "shop_%d" % i, "kind": "shop", "pos": p, "label": "市", "name": "古玩铺", "story": "店主是一位戴狐面具的老者。"})
			occupied[p] = true
	for i in 5:
		var p: Vector2i = _pick_free_pos(rng, 4, WORLD_W - 4, 2, WORLD_H - 3, tiles, occupied)
		if p != Vector2i(-1, -1):
			entities.append({"id": "rest_%d" % i, "kind": "rest", "pos": p, "label": "歇", "name": "讲古驿站", "story": "可以在这里休整、读古卷。"})
			occupied[p] = true

	# 6.5 宝箱（5~7 个，随机奖励池）
	var treasure_count: int = rng.randi_range(5, 7)
	for i in treasure_count:
		var p: Vector2i = _pick_free_pos(rng, 4, WORLD_W - 4, 2, WORLD_H - 3, tiles, occupied)
		if p != Vector2i(-1, -1):
			var loot: Dictionary = _roll_treasure_loot(rng)
			entities.append({"id": "treasure_%d" % i, "kind": "treasure", "pos": p, "label": "宝", "name": "山海宝匣", "loot": loot})
			occupied[p] = true

	# 6.6 回响事件（最多 4 个，从 echo_events.json 抽取，不重复）
	var events: Array = EventDatabase.load_all()
	events.shuffle()
	var event_count: int = mini(4, events.size())
	for i in event_count:
		var p: Vector2i = _pick_free_pos(rng, 5, WORLD_W - 4, 2, WORLD_H - 3, tiles, occupied)
		if p != Vector2i(-1, -1):
			var ev: Dictionary = events[i]
			entities.append({
				"id": "event_%d" % i, "kind": "event", "pos": p, "label": "录",
				"name": str(ev.get("name", "回响事件")), "story": str(ev.get("story", "")),
				"options": ev.get("options", []),
			})
			occupied[p] = true

	# 6.7 文化片段（10~14 个零散光点，自动拾取）
	var frag_count: int = rng.randi_range(10, 14)
	for i in frag_count:
		var p: Vector2i = _pick_free_pos(rng, 2, WORLD_W - 3, 2, WORLD_H - 3, tiles, occupied)
		if p != Vector2i(-1, -1):
			entities.append({"id": "fragment_%d" % i, "kind": "fragment", "pos": p, "label": "片", "name": "文化片段"})
			occupied[p] = true

	# 7) 联通性保证：用 BFS 从玩家位置走，把不可达的实体周围岩石打通
	_ensure_reachability(tiles, player, entities)

	return {
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
	RunState.seed_value = randi()
	RunState.map_data = {}
	RunState.last_entity_id = ""
	RunState.last_battle_was_boss = false
	RunState.last_battle_won = false
	RunState.level = 1
	RunState.exp_value = 0
	RunState.exp_to_next = 10
	RunState.hp = RunState.max_hp
	RunState.exp_changed.emit(RunState.exp_value, RunState.exp_to_next)
	RunState.hp_changed.emit(RunState.hp, RunState.max_hp)
	_reload_current_scene_deferred.call_deferred()


## 玩家平滑连续移动：在 _process 中按帧推进，遇到岩石阻挡，进入实体格触发对话框
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
	# 分轴碰撞：先 X 后 Y，沿一个轴受阻不影响另一轴
	var radius: float = PLAYER_COLLISION_RADIUS_ISO if _view_mode == ViewMode.ISOMETRIC else PLAYER_COLLISION_RADIUS_TOP
	var nx: float = _player_pixel.x + step.x
	if step.x != 0.0:
		if _can_stand_at(Vector2(nx, _player_pixel.y), radius):
			_player_pixel.x = nx
	var ny: float = _player_pixel.y + step.y
	if step.y != 0.0:
		if _can_stand_at(Vector2(_player_pixel.x, ny), radius):
			_player_pixel.y = ny
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
			_confirm_text.text = "前方传来低吼，是被忘川扰乱的异兽：\n[ %s ]\n%s\n是否进入战斗？" % [name, story]
			_confirm_yes.text = "迎战"
		"elite":
			_confirm_text.text = "前方是被深度侵蚀的精英：\n[ %s ]\n%s\n挑战胜利可获得唤醒卡。" % [name, story]
			_confirm_yes.text = "挑战"
		"boss_weak", "boss_mid", "boss_hard":
			var diff_word: String = {"boss_weak": "（弱）", "boss_mid": "（中等）", "boss_hard": "（强，谨慎）"}[kind]
			var lv: int = RunState.level
			var energy_b: int = (1 if lv >= 3 else 0) + (1 if lv >= 7 else 0)
			var hand_b: int = 1 if lv >= 5 else 0
			var buff: String = ""
			if energy_b > 0 or hand_b > 0:
				buff = "\n[等级 Lv.%d 卡牌战斗加成：每回合 +%d 灵韵，起手 +%d 抽牌]" % [lv, energy_b, hand_b]
			_confirm_text.text = "BOSS%s：\n[ %s ]\n%s%s\n是否决战？" % [diff_word, name, story, buff]
			_confirm_yes.text = "决战"
		"shop":
			_confirm_text.text = "[ %s ]\n%s\n用灵韵碎片可在此购买卡牌、回血、永久增益。" % [name, story]
			_confirm_yes.text = "进店"
		"rest":
			_confirm_text.text = "[ %s ]\n%s\n恢复 25 点气血。" % [name, story]
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
			RunState.heal(25)
			data["entities"].erase(e)
			queue_redraw()
			_minimap.queue_redraw()
			_update_status()


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
	var text: String = "你打开了一只布满苔藓的山海宝匣。\n\n%s" % str(loot.get("text", "（空）"))
	_apply_reward(loot)
	AudioEngine.play_sfx("pickup")
	data["entities"].erase(e)
	_minimap.queue_redraw()
	_update_status()
	_show_event_panel("山海宝匣", text, [{"label": "继续", "callback": Callable(self, "_close_event_panel")}])


func _trigger_event(e: Dictionary) -> void:
	pending_entity = e
	var opts: Array = e.get("options", [])
	var ui_options: Array = []
	for opt in opts:
		var o: Dictionary = opt
		var label: String = "%s\n→ %s" % [str(o.get("label", "?")), str(o.get("preview", ""))]
		ui_options.append({"label": label, "callback": Callable(self, "_on_event_choice").bind(o)})
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


func _enter_shop(e: Dictionary) -> void:
	pending_entity = e
	_shop_items.clear()
	_shop_buttons.clear()
	# 随机抽 3 张卡（排除已经在卡组里的"通用基础卡"以避免单调）
	var pool: Array = CardDatabase.all_cards()
	pool.shuffle()
	var picks: Array = []
	for c in pool:
		if str(c.id) == "neutral.strike" or str(c.id) == "neutral.guard":
			continue
		picks.append(c)
		if picks.size() >= 3:
			break
	for c in picks:
		_shop_items.append({
			"type": "card", "card": c,
			"label": "[卡] 《%s》（%s）  ·  %d 碎片" % [c.title, c.get_school_name(), SHOP_CARD_PRICE],
			"price": SHOP_CARD_PRICE,
		})
	_shop_items.append({
		"type": "heal", "amount": SHOP_HEAL_AMOUNT,
		"label": "[药] 立刻回复 %d 气血  ·  %d 碎片" % [SHOP_HEAL_AMOUNT, SHOP_HEAL_PRICE],
		"price": SHOP_HEAL_PRICE,
	})
	_shop_items.append({
		"type": "max_hp", "amount": SHOP_MAXHP_AMOUNT,
		"label": "[丹] 永久 +%d 最大气血  ·  %d 碎片" % [SHOP_MAXHP_AMOUNT, SHOP_MAXHP_PRICE],
		"price": SHOP_MAXHP_PRICE,
	})
	_shop_items.append({"type": "leave", "label": "[离开]", "price": 0})
	_show_shop_panel()


func _show_shop_panel() -> void:
	_event_panel.visible = true
	_event_title.text = "古玩铺"
	_refresh_shop_body()
	for c in _event_options.get_children():
		c.queue_free()
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
	_event_body.text = "店主戴狐面具，玻璃柜中陈列着几样东西。\n\n你的灵韵碎片：%d" % GameState.fragments


func _refresh_shop_buttons() -> void:
	for i in _shop_buttons.size():
		var item: Dictionary = _shop_items[i]
		var btn: Button = _shop_buttons[i]
		var label: String = item["label"]
		if item.get("sold", false):
			btn.text = "—— 已售出 ——"
			btn.disabled = true
			continue
		if item["type"] == "leave":
			btn.text = label
			btn.disabled = false
			continue
		var price: int = int(item["price"])
		if GameState.fragments < price:
			btn.text = label + "   （碎片不足）"
			btn.disabled = true
		else:
			btn.text = label
			btn.disabled = false


func _on_shop_buy(idx: int) -> void:
	if idx < 0 or idx >= _shop_items.size():
		return
	var item: Dictionary = _shop_items[idx]
	if item["type"] == "leave":
		_close_event_panel()
		# 商铺访问过即消失（一次性）
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
	if item.get("sold", false):
		return
	var price: int = int(item["price"])
	if GameState.fragments < price:
		return
	GameState.add_fragments(-price)
	item["sold"] = true
	AudioEngine.play_sfx("shop_buy")
	match str(item["type"]):
		"card":
			var card: Card = item["card"]
			RunState.add_card_to_deck(card)
			GameState.unlock_codex("card." + card.id)
			_add_floating_text(_player_pixel + Vector2(0, -36), "+《%s》入卡组" % card.title, Color(1.0, 0.85, 0.4))
		"heal":
			RunState.heal(int(item["amount"]))
		"max_hp":
			var amt: int = int(item["amount"])
			RunState.max_hp += amt
			RunState.hp = mini(RunState.max_hp, RunState.hp + amt)
			RunState.hp_changed.emit(RunState.hp, RunState.max_hp)
	_refresh_shop_body()
	_refresh_shop_buttons()
	_update_status()


# ============== 通用面板 ==============

func _show_event_panel(title: String, body: String, options: Array) -> void:
	_event_panel.visible = true
	_event_title.text = title
	_event_body.text = body
	for c in _event_options.get_children():
		c.queue_free()
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
	for c in _event_options.get_children():
		c.queue_free()
	_update_status()


# ============== BOSS 奖励 ==============


func _grant_boss_reward(kind: String) -> void:
	match kind:
		"boss_weak":
			GameState.add_fragments(30)
			RunState.add_exp(20)
			RunState.heal(20)
		"boss_mid":
			GameState.add_fragments(60)
			RunState.add_exp(40)
			RunState.heal(35)
		"boss_hard":
			GameState.add_fragments(120)
			RunState.add_exp(80)
			RunState.heal(50)
		_:
			GameState.add_fragments(20)
			RunState.add_exp(10)


func _show_boss_victory(kind: String, name: String) -> void:
	_victory.visible = true
	var defeated: int = RunState.bosses_defeated
	var total: int = RunState.BOSSES_TO_CLEAR
	if defeated >= total:
		_victory_text.text = "南山 · 朱雀庭   全境净化！\n你已唤醒所有 %d 位 BOSS。\n那些被遗忘的山海生灵，重新被讲述。\n\n（按下方按钮回主菜单。）" % total
		_victory_btn.text = "回到主菜单"
	else:
		var reward_line: String = ""
		match kind:
			"boss_weak": reward_line = "+30 碎片  +20 EXP  +20 HP"
			"boss_mid":  reward_line = "+60 碎片  +40 EXP  +35 HP"
			"boss_hard": reward_line = "+120 碎片  +80 EXP  +50 HP"
			_:           reward_line = ""
		_victory_text.text = "你击败了 BOSS：[ %s ]\n%s\n\n通关进度：%d / %d\n地图上还有更强的 BOSS 等你。" % [
			name, reward_line, defeated, total
		]
		_victory_btn.text = "继续探索"


func _show_victory() -> void:
	# 兼容老调用：直接用进度感知版本（无 kind 时用占位）
	_show_boss_victory("", "BOSS")


func _on_victory_close() -> void:
	if RunState.bosses_defeated >= RunState.BOSSES_TO_CLEAR:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		# 失败死亡和未通关都用同一个面板，按钮统一关掉继续
		_victory.visible = false
		# 失败时 map_data 已被清空 → 回主菜单
		if RunState.is_dead() or RunState.map_data.is_empty():
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


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
				_draw_grass_tile(rect, x, y)

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
	var cam_center: Vector2 = _camera.get_screen_center_position()
	var view_r: float = VIEWPORT_W * 1.2
	var view_h: float = VIEWPORT_H * 1.2
	var center_grid := Vector2i(data["player"])
	var x_min: int = clampi(center_grid.x - 18, 0, WORLD_W - 1)
	var x_max: int = clampi(center_grid.x + 18, 0, WORLD_W - 1)
	var y_min: int = clampi(center_grid.y - 18, 0, WORLD_H - 1)
	var y_max: int = clampi(center_grid.y + 18, 0, WORLD_H - 1)

	# 收集视野内所有内容，分 4 层绘制
	var tile_list: Array = []
	var tree_list: Array = []
	var entity_list: Array = []
	var player_item: Dictionary = {}

	for y in range(y_min, y_max + 1):
		for x in range(x_min, x_max + 1):
			var g := Vector2i(x, y)
			var center: Vector2 = _grid_to_pixel(g)
			if abs(center.x - cam_center.x) > view_r: continue
			if abs(center.y - cam_center.y) > view_h: continue
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
		if abs(iso_pos.x - cam_center.x) > view_r: continue
		if abs(iso_pos.y - cam_center.y) > view_h: continue
		entity_list.append({"pos": p, "center": iso_pos, "data": e, "z": p.x + p.y})

	player_item = {"center": _top_down_pixel_to_iso(_player_pixel), "z": data["player"].x + data["player"].y}

	# 同层内按 z 排序（后方先画）
	# ---- 第1层：所有草方块（地板） ----
	var td: Dictionary = PixelSprites.iso_tile_texture(ISO_FLOOR_TILESET_NAME)
	var wall_td: Dictionary = PixelSprites.iso_tile_texture(ISO_WALL_TILESET_NAME)
	var has_tex := not td.is_empty() and td.has("tex")
	var has_wall_tex := not wall_td.is_empty() and wall_td.has("tex")
	var ts := int(td.get("ts", 128))
	var cols := int(max(1, int(td.get("cols", 5))))
	for t in tile_list:
		var center: Vector2 = t.center
		var r := Rect2(center.x - ISO_HALF_W, center.y - ISO_HALF_H, ISO_TILE_W, ISO_FLOOR_H)
		if has_tex:
			var gcol := 0 if (int(t.x) + int(t.y)) % 2 == 0 else 1
			gcol = clampi(gcol, 0, cols - 1)
			draw_texture_rect_region(td.tex, r, Rect2(gcol * ts, 0, ts, ISO_FLOOR_H))
		else:
			_draw_iso_floor_diamond(center, COLOR_GRASS_A if (int(t.x) + int(t.y)) % 2 == 0 else COLOR_GRASS_B)

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
				_draw_iso_wall(item, has_wall_tex, wall_td, int(wall_td.get("ts", 128)))
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
			var pos: Vector2 = _top_down_pixel_to_iso(Vector2(ft["pos"]))
			draw_string(_font, pos, str(ft["text"]), HORIZONTAL_ALIGNMENT_CENTER, -1, 18, col)


func _draw_iso_walkable_marker(center: Vector2, is_current: bool) -> void:
	var pts := _iso_walkable_pts(center)
	var fill_alpha: float = 0.18 if is_current else 0.08
	var line_alpha: float = 0.90 if is_current else 0.42
	draw_colored_polygon(pts, Color(0.72, 1.0, 0.58, fill_alpha))
	var closed := PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]])
	draw_polyline(closed, Color(0.86, 1.0, 0.68, line_alpha), 3.0 if is_current else 1.5)


func _draw_iso_blocked_marker(center: Vector2) -> void:
	var pts := _iso_walkable_pts(center)
	draw_colored_polygon(pts, Color(0.16, 0.08, 0.03, 0.32))
	var closed := PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]])
	draw_polyline(closed, Color(0.95, 0.72, 0.28, 0.78), 2.0)


func _draw_iso_wall(item: Dictionary, has_tex: bool, td: Dictionary, ts: int) -> void:
	var center: Vector2 = item.center
	if has_tex:
		var tcol: int = int((int(item.x) * 3 + int(item.y)) % 5)
		var tr := Rect2(center.x - ISO_HALF_W, center.y - ISO_HALF_H, ISO_TILE_W, ISO_TILE_H)
		draw_texture_rect_region(td.tex, tr, Rect2(tcol * ts, 0, ts, ts))
	else:
		_draw_iso_tree_fallback(center)


func _draw_iso_entity(item: Dictionary) -> void:
	var e: Dictionary = item.data
	var iso_pos: Vector2 = item.center
	var sprite_size: float = PixelSprites.PIXEL * PixelSprites.SIZE * ISO_ENEMY_SPRITE_SCALE
	var sprite_half: float = sprite_size * 0.5
	var foot_pos := iso_pos + Vector2(0, ISO_HALF_H)
	var origin := Vector2(foot_pos.x - sprite_half, foot_pos.y - sprite_size)
	_draw_iso_entity_shadow(iso_pos)
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
		return 1.08
	match key:
		"elite":
			return 0.88
		"treasure":
			return 0.62
		"shop", "rest", "event":
			return 0.68
		"fragment":
			return 0.52
		_:
			return 0.74


func _iso_entity_anchor_ratio_for_key(key: String) -> float:
	if key.begins_with("boss"):
		return 0.92
	match key:
		"elite":
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
	var foot_pos := ppos + Vector2(0, ISO_HALF_H)
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


func _draw_iso_entity_shadow(pos: Vector2) -> void:
	# 简化的椭圆阴影（用多边形近似）
	var pts: PackedVector2Array = PackedVector2Array()
	var center := pos + Vector2(0, ISO_HALF_H * 0.8)
	var seg: int = 16
	for i in seg:
		var a: float = TAU * i / seg
		pts.append(Vector2(center.x + cos(a) * 14, center.y + sin(a) * 3.5))
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
		pts.append(Vector2(center.x + cos(a) * rx, center.y + ISO_HALF_H + sin(a) * ry))
	draw_colored_polygon(pts, Color(0.12, 0.56, 1.0, 0.16 + pulse * 0.08))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.38, 0.78, 1.0, 0.65 + pulse * 0.25), 2.0)


func _draw_grass_tile(rect: Rect2, x: int, y: int) -> void:
	# 尝试真实贴图（同一贴图集，不同 tile 位置产生视觉变化）
	var td: Dictionary = PixelSprites.tile_texture("grass")
	if td.has("tex") and td.tex != null:
		draw_texture_rect_region(td.tex, rect, td.region)
		return
	var checker: bool = (x + y) % 2 == 0
	var base: Color = COLOR_GRASS_A if checker else COLOR_GRASS_B
	# 用 8x8 子格画底色，呈现像素感
	var sub: float = TILE_SIZE / 8.0
	# tile 级 hash 决定装饰，避免每帧抖动 + 控制密度
	var tile_h: int = ((x * 73856093) ^ (y * 19349663)) & 0xFFFFFF
	var has_flower: bool = (tile_h % 100) < 6           # 6% tile 有花
	var flower_pos: Vector2i = Vector2i((tile_h >> 8) % 6 + 1, (tile_h >> 16) % 6 + 1)
	var has_moss: bool = ((tile_h >> 4) % 100) < 12 and not checker
	var has_pebble: bool = ((tile_h >> 2) % 100) < 4    # 4% tile 有小石子
	var pebble_pos: Vector2i = Vector2i((tile_h >> 10) % 5 + 1, (tile_h >> 18) % 5 + 1)
	var grass_density: int = (tile_h >> 5) % 4           # 0-3 控制草密度
	for sy in 8:
		for sx in 8:
			var h: int = ((x * 73856093) ^ (y * 19349663) ^ (sx * 83492791) ^ (sy * 12289)) & 0xFFFFFF
			var c: Color = base
			var v: int = h % 64
			var sub_h: int = (h >> 8) % 100
			if has_flower and sx == flower_pos.x and sy == flower_pos.y:
				c = COLOR_FLOWER
			elif has_pebble and sx >= pebble_pos.x and sx <= pebble_pos.x + 1 and sy >= pebble_pos.y and sy <= pebble_pos.y + 1:
				# 小石子：灰棕色小点
				var pc: Color = Color("#5a4e42") if sub_h < 50 else Color("#706050")
				if v < 30:
					c = pc
				else:
					c = pc.darkened(0.1)
			elif grass_density > 1 and v < 3 + grass_density * 2:
				# 草叶簇：亮绿色线条
				c = base.lightened(0.08 + grass_density * 0.03)
			elif v < 3:
				c = base.lightened(0.14)                  # 草尖高光
			elif v < 10 - grass_density:
				c = COLOR_GRASS_DARK                       # 深色草簇
			elif has_moss and v < 14:
				c = Color("#3a4a2a")                        # 苔藓
			elif v < 16 and not checker:
				c = base.darkened(0.06)                    # 次要暗纹
			draw_rect(Rect2(rect.position.x + sx * sub, rect.position.y + sy * sub, sub + 0.5, sub + 0.5), c, true)


func _draw_rock_tile(rect: Rect2) -> void:
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
	var edge := Color("#1a2214")
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
	# 整张地图（小尺度）
	for y in WORLD_H:
		for x in WORLD_W:
			var v: int = int(data["tiles"][y][x])
			var c: Color = COLOR_GRASS_A if v == 0 else COLOR_ROCK
			_minimap.draw_rect(Rect2(x * sx, y * sy, sx + 0.5, sy + 0.5), c, true)
	# 实体
	for e in data["entities"]:
		var p: Vector2i = e["pos"]
		var ec: Color = _color_for_kind(str(e["kind"]))
		# BOSS 用更大的点
		var k: String = str(e["kind"])
		var center := Vector2((p.x + 0.5) * sx, (p.y + 0.5) * sy)
		if k.begins_with("boss"):
			var boss_r: float = max(3.2, sx * 2.0)
			_minimap.draw_circle(center, boss_r + 1.5, Color(0.05, 0.02, 0.02, 0.85))
			_minimap.draw_circle(center, boss_r, ec)
			_minimap.draw_arc(center, boss_r + 2.0, 0.0, TAU, 20, Color(1.0, 0.92, 0.25, 0.90), 1.2)
		else:
			var size_mul: float = 2.0 if k == "elite" else 1.4
			var dot := Rect2(p.x * sx - sx * (size_mul - 1) * 0.5, p.y * sy - sy * (size_mul - 1) * 0.5, sx * size_mul, sy * size_mul)
			_minimap.draw_rect(dot, ec, true)
	# 玩家
	var pp: Vector2i = data["player"]
	var player_center := Vector2((pp.x + 0.5) * sx, (pp.y + 0.5) * sy)
	var psize: float = max(3.6, sx * 2.2)
	_minimap.draw_circle(player_center, psize + 1.5, Color(0.05, 0.04, 0.0, 0.85))
	_minimap.draw_circle(player_center, psize, COLOR_PLAYER)
	_minimap.draw_arc(player_center, psize + 2.0, 0.0, TAU, 20, Color(0.30, 0.82, 1.0, 0.90), 1.2)
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

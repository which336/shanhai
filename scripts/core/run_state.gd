## RunState: 单局状态（Autoload 单例）
## 一次冒险中的：HP、灵韵、当前卡组、地图位置等。开新局时清空。
extends Node

signal hp_changed(hp: int, max_hp: int)
signal energy_changed(energy: int, max_energy: int)
signal deck_changed()

const MAX_HP_INIT: int = 70
const MAX_ENERGY_INIT: int = 3
const INITIAL_HAND_COUNT: int = 4      # 战斗开始时的起手牌数
const PER_TURN_DRAW_COUNT: int = 2     # 第 2 回合起每回合追加摸牌数

var character_id: String = "fang_xun"
var hp: int = MAX_HP_INIT
var max_hp: int = MAX_HP_INIT
var energy: int = MAX_ENERGY_INIT
var max_energy: int = MAX_ENERGY_INIT
var hand_size: int = INITIAL_HAND_COUNT          # 起手牌数
var per_turn_draw: int = PER_TURN_DRAW_COUNT     # 每回合追加摸牌数

var run_deck: Array[Card] = []          # 当前卡组（卡牌模板的引用）
var current_floor: int = 0              # 当前层数（节点深度）
var next_battle_enemy_ids: PackedStringArray = PackedStringArray(["hu_diao", "lu_shu"])

## 经验/等级（即时战斗用）
var level: int = 1
var exp_value: int = 0
var exp_to_next: int = 10

## 通关进度（3 个 BOSS 都击败 = 真正通关）
const BOSSES_TO_CLEAR: int = 3
const CHAPTER_SOUTH: int = 0
const CHAPTER_WEST: int = 1
const CHAPTER_NORTH: int = 2
const CHAPTER_EAST: int = 3
const CHAPTER_CENTRAL: int = 4

var current_chapter_index: int = CHAPTER_SOUTH
var bosses_defeated: int = 0

## 探索地图状态：从地图进入战斗时由地图写入；战斗结束后地图据此恢复
var map_data: Dictionary = {}
var last_entity_id: String = ""
var last_battle_was_boss: bool = false
var last_battle_won: bool = false

## 图鉴返回路径：从地图按 K 打开图鉴时，回去时回到地图而不是主菜单
var return_after_codex: String = ""
var map_view_mode: int = 0             # 0 = top-down, 1 = isometric

var seed_value: int = 0                 # 本局随机种子


signal level_up(new_level: int)
signal exp_changed(value: int, to_next: int)


## 增加经验，可能升级（升级会满血 + 提高 max_hp）
func add_exp(amount: int) -> bool:
	exp_value += amount
	var leveled := false
	while exp_value >= exp_to_next:
		exp_value -= exp_to_next
		level += 1
		max_hp += 10
		hp = max_hp
		exp_to_next = int(round(exp_to_next * 1.45))
		leveled = true
		level_up.emit(level)
	exp_changed.emit(exp_value, exp_to_next)
	return leveled


func reset_for_new_run(character: String = "fang_xun") -> void:
	character_id = character
	hp = MAX_HP_INIT
	max_hp = MAX_HP_INIT
	energy = MAX_ENERGY_INIT
	max_energy = MAX_ENERGY_INIT
	hand_size = INITIAL_HAND_COUNT
	per_turn_draw = PER_TURN_DRAW_COUNT
	current_floor = 0
	current_chapter_index = CHAPTER_SOUTH
	next_battle_enemy_ids = PackedStringArray(["hu_diao", "lu_shu"])
	level = 1
	exp_value = 0
	exp_to_next = 10
	bosses_defeated = 0
	map_data = {}
	last_entity_id = ""
	last_battle_was_boss = false
	last_battle_won = false
	map_view_mode = 0
	seed_value = randi()
	run_deck.clear()
	# 从 CardDatabase 取该角色的起手卡组
	var starter_ids: PackedStringArray = CardDatabase.get_starter_deck(character)
	starter_ids = _apply_active_bookmark(starter_ids)
	for cid in starter_ids:
		var c: Card = CardDatabase.get_card(cid)
		if c != null:
			run_deck.append(c)
	deck_changed.emit()


func _apply_active_bookmark(starter_ids: PackedStringArray) -> PackedStringArray:
	var def: Dictionary = GameState.active_bookmark_def()
	if def.is_empty():
		return starter_ids
	var remove_id: String = str(def.get("remove_card", ""))
	var add_id: String = str(def.get("add_card", ""))
	if remove_id == "" or add_id == "" or not CardDatabase.has_card(add_id):
		return starter_ids
	var result := PackedStringArray()
	var replaced := false
	for cid in starter_ids:
		if not replaced and cid == remove_id:
			result.append(add_id)
			replaced = true
		else:
			result.append(cid)
	if not replaced:
		result.append(add_id)
	return result



func has_next_chapter() -> bool:
	return current_chapter_index < CHAPTER_CENTRAL


func advance_to_next_chapter() -> void:
	if not has_next_chapter():
		return
	current_chapter_index += 1
	current_floor = current_chapter_index
	bosses_defeated = 0
	hp = max_hp
	energy = max_energy
	match current_chapter_index:
		CHAPTER_WEST:
			next_battle_enemy_ids = PackedStringArray(["zheng_beast", "tian_gou"])
		CHAPTER_NORTH:
			next_battle_enemy_ids = PackedStringArray(["he_luo_fish", "fei_yi"])
		CHAPTER_EAST:
			next_battle_enemy_ids = PackedStringArray(["dang_kang", "qiu_yu"])
		CHAPTER_CENTRAL:
			next_battle_enemy_ids = PackedStringArray(["kui", "tu_lou"])
		_:
			next_battle_enemy_ids = PackedStringArray(["hu_diao", "lu_shu"])
	map_data = {}
	last_entity_id = ""
	last_battle_was_boss = false
	last_battle_won = false
	seed_value = randi()
	hp_changed.emit(hp, max_hp)
	energy_changed.emit(energy, max_energy)
	exp_changed.emit(exp_value, exp_to_next)


func reset_map_progress_to_first_chapter() -> void:
	current_chapter_index = CHAPTER_SOUTH
	current_floor = 0
	hp = MAX_HP_INIT
	max_hp = MAX_HP_INIT
	energy = MAX_ENERGY_INIT
	max_energy = MAX_ENERGY_INIT
	hand_size = INITIAL_HAND_COUNT
	per_turn_draw = PER_TURN_DRAW_COUNT
	level = 1
	exp_value = 0
	exp_to_next = 10
	bosses_defeated = 0
	next_battle_enemy_ids = PackedStringArray(["hu_diao", "lu_shu"])
	map_data = {}
	last_entity_id = ""
	last_battle_was_boss = false
	last_battle_won = false
	seed_value = randi()
	hp_changed.emit(hp, max_hp)
	energy_changed.emit(energy, max_energy)
	exp_changed.emit(exp_value, exp_to_next)


func add_card_to_deck(card: Card) -> void:
	if card == null:
		return
	run_deck.append(card)
	deck_changed.emit()


func remove_card_from_deck(card: Card) -> bool:
	var idx := run_deck.find(card)
	if idx < 0:
		return false
	run_deck.remove_at(idx)
	deck_changed.emit()
	return true


func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	hp_changed.emit(hp, max_hp)


func heal(amount: int) -> void:
	hp = min(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)


func is_dead() -> bool:
	return hp <= 0

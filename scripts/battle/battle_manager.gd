## BattleManager: 战斗主控（场景脚本）
## 负责：场景初始化、回合循环、出牌结算、胜负判定。
## UI 节点通过 `@onready` 取，并监听本节点信号刷新。
extends Node2D

signal battle_started()
signal turn_changed(is_player_turn: bool, turn_number: int)
signal card_played(card: Card, target: BattleEnemy)
signal battle_won()
signal battle_lost()
signal log_message(text: String)
signal ally_changed(ally: Dictionary)

@export var enemy_ids: PackedStringArray = PackedStringArray()

@onready var player: BattlePlayer = $Player
@onready var enemies_container: Node2D = $Enemies

var deck: Deck = null
var turn_number: int = 0
var is_player_turn: bool = true
var active_ally: Dictionary = {}

const ALLY_DEFS: Dictionary = {
	"ally_heluo": {"id": "ally_heluo", "display_name": "河罗鱼", "duration": 3, "action_kind": "draw", "amount": 1, "school": Card.School.HAI},
	"ally_feiyi": {"id": "ally_feiyi", "display_name": "肥遗", "duration": 3, "action_kind": "damage_lowest", "amount": 5, "school": Card.School.HUANG},
	"ally_zhuhuai": {"id": "ally_zhuhuai", "display_name": "诸怀", "duration": 3, "action_kind": "block", "amount": 6, "school": Card.School.SHAN},
	"ally_xiao": {"id": "ally_xiao", "display_name": "嚣", "duration": 3, "action_kind": "draw", "amount": 1, "school": Card.School.HAI},
	"ally_xiangliu": {"id": "ally_xiangliu", "display_name": "相柳影", "duration": 3, "action_kind": "damage_lowest", "amount": 7, "school": Card.School.HUANG},
	"ally_zhulong": {"id": "ally_zhulong", "display_name": "烛龙残照", "duration": 3, "action_kind": "damage_lowest", "amount": 9, "school": Card.School.HAI},
	"ally_qinglong": {"id": "ally_qinglong", "display_name": "青龙残影", "duration": 3, "action_kind": "damage_lowest", "amount": 11, "school": Card.School.HAI},
}

## 本回合内已出某流派的次数（用于"共鸣"机制）
var school_count_this_turn: Dictionary = {}


func _ready() -> void:
	# 调试便利：直接 F5 此场景时也能跑（没经过主菜单初始化 RunState）
	if RunState.run_deck.is_empty():
		RunState.reset_for_new_run("fang_xun")
	AudioEngine.play_bgm("battle")
	AudioEngine.play_sfx("battle_start")
	_setup_battle.call_deferred()


func _setup_battle() -> void:
	# 等级提供的额外资源（鼓励先在地图刷经验再打 BOSS）
	var lv: int = RunState.level
	var energy_bonus: int = 0
	if lv >= 4:
		energy_bonus += 1
	if lv >= 8:
		energy_bonus += 1
	RunState.max_energy = RunState.MAX_ENERGY_INIT + energy_bonus
	# 等级影响摸牌：保留手牌规则下，升级提高后续回合的追加摸牌。
	var draw_bonus: int = 0
	if lv >= 6:
		draw_bonus += 1
	RunState.hand_size = RunState.INITIAL_HAND_COUNT
	RunState.per_turn_draw = RunState.PER_TURN_DRAW_COUNT + draw_bonus

	# 玩家
	player.reset_for_battle()
	active_ally.clear()
	ally_changed.emit({})

	# 敌人
	for child in enemies_container.get_children():
		child.queue_free()
	if not RunState.next_battle_enemy_ids.is_empty():
		enemy_ids = RunState.next_battle_enemy_ids
	for eid in enemy_ids:
		var data: EnemyData = EnemyDatabase.get_enemy(eid)
		if data == null:
			push_warning("[BattleManager] 找不到敌人：%s（请检查 data/enemies/enemies.json）" % eid)
			continue
		var e := BattleEnemy.new()
		e.name = eid
		enemies_container.add_child(e)
		e.setup(data)
		e.died.connect(_on_enemy_died.bind(e))

	# 牌组
	deck = Deck.new()
	deck.init_from_deck(RunState.run_deck, RunState.seed_value)

	turn_number = 0
	battle_started.emit()
	_start_player_turn()


# ========== 回合流转 ==========

func _start_player_turn() -> void:
	turn_number += 1
	is_player_turn = true
	school_count_this_turn.clear()
	RunState.energy = RunState.max_energy
	RunState.energy_changed.emit(RunState.energy, RunState.max_energy)
	player.clear_block_at_turn_start()
	player.on_turn_start()
	# 保留手牌规则：第 1 回合起手 4 张；之后每回合追加摸 2 张。
	var draw_count: int = RunState.hand_size if turn_number == 1 else RunState.per_turn_draw
	_recover_cards_if_empty()
	deck.draw(draw_count)
	_tick_ally_turn()
	if _alive_enemies().is_empty():
		emit_signal("log_message", "同伴清除了最后的敌人。")
		battle_won.emit()
		return
	turn_changed.emit(true, turn_number)
	emit_signal("log_message", "—— 第 %d 回合 · 玩家回合 ——" % turn_number)


func end_player_turn() -> void:
	if not is_player_turn:
		return
	is_player_turn = false
	# 回合结束不再弃掉未使用手牌；玩家可以保留手牌到下一轮。
	player.on_turn_end()
	turn_changed.emit(false, turn_number)
	await _run_enemy_phase()


func _run_enemy_phase() -> void:
	emit_signal("log_message", "—— 第 %d 回合 · 敌方行动 ——" % turn_number)
	await get_tree().create_timer(0.35).timeout
	for e in _alive_enemies():
		e.on_turn_start()
		e.act_on(player)
		await get_tree().create_timer(0.18).timeout
		if RunState.is_dead():
			emit_signal("log_message", "你被击倒了……忘川带你回到了现实。")
			battle_lost.emit()
			return
		e.advance_intent()
		e.on_turn_end()
	if _alive_enemies().is_empty():
		emit_signal("log_message", "敌人尽数化散，灵韵归位。")
		battle_won.emit()
		return
	_start_player_turn()


# ========== 出牌 ==========

func can_play(card: Card) -> bool:
	if not is_player_turn:
		return false
	return RunState.energy >= _effective_card_cost(card)


func effective_card_cost(card: Card) -> int:
	return _effective_card_cost(card)


func play_card(card: Card, target: BattleEnemy = null) -> bool:
	if deck == null:
		return false
	var hand_index: int = deck.hand.find(card)
	return play_card_at_index(hand_index, target)


## UI 专用：按手牌位置出牌。
## 关键修复点：
## 1. 多张同名基础牌共享同一个 Card Resource，不能用 hand.find(card) 删除。
## 2. 抽卡效果必须在源卡离开手牌后结算，否则抽到的新牌会和源卡同时参与重建，容易出现"抽了但源卡还在"。
func play_card_at_index(hand_index: int, target: BattleEnemy = null) -> bool:
	if deck == null or hand_index < 0 or hand_index >= deck.hand.size():
		return false
	var card: Card = deck.hand[hand_index]
	if not can_play(card):
		return false
	if card.requires_target and target == null:
		return false

	# 扣灵韵
	var effective_cost: int = _effective_card_cost(card)
	RunState.energy -= effective_cost
	RunState.energy_changed.emit(RunState.energy, RunState.max_energy)
	_consume_school_discount(card)

	# 源卡先离开手牌，再结算效果。只有卡牌自身标记为 exhaust 时才消耗。
	var should_exhaust: bool = card.exhaust
	deck.move_hand_card_to_pile(hand_index, should_exhaust)

	# 同流派计数 / 共鸣
	var sk: int = card.school
	school_count_this_turn[sk] = school_count_this_turn.get(sk, 0) + 1
	if school_count_this_turn[sk] == 3 and sk != Card.School.NEUTRAL:
		_apply_resonance(sk)

	# 结算效果（此时抽牌不会把源卡一起留在手牌里）
	for eff in card.effects:
		_resolve_effect(eff, card, target)
	_resolve_card_bonus_effects(card, target)

	# 图鉴 / 音效 / UI
	if card.id != "":
		GameState.unlock_codex("card." + card.id)
	emit_signal("card_played", card, target)
	emit_signal("log_message", "出牌：%s%s" % [card.title, "（消耗）" if should_exhaust else ""])
	if should_exhaust:
		AudioEngine.play_sfx("card_exhaust")
	else:
		AudioEngine.play_sfx("card_play")

	if _alive_enemies().is_empty():
		emit_signal("log_message", "敌人尽数化散，灵韵归位。")
		battle_won.emit()
	return true


func _effective_card_cost(card: Card) -> int:
	var discount: int = _school_discount(card.school)
	return maxi(0, card.cost - discount)


func _school_discount(school: int) -> int:
	match school:
		Card.School.SHAN:
			return int(player.statuses.get(StatusEffect.ID_RESONANCE_SHAN, 0))
		Card.School.HAI:
			return int(player.statuses.get(StatusEffect.ID_RESONANCE_HAI, 0))
		Card.School.HUANG:
			return int(player.statuses.get(StatusEffect.ID_RESONANCE_HUANG, 0))
	return 0


func _consume_school_discount(card: Card) -> void:
	if card.school == Card.School.NEUTRAL:
		return
	var status_id: String = ""
	match card.school:
		Card.School.SHAN:
			status_id = StatusEffect.ID_RESONANCE_SHAN
		Card.School.HAI:
			status_id = StatusEffect.ID_RESONANCE_HAI
		Card.School.HUANG:
			status_id = StatusEffect.ID_RESONANCE_HUANG
	if status_id == "" or not player.statuses.has(status_id):
		return
	player.statuses[status_id] = maxi(0, int(player.statuses[status_id]) - 1)
	if int(player.statuses[status_id]) <= 0:
		player.statuses.erase(status_id)
	player.status_changed.emit()


func _recover_cards_if_empty() -> void:
	if deck == null:
		return
	if not deck.hand.is_empty() or not deck.draw_pile.is_empty() or not deck.discard_pile.is_empty():
		return
	if deck.exhaust_pile.is_empty():
		return
	deck.draw_pile.append_array(deck.exhaust_pile)
	deck.exhaust_pile.clear()
	deck.shuffle_draw()
	deck.hand_changed.emit()
	deck.piles_changed.emit()
	emit_signal("log_message", "灵韵回流：消耗堆洗回抽牌堆，避免无牌可出。")


func _apply_resonance(school: int) -> void:
	match school:
		Card.School.SHAN:
			player.gain_block(4)
			player.apply_status(StatusEffect.ID_RESONANCE_SHAN, 1)
			emit_signal("log_message", "山经共鸣 · 立木为屏，护盾 +4")
		Card.School.HAI:
			deck.draw(1)
			player.apply_status(StatusEffect.ID_RESONANCE_HAI, 1)
			emit_signal("log_message", "海经共鸣 · 借浪而起，抽 1 张")
		Card.School.HUANG:
			player.apply_status(StatusEffect.ID_STRENGTHEN, 2)
			player.apply_status(StatusEffect.ID_RESONANCE_HUANG, 1)
			emit_signal("log_message", "荒经共鸣 · 锐意如锋，强化 +2")


func _resolve_effect(eff: CardEffect, source_card: Card, target: BattleEnemy) -> void:
	match eff.kind:
		CardEffect.Kind.DAMAGE:
			if eff.target == CardEffect.Target.NONE or eff.target == CardEffect.Target.SELF:
				var taken := player.take_damage(eff.amount)
				emit_signal("log_message", "→ 血祭代价：自身承受 %d 伤害" % taken)
				return
			var targets: Array[BattleEnemy] = _select_targets(eff.target, target)
			for tgt in targets:
				var raw := StatusEffect.calc_damage_modifier(player.statuses, tgt.statuses, eff.amount)
				tgt.take_damage(raw)
				emit_signal("log_message", "→ %s 受到 %d 伤害" % [tgt.data.display_name, raw])
		CardEffect.Kind.BLOCK:
			player.gain_block(eff.amount)
			emit_signal("log_message", "→ 获得 %d 护盾" % eff.amount)
		CardEffect.Kind.HEAL:
			RunState.heal(eff.amount)
			emit_signal("log_message", "→ 恢复 %d 生命" % eff.amount)
		CardEffect.Kind.DRAW:
			deck.draw(eff.amount)
			emit_signal("log_message", "→ 抽 %d 张牌" % eff.amount)
		CardEffect.Kind.GAIN_ENERGY:
			RunState.energy += eff.amount
			RunState.energy_changed.emit(RunState.energy, RunState.max_energy)
			emit_signal("log_message", "→ 获得 %d 灵韵" % eff.amount)
		CardEffect.Kind.APPLY_STATUS:
			var targets: Array[BattleEnemy] = _select_targets(eff.target, target)
			for tgt in targets:
				tgt.apply_status(eff.status_id, eff.status_stack)
				emit_signal("log_message", "→ %s 获得 [%s] x %d" % [tgt.data.display_name, StatusEffect.display_name(eff.status_id), eff.status_stack])
		CardEffect.Kind.SELF_STATUS:
			player.apply_status(eff.status_id, eff.status_stack)
			emit_signal("log_message", "→ 自身获得 [%s] x %d" % [StatusEffect.display_name(eff.status_id), eff.status_stack])
		CardEffect.Kind.DISCARD_RANDOM:
			deck.discard_random(eff.amount)
			emit_signal("log_message", "→ 随机弃 %d 张" % eff.amount)
		CardEffect.Kind.EXHAUST_HAND:
			# 暂不实现，预留
			pass
		CardEffect.Kind.SUMMON_ALLY:
			_summon_ally(eff.status_id, eff.amount)


func _summon_ally(ally_id: String, requested_duration: int) -> void:
	if not ALLY_DEFS.has(ally_id):
		emit_signal("log_message", "未找到同伴定义：%s" % ally_id)
		return
	var def: Dictionary = ALLY_DEFS[ally_id]
	var duration: int = requested_duration if requested_duration > 0 else int(def.get("duration", 3))
	active_ally = def.duplicate(true)
	active_ally["turns"] = duration
	active_ally["last_action"] = "等待下个玩家回合开始行动"
	ally_changed.emit(active_ally.duplicate(true))
	emit_signal("log_message", "召唤同伴：%s（%d 回合）" % [str(active_ally.get("display_name", ally_id)), duration])


func _tick_ally_turn() -> void:
	if active_ally.is_empty():
		return
	var action_kind: String = str(active_ally.get("action_kind", ""))
	var amount: int = int(active_ally.get("amount", 0))
	var action_text: String = ""
	match action_kind:
		"damage_lowest":
			var target := _lowest_hp_enemy()
			if target != null:
				var dealt: int = target.take_damage(amount)
				action_text = "对 %s 造成 %d 伤害" % [target.data.display_name, dealt]
			else:
				action_text = "没有可攻击目标"
		"block":
			player.gain_block(amount)
			action_text = "为玩家获得 %d 护盾" % amount
		"draw":
			if deck != null:
				deck.draw(maxi(1, amount))
			action_text = "抽 %d 张牌" % maxi(1, amount)
		_:
			action_text = "没有配置行动"
	active_ally["last_action"] = action_text
	active_ally["turns"] = int(active_ally.get("turns", 0)) - 1
	emit_signal("log_message", "%s：%s" % [str(active_ally.get("display_name", "同伴")), action_text])
	if int(active_ally.get("turns", 0)) <= 0:
		emit_signal("log_message", "%s 离场。" % str(active_ally.get("display_name", "同伴")))
		active_ally.clear()
		ally_changed.emit({})
	else:
		ally_changed.emit(active_ally.duplicate(true))


func _lowest_hp_enemy() -> BattleEnemy:
	var choice: BattleEnemy = null
	for e in _alive_enemies():
		if choice == null or e.hp < choice.hp:
			choice = e
	return choice


func _resolve_card_bonus_effects(card: Card, target: BattleEnemy) -> void:
	match card.id:
		"neutral.warrior_oath":
			if player.block > 0:
				_deal_bonus_damage(card, target, "护盾在身，侠者誓追加一击")
		"hai.bifang_dance":
			if target != null and not target.is_dead() and target.statuses.has(StatusEffect.ID_WET):
				_deal_bonus_damage(card, target, "目标湿润，毕方闪羽追加一击")
		"huang.xingtian_axe":
			if deck != null and deck.hand.is_empty():
				_deal_bonus_damage(card, target, "手牌已空，刑天舞戚追加一击")


func _deal_bonus_damage(card: Card, target: BattleEnemy, message: String) -> void:
	if target == null or target.is_dead():
		return
	var amount: int = _first_damage_amount(card)
	if amount <= 0:
		return
	var raw := StatusEffect.calc_damage_modifier(player.statuses, target.statuses, amount)
	target.take_damage(raw)
	emit_signal("log_message", "→ %s：%s，造成 %d 伤害" % [target.data.display_name, message, raw])


func _first_damage_amount(card: Card) -> int:
	for eff in card.effects:
		if eff.kind == CardEffect.Kind.DAMAGE:
			return eff.amount
	return 0


func _select_targets(t: int, single: BattleEnemy) -> Array[BattleEnemy]:
	match t:
		CardEffect.Target.SINGLE:
			if single != null and not single.is_dead():
				return [single] as Array[BattleEnemy]
			return [] as Array[BattleEnemy]
		CardEffect.Target.ALL_ENEMIES:
			return _alive_enemies()
		_:
			return [] as Array[BattleEnemy]


func _alive_enemies() -> Array[BattleEnemy]:
	var out: Array[BattleEnemy] = []
	for c in enemies_container.get_children():
		if c is BattleEnemy and not c.is_dead():
			out.append(c)
	return out


func _on_enemy_died(e: BattleEnemy) -> void:
	emit_signal("log_message", "%s 灵韵流散。" % e.data.display_name)
	# 解锁该敌人对应的图鉴
	if e.data.id != "":
		GameState.unlock_codex("beast." + e.data.id)

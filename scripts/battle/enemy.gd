## Enemy: 战斗中的敌人节点
class_name BattleEnemy extends Node2D

signal hp_changed(hp: int, max_hp: int)
signal block_changed(amount: int)
signal intent_changed(intent_kind: int, amount: int)
signal status_changed()
signal died()

var data: EnemyData = null
var hp: int = 0
var max_hp: int = 0
var block: int = 0
var statuses: Dictionary = {}
var turn_index: int = 0
var current_intent: EnemyData.Intent = null


func setup(d: EnemyData) -> void:
	data = d
	max_hp = d.max_hp
	hp = max_hp
	block = 0
	turn_index = 0
	statuses.clear()
	current_intent = d.resolve_intent(turn_index)
	hp_changed.emit(hp, max_hp)
	block_changed.emit(block)
	intent_changed.emit(current_intent.kind, current_intent.amount)
	status_changed.emit()


func take_damage(raw: int) -> int:
	var dmg: int = raw
	if block > 0:
		var absorbed: int = mini(block, dmg)
		block -= absorbed
		dmg -= absorbed
		block_changed.emit(block)
	if dmg > 0:
		hp = max(0, hp - dmg)
		hp_changed.emit(hp, max_hp)
		if hp <= 0:
			died.emit()
	return dmg


func gain_block(amount: int) -> void:
	block += amount
	block_changed.emit(block)


func apply_status(status_id: String, stack: int) -> void:
	statuses[status_id] = statuses.get(status_id, 0) + stack
	status_changed.emit()


## 让敌人执行当前 intent
func act_on(player: BattlePlayer) -> void:
	if current_intent == null or hp <= 0:
		return
	match current_intent.kind:
		EnemyData.IntentKind.ATTACK:
			var raw := StatusEffect.calc_damage_modifier(statuses, player.statuses, current_intent.amount)
			player.take_damage(raw)
		EnemyData.IntentKind.BLOCK:
			gain_block(current_intent.amount)
		EnemyData.IntentKind.BUFF:
			apply_status(StatusEffect.ID_STRENGTHEN, max(1, current_intent.amount))
		EnemyData.IntentKind.DEBUFF:
			player.apply_status(StatusEffect.ID_VULNERABLE, max(1, current_intent.amount))
		EnemyData.IntentKind.IDLE:
			pass


## 回合结束后推进到下一 intent
func advance_intent() -> void:
	turn_index += 1
	current_intent = data.resolve_intent(turn_index)
	intent_changed.emit(current_intent.kind, current_intent.amount)


func on_turn_start() -> void:
	# 敌人回合开始清护盾（参考 STS 规则）
	if block != 0:
		block = 0
		block_changed.emit(block)


func is_dead() -> bool:
	return hp <= 0

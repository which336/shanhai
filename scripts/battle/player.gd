## Player: 战斗中的玩家节点（控制 HP / 护盾 / 状态显示）
## 实际 HP/灵韵 数据存在 RunState；这里负责：战斗内表现 + 护盾 + 状态
class_name BattlePlayer extends Node2D

signal block_changed(amount: int)
signal status_changed()

var block: int = 0
var statuses: Dictionary = {}     # status_id -> stack


func reset_for_battle() -> void:
	block = 0
	statuses.clear()
	block_changed.emit(block)
	status_changed.emit()


## 受到攻击伤害（先扣护盾再扣 HP）
func take_damage(raw: int) -> int:
	var dmg: int = raw
	var was_vulnerable: bool = statuses.has(StatusEffect.ID_VULNERABLE)
	if block > 0:
		var absorbed: int = mini(block, dmg)
		block -= absorbed
		dmg -= absorbed
		block_changed.emit(block)
	if dmg > 0:
		RunState.take_damage(dmg)
	if was_vulnerable:
		statuses[StatusEffect.ID_VULNERABLE] = maxi(0, int(statuses[StatusEffect.ID_VULNERABLE]) - 1)
		if int(statuses.get(StatusEffect.ID_VULNERABLE, 0)) <= 0:
			statuses.erase(StatusEffect.ID_VULNERABLE)
		status_changed.emit()
	return dmg


func gain_block(amount: int) -> void:
	block += amount
	block_changed.emit(block)


func apply_status(status_id: String, stack: int) -> void:
	statuses[status_id] = statuses.get(status_id, 0) + stack
	status_changed.emit()


func clear_block_at_turn_start() -> void:
	if block != 0:
		block = 0
		block_changed.emit(block)


## 回合开始：处理回合开始效果（根脉、灼焰）
func on_turn_start() -> void:
	if statuses.has(StatusEffect.ID_ROOT):
		gain_block(statuses[StatusEffect.ID_ROOT])
	if statuses.has(StatusEffect.ID_BURN):
		take_damage(statuses[StatusEffect.ID_BURN])


## 回合结束：状态层数衰减（共鸣类只持续本回合，立即清；其他递减 1）
func on_turn_end() -> void:
	for sid in statuses.keys():
		if sid.begins_with("resonance_"):
			statuses.erase(sid)
		elif sid == StatusEffect.ID_VULNERABLE:
			continue
		elif sid == StatusEffect.ID_ROOT:
			continue
		else:
			statuses[sid] = max(0, statuses[sid] - 1)
			if statuses[sid] <= 0:
				statuses.erase(sid)
	status_changed.emit()

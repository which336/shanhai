## Card: 一张卡牌的"模板"（Resource，不可变数据 + 默认逻辑）
## 战斗中真正参与流转的是 CardInstance（运行时副本）。
## 每张卡都对应一条山海经条目（classic_quote + translation 是文化承载的核心）。
class_name Card extends Resource

enum School {
	NEUTRAL,  # 通用
	SHAN,     # 山经 · 守拙流（防御 / 草木）
	HAI,      # 海经 · 灵动流（速度 / 水族）
	HUANG,    # 荒经 · 锐意流（爆发 / 凶兽）
}

enum Rarity {
	COMMON,
	RARE,
	MYTHIC,
	RELIC,    # 唤醒所得，独一无二
}

enum CardType {
	ATTACK,
	SKILL,
	POWER,    # 持续效果（一次性铺到玩家身上，整局生效）
}

@export var id: String = ""                 # 全局唯一，如 "shan.jianmu"
@export var title: String = ""              # 中文卡名，如 "建木·承露"
@export var school: School = School.NEUTRAL
@export var card_type: CardType = CardType.SKILL
@export var rarity: Rarity = Rarity.COMMON
@export var cost: int = 1                   # 灵韵消耗（-1 表示 X 费）
@export var exhaust: bool = false           # 出牌后消耗（不进弃牌堆）
@export var requires_target: bool = false   # 是否需要选择敌方目标

@export var effects: Array[CardEffect] = []

## ===== 文化字段（核心）=====
@export_multiline var classic_quote: String = ""   # 山海经原文
@export_multiline var translation: String = ""     # 白话译注
@export_multiline var description: String = ""     # 玩法描述（可使用 {0}~{n} 占位指代 effects[i].amount）
@export_multiline var alive_today: String = ""     # "今天活在哪里"——文化关照现实

## ===== 美术（占位，可选）=====
@export var art: Texture2D = null
@export var art_tint: Color = Color(1, 1, 1, 1)


func get_school_name() -> String:
	match school:
		School.SHAN: return "山经"
		School.HAI: return "海经"
		School.HUANG: return "荒经"
		_: return "通用"


func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return "凡品"
		Rarity.RARE: return "珍品"
		Rarity.MYTHIC: return "神品"
		Rarity.RELIC: return "遗珍"
	return "?"


## 把 description 中的 {0} {1} 替换为对应 effect 的 amount，方便策划只写一份描述
func get_resolved_description() -> String:
	var s := description
	for i in effects.size():
		var value: int = effects[i].amount
		if (effects[i].kind == CardEffect.Kind.APPLY_STATUS or effects[i].kind == CardEffect.Kind.SELF_STATUS) and effects[i].status_stack != 0:
			value = effects[i].status_stack
		s = s.replace("{%d}" % i, str(value))
	return s

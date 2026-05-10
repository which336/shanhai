## Card: 一张卡牌的模板数据。
## 战斗中实际流转的是 CardInstance；这里保持为可复用、可存档引用的静态定义。
class_name Card extends Resource

enum School {
	NEUTRAL,
	SHAN,
	HAI,
	HUANG,
}

enum Rarity {
	COMMON,
	RARE,
	MYTHIC,
	RELIC,
}

enum CardType {
	ATTACK,
	SKILL,
	POWER,
}

@export var id: String = ""
@export var title: String = ""
@export var school: School = School.NEUTRAL
@export var card_type: CardType = CardType.SKILL
@export var rarity: Rarity = Rarity.COMMON
@export var cost: int = 1
@export var exhaust: bool = false
@export var requires_target: bool = false
@export var keywords: Array[String] = []

@export var effects: Array[CardEffect] = []

@export_multiline var classic_quote: String = ""
@export_multiline var translation: String = ""
@export_multiline var description: String = ""
@export_multiline var alive_today: String = ""

@export var art: Texture2D = null
@export var art_tint: Color = Color(1, 1, 1, 1)


func get_school_name() -> String:
	match school:
		School.SHAN:
			return "山经"
		School.HAI:
			return "海经"
		School.HUANG:
			return "荒经"
		_:
			return "通用"


func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON:
			return "凡品"
		Rarity.RARE:
			return "珍品"
		Rarity.MYTHIC:
			return "神品"
		Rarity.RELIC:
			return "遗珍"
	return "?"


func has_keyword(keyword: String) -> bool:
	return keywords.has(keyword)


func get_keywords_text(separator: String = " · ") -> String:
	return separator.join(keywords)


func get_resolved_description() -> String:
	var s := description
	for i in effects.size():
		var value: int = effects[i].amount
		if (effects[i].kind == CardEffect.Kind.APPLY_STATUS or effects[i].kind == CardEffect.Kind.SELF_STATUS) and effects[i].status_stack != 0:
			value = effects[i].status_stack
		s = s.replace("{%d}" % i, str(value))
	return s

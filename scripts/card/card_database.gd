## CardDatabase: 启动时从 JSON 加载所有卡牌。
extends Node

const CARDS_PATH: String = "res://data/cards/cards.json"

var _cards: Dictionary = {}

const STARTER_DECKS: Dictionary = {
	"fang_xun": [
		"neutral.strike",
		"neutral.strike",
		"neutral.strike",
		"neutral.strike",
		"neutral.guard",
		"neutral.guard",
		"neutral.guard",
		"shan.jianmu",
	],
	"ali": [
		"neutral.strike",
		"neutral.strike",
		"neutral.guard",
		"neutral.guard",
		"ali.foxtail_feint",
		"ali.moonlit_wound",
		"huang.qiongqi_lash",
		"neutral.scroll_study",
	],
	"luo_ling": [
		"neutral.strike",
		"neutral.strike",
		"neutral.guard",
		"neutral.guard",
		"hai.yinglong_call",
		"hai.wenyao_evade",
		"hai.kun_swift",
		"hai.tide_return",
	],
	"sang_qi": [
		"neutral.strike",
		"neutral.guard",
		"neutral.guard",
		"neutral.guard",
		"sangqi.root_guard",
		"sangqi.fusang_sprout",
		"shan.jianmu",
		"shan.fusang",
	]
}


func _ready() -> void:
	reload_all()


func reload_all() -> void:
	_cards.clear()
	var f := FileAccess.open(CARDS_PATH, FileAccess.READ)
	if f == null:
		push_warning("[CardDatabase] 找不到卡牌定义：%s" % CARDS_PATH)
		return
	var text := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(text)
	if not (data is Array):
		push_warning("[CardDatabase] 卡牌 JSON 必须是数组，实际为：%s" % typeof(data))
		return
	for card_def in data:
		if not (card_def is Dictionary):
			continue
		if card_def.has("_section"):
			continue
		var c := _build_card(card_def)
		if c != null and c.id != "":
			_cards[c.id] = c
		else:
			push_warning("[CardDatabase] 跳过无效卡牌定义：%s" % card_def)
	print("[CardDatabase] 已加载 %d 张卡" % _cards.size())


func _build_card(d: Dictionary) -> Card:
	var c := Card.new()
	c.id = d.get("id", "")
	c.title = d.get("title", "")
	c.school = int(d.get("school", Card.School.NEUTRAL))
	c.card_type = int(d.get("card_type", Card.CardType.SKILL))
	c.rarity = int(d.get("rarity", Card.Rarity.COMMON))
	c.cost = int(d.get("cost", 1))
	c.exhaust = bool(d.get("exhaust", false))
	c.requires_target = bool(d.get("requires_target", false))
	c.keywords = _parse_keywords(d.get("keywords", []))
	c.classic_quote = d.get("classic_quote", "")
	c.translation = d.get("translation", "")
	c.description = d.get("description", "")
	c.alive_today = d.get("alive_today", "")
	var effects_array: Array[CardEffect] = []
	for eff_def in d.get("effects", []):
		if not (eff_def is Dictionary):
			continue
		var eff := CardEffect.new()
		eff.kind = int(eff_def.get("kind", CardEffect.Kind.DAMAGE))
		eff.amount = int(eff_def.get("amount", 0))
		eff.target = int(eff_def.get("target", CardEffect.Target.SINGLE))
		eff.status_id = eff_def.get("status_id", "")
		eff.status_stack = int(eff_def.get("status_stack", 0))
		effects_array.append(eff)
	c.effects = effects_array
	return c


func _parse_keywords(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (raw is Array):
		return result
	for item in raw:
		var keyword := str(item).strip_edges()
		if keyword != "" and not result.has(keyword):
			result.append(keyword)
	return result


func get_card(id: String) -> Card:
	return _cards.get(id, null)


func has_card(id: String) -> bool:
	return _cards.has(id)


func all_cards() -> Array:
	return _cards.values()


func get_starter_deck(character_id: String) -> PackedStringArray:
	var ids: Array = STARTER_DECKS.get(character_id, [])
	var result := PackedStringArray()
	for id in ids:
		result.append(id)
	return result


func query(school: int = -1, rarity: int = -1) -> Array:
	var out: Array = []
	for c in _cards.values():
		if school >= 0 and c.school != school:
			continue
		if rarity >= 0 and c.rarity != rarity:
			continue
		out.append(c)
	return out

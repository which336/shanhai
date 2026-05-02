## CardDatabase: 启动时从 JSON 加载所有卡牌（Autoload 单例）
## 数据驱动：策划在 data/cards/cards.json 中加新卡，不动代码即可上线
extends Node

const CARDS_PATH: String = "res://data/cards/cards.json"

var _cards: Dictionary = {}             # id -> Card

## 起手卡组（角色 -> 卡 ID 列表）。MVP 仅一个角色。
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
			continue   # JSON 里用作章节注释的伪条目
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


## 按流派/稀有度筛选（用于商人 / 战利品池）
func query(school: int = -1, rarity: int = -1) -> Array:
	var out: Array = []
	for c in _cards.values():
		if school >= 0 and c.school != school:
			continue
		if rarity >= 0 and c.rarity != rarity:
			continue
		out.append(c)
	return out

## EnemyData: 敌人模板（Resource）
## 行为模式由 intent_pattern 决定：每回合按 pattern 数组循环取一个 intent
class_name EnemyData extends Resource

enum IntentKind {
	ATTACK,
	BLOCK,
	BUFF,
	DEBUFF,
	IDLE,
}

class Intent:
	var kind: IntentKind
	var amount: int = 0
	var note: String = ""
	func _init(k: IntentKind = IntentKind.ATTACK, a: int = 0, n: String = "") -> void:
		kind = k
		amount = a
		note = n

@export var id: String = ""
@export var display_name: String = ""
@export var max_hp: int = 20
@export var is_elite: bool = false
@export var is_boss: bool = false

## 行动模式：字符串数组，每回合按下标循环
## 格式 "ATTACK:6"、"BLOCK:5"、"BUFF:strengthen:2"
@export var intent_pattern: PackedStringArray = PackedStringArray()

## ===== 文化字段（图鉴用）=====
@export_multiline var classic_quote: String = ""
@export_multiline var translation: String = ""
@export_multiline var awaken_options: PackedStringArray = PackedStringArray()
@export var awaken_correct_index: int = 0  # 正确译文在 options 中的下标
@export_multiline var awaken_card_id: String = ""  # 唤醒成功后获得的卡 ID


## 把字符串 pattern 解析为结构化 intent
func resolve_intent(turn_index: int) -> Intent:
	if intent_pattern.is_empty():
		return Intent.new(IntentKind.IDLE, 0, "踟蹰")
	var raw: String = intent_pattern[turn_index % intent_pattern.size()]
	var parts: PackedStringArray = raw.split(":")
	var kind_str: String = parts[0].strip_edges()
	var amount: int = 0
	if parts.size() >= 2 and parts[1].is_valid_int():
		amount = parts[1].to_int()
	var kind: IntentKind = IntentKind.IDLE
	match kind_str.to_upper():
		"ATTACK": kind = IntentKind.ATTACK
		"BLOCK": kind = IntentKind.BLOCK
		"BUFF": kind = IntentKind.BUFF
		"DEBUFF": kind = IntentKind.DEBUFF
		_: kind = IntentKind.IDLE
	return Intent.new(kind, amount, raw)

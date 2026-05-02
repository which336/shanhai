## EnemyDatabase: 启动时从 JSON 加载所有敌人（Autoload 单例）
extends Node

const ENEMIES_PATH: String = "res://data/enemies/enemies.json"

var _enemies: Dictionary = {}     # id -> EnemyData


func _ready() -> void:
	reload_all()


func reload_all() -> void:
	_enemies.clear()
	var f := FileAccess.open(ENEMIES_PATH, FileAccess.READ)
	if f == null:
		push_warning("[EnemyDatabase] 找不到敌人定义：%s" % ENEMIES_PATH)
		return
	var text := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(text)
	if not (data is Array):
		push_warning("[EnemyDatabase] 敌人 JSON 必须是数组")
		return
	for d in data:
		if not (d is Dictionary):
			continue
		var e := _build_enemy(d)
		if e != null and e.id != "":
			_enemies[e.id] = e
	print("[EnemyDatabase] 已加载 %d 个敌人" % _enemies.size())


func _build_enemy(d: Dictionary) -> EnemyData:
	var e := EnemyData.new()
	e.id = d.get("id", "")
	e.display_name = d.get("display_name", "")
	e.max_hp = int(d.get("max_hp", 20))
	e.is_elite = bool(d.get("is_elite", false))
	e.is_boss = bool(d.get("is_boss", false))
	var pattern := PackedStringArray()
	for s in d.get("intent_pattern", []):
		pattern.append(str(s))
	e.intent_pattern = pattern
	e.classic_quote = d.get("classic_quote", "")
	e.translation = d.get("translation", "")
	var opts := PackedStringArray()
	for s in d.get("awaken_options", []):
		opts.append(str(s))
	e.awaken_options = opts
	e.awaken_correct_index = int(d.get("awaken_correct_index", 0))
	e.awaken_card_id = d.get("awaken_card_id", "")
	return e


func get_enemy(id: String) -> EnemyData:
	return _enemies.get(id, null)


func has_enemy(id: String) -> bool:
	return _enemies.has(id)


func all_enemies() -> Array:
	return _enemies.values()

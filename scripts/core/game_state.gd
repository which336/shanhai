## GameState: 全局玩家状态（Autoload 单例）
## 跨局保留的内容：已解锁图鉴、典籍碎片、解锁的角色、设置等
extends Node

signal codex_unlocked(entry_id: String)
signal fragments_changed(amount: int)
signal bookmarks_changed()
signal characters_changed()
signal endings_changed()
signal codex_learning_changed()
signal settings_changed()

const BOOKMARK_NONE: String = ""
const BOOKMARK_RESEARCH: String = "research"
const BOOKMARK_SHAN: String = "shan"
const BOOKMARK_HAI: String = "hai"
const BOOKMARK_HUANG: String = "huang"

const CHARACTER_FANG_XUN: String = "fang_xun"
const CHARACTER_ALI: String = "ali"
const CHARACTER_LUO_LING: String = "luo_ling"
const CHARACTER_SANG_QI: String = "sang_qi"

const ENDING_CANXIANG: String = "canxiang_weiming"
const ENDING_WUJING: String = "wujing_jinghua"
const ENDING_CHONGMING: String = "shanhai_chongming"
const ENDING_DEFS: Array[Dictionary] = [
	{
		"id": ENDING_CANXIANG,
		"title": "残响未明",
		"rank": 1,
		"description": "五境已净，仍有许多名字沉在雾底。",
	},
	{
		"id": ENDING_WUJING,
		"title": "五境净化",
		"rank": 2,
		"description": "五境归于清明，被遗忘者重新有了回声。",
	},
	{
		"id": ENDING_CHONGMING,
		"title": "山海重明",
		"rank": 3,
		"description": "你不只走过五境，也记住了它们为何仍该被看见。",
	},
]

const CHARACTER_DEFS: Array[Dictionary] = [
	{
		"id": CHARACTER_FANG_XUN,
		"title": "方寻",
		"subtitle": "古卷行者",
		"school": "通用",
		"cost": 0,
		"codex_required": 0,
		"max_hp": 70,
		"max_energy": 3,
		"initial_hand": 4,
		"per_turn_draw": 2,
		"description": "均衡起手，适合熟悉五境流程与三流派基础节奏。",
	},
	{
		"id": CHARACTER_ALI,
		"title": "阿离",
		"subtitle": "九尾狐裔",
		"school": "荒经 / 诡术",
		"cost": 220,
		"codex_required": 20,
		"max_hp": 60,
		"max_energy": 3,
		"initial_hand": 4,
		"per_turn_draw": 2,
		"description": "以九尾狐裔的惑敌与血祭换取爆发，偏凶势、血祭和易伤路线。",
	},
	{
		"id": CHARACTER_LUO_LING,
		"title": "洛泠",
		"subtitle": "海经行者",
		"school": "海经 / 行雨",
		"cost": 240,
		"codex_required": 24,
		"max_hp": 65,
		"max_energy": 3,
		"initial_hand": 5,
		"per_turn_draw": 2,
		"description": "以潮涌和湿润维持手牌流动，偏抽牌、灵韵调度和水势铺场。",
	},
	{
		"id": CHARACTER_SANG_QI,
		"title": "桑岐",
		"subtitle": "扶桑守望",
		"school": "山经 / 根脉",
		"cost": 260,
		"codex_required": 28,
		"max_hp": 78,
		"max_energy": 3,
		"initial_hand": 4,
		"per_turn_draw": 2,
		"description": "以扶桑根脉稳住战线，偏护盾、根脉续防和生息回复，适合慢节奏构筑。",
	},
]

const BOOKMARK_DEFS: Array[Dictionary] = [
	{
		"id": BOOKMARK_RESEARCH,
		"title": "研读藏签",
		"school": "中立",
		"cost": 80,
		"codex_required": 5,
		"remove_card": "neutral.strike",
		"add_card": "neutral.scroll_study",
		"description": "开局将 1 张「击」替换为「古卷研读」。",
	},
	{
		"id": BOOKMARK_SHAN,
		"title": "山藏签",
		"school": "山经",
		"cost": 120,
		"codex_required": 8,
		"remove_card": "neutral.guard",
		"add_card": "shan.fusang",
		"description": "开局将 1 张「守」替换为「扶桑·朝露」。",
	},
	{
		"id": BOOKMARK_HAI,
		"title": "海藏签",
		"school": "海经",
		"cost": 160,
		"codex_required": 12,
		"remove_card": "neutral.guard",
		"add_card": "hai.wenyao_evade",
		"description": "开局将 1 张「守」替换为「文鳐·夜遁」。",
	},
	{
		"id": BOOKMARK_HUANG,
		"title": "荒藏签",
		"school": "荒经",
		"cost": 200,
		"codex_required": 16,
		"remove_card": "neutral.strike",
		"add_card": "huang.qiongqi_lash",
		"description": "开局将 1 张「击」替换为「穷奇·裂风」。",
	},
]


func _ready() -> void:
	ensure_settings_defaults()
	_apply_runtime_settings()
	_setup_cjk_font()
	# 全局快捷键：ESC 返回主菜单（在战斗等场景中很有用）
	process_mode = Node.PROCESS_MODE_ALWAYS


## 安装支持中文的系统字体作为全局回退，避免中文显示成方块
func _setup_cjk_font() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei", "Microsoft YaHei UI",
		"DengXian", "Source Han Sans SC",
		"Noto Sans CJK SC", "Noto Sans SC",
		"PingFang SC", "Hiragino Sans GB",
		"WenQuanYi Micro Hei", "SimSun", "Sans-Serif",
	])
	font.font_weight = 400
	font.allow_system_fallback = true
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 18


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			var current_scene: Node = get_tree().current_scene
			if current_scene == null:
				return
			var path: String = current_scene.scene_file_path
			if path == "" or path.ends_with("main_menu.tscn"):
				return
			# 地图场景自己处理 ESC，并弹出返回主菜单确认框。
			if path.ends_with("map.tscn"):
				return
			# 战斗场景按 ESC = 放弃这场战斗，回地图
			if path.ends_with("battle.tscn"):
				var run_state := get_node_or_null("/root/RunState")
				if run_state != null:
					run_state.set("last_battle_won", false)
				get_tree().change_scene_to_file("res://scenes/map/map.tscn")
				get_viewport().set_input_as_handled()
				return
			# 图鉴按 ESC：交给图鉴自己处理（已绑定 _on_back，会读 return_after_codex）
			if path.ends_with("codex.tscn"):
				return
			# 其他场景：回主菜单
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
			get_viewport().set_input_as_handled()

var unlocked_codex: Dictionary = {}     # entry_id -> true
var learned_codex: Dictionary = {}      # entry_id -> true
var fragments: int = 0                  # 典籍碎片（meta 货币）
var unlocked_characters: Array[String] = [CHARACTER_FANG_XUN]
var active_character_id: String = CHARACTER_FANG_XUN
var unlocked_bookmarks: Dictionary = {}
var active_bookmark_id: String = BOOKMARK_NONE
var seen_endings: Dictionary = {}
var best_ending_id: String = ""
var settings: Dictionary = {
	"locale": "zh_CN",
	"bgm_volume": 0.6,
	"sfx_volume": 0.8,
	"fullscreen": false,
	"show_dev_tools": false,
	"tutorial_seen": false,
}


func unlock_codex(entry_id: String) -> bool:
	if entry_id == "" or unlocked_codex.has(entry_id) or not is_valid_codex_entry(entry_id):
		return false
	unlocked_codex[entry_id] = true
	codex_unlocked.emit(entry_id)
	return true


func mark_codex_learned(entry_id: String) -> bool:
	if entry_id == "" or not unlocked_codex.has(entry_id) or learned_codex.has(entry_id) or not is_valid_codex_entry(entry_id):
		return false
	learned_codex[entry_id] = true
	codex_learning_changed.emit()
	return true


func is_codex_learned(entry_id: String) -> bool:
	return learned_codex.has(entry_id)


func add_fragments(amount: int) -> void:
	fragments = max(0, fragments + amount)
	fragments_changed.emit(fragments)


func default_settings() -> Dictionary:
	return {
		"locale": "zh_CN",
		"bgm_volume": 0.6,
		"sfx_volume": 0.8,
		"fullscreen": false,
		"show_dev_tools": false,
		"tutorial_seen": false,
	}


func ensure_settings_defaults() -> void:
	var defaults := default_settings()
	for key in defaults.keys():
		if not settings.has(key):
			settings[key] = defaults[key]
	settings["bgm_volume"] = clampf(float(settings.get("bgm_volume", defaults["bgm_volume"])), 0.0, 1.0)
	settings["sfx_volume"] = clampf(float(settings.get("sfx_volume", defaults["sfx_volume"])), 0.0, 1.0)
	settings["fullscreen"] = bool(settings.get("fullscreen", defaults["fullscreen"]))
	settings["show_dev_tools"] = bool(settings.get("show_dev_tools", defaults["show_dev_tools"]))
	settings["tutorial_seen"] = bool(settings.get("tutorial_seen", defaults["tutorial_seen"]))


func setting_value(key: String, fallback: Variant = null) -> Variant:
	ensure_settings_defaults()
	return settings.get(key, fallback)


func set_setting_value(key: String, value: Variant, save_now: bool = true) -> void:
	ensure_settings_defaults()
	settings[key] = value
	ensure_settings_defaults()
	_apply_runtime_settings()
	settings_changed.emit()
	if save_now:
		var save_system := get_node_or_null("/root/SaveSystem")
		if save_system != null:
			save_system.call("save")


func mark_tutorial_seen(save_now: bool = true) -> void:
	set_setting_value("tutorial_seen", true, save_now)


func _apply_runtime_settings() -> void:
	ensure_settings_defaults()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings.get("fullscreen", false)) else DisplayServer.WINDOW_MODE_WINDOWED)
	var audio := get_node_or_null("/root/AudioEngine")
	if audio != null and audio.has_method("apply_settings"):
		audio.call("apply_settings", settings)


func is_codex_unlocked(entry_id: String) -> bool:
	return unlocked_codex.has(entry_id)


func codex_total_entries() -> int:
	var total := 0
	var card_db := get_node_or_null("/root/CardDatabase")
	if card_db != null:
		total += int(card_db.call("all_cards").size())
	var enemy_db := get_node_or_null("/root/EnemyDatabase")
	if enemy_db != null:
		total += int(enemy_db.call("all_enemies").size())
	return total


func valid_codex_unlocked_count() -> int:
	var count := 0
	for entry_id in unlocked_codex.keys():
		if is_valid_codex_entry(str(entry_id)):
			count += 1
	return count


func valid_codex_learned_count() -> int:
	var count := 0
	for entry_id in learned_codex.keys():
		var id := str(entry_id)
		if unlocked_codex.has(id) and is_valid_codex_entry(id):
			count += 1
	return count


func codex_unlearned_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for entry_id in unlocked_codex.keys():
		var id := str(entry_id)
		if is_valid_codex_entry(id) and not learned_codex.has(id):
			ids.append(id)
	ids.sort()
	return ids


func codex_learning_summary() -> String:
	var unlocked: int = valid_codex_unlocked_count()
	var learned: int = valid_codex_learned_count()
	var total: int = maxi(1, codex_total_entries())
	var unlocked_percent: int = int(round(float(unlocked) * 100.0 / float(total)))
	return "图鉴学习：已研读 %d / %d  ·  图鉴完成 %d / %d（%d%%）" % [
		learned,
		unlocked,
		unlocked,
		total,
		unlocked_percent,
	]


func is_valid_codex_entry(entry_id: String) -> bool:
	if entry_id.begins_with("card."):
		var card_db := get_node_or_null("/root/CardDatabase")
		return card_db != null and bool(card_db.call("has_card", entry_id.substr(5)))
	if entry_id.begins_with("beast."):
		var enemy_db := get_node_or_null("/root/EnemyDatabase")
		return enemy_db != null and bool(enemy_db.call("has_enemy", entry_id.substr(6)))
	return false


func prune_invalid_codex_entries() -> int:
	var removed := 0
	for entry_id in unlocked_codex.keys():
		if not is_valid_codex_entry(str(entry_id)):
			unlocked_codex.erase(entry_id)
			removed += 1
	for entry_id in learned_codex.keys():
		var id := str(entry_id)
		if not unlocked_codex.has(id) or not is_valid_codex_entry(id):
			learned_codex.erase(id)
			removed += 1
	return removed


func get_codex_completion_ratio(total: int) -> float:
	if total <= 0:
		return 0.0
	return float(valid_codex_unlocked_count()) / float(total)


func character_defs() -> Array[Dictionary]:
	return CHARACTER_DEFS.duplicate(true)


func character_def(character_id: String) -> Dictionary:
	for def in CHARACTER_DEFS:
		if str(def.get("id", "")) == character_id:
			return def.duplicate(true)
	return {}


func is_character_unlocked(character_id: String) -> bool:
	return unlocked_characters.has(character_id)


func can_unlock_character(character_id: String) -> bool:
	var def := character_def(character_id)
	if def.is_empty() or is_character_unlocked(character_id):
		return false
	if fragments < int(def.get("cost", 0)):
		return false
	return valid_codex_unlocked_count() >= int(def.get("codex_required", 0))


func unlock_character(character_id: String) -> bool:
	if not can_unlock_character(character_id):
		return false
	var def := character_def(character_id)
	add_fragments(-int(def.get("cost", 0)))
	unlocked_characters.append(character_id)
	active_character_id = character_id
	characters_changed.emit()
	return true


func set_active_character(character_id: String) -> bool:
	if not is_character_unlocked(character_id):
		return false
	if character_def(character_id).is_empty():
		return false
	active_character_id = character_id
	characters_changed.emit()
	return true


func active_character_def() -> Dictionary:
	var def := character_def(active_character_id)
	if def.is_empty():
		return character_def(CHARACTER_FANG_XUN)
	return def


func bookmark_defs() -> Array[Dictionary]:
	return BOOKMARK_DEFS.duplicate(true)


func bookmark_def(bookmark_id: String) -> Dictionary:
	for def in BOOKMARK_DEFS:
		if str(def.get("id", "")) == bookmark_id:
			return def.duplicate(true)
	return {}


func is_bookmark_unlocked(bookmark_id: String) -> bool:
	return unlocked_bookmarks.has(bookmark_id)


func can_unlock_bookmark(bookmark_id: String) -> bool:
	var def := bookmark_def(bookmark_id)
	if def.is_empty() or is_bookmark_unlocked(bookmark_id):
		return false
	if fragments < int(def.get("cost", 0)):
		return false
	return valid_codex_unlocked_count() >= int(def.get("codex_required", 0))


func unlock_bookmark(bookmark_id: String) -> bool:
	if not can_unlock_bookmark(bookmark_id):
		return false
	var def := bookmark_def(bookmark_id)
	add_fragments(-int(def.get("cost", 0)))
	unlocked_bookmarks[bookmark_id] = true
	if active_bookmark_id == BOOKMARK_NONE:
		active_bookmark_id = bookmark_id
	bookmarks_changed.emit()
	return true


func set_active_bookmark(bookmark_id: String) -> bool:
	if bookmark_id == BOOKMARK_NONE:
		active_bookmark_id = BOOKMARK_NONE
		bookmarks_changed.emit()
		return true
	if not is_bookmark_unlocked(bookmark_id):
		return false
	active_bookmark_id = bookmark_id
	bookmarks_changed.emit()
	return true


func active_bookmark_def() -> Dictionary:
	if active_bookmark_id == BOOKMARK_NONE:
		return {}
	return bookmark_def(active_bookmark_id)


func ending_defs() -> Array[Dictionary]:
	return ENDING_DEFS.duplicate(true)


func ending_def(ending_id: String) -> Dictionary:
	for def in ENDING_DEFS:
		if str(def.get("id", "")) == ending_id:
			return def.duplicate(true)
	return {}


func ending_title(ending_id: String) -> String:
	var def := ending_def(ending_id)
	return str(def.get("title", ending_id)) if not def.is_empty() else ending_id


func ending_rank(ending_id: String) -> int:
	var def := ending_def(ending_id)
	return int(def.get("rank", 0)) if not def.is_empty() else 0


func evaluate_current_ending() -> Dictionary:
	var total: int = maxi(1, codex_total_entries())
	var unlocked: int = valid_codex_unlocked_count()
	var ratio: float = float(unlocked) / float(total)
	var run_state := get_node_or_null("/root/RunState")
	var guard_count := 0
	var companion_count := 0
	var practical_count := 0
	if run_state != null:
		guard_count = int(run_state.call("ending_marker_count", "guard"))
		companion_count = int(run_state.call("ending_marker_count", "companion"))
		practical_count = int(run_state.call("ending_marker_count", "practical"))
	var meaningful: int = guard_count + companion_count
	var ending_id := ENDING_CANXIANG
	if ratio >= 0.6 and meaningful >= 3:
		ending_id = ENDING_CHONGMING
	elif ratio >= 0.3 or meaningful >= 1:
		ending_id = ENDING_WUJING
	var def := ending_def(ending_id)
	return {
		"id": ending_id,
		"title": str(def.get("title", ending_id)),
		"rank": int(def.get("rank", 0)),
		"description": str(def.get("description", "")),
		"codex_unlocked": unlocked,
		"codex_total": total,
		"codex_ratio": ratio,
		"meaningful_markers": meaningful,
		"guard_markers": guard_count,
		"companion_markers": companion_count,
		"practical_markers": practical_count,
	}


func record_ending(ending_id: String) -> bool:
	if ending_def(ending_id).is_empty():
		return false
	seen_endings[ending_id] = true
	if best_ending_id == "" or ending_rank(ending_id) > ending_rank(best_ending_id):
		best_ending_id = ending_id
	endings_changed.emit()
	return true


func seen_ending_titles() -> PackedStringArray:
	var titles := PackedStringArray()
	for def in ENDING_DEFS:
		var ending_id := str(def.get("id", ""))
		if seen_endings.has(ending_id):
			titles.append(str(def.get("title", ending_id)))
	return titles


func endings_summary() -> String:
	var titles := seen_ending_titles()
	var best := "未见终局" if best_ending_id == "" else ending_title(best_ending_id)
	if titles.is_empty():
		return "终局收藏：未见终局"
	return "终局收藏：%d / %d  ·  最高：%s" % [titles.size(), ENDING_DEFS.size(), best]


## 序列化 / 反序列化
func to_dict() -> Dictionary:
	prune_invalid_codex_entries()
	ensure_settings_defaults()
	return {
		"unlocked_codex": unlocked_codex.keys(),
		"learned_codex": learned_codex.keys(),
		"fragments": fragments,
		"unlocked_characters": unlocked_characters.duplicate(),
		"active_character_id": active_character_id,
		"unlocked_bookmarks": unlocked_bookmarks.keys(),
		"active_bookmark_id": active_bookmark_id,
		"seen_endings": seen_endings.keys(),
		"best_ending_id": best_ending_id,
		"settings": settings.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	unlocked_codex.clear()
	learned_codex.clear()
	for k in data.get("unlocked_codex", []):
		var entry_id := str(k)
		if is_valid_codex_entry(entry_id):
			unlocked_codex[entry_id] = true
	for k in data.get("learned_codex", []):
		var entry_id := str(k)
		if unlocked_codex.has(entry_id) and is_valid_codex_entry(entry_id):
			learned_codex[entry_id] = true
	fragments = data.get("fragments", 0)
	var chars = data.get("unlocked_characters", [CHARACTER_FANG_XUN])
	unlocked_characters.clear()
	for c in chars:
		var char_id := str(c)
		if not character_def(char_id).is_empty() and not unlocked_characters.has(char_id):
			unlocked_characters.append(char_id)
	if not unlocked_characters.has(CHARACTER_FANG_XUN):
		unlocked_characters.append(CHARACTER_FANG_XUN)
	active_character_id = str(data.get("active_character_id", CHARACTER_FANG_XUN))
	if character_def(active_character_id).is_empty() or not unlocked_characters.has(active_character_id):
		active_character_id = CHARACTER_FANG_XUN
	unlocked_bookmarks.clear()
	for bookmark_id in data.get("unlocked_bookmarks", []):
		var bookmark_id_str := str(bookmark_id)
		if not bookmark_def(bookmark_id_str).is_empty():
			unlocked_bookmarks[bookmark_id_str] = true
	active_bookmark_id = str(data.get("active_bookmark_id", BOOKMARK_NONE))
	if active_bookmark_id != BOOKMARK_NONE and not unlocked_bookmarks.has(active_bookmark_id):
		active_bookmark_id = BOOKMARK_NONE
	seen_endings.clear()
	for ending_id in data.get("seen_endings", []):
		var ending_id_str := str(ending_id)
		if not ending_def(ending_id_str).is_empty():
			seen_endings[ending_id_str] = true
	best_ending_id = str(data.get("best_ending_id", ""))
	if ending_def(best_ending_id).is_empty():
		best_ending_id = ""
	for ending_id in seen_endings.keys():
		if best_ending_id == "" or ending_rank(str(ending_id)) > ending_rank(best_ending_id):
			best_ending_id = str(ending_id)
	var s = data.get("settings", null)
	settings = default_settings()
	if s is Dictionary:
		for key in s.keys():
			settings[key] = s[key]
	ensure_settings_defaults()
	_apply_runtime_settings()

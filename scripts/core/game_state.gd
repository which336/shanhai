## GameState: 全局玩家状态（Autoload 单例）
## 跨局保留的内容：已解锁图鉴、典籍碎片、解锁的角色、设置等
extends Node

signal codex_unlocked(entry_id: String)
signal fragments_changed(amount: int)


func _ready() -> void:
	_setup_cjk_font()
	# 全局快捷键：ESC 返回主菜单（在战斗等场景中很有用）
	process_mode = Node.PROCESS_MODE_ALWAYS


## 安装支持中文的系统字体作为全局回退，避免中文显示成方块
func _setup_cjk_font() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei",
		"PingFang SC", "Hiragino Sans GB",
		"Noto Sans CJK SC", "WenQuanYi Micro Hei",
		"SimHei", "SimSun", "Sans-Serif",
	])
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
			# 战斗场景按 ESC = 放弃这场战斗，回地图
			if path.ends_with("battle.tscn"):
				RunState.last_battle_won = false
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
var fragments: int = 0                  # 典籍碎片（meta 货币）
var unlocked_characters: Array[String] = ["fang_xun"]
var settings: Dictionary = {
	"locale": "zh_CN",
	"sfx_volume": 0.8,
	"bgm_volume": 0.6,
}


func unlock_codex(entry_id: String) -> bool:
	if entry_id == "" or unlocked_codex.has(entry_id):
		return false
	unlocked_codex[entry_id] = true
	codex_unlocked.emit(entry_id)
	return true


func add_fragments(amount: int) -> void:
	fragments = max(0, fragments + amount)
	fragments_changed.emit(fragments)


func is_codex_unlocked(entry_id: String) -> bool:
	return unlocked_codex.has(entry_id)


func get_codex_completion_ratio(total: int) -> float:
	if total <= 0:
		return 0.0
	return float(unlocked_codex.size()) / float(total)


## 序列化 / 反序列化
func to_dict() -> Dictionary:
	return {
		"unlocked_codex": unlocked_codex.keys(),
		"fragments": fragments,
		"unlocked_characters": unlocked_characters,
		"settings": settings,
	}


func from_dict(data: Dictionary) -> void:
	unlocked_codex.clear()
	for k in data.get("unlocked_codex", []):
		unlocked_codex[k] = true
	fragments = data.get("fragments", 0)
	var chars = data.get("unlocked_characters", ["fang_xun"])
	unlocked_characters.clear()
	for c in chars:
		unlocked_characters.append(c)
	var s = data.get("settings", null)
	if s is Dictionary:
		settings = s

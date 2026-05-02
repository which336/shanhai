## SaveSystem: 简易 JSON 存档（Autoload 单例）
## 只保存 GameState（meta 进度），不保存运行中的 RunState
extends Node

const SAVE_PATH: String = "user://save.json"
const SAVE_VERSION: int = 1


func save() -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"game_state": GameState.to_dict(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[SaveSystem] 无法写入存档：%s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	return true


func load_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		push_warning("[SaveSystem] 存档格式不正确")
		return false
	var version: int = data.get("version", 0)
	if version != SAVE_VERSION:
		push_warning("[SaveSystem] 存档版本不匹配 (saved=%d, current=%d)" % [version, SAVE_VERSION])
	GameState.from_dict(data.get("game_state", {}))
	return true


func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

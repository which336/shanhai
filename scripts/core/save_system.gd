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
	return load_from_text(text)


func load_from_text(text: String, warn: bool = true) -> bool:
	var data: Variant = JSON.parse_string(text)
	return _apply_payload(data, warn)


func _apply_payload(data: Variant, warn: bool = true) -> bool:
	if not (data is Dictionary):
		_warn(warn, "[SaveSystem] 存档格式不正确")
		return false
	var version: int = data.get("version", 0)
	if version != SAVE_VERSION:
		_warn(warn, "[SaveSystem] 存档版本不匹配 (saved=%d, current=%d)" % [version, SAVE_VERSION])
	var raw_game_state: Variant = data.get("game_state", {})
	if not (raw_game_state is Dictionary):
		_warn(warn, "[SaveSystem] 存档 game_state 格式不正确")
		return false
	GameState.from_dict(raw_game_state)
	return true


func _warn(enabled: bool, message: String) -> void:
	if enabled:
		push_warning(message)


func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

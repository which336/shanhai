## EventDatabase: 加载 data/events/echo_events.json
## 不挂 Autoload，由 map_scene 在生成时手动加载即可
class_name EventDatabase

const EVENTS_PATH: String = "res://data/events/echo_events.json"


static func load_all() -> Array:
	var f := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	if f == null:
		push_warning("[EventDatabase] 找不到事件文件：%s" % EVENTS_PATH)
		return []
	var text: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(text)
	if not (data is Array):
		push_warning("[EventDatabase] 事件 JSON 必须是数组")
		return []
	return data

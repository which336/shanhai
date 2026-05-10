## FinaleView: 忘川之心终局对话，只服务 v0.12 终局闭环。
extends Control

const STUDY_ROOM_SCENE: String = "res://scenes/meta/study_room.tscn"

@onready var _title: Label = $Root/Title
@onready var _metrics: Label = $Root/Metrics
@onready var _body: RichTextLabel = $Root/Body
@onready var _choices: VBoxContainer = $Root/Choices
@onready var _footer: Label = $Root/Footer

var _step: int = 0
var _ending: Dictionary = {}
var _recorded: bool = false


func _ready() -> void:
	_apply_style()
	_show_opening()
	AudioEngine.play_bgm("menu")


func _apply_style() -> void:
	_title.add_theme_font_size_override("font_size", 42)
	_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.48))
	_metrics.add_theme_font_size_override("font_size", 17)
	_metrics.add_theme_color_override("font_color", Color(0.78, 0.88, 0.9))
	_footer.add_theme_font_size_override("font_size", 15)
	_footer.add_theme_color_override("font_color", Color(0.66, 0.78, 0.82))
	_body.bbcode_enabled = true
	_body.add_theme_font_size_override("normal_font_size", 22)
	_body.add_theme_color_override("default_color", Color(0.92, 0.88, 0.75))
	_choices.add_theme_constant_override("separation", 10)
	_refresh_metrics()


func _refresh_metrics() -> void:
	var total: int = maxi(1, GameState.codex_total_entries())
	var unlocked: int = GameState.valid_codex_unlocked_count()
	var percent: int = int(round(float(unlocked) * 100.0 / float(total)))
	_metrics.text = "图鉴 %d / %d（%d%%）  ·  守护 %d  ·  陪伴 %d  ·  实用 %d" % [
		unlocked,
		total,
		percent,
		RunState.ending_marker_count(RunState.ENDING_MARKER_GUARD),
		RunState.ending_marker_count(RunState.ENDING_MARKER_COMPANION),
		RunState.ending_marker_count(RunState.ENDING_MARKER_PRACTICAL),
	]


func _show_opening() -> void:
	_step = 0
	_title.text = "忘川之心"
	_body.text = "[center][b]黑水无声，残卷浮起。[/b][/center]\n\n你走过五境，带回许多名字。雾中没有新的敌人，只有一句反复回来的问话：\n\n[b]“你记住它们，是为了胜利，还是为了让它们继续被看见？”[/b]"
	_footer.text = "终局不是战斗。这里会根据本局图鉴与事件伏笔判定结局。"
	_set_choices([
		{"label": "走近黑水", "callback": Callable(self, "_show_inquiry").bind(1, "")},
	])


func _show_inquiry(index: int, response: String) -> void:
	_step = index
	_refresh_metrics()
	var prefix := ""
	if response != "":
		prefix = "[color=#9fd8c8]%s[/color]\n\n" % response
	match index:
		1:
			_title.text = "第一问 · 名字"
			_body.text = prefix + "残卷展开，显出你唤醒过的异兽与卡牌。\n\n[b]“名字被写下时，是否也被理解？”[/b]"
			_footer.text = "回答不会改变主要结局，只决定忘川怎样回应你。"
			_set_choices([
				{"label": "把名字逐一读出", "response": "雾中有细小的光点应声亮起。"},
				{"label": "承认仍有许多空白", "response": "黑水没有责备，只把空白留在卷边。"},
				{"label": "说胜利也需要名字", "response": "残卷轻轻合拢，像是在衡量这句话的重量。"},
			])
		2:
			_title.text = "第二问 · 选择"
			_body.text = prefix + "事件的回声从水下浮上来：守护、陪伴、实用，各有痕迹。\n\n[b]“你伸手时，是为了得到，还是为了同行？”[/b]"
			_set_choices([
				{"label": "我曾选择守在它们身侧", "response": "守护的伏笔在水面连成一道浅桥。"},
				{"label": "我曾选择坐到天亮", "response": "陪伴的回声不响，却停留得最久。"},
				{"label": "我也需要活着走到这里", "response": "实用并不羞耻，雾只是问它是否遮住了理解。"},
			])
		3:
			_title.text = "第三问 · 山海"
			_body.text = prefix + "五境的颜色在黑水中归一，又慢慢分开。\n\n[b]“山海若再明，你准备把它带回哪里？”[/b]"
			_set_choices([
				{"label": "带回书房，留给下一次翻阅", "response": "祖父书房的灯影在水面出现。"},
				{"label": "带回人间，留在名字和纹样里", "response": "金色字迹从卷上飞散，落向看不见的街巷。"},
				{"label": "带回下一局，再确认一次", "response": "忘川之心沉默片刻，像是准许你重来。"},
			])
		_:
			_show_judgement(response)


func _show_judgement(response: String = "") -> void:
	_step = 4
	_refresh_metrics()
	_ending = GameState.evaluate_current_ending()
	if not _recorded:
		GameState.record_ending(str(_ending.get("id", "")))
		SaveSystem.save()
		_recorded = true
	var prefix := ""
	if response != "":
		prefix = "[color=#9fd8c8]%s[/color]\n\n" % response
	_title.text = "判定 · %s" % str(_ending.get("title", ""))
	_body.text = prefix + "[b]%s[/b]\n\n%s\n\n图鉴：%d / %d\n守护 + 陪伴：%d\n\n[b]判定说明：[/b]%s\n\n忘川之心不问你击败了多少敌人，只问有多少名字被重新放回光里。" % [
		str(_ending.get("title", "")),
		str(_ending.get("description", "")),
		int(_ending.get("codex_unlocked", 0)),
		int(_ending.get("codex_total", 0)),
		int(_ending.get("meaningful_markers", 0)),
		_judgement_explanation(_ending),
	]
	_footer.text = "结局已收入祖父书房。"
	_set_choices([
		{"label": "查看结局", "callback": Callable(self, "_show_ending")},
	])


func _show_ending() -> void:
	_step = 5
	var ending_id: String = str(_ending.get("id", ""))
	_title.text = str(_ending.get("title", "终局"))
	match ending_id:
		GameState.ENDING_CHONGMING:
			_body.text = "[center][b]山海重明[/b][/center]\n\n你带回的不只是胜利，还有足够多被认真读过的名字。黑水退去，残卷上的空白开始自行补全。\n\n祖父书房的门开着，灯仍亮着。下一次翻卷时，山海不再只是传说。"
		GameState.ENDING_WUJING:
			_body.text = "[center][b]五境净化[/b][/center]\n\n五境已净，雾退到更深处。你记住了一部分，也错过了一部分。\n\n这不是失败。书房会保留这次清明，等待你在下一趟旅程里补上更多名字。"
		_:
			_body.text = "[center][b]残响未明[/b][/center]\n\n五境归静，但黑水下仍有太多未被辨认的回声。你抵达了终点，却还没有足够理解它们。\n\n祖父书房仍会接住这次旅程。遗忘没有被消灭，只是被你暂时照见。"
	_footer.text = GameState.endings_summary()
	_set_choices([
		{"label": "回到祖父书房", "callback": Callable(self, "_finish")},
	])


func _judgement_explanation(ending: Dictionary) -> String:
	var ending_id: String = str(ending.get("id", ""))
	var total: int = maxi(1, int(ending.get("codex_total", GameState.codex_total_entries())))
	var unlocked: int = int(ending.get("codex_unlocked", GameState.valid_codex_unlocked_count()))
	var meaningful: int = int(ending.get("meaningful_markers", 0))
	var true_codex_need: int = maxi(0, int(ceil(float(total) * 0.6)) - unlocked)
	var true_marker_need: int = maxi(0, 3 - meaningful)
	var mid_codex_need: int = maxi(0, int(ceil(float(total) * 0.3)) - unlocked)
	match ending_id:
		GameState.ENDING_CHONGMING:
			return "图鉴达到 60%%，且守护 + 陪伴达到 3 次，因此进入「山海重明」。"
		GameState.ENDING_WUJING:
			if true_codex_need <= 0 and true_marker_need > 0:
				return "图鉴已达到真结局要求；还需要守护/陪伴 %d 次，才能进入「山海重明」。" % true_marker_need
			if true_codex_need > 0 and true_marker_need <= 0:
				return "守护 + 陪伴已达到真结局要求；还需要有效图鉴 %d 条，才能进入「山海重明」。" % true_codex_need
			return "已达到「五境净化」；还需要有效图鉴 %d 条、守护/陪伴 %d 次，才能进入「山海重明」。" % [true_codex_need, true_marker_need]
		_:
			return "尚未达到「五境净化」。还需要有效图鉴 %d 条，或至少 1 次守护/陪伴伏笔。" % mid_codex_need


func _set_choices(items: Array) -> void:
	for child in _choices.get_children():
		child.queue_free()
	for item in items:
		var button := Button.new()
		button.text = str(item.get("label", "继续"))
		button.custom_minimum_size = Vector2(420, 48)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 19)
		button.add_theme_color_override("font_color", Color(0.96, 0.88, 0.64))
		button.add_theme_stylebox_override("normal", _button_style(Color(0.06, 0.12, 0.13, 0.88), Color(0.74, 0.58, 0.32, 0.72)))
		button.add_theme_stylebox_override("hover", _button_style(Color(0.08, 0.18, 0.18, 0.94), Color(0.95, 0.78, 0.42, 0.92)))
		button.add_theme_stylebox_override("pressed", _button_style(Color(0.03, 0.08, 0.09, 0.96), Color(0.98, 0.88, 0.48, 1.0)))
		if item.has("callback"):
			button.pressed.connect(item["callback"])
		else:
			button.pressed.connect(_show_inquiry.bind(_step + 1, str(item.get("response", ""))))
		_choices.add_child(button)


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style


func _finish() -> void:
	RunState.reset_for_new_run(GameState.active_character_id)
	get_tree().change_scene_to_file(STUDY_ROOM_SCENE)

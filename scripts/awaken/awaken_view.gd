## AwakenView: 战胜后弹出的"唤醒"小游戏
## 给出山海经原文 + 4 段译文，玩家选最贴合原文的那段
## 选对 → 加唤醒卡到本局卡组；选错 → 加通用奖励卡
class_name AwakenView extends Control

signal closed()

const REWARD_CARD_WHEN_WRONG: String = "neutral.scroll_study"

var _data: EnemyData = null
var _awaken_card: Card = null
var _consolation_card: Card = null

var _option_buttons: Array[Button] = []
var _option_labels: Array[Label] = []

@onready var _title: Label = $Panel/V/Title
@onready var _quote: RichTextLabel = $Panel/V/Quote
@onready var _hint: Label = $Panel/V/Hint
@onready var _options_box: VBoxContainer = $Panel/V/Options
@onready var _result: RichTextLabel = $Panel/V/Result
@onready var _close_btn: Button = $Panel/V/CloseButton


func setup(d: EnemyData) -> void:
	_data = d
	_awaken_card = CardDatabase.get_card(d.awaken_card_id)
	_consolation_card = CardDatabase.get_card(REWARD_CARD_WHEN_WRONG)
	if not is_node_ready():
		await ready
	_title.text = "唤醒  ·  %s" % d.display_name
	_quote.clear()
	_quote.append_text("[i][color=#9bd]%s[/color][/i]" % d.classic_quote)
	_hint.text = "下面 4 段白话，哪一段最贴合原文？"
	_result.visible = false
	_close_btn.visible = false
	_close_btn.pressed.connect(_on_close)
	_build_options()


func _build_options() -> void:
	_option_buttons.clear()
	_option_labels.clear()
	for c in _options_box.get_children():
		c.queue_free()
	var letters := ["A", "B", "C", "D", "E", "F"]
	for i in _data.awaken_options.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var btn := Button.new()
		btn.text = letters[i] if i < letters.size() else str(i + 1)
		btn.custom_minimum_size = Vector2(48, 40)
		btn.pressed.connect(_on_option_chosen.bind(i))
		var lbl := Label.new()
		lbl.text = _data.awaken_options[i]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(btn)
		row.add_child(lbl)
		_options_box.add_child(row)
		_option_buttons.append(btn)
		_option_labels.append(lbl)


func _on_option_chosen(idx: int) -> void:
	# 禁用所有按钮
	for b in _option_buttons:
		b.disabled = true
	_result.visible = true
	_result.clear()
	if idx == _data.awaken_correct_index:
		_result.append_text("[b][color=#9ec97a]你读懂了它。[/color][/b]\n\n")
		_result.append_text("[i]%s[/i] 回归本性，化为同伴。\n" % _data.display_name)
		if _awaken_card != null:
			RunState.add_card_to_deck(_awaken_card)
			GameState.unlock_codex("card." + _awaken_card.id)
			_result.append_text("\n[b]卡组中加入：[/b][color=#e6c97a]%s[/color]" % _awaken_card.title)
		GameState.add_fragments(15)
	else:
		_result.append_text("[b][color=#aaa]你净化了它，却没能真正读懂它。[/color][/b]\n\n")
		_result.append_text("[i]%s[/i] 灵韵散去。\n" % _data.display_name)
		if _consolation_card != null:
			RunState.add_card_to_deck(_consolation_card)
			_result.append_text("\n[b]卡组中加入：[/b][color=#bbb]%s[/color]（通用补偿）" % _consolation_card.title)
		GameState.add_fragments(5)
	# 标出对错配色
	for i in _option_labels.size():
		if i == _data.awaken_correct_index:
			_option_labels[i].add_theme_color_override("font_color", Color(0.65, 0.9, 0.5))
		elif i == idx:
			_option_labels[i].add_theme_color_override("font_color", Color(0.9, 0.55, 0.55))
	_close_btn.visible = true
	GameState.unlock_codex("beast." + _data.id)
	SaveSystem.save()


func _on_close() -> void:
	closed.emit()

## CardView: 一张卡牌的可视化（占位 UI，纯 Control + Label）
## 后续可以替换成图片 + 美术框，不影响外部接口
class_name CardView extends PanelContainer

signal play_requested(card_view)

var card: Card = null
var hand_index: int = -1

@onready var _title: Label = $V/Title
@onready var _cost: Label = $V/Header/Cost
@onready var _school: Label = $V/Header/School
@onready var _description: Label = $V/Description
@onready var _quote: Label = $V/Quote


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_set_descendant_mouse_filter_ignore(self)


func _set_descendant_mouse_filter_ignore(root: Node) -> void:
	for child in root.get_children():
		if child is Control:
			var control: Control = child
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_descendant_mouse_filter_ignore(child)


func setup(c: Card, idx: int = -1) -> void:
	card = c
	hand_index = idx
	if not is_node_ready():
		await ready
	_title.text = c.title
	_cost.text = "费 %d" % c.cost
	_school.text = c.get_school_name()
	_description.text = _make_card_summary(c.get_resolved_description(), 34)
	# 卡面只显示极短引文，完整原文进图鉴看；短摘要可避免导出后字体差异造成溢出。
	var snippet: String = _make_card_summary(c.classic_quote, 10)
	if snippet != "":
		_quote.text = "「%s」" % snippet
	else:
		_quote.text = ""
	# 流派配色（背景边框）
	var color := Color(0.85, 0.85, 0.85)
	match c.school:
		Card.School.SHAN:
			color = Color(0.55, 0.78, 0.5)
		Card.School.HAI:
			color = Color(0.45, 0.7, 0.95)
		Card.School.HUANG:
			color = Color(0.95, 0.55, 0.45)
		_:
			color = Color(0.85, 0.78, 0.55)
	self.modulate = color


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		play_requested.emit(self)
		accept_event()


func _make_card_summary(text: String, max_chars: int) -> String:
	var summary := text.strip_edges()
	summary = summary.replace("\r\n", " ")
	summary = summary.replace("\n", " ")
	summary = summary.replace("\t", " ")
	while summary.contains("  "):
		summary = summary.replace("  ", " ")
	if summary.length() <= max_chars:
		return summary
	return summary.substr(0, max_chars - 1) + "…"

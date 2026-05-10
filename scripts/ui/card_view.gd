## CardView: shared visual card frame for battle, rewards, shops, and codex previews.
class_name CardView extends PanelContainer

signal play_requested(card_view)

const CARD_FRAME_TEXTURE: Texture2D = preload("res://assets/textures/backgrounds/card_frame.png")
const FAN_COLLAPSED_SIZE: Vector2 = Vector2(126, 168)
const FAN_EXPANDED_SIZE: Vector2 = Vector2(156, 214)
const EXPANDED_DESCRIPTION_MAX_CHARS: int = 30

var card: Card = null
var hand_index: int = -1
var _hovered: bool = false
var _accent: Color = Color(0.85, 0.78, 0.55)
var _base_bg: Color = Color(0.18, 0.145, 0.09, 0.84)
var _rarity_accent: Color = Color(0.48, 0.33, 0.16, 0.95)
var _rarity_glow: Color = Color(0.18, 0.12, 0.06, 0.1)

@onready var _title: Label = $V/Title
@onready var _cost: Label = $V/Header/Cost
@onready var _school: Label = $V/Header/School
@onready var _keywords: Label = $V/Keywords
@onready var _description: Label = $V/Description
@onready var _quote: Label = $V/Quote


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	_quote.text = ""
	_quote.visible = false
	_quote.custom_minimum_size = Vector2.ZERO
	_set_descendant_mouse_filter_ignore(self)
	mouse_entered.connect(func() -> void:
		_hovered = true
		_apply_style()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		_apply_style()
	)


func _set_descendant_mouse_filter_ignore(root: Node) -> void:
	for child in root.get_children():
		if child is Control:
			var control: Control = child
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_descendant_mouse_filter_ignore(child)


func setup(c: Card, idx: int = -1, display_cost: int = -1) -> void:
	card = c
	hand_index = idx
	if not is_node_ready():
		await ready
	_title.text = c.title
	var shown_cost: int = c.cost if display_cost < 0 else display_cost
	_cost.text = "费 %d" % shown_cost
	if shown_cost < c.cost:
		_cost.text = "费 %d→%d" % [c.cost, shown_cost]
	_school.text = "%s · %s · %s" % [_school_mark(c), _card_type_short(c), _rarity_name(c)]
	_keywords.text = c.get_keywords_text(" · ")
	_keywords.visible = _keywords.text != ""
	_description.text = _make_card_summary(c.get_resolved_description(), EXPANDED_DESCRIPTION_MAX_CHARS)
	_quote.text = ""
	_quote.visible = false
	_quote.custom_minimum_size = Vector2.ZERO
	_accent = _school_accent(c)
	_base_bg = _school_background(c)
	_rarity_accent = _rarity_border(c)
	_rarity_glow = _rarity_glow_color(c)
	set_process(c.rarity == Card.Rarity.MYTHIC or c.rarity == Card.Rarity.RELIC)
	_apply_style()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	draw_rect(rect, _base_bg)
	draw_texture_rect(CARD_FRAME_TEXTURE, rect, false, Color(1, 1, 1, 0.82))
	_draw_school_wash(rect)
	_draw_rarity_effect(rect)


func _draw_school_wash(rect: Rect2) -> void:
	var inset := maxf(8.0, rect.size.x * 0.07)
	var body := rect.grow(-inset)
	body.position.y += rect.size.y * 0.09
	body.size.y -= rect.size.y * 0.16
	draw_rect(body, _base_bg.lightened(0.18), true)
	draw_rect(body, Color(0.02, 0.018, 0.012, 0.22), false, 1.0)
	var band_h := maxf(24.0, rect.size.y * 0.17)
	draw_rect(Rect2(Vector2(inset, inset), Vector2(rect.size.x - inset * 2.0, band_h)), _base_bg.darkened(0.08), true)


func _draw_rarity_effect(rect: Rect2) -> void:
	var border_width := 3.0 if _hovered else 2.0
	var border_rect := rect.grow(-3.0)
	match card.rarity if card != null else Card.Rarity.COMMON:
		Card.Rarity.COMMON:
			draw_rect(border_rect, _rarity_accent, false, border_width)
			draw_rect(border_rect.grow(-3.0), Color(0.32, 0.2, 0.09, 0.32), false, 1.0)
		Card.Rarity.RARE:
			draw_rect(border_rect, _rarity_accent, false, border_width)
			draw_rect(border_rect.grow(-3.0), Color(1.0, 0.92, 0.58, 0.26 if _hovered else 0.16), false, 1.0)
			draw_line(Vector2(rect.size.x * 0.18, 5.0), Vector2(rect.size.x * 0.82, 5.0), Color(1.0, 0.95, 0.68, 0.45), 1.0)
		Card.Rarity.MYTHIC:
			var t := Time.get_ticks_msec() / 1000.0
			for i in 4:
				var hue := fposmod(t * 0.11 + float(i) * 0.18, 1.0)
				draw_rect(border_rect.grow(-float(i) * 2.0), Color.from_hsv(hue, 0.46, 1.0, 0.72 - float(i) * 0.12), false, 1.0)
			_draw_sweeping_glint(rect, Color(0.8, 1.0, 0.95, 0.34))
		Card.Rarity.RELIC:
			draw_rect(border_rect, _rarity_accent, false, border_width)
			draw_rect(border_rect.grow(-4.0), Color(0.72, 0.42, 1.0, 0.34), false, 1.0)
			_draw_sweeping_glint(rect, Color(0.78, 0.48, 1.0, 0.28))


func _draw_sweeping_glint(rect: Rect2, color: Color) -> void:
	var t := fposmod(Time.get_ticks_msec() / 1300.0, 1.0)
	var x := lerpf(-rect.size.x * 0.35, rect.size.x * 1.1, t)
	draw_line(Vector2(x, 4.0), Vector2(x + rect.size.x * 0.34, rect.size.y - 4.0), color, 2.0)
	draw_line(Vector2(x + 8.0, 4.0), Vector2(x + rect.size.x * 0.34 + 8.0, rect.size.y - 4.0), Color(color.r, color.g, color.b, color.a * 0.45), 1.0)


func _school_accent(c: Card) -> Color:
	match c.school:
		Card.School.SHAN:
			return Color(0.58, 0.92, 0.55)
		Card.School.HAI:
			return Color(0.43, 0.82, 1.0)
		Card.School.HUANG:
			return Color(1.0, 0.52, 0.4)
		_:
			return Color(0.92, 0.82, 0.48)


func _school_background(c: Card) -> Color:
	match c.school:
		Card.School.SHAN:
			return Color(0.04, 0.18, 0.115, 0.86)
		Card.School.HAI:
			return Color(0.035, 0.15, 0.22, 0.86)
		Card.School.HUANG:
			return Color(0.22, 0.055, 0.045, 0.86)
		_:
			return Color(0.18, 0.145, 0.09, 0.84)


func _rarity_border(c: Card) -> Color:
	match c.rarity:
		Card.Rarity.RARE:
			return Color(1.0, 0.78, 0.32, 0.95)
		Card.Rarity.MYTHIC:
			return Color(0.62, 0.94, 1.0, 0.95)
		Card.Rarity.RELIC:
			return Color(0.72, 0.42, 1.0, 0.95)
		_:
			return Color(0.48, 0.33, 0.16, 0.95)


func _rarity_glow_color(c: Card) -> Color:
	match c.rarity:
		Card.Rarity.RARE:
			return Color(1.0, 0.78, 0.32, 0.18)
		Card.Rarity.MYTHIC:
			return Color(0.62, 0.94, 1.0, 0.28)
		Card.Rarity.RELIC:
			return Color(0.72, 0.42, 1.0, 0.28)
		_:
			return Color(0.18, 0.12, 0.06, 0.1)


func _school_mark(c: Card) -> String:
	match c.school:
		Card.School.SHAN:
			return "山"
		Card.School.HAI:
			return "海"
		Card.School.HUANG:
			return "荒"
		_:
			return "通"


func _rarity_name(c: Card) -> String:
	match c.rarity:
		Card.Rarity.RARE:
			return "珍品"
		Card.Rarity.MYTHIC:
			return "神品"
		Card.Rarity.RELIC:
			return "遗珍"
		_:
			return "凡品"


func _card_type_short(c: Card) -> String:
	match c.card_type:
		Card.CardType.ATTACK:
			return "攻"
		Card.CardType.SKILL:
			return "技"
		Card.CardType.POWER:
			return "力"
	return "牌"


func _apply_style() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0, 0, 0, 0)
	panel.border_color = Color(0, 0, 0, 0)
	panel.set_border_width_all(0)
	panel.set_corner_radius_all(3)
	panel.shadow_color = _rarity_glow if _hovered else Color(0.0, 0.0, 0.0, 0.36)
	panel.shadow_size = 8 if _hovered else 4
	panel.content_margin_left = 13
	panel.content_margin_right = 13
	panel.content_margin_top = 10
	panel.content_margin_bottom = 10
	add_theme_stylebox_override("panel", panel)
	_title.add_theme_color_override("font_color", _accent.lightened(0.32))
	_cost.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62))
	_school.add_theme_color_override("font_color", _accent.lightened(0.1))
	_keywords.add_theme_color_override("font_color", _accent.lightened(0.24))
	_description.add_theme_color_override("font_color", Color(0.95, 0.9, 0.76))
	_quote.add_theme_color_override("font_color", Color(0.78, 0.72, 0.52))
	queue_redraw()


func set_fan_expanded(expanded: bool) -> void:
	custom_minimum_size = FAN_EXPANDED_SIZE if expanded else FAN_COLLAPSED_SIZE
	size = custom_minimum_size
	_description.visible = expanded
	_quote.text = ""
	_quote.visible = false
	_quote.custom_minimum_size = Vector2.ZERO
	_title.add_theme_font_size_override("font_size", 15 if expanded else 13)
	_cost.add_theme_font_size_override("font_size", 12 if expanded else 11)
	_school.add_theme_font_size_override("font_size", 12 if expanded else 10)
	_keywords.add_theme_font_size_override("font_size", 12 if expanded else 10)
	_description.add_theme_font_size_override("font_size", 12 if expanded else 11)
	_quote.add_theme_font_size_override("font_size", 10 if expanded else 9)
	queue_redraw()


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


func _is_dense_description() -> bool:
	return str(_description.text).length() >= EXPANDED_DESCRIPTION_MAX_CHARS - 2

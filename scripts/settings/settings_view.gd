## SettingsView: v0.13 小范围外测设置页。
extends Control

const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"

var _bgm_slider: HSlider = null
var _sfx_slider: HSlider = null
var _fullscreen_check: CheckBox = null
var _dev_tools_check: CheckBox = null
var _message: Label = null
var _dirty: bool = false


func _ready() -> void:
	GameState.ensure_settings_defaults()
	_build_ui()
	_load_values()
	AudioEngine.play_bgm("menu")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_back()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.018, 0.027, 0.032, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := VBoxContainer.new()
	panel.name = "SettingsPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -360
	panel.offset_top = -250
	panel.offset_right = 360
	panel.offset_bottom = 250
	panel.add_theme_constant_override("separation", 16)
	add_child(panel)

	var title := Label.new()
	title.name = "Title"
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	panel.add_child(title)

	_bgm_slider = _add_slider_row(panel, "BGM 音量", "BgmSlider")
	_bgm_slider.value_changed.connect(_on_bgm_changed)
	_sfx_slider = _add_slider_row(panel, "SFX 音量", "SfxSlider")
	_sfx_slider.value_changed.connect(_on_sfx_changed)

	_fullscreen_check = CheckBox.new()
	_fullscreen_check.name = "FullscreenCheck"
	_fullscreen_check.text = "全屏显示"
	_style_check(_fullscreen_check)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	panel.add_child(_fullscreen_check)

	_dev_tools_check = CheckBox.new()
	_dev_tools_check.name = "DevToolsCheck"
	_dev_tools_check.text = "显示开发工具（跳关 / 全图鉴解锁）"
	_style_check(_dev_tools_check)
	_dev_tools_check.toggled.connect(_on_dev_tools_toggled)
	panel.add_child(_dev_tools_check)

	_message = Label.new()
	_message.name = "Message"
	_message.text = "设置会立即生效；返回或应用时保存。"
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 16)
	_message.add_theme_color_override("font_color", Color(0.76, 0.86, 0.82))
	panel.add_child(_message)

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	panel.add_child(actions)

	var apply_btn := _make_button("应用")
	apply_btn.name = "ApplyButton"
	apply_btn.pressed.connect(_on_apply)
	actions.add_child(apply_btn)

	var back_btn := _make_button("返回主菜单")
	back_btn.name = "BackButton"
	back_btn.pressed.connect(_on_back)
	actions.add_child(back_btn)


func _add_slider_row(parent: VBoxContainer, label_text: String, slider_name: String) -> HSlider:
	var row := HBoxContainer.new()
	row.name = "%sRow" % slider_name
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(130, 32)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.93, 0.88, 0.72))
	row.add_child(label)

	var slider := HSlider.new()
	slider.name = slider_name
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(420, 32)
	row.add_child(slider)
	return slider


func _load_values() -> void:
	_bgm_slider.value = float(GameState.setting_value("bgm_volume", 0.6))
	_sfx_slider.value = float(GameState.setting_value("sfx_volume", 0.8))
	_fullscreen_check.button_pressed = bool(GameState.setting_value("fullscreen", false))
	_dev_tools_check.button_pressed = bool(GameState.setting_value("show_dev_tools", false))
	_dirty = false


func _on_bgm_changed(value: float) -> void:
	GameState.set_setting_value("bgm_volume", value, false)
	_mark_dirty()


func _on_sfx_changed(value: float) -> void:
	GameState.set_setting_value("sfx_volume", value, false)
	_mark_dirty()


func _on_fullscreen_toggled(enabled: bool) -> void:
	GameState.set_setting_value("fullscreen", enabled, false)
	_mark_dirty()


func _on_dev_tools_toggled(enabled: bool) -> void:
	GameState.set_setting_value("show_dev_tools", enabled, false)
	_mark_dirty()


func _mark_dirty() -> void:
	_dirty = true
	if _message != null:
		_message.text = "设置已生效，返回或应用时保存。"


func _on_apply() -> void:
	AudioEngine.play_sfx("click")
	SaveSystem.save()
	_dirty = false
	_message.text = "设置已保存。"


func _on_back() -> void:
	AudioEngine.play_sfx("click")
	if _dirty:
		SaveSystem.save()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _style_check(check: CheckBox) -> void:
	check.focus_mode = Control.FOCUS_NONE
	check.add_theme_font_size_override("font_size", 18)
	check.add_theme_color_override("font_color", Color(0.93, 0.88, 0.72))
	check.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.72))


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 42)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.96, 0.88, 0.64))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.04, 0.08, 0.09, 0.88), Color(0.74, 0.58, 0.32, 0.72)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.07, 0.14, 0.14, 0.94), Color(0.95, 0.78, 0.42, 0.92)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.03, 0.08, 0.09, 0.96), Color(0.98, 0.88, 0.48, 1.0)))
	return button


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

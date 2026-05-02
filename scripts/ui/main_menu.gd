## MainMenu: 主菜单
## MVP 仅有「开始冒险」「山海图鉴」「退出」
extends Control

@onready var _start_btn: Button = $V/StartButton
@onready var _codex_btn: Button = $V/CodexButton
@onready var _quit_btn: Button = $V/QuitButton
@onready var _info_label: Label = $V/Info


func _ready() -> void:
	_start_btn.pressed.connect(_on_start)
	_codex_btn.pressed.connect(_on_codex)
	_quit_btn.pressed.connect(_on_quit)

	# 加载存档（如果有）
	SaveSystem.load_save()
	_refresh_info()
	AudioEngine.play_bgm("menu")


func _refresh_info() -> void:
	var unlocked: int = GameState.unlocked_codex.size()
	var total: int = max(1, CardDatabase.all_cards().size())
	_info_label.text = "山海图鉴：%d / %d  ·  典籍碎片：%d" % [unlocked, total, GameState.fragments]


func _on_start() -> void:
	AudioEngine.play_sfx("click")
	RunState.reset_for_new_run("fang_xun")
	# 显式生成新随机种子，让每次冒险地图布局都不同
	randomize()
	RunState.seed_value = randi()
	RunState.map_data = {}
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")


func _on_codex() -> void:
	AudioEngine.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/codex/codex.tscn")


func _on_quit() -> void:
	AudioEngine.play_sfx("click")
	get_tree().quit()

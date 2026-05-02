## CodexView: 山海图鉴查看界面（MVP 极简版）
## 从 CardDatabase 把所有卡列出来，已解锁的可看原文/译注/今日存续
extends Control

@onready var _list: VBoxContainer = $H/Scroll/List
@onready var _detail: RichTextLabel = $H/Detail
@onready var _back_btn: Button = $BackButton

var _is_returning: bool = false


func _ready() -> void:
	_back_btn.pressed.connect(_on_back)
	_build_list()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_K:
			var viewport: Viewport = get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
			_on_back()


func _build_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var cards: Array = CardDatabase.all_cards()
	cards.sort_custom(func(a, b): return a.school < b.school or (a.school == b.school and a.id < b.id))
	for c in cards:
		if not (c is Card):
			continue
		var btn := Button.new()
		var unlocked: bool = GameState.is_codex_unlocked("card." + c.id)
		btn.text = "%s · %s%s" % [c.get_school_name(), c.title, "" if unlocked else "  （未解锁）"]
		btn.pressed.connect(_show_detail.bind(c, unlocked))
		_list.add_child(btn)
	if cards.is_empty():
		_detail.text = "尚未加载到任何卡牌资源（请检查 data/cards/ 目录）"
	else:
		_show_detail(cards[0], GameState.is_codex_unlocked("card." + cards[0].id))


func _show_detail(card: Card, unlocked: bool) -> void:
	if not unlocked:
		_detail.clear()
		_detail.append_text("[b]%s · %s[/b]\n\n" % [card.get_school_name(), card.title])
		_detail.append_text("[i]——尚未在冒险中遇见，原文已被忘川之雾遮蔽。[/i]\n")
		return
	_detail.clear()
	_detail.append_text("[b][color=#e6c97a]%s[/color][/b]  [color=#888](%s · %s)[/color]\n" % [card.title, card.get_school_name(), card.get_rarity_name()])
	_detail.append_text("[color=#aaa]费用 %d  · 类型 %s[/color]\n\n" % [card.cost, _type_name(card.card_type)])
	_detail.append_text("[b]玩法：[/b]%s\n\n" % card.get_resolved_description())
	if card.classic_quote != "":
		_detail.append_text("[b][color=#9bd]山海经原文：[/color][/b]\n[i]%s[/i]\n\n" % card.classic_quote)
	if card.translation != "":
		_detail.append_text("[b][color=#9bd]白话译注：[/color][/b]\n%s\n\n" % card.translation)
	if card.alive_today != "":
		_detail.append_text("[b][color=#cd9]今天活在哪里：[/color][/b]\n%s\n" % card.alive_today)


func _type_name(t: int) -> String:
	match t:
		Card.CardType.ATTACK: return "攻击"
		Card.CardType.SKILL: return "法术"
		Card.CardType.POWER: return "持续"
	return "未知"


func _on_back() -> void:
	if _is_returning:
		return
	_is_returning = true
	if RunState.return_after_codex != "":
		var dest: String = RunState.return_after_codex
		RunState.return_after_codex = ""
		get_tree().change_scene_to_file(dest)
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

## CodexView: 山海图鉴查看界面
## 列出卡牌与异兽，已解锁条目可看原文、译注和唤醒信息。
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
	var card_section := Button.new()
	card_section.text = "—— 卡牌 ——"
	card_section.disabled = true
	_list.add_child(card_section)
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
	var beast_section := Button.new()
	beast_section.text = "—— 异兽 / 神祇 ——"
	beast_section.disabled = true
	_list.add_child(beast_section)
	var enemies: Array = EnemyDatabase.all_enemies()
	enemies.sort_custom(func(a, b): return _enemy_sort_key(a) < _enemy_sort_key(b))
	for e in enemies:
		if not (e is EnemyData):
			continue
		var btn := Button.new()
		var unlocked: bool = GameState.is_codex_unlocked("beast." + e.id)
		btn.text = "%s · %s%s" % [_enemy_type_name(e), e.display_name, "" if unlocked else "  （未解锁）"]
		btn.pressed.connect(_show_enemy_detail.bind(e, unlocked))
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


func _show_enemy_detail(enemy: EnemyData, unlocked: bool) -> void:
	if not unlocked:
		_detail.clear()
		_detail.append_text("[b]%s · %s[/b]\n\n" % [_enemy_type_name(enemy), enemy.display_name])
		_detail.append_text("[i]——尚未在冒险中击败或唤醒，形貌仍被忘川之雾遮蔽。[/i]\n")
		return
	_detail.clear()
	_detail.append_text("[b][color=#e6c97a]%s[/color][/b]  [color=#888](%s)[/color]\n" % [enemy.display_name, _enemy_type_name(enemy)])
	_detail.append_text("[color=#aaa]气血 %d  · 行动循环 %d 段[/color]\n\n" % [enemy.max_hp, enemy.intent_pattern.size()])
	if enemy.classic_quote != "":
		_detail.append_text("[b][color=#9bd]山海经原文：[/color][/b]\n[i]%s[/i]\n\n" % enemy.classic_quote)
	if enemy.translation != "":
		_detail.append_text("[b][color=#9bd]白话译注：[/color][/b]\n%s\n\n" % enemy.translation)
	if not enemy.awaken_options.is_empty():
		_detail.append_text("[b][color=#cd9]唤醒问答：[/color][/b]\n")
		for i in enemy.awaken_options.size():
			var mark: String = "✓ " if i == enemy.awaken_correct_index else "  "
			_detail.append_text("%s%s\n" % [mark, enemy.awaken_options[i]])
	if enemy.awaken_card_id != "":
		var card: Card = CardDatabase.get_card(enemy.awaken_card_id)
		var title: String = card.title if card != null else enemy.awaken_card_id
		_detail.append_text("\n[b]唤醒奖励：[/b]《%s》\n" % title)


func _type_name(t: int) -> String:
	match t:
		Card.CardType.ATTACK: return "攻击"
		Card.CardType.SKILL: return "法术"
		Card.CardType.POWER: return "持续"
	return "未知"


func _enemy_type_name(enemy: EnemyData) -> String:
	if enemy.is_boss:
		return "Boss"
	if enemy.is_elite:
		return "精英"
	return "异兽"


func _enemy_sort_key(enemy: EnemyData) -> String:
	var prefix: String = "1"
	if enemy.is_boss:
		prefix = "3"
	elif enemy.is_elite:
		prefix = "2"
	return "%s.%s" % [prefix, enemy.id]


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

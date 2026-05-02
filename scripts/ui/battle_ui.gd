## BattleUI: 把 BattleManager 的状态绑到屏幕上
## 包含：玩家 HP、灵韵、护盾、手牌、敌人状态、日志、结束回合按钮
extends Control

const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/battle/card_view.tscn")
const AWAKEN_SCENE: PackedScene = preload("res://scenes/awaken/awaken.tscn")

@onready var _battle: Node2D = get_node("../Battle")
@onready var _hp: Label = $TopBar/HP
@onready var _energy: Label = $TopBar/Energy
@onready var _block: Label = $TopBar/Block
@onready var _turn: Label = $TopBar/Turn
@onready var _hand: Container = $HandArea
@onready var _enemies_panel: VBoxContainer = $EnemiesPanel
@onready var _log: RichTextLabel = $LogArea
@onready var _end_turn_btn: Button = $EndTurnButton
@onready var _back_btn: Button = $BackButton
@onready var _result_panel: PanelContainer = $ResultPanel
@onready var _result_label: Label = $ResultPanel/V/ResultLabel
@onready var _result_button: Button = $ResultPanel/V/ResultButton

var _selected_enemy: BattleEnemy = null
var _last_play_time_ms: int = 0     # 防止快速重建 UI 时同一鼠标按下事件触发多次出牌
const PLAY_CLICK_THROTTLE_MS: int = 80


func _ready() -> void:
	z_index = 100
	# 兜底：用代码固定关键 UI 区域，避免手写 .tscn 的布局属性在不同窗口/DPI 下失效。
	_fix_runtime_layout()
	# 初始隐藏结果面板
	_result_panel.visible = false
	# 绑信号
	_battle.battle_started.connect(_on_battle_started)
	_battle.turn_changed.connect(_on_turn_changed)
	_battle.battle_won.connect(_on_battle_won)
	_battle.battle_lost.connect(_on_battle_lost)
	_battle.log_message.connect(_append_log)
	_battle.card_played.connect(_on_card_played)

	RunState.hp_changed.connect(_on_hp_changed)
	RunState.energy_changed.connect(_on_energy_changed)
	_battle.player.block_changed.connect(_on_block_changed)

	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	_back_btn.pressed.connect(_on_back_pressed)
	_result_button.pressed.connect(_on_result_button)

	_refresh_top()
	_rebuild_enemy_list()
	_refresh_hand()
	_refresh_top()
	_wait_for_battle_ready()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_fix_runtime_layout()


func _fix_runtime_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = Vector2(1280, 720)
	position = Vector2.ZERO
	size = viewport_size
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 0
	offset_top = 0
	offset_right = viewport_size.x
	offset_bottom = viewport_size.y

	$TopBar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	$TopBar.position = Vector2(16, 12)
	$TopBar.size = Vector2(maxf(760, viewport_size.x - 180), 36)

	# HandArea 用 HFlowContainer，自动多行换行（卡牌多时不会被切到屏外）
	_hand.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hand.position = Vector2(16, maxf(280, viewport_size.y - 370))
	_hand.size = Vector2(maxf(980, viewport_size.x - 32), 350)
	if _hand is FlowContainer:
		(_hand as FlowContainer).alignment = FlowContainer.ALIGNMENT_CENTER
	_hand.add_theme_constant_override("h_separation", 8)
	_hand.add_theme_constant_override("v_separation", 8)

	# HandArea 高度 350，所以 EnemiesPanel/LogArea 顶部留 60，底部留 380
	var top_block_h: float = maxf(220.0, viewport_size.y - 410.0)
	_enemies_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_enemies_panel.position = Vector2(maxf(640, viewport_size.x - 360), 64)
	_enemies_panel.size = Vector2(340, top_block_h)

	_log.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_log.position = Vector2(16, 64)
	_log.size = Vector2(520, top_block_h)

	_end_turn_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_end_turn_btn.position = Vector2(maxf(640, viewport_size.x - 200), maxf(64 + top_block_h - 4, viewport_size.y - 410))
	_end_turn_btn.size = Vector2(180, 42)

	_back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_back_btn.position = Vector2(maxf(640, viewport_size.x - 140), 12)
	_back_btn.size = Vector2(124, 34)


# ========== 信号回调 ==========

func _on_battle_started() -> void:
	_rebuild_enemy_list()
	_refresh_hand()
	_refresh_top()


## BattleManager 使用 call_deferred 初始化；如果 UI 的 _ready 先跑完，
## 第一次刷新会拿不到 deck/enemies。这里主动等到战斗数据就绪后再刷新一次。
func _wait_for_battle_ready() -> void:
	for i in 30:
		if _battle.deck != null and _battle.enemies_container.get_child_count() > 0:
			_rebuild_enemy_list()
			_refresh_hand()
			_refresh_top()
			_append_log("[color=#9bd]战斗界面已就绪：点击下方卡牌即可出牌，右上角可返回。[/color]")
			if RunState.last_battle_was_boss:
				_append_log("[color=#e6c97a][b]BOSS 战：[/b]普通卡会进入弃牌堆并循环；只有写明“消耗”的卡才会临时进入消耗堆。[/color]")
			return
		await get_tree().process_frame
	_append_log("[color=#e99]战斗初始化超时，请查看输出面板。[/color]")


func _on_turn_changed(is_player: bool, turn_no: int) -> void:
	_turn.text = "第 %d 回合 · %s" % [turn_no, "你的回合" if is_player else "对手回合"]
	_end_turn_btn.disabled = not is_player
	_rebuild_enemy_list()
	_refresh_hand()
	_refresh_top()


func _on_card_played(_card: Card, _target: BattleEnemy) -> void:
	_refresh_hand()
	_refresh_top()
	_rebuild_enemy_list()


func _on_hp_changed(hp: int, mx: int) -> void:
	_hp.text = "气血 %d / %d" % [hp, mx]


func _on_energy_changed(en: int, mx: int) -> void:
	_energy.text = "灵韵 %d / %d" % [en, mx]


func _on_block_changed(b: int) -> void:
	_block.text = "护盾 %d" % b


func _on_battle_won() -> void:
	# 寻找有 awaken_options 的敌人，依次进入"唤醒"小游戏
	var awakable: Array[BattleEnemy] = []
	for c in _battle.enemies_container.get_children():
		if c is BattleEnemy and c.data != null and c.data.awaken_options.size() > 0:
			awakable.append(c)
	if awakable.is_empty():
		_show_result(true)
		return
	_run_awaken_chain(awakable, 0)


func _run_awaken_chain(list: Array[BattleEnemy], idx: int) -> void:
	if idx >= list.size():
		_show_result(true)
		return
	var aw: AwakenView = AWAKEN_SCENE.instantiate()
	add_child(aw)
	aw.setup(list[idx].data)
	aw.closed.connect(func ():
		aw.queue_free()
		_run_awaken_chain(list, idx + 1)
	)


func _on_battle_lost() -> void:
	_show_result(false)


func _show_result(win: bool) -> void:
	_result_panel.visible = true
	RunState.last_battle_won = win
	if win:
		_result_label.text = "胜利！\n你又唤醒了一缕被遗忘的灵韵。"
		_result_button.text = "返回地图"
		AudioEngine.play_sfx("battle_win")
		SaveSystem.save()
	else:
		_result_label.text = "你被忘川带回了……\n但你拾到的图鉴页都已留下。"
		_result_button.text = "返回主菜单"
		AudioEngine.play_sfx("die")
		# 失败：清空 map_data，下次再来重新生成
		RunState.map_data = {}
		SaveSystem.save()


func _on_result_button() -> void:
	# 失败时回主菜单（map_data 已被 _show_result 清空）；胜利回地图
	if RunState.is_dead():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/map/map.tscn")


func _on_end_turn_pressed() -> void:
	_battle.end_player_turn()


func _on_back_pressed() -> void:
	# 主动放弃这场战斗：不算胜利，节点保留
	RunState.last_battle_won = false
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")


# ========== 刷新 ==========

func _refresh_top() -> void:
	_hp.text = "气血 %d / %d" % [RunState.hp, RunState.max_hp]
	_energy.text = "灵韵 %d / %d" % [RunState.energy, RunState.max_energy]
	_block.text = "护盾 %d" % _battle.player.block
	_turn.text = "第 %d 回合 · %s" % [_battle.turn_number, "你的回合" if _battle.is_player_turn else "对手回合"]


func _refresh_hand() -> void:
	# 清空当前的卡视图。用 queue_free 避免在卡牌自己的点击回调栈里立即 free 自己。
	for c in _hand.get_children():
		if c is Control:
			var old_view: Control = c
			old_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			old_view.visible = false
		c.queue_free()
	if _battle.deck == null:
		return
	for i in _battle.deck.hand.size():
		var card: Card = _battle.deck.hand[i]
		var view: CardView = CARD_VIEW_SCENE.instantiate()
		_hand.add_child(view)
		view.setup(card, i)
		view.play_requested.connect(_on_card_view_play_requested)


func _on_card_view_play_requested(view: CardView) -> void:
	# 防护 1：view 必须仍然有效
	if view == null or not is_instance_valid(view):
		return
	if view.card == null:
		return
	var card: Card = view.card
	var hand_index: int = view.hand_index
	# 防护 2：手牌下标必须仍然有效，且该位置仍是这张卡
	if _battle.deck == null or hand_index < 0 or hand_index >= _battle.deck.hand.size():
		return
	if _battle.deck.hand[hand_index] != card:
		return
	# 防护 3：必须是玩家回合
	if not _battle.is_player_turn:
		return
	# 防护 4：节流，避免在 UI 重建瞬间被同一次鼠标按下触发多次。
	# 放在有效性检查之后，避免旧 view 的无效信号吞掉下一次正常点击。
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_play_time_ms < PLAY_CLICK_THROTTLE_MS:
		return
	_last_play_time_ms = now_ms
	# 灵韵不足：日志 + 屏幕中央醒目提示
	if RunState.energy < card.cost:
		_append_log("[color=#e8a060][b]灵韵不足[/b]：吟咏 [color=#e6c97a]%s[/color] 需要 %d 灵韵，当前 %d。[/color]" % [card.title, card.cost, RunState.energy])
		_show_toast("灵韵不足！(%d / %d)" % [RunState.energy, card.cost])
		return
	# 选目标
	var target: BattleEnemy = null
	if card.requires_target:
		target = _selected_enemy
		if target == null or target.is_dead():
			for c in _battle.enemies_container.get_children():
				if c is BattleEnemy and not c.is_dead():
					target = c
					break
	_battle.play_card_at_index(hand_index, target)


func _rebuild_enemy_list() -> void:
	for c in _enemies_panel.get_children():
		c.queue_free()
	for enemy_node in _battle.enemies_container.get_children():
		if not (enemy_node is BattleEnemy):
			continue
		var enemy: BattleEnemy = enemy_node
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(320, 88)
		var v := VBoxContainer.new()
		row.add_child(v)
		var name_label := Label.new()
		name_label.name = "Name"
		var hp_label := Label.new()
		hp_label.name = "HP"
		var intent_label := Label.new()
		intent_label.name = "Intent"
		var status_label := Label.new()
		status_label.name = "Status"
		v.add_child(name_label)
		v.add_child(hp_label)
		v.add_child(intent_label)
		v.add_child(status_label)
		_enemies_panel.add_child(row)
		var elite_tag: String = "  ★精英" if enemy.data.is_elite else ""
		var boss_tag: String = "  ☉BOSS" if enemy.data.is_boss else ""
		var dead_tag: String = "  （已化散）" if enemy.is_dead() else ""
		name_label.text = enemy.data.display_name + elite_tag + boss_tag + dead_tag
		hp_label.text = "HP %d / %d  护盾 %d" % [enemy.hp, enemy.max_hp, enemy.block]
		var it: EnemyData.Intent = enemy.current_intent
		if it == null or enemy.is_dead():
			intent_label.text = "意图：—"
		else:
			match it.kind:
				EnemyData.IntentKind.ATTACK: intent_label.text = "意图：将攻击 %d" % it.amount
				EnemyData.IntentKind.BLOCK: intent_label.text = "意图：自我守护 %d" % it.amount
				EnemyData.IntentKind.BUFF: intent_label.text = "意图：自我强化"
				EnemyData.IntentKind.DEBUFF: intent_label.text = "意图：施加易伤"
				_: intent_label.text = "意图：踟蹰"
		var statuses: PackedStringArray = PackedStringArray()
		for sid in enemy.statuses.keys():
			var sid_str: String = sid
			statuses.append("[%s x%d]" % [StatusEffect.display_name(sid_str), int(enemy.statuses[sid_str])])
		status_label.text = "状态：" + (" ".join(statuses) if statuses.size() > 0 else "—")


func _append_log(text: String) -> void:
	_log.append_text(text + "\n")


## 屏幕中央短暂提示，1 秒后消失
func _show_toast(text: String) -> void:
	var toast := Label.new()
	toast.text = text
	toast.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	toast.add_theme_font_size_override("font_size", 32)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	toast.size = Vector2(400, 60)
	toast.position = -toast.size * 0.5 + Vector2(0, -40)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.z_index = 200
	add_child(toast)
	var tw := create_tween()
	tw.tween_property(toast, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.tween_callback(toast.queue_free)

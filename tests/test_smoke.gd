## 冒烟测试：在 headless 模式下模拟一整场战斗
## 用法：godot --headless tests/test_scene.tscn --path E:\cursor_project\shanghai --quit-after 600
extends Node


func _ready() -> void:
	print("\n==================== 冒烟测试 ====================")
	_test_databases()
	await _test_battle_flow()
	print("==================== 测试完成 ====================\n")
	get_tree().quit(0)


func _test_databases() -> void:
	print("\n--- 1. 数据库加载 ---")
	var card_count: int = CardDatabase.all_cards().size()
	var enemy_count: int = EnemyDatabase.all_enemies().size()
	assert(card_count >= 20, "卡牌数量异常：%d" % card_count)
	assert(enemy_count >= 5, "敌人数量异常：%d" % enemy_count)
	print("[OK] CardDatabase: %d 张卡" % card_count)
	print("[OK] EnemyDatabase: %d 只敌人" % enemy_count)

	# 验证起手卡组每张都能找到
	var starter: PackedStringArray = CardDatabase.get_starter_deck("fang_xun")
	for cid in starter:
		assert(CardDatabase.has_card(cid), "起手卡缺失：%s" % cid)
	print("[OK] 方寻起手卡组 %d 张全部就位" % starter.size())

	# 验证可被唤醒的敌人有合法的奖励卡
	for e in EnemyDatabase.all_enemies():
		var ed: EnemyData = e
		if ed.awaken_options.size() > 0:
			assert(CardDatabase.has_card(ed.awaken_card_id), "敌人 %s 的唤醒卡缺失：%s" % [ed.id, ed.awaken_card_id])
			print("  [OK] 敌人 %s 的唤醒卡 %s 存在" % [ed.id, ed.awaken_card_id])


func _test_battle_flow() -> void:
	print("\n--- 2. 加载战斗场景 ---")
	RunState.reset_for_new_run("fang_xun")
	print("[OK] RunState 已初始化，HP=%d 灵韵=%d 卡组=%d" % [RunState.hp, RunState.energy, RunState.run_deck.size()])
	var scene: PackedScene = load("res://scenes/battle/battle.tscn")
	assert(scene != null, "战斗场景加载失败")
	var root: Node = scene.instantiate()
	# 当前 SceneTree root 正在 setup，必须用 call_deferred
	get_tree().get_root().add_child.call_deferred(root)
	# 等三帧：deferred add → _ready → _setup_battle
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	print("[OK] 战斗场景已实例化")

	var battle: Node = root.get_node("Battle")
	assert(battle != null, "找不到 Battle 节点")
	print("[OK] BattleManager 节点存在")
	print("    - 当前回合 %d, is_player_turn=%s" % [battle.turn_number, battle.is_player_turn])
	print("    - 手牌: %d  抽牌堆: %d  弃牌堆: %d" % [battle.deck.hand.size(), battle.deck.draw_pile.size(), battle.deck.discard_pile.size()])

	var enemies: Node = battle.get_node("Enemies")
	for e in enemies.get_children():
		var be: BattleEnemy = e
		print("    - 敌人 %s HP=%d/%d 意图=%d/%d" % [be.data.display_name, be.hp, be.max_hp, be.current_intent.kind, be.current_intent.amount])

	_test_card_interactions(battle)
	await get_tree().process_frame

	# 交互专项测试会直接改手牌，跑自动战斗前重置一场干净战斗。
	RunState.reset_for_new_run("fang_xun")
	battle.player.reset_for_battle()
	battle.deck.init_from_deck(RunState.run_deck, RunState.seed_value)
	battle.turn_number = 0
	battle.is_player_turn = true
	battle.school_count_this_turn.clear()
	battle._start_player_turn()

	print("\n--- 4. 自动战斗 ---")
	var max_turns: int = 30
	var turn_safety: int = 0
	while turn_safety < max_turns:
		turn_safety += 1
		# 出能出的所有牌
		var played_any: bool = true
		while played_any:
			played_any = false
			var hand_copy: Array = battle.deck.hand.duplicate()
			for card in hand_copy:
				var c: Card = card
				if not battle.can_play(c):
					continue
				var target: BattleEnemy = null
				if c.requires_target:
					for ee in enemies.get_children():
						var bb: BattleEnemy = ee
						if not bb.is_dead():
							target = bb
							break
					if target == null:
						break
				if battle.play_card(c, target):
					played_any = true
					await get_tree().process_frame
				if RunState.is_dead() or _all_enemies_dead(enemies):
					break
			if RunState.is_dead() or _all_enemies_dead(enemies):
				break

		if _all_enemies_dead(enemies):
			print("[OK] 战斗胜利于第 %d 回合，玩家剩余 HP=%d" % [battle.turn_number, RunState.hp])
			break
		if RunState.is_dead():
			print("[NOTE] 战斗败北于第 %d 回合（自动 AI 较弱属正常）" % battle.turn_number)
			break

		battle.end_player_turn()
		await get_tree().process_frame
		await get_tree().process_frame

	print("\n--- 5. 解锁状态 ---")
	print("[OK] GameState 解锁图鉴: %d 条" % GameState.unlocked_codex.size())
	for k in GameState.unlocked_codex.keys():
		print("    - " + str(k))
	print("[OK] 当前卡组: %d 张" % RunState.run_deck.size())


func _test_card_interactions(battle: Node) -> void:
	print("\n--- 3. 卡牌交互专项 ---")

	var draw_card: Card = CardDatabase.get_card("hai.yinglong_call").duplicate(true) as Card
	var guard_a: Card = CardDatabase.get_card("neutral.guard").duplicate(true) as Card
	var guard_b: Card = CardDatabase.get_card("neutral.guard").duplicate(true) as Card
	var strike_a: Card = CardDatabase.get_card("neutral.strike").duplicate(true) as Card
	var strike_b: Card = CardDatabase.get_card("neutral.strike").duplicate(true) as Card
	assert(draw_card != null and guard_a != null and guard_b != null and strike_a != null and strike_b != null, "专项测试卡牌缺失")

	# 抽卡牌：源卡应先离开手牌，再把抽到的牌加入手牌。
	_set_cards(battle.deck.hand, [draw_card, guard_a])
	_set_cards(battle.deck.draw_pile, [strike_a, strike_b])
	battle.deck.discard_pile.clear()
	battle.deck.exhaust_pile.clear()
	RunState.energy = RunState.max_energy
	battle.is_player_turn = true
	var draw_ok: bool = battle.play_card_at_index(0, null)
	assert(draw_ok, "抽卡牌没有成功打出")
	assert(not battle.deck.hand.has(draw_card), "抽卡牌打出后仍留在手牌")
	assert(battle.deck.discard_pile.has(draw_card), "抽卡牌没有进入弃牌堆")
	assert(battle.deck.hand.size() == 3, "抽卡牌后手牌数量异常：%d" % battle.deck.hand.size())
	print("[OK] 抽卡牌会消失并正确抽牌")

	# 第二回合场景：手牌保留后，下一回合抽到的抽卡牌仍可正常点击/结算。
	_set_cards(battle.deck.hand, [guard_a, draw_card])
	_set_cards(battle.deck.draw_pile, [strike_a, strike_b])
	battle.deck.discard_pile.clear()
	battle.deck.exhaust_pile.clear()
	RunState.energy = RunState.max_energy
	battle.turn_number = 2
	battle.is_player_turn = true
	var second_draw_ok: bool = battle.play_card_at_index(1, null)
	assert(second_draw_ok, "第二回合抽卡牌没有响应")
	assert(not battle.deck.hand.has(draw_card), "第二回合抽卡牌打出后仍留在手牌")
	assert(battle.deck.hand.size() == 3, "第二回合抽卡后手牌数量异常：%d" % battle.deck.hand.size())
	print("[OK] 第二回合抽卡牌可正常结算")

	# 同一个 Card Resource 出现多次时，只能移除点击的那一张位置。
	var shared_guard: Card = CardDatabase.get_card("neutral.guard")
	_set_cards(battle.deck.hand, [shared_guard, shared_guard, guard_b])
	battle.deck.draw_pile.clear()
	battle.deck.discard_pile.clear()
	battle.deck.exhaust_pile.clear()
	RunState.energy = RunState.max_energy
	battle.is_player_turn = true
	var guard_ok: bool = battle.play_card_at_index(1, null)
	assert(guard_ok, "同名基础牌没有成功打出")
	assert(battle.deck.hand.size() == 2, "同名基础牌一次移除了多张：%d" % battle.deck.hand.size())
	assert(battle.deck.discard_pile.size() == 1, "同名基础牌弃牌堆数量异常：%d" % battle.deck.discard_pile.size())
	print("[OK] 同名基础牌只移除点击的一张")

	# BOSS 战不再强制全卡消耗：普通卡进弃牌堆，只有写明“消耗”的卡进消耗堆。
	var normal_guard: Card = CardDatabase.get_card("neutral.guard").duplicate(true) as Card
	var exhaust_study: Card = CardDatabase.get_card("neutral.scroll_study").duplicate(true) as Card
	assert(normal_guard != null and exhaust_study != null, "BOSS 规则测试卡牌缺失")
	RunState.last_battle_was_boss = true
	_set_cards(battle.deck.hand, [normal_guard])
	battle.deck.draw_pile.clear()
	battle.deck.discard_pile.clear()
	battle.deck.exhaust_pile.clear()
	RunState.energy = RunState.max_energy
	battle.is_player_turn = true
	var boss_normal_ok: bool = battle.play_card_at_index(0, null)
	assert(boss_normal_ok, "BOSS 战普通卡没有成功打出")
	assert(battle.deck.discard_pile.has(normal_guard), "BOSS 战普通卡不应进入消耗堆")
	assert(battle.deck.exhaust_pile.is_empty(), "BOSS 战普通卡错误进入消耗堆")

	_set_cards(battle.deck.hand, [exhaust_study])
	battle.deck.draw_pile.clear()
	battle.deck.discard_pile.clear()
	battle.deck.exhaust_pile.clear()
	RunState.energy = RunState.max_energy
	var boss_exhaust_ok: bool = battle.play_card_at_index(0, null)
	assert(boss_exhaust_ok, "BOSS 战消耗卡没有成功打出")
	assert(battle.deck.exhaust_pile.has(exhaust_study), "写明消耗的卡应进入消耗堆")
	RunState.last_battle_was_boss = false
	print("[OK] BOSS 战普通卡循环，只有消耗卡进消耗堆")


func _set_cards(target: Array[Card], cards: Array) -> void:
	target.clear()
	for card in cards:
		var c: Card = card
		target.append(c)


func _all_enemies_dead(enemies: Node) -> bool:
	for ee in enemies.get_children():
		var bb: BattleEnemy = ee
		if not bb.is_dead():
			return false
	return true

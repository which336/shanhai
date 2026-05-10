## BattleStage: sprite-only battle presentation with lunge, defend, hit, and float text.
extends Control

const PixelSprites = preload("res://scripts/map/pixel_sprites.gd")

const ANIM_IDLE: String = "idle"
const ANIM_ATTACK: String = "attack"
const ANIM_HIT: String = "hit"
const ANIM_DEATH: String = "death"
const ANIM_CAST: String = "cast"
const ANIM_DEFEND: String = "defend"
const REQUIRED_ANIMS: Array[String] = [ANIM_IDLE, ANIM_ATTACK, ANIM_HIT, ANIM_DEATH, ANIM_CAST, ANIM_DEFEND]

var _battle: Node = null
var _player_sprite: AnimatedSprite2D = null
var _enemy_sprites: Dictionary = {}
var _enemy_last_hp: Dictionary = {}
var _enemy_last_block: Dictionary = {}
var _tweens: Dictionary = {}
var _player_last_block: int = 0


func bind_battle(battle: Node) -> void:
	_battle = battle
	if _battle == null:
		return
	if _battle.has_signal("battle_started") and not _battle.battle_started.is_connected(_rebuild):
		_battle.battle_started.connect(_rebuild)
	if _battle.has_signal("card_played") and not _battle.card_played.is_connected(_on_card_played):
		_battle.card_played.connect(_on_card_played)
	if _battle.has_signal("turn_changed"):
		_battle.turn_changed.connect(func(_is_player: bool, _turn: int): _refresh_layout())
	if _battle.player != null:
		if _battle.player.has_signal("damaged") and not _battle.player.damaged.is_connected(_on_player_damaged):
			_battle.player.damaged.connect(_on_player_damaged)
		if _battle.player.has_signal("block_changed") and not _battle.player.block_changed.is_connected(_on_player_block_changed):
			_battle.player.block_changed.connect(_on_player_block_changed)
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_refresh_layout()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_enemy_sprites.clear()
	_enemy_last_hp.clear()
	_enemy_last_block.clear()
	_tweens.clear()
	_player_last_block = int(_battle.player.block) if _battle != null and _battle.player != null else 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_player()
	if _battle == null:
		return
	for enemy_node in _battle.enemies_container.get_children():
		if enemy_node is BattleEnemy:
			_build_enemy(enemy_node)
	_refresh_layout()


func _build_player() -> void:
	_player_sprite = AnimatedSprite2D.new()
	_player_sprite.name = "PlayerAnim"
	_player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player_sprite.sprite_frames = _player_frames()
	_player_sprite.animation_finished.connect(func(): _play_idle(_player_sprite))
	add_child(_player_sprite)
	_play_idle(_player_sprite)


func _build_enemy(enemy: BattleEnemy) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.name = "EnemyAnim_%s" % enemy.data.id
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.flip_h = false
	sprite.sprite_frames = _enemy_frames(_sprite_key_for_enemy(enemy))
	sprite.animation_finished.connect(func(): _play_idle(sprite))
	add_child(sprite)
	_play_idle(sprite)
	_enemy_sprites[enemy] = sprite
	_enemy_last_hp[enemy] = enemy.hp
	_enemy_last_block[enemy] = enemy.block
	if not enemy.hp_changed.is_connected(_on_enemy_hp_changed.bind(enemy)):
		enemy.hp_changed.connect(_on_enemy_hp_changed.bind(enemy))
	if not enemy.block_changed.is_connected(_on_enemy_block_changed.bind(enemy)):
		enemy.block_changed.connect(_on_enemy_block_changed.bind(enemy))
	if enemy.has_signal("acted"):
		enemy.acted.connect(_on_enemy_acted.bind(enemy))


func _player_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	var idle := _first_frame_only(_player_textures("idle"))
	_add_animation(frames, ANIM_IDLE, idle, true, 1.0)
	_add_animation(frames, ANIM_ATTACK, _player_textures("attack"), false, 10.0)
	_add_animation(frames, ANIM_HIT, idle, false, 12.0)
	_add_animation(frames, ANIM_DEATH, idle, false, 6.0)
	_add_animation(frames, ANIM_CAST, _player_textures("attack"), false, 8.0)
	_add_animation(frames, ANIM_DEFEND, idle, false, 8.0)
	return frames


func _enemy_frames(enemy_key: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var idle := _first_frame_only(_enemy_textures(enemy_key, PixelSprites.DIR_LEFT))
	var attack := _enemy_textures(enemy_key, PixelSprites.DIR_LEFT)
	_add_animation(frames, ANIM_IDLE, idle, true, 1.0)
	_add_animation(frames, ANIM_ATTACK, attack, false, 9.0)
	_add_animation(frames, ANIM_HIT, idle, false, 12.0)
	_add_animation(frames, ANIM_DEATH, idle, false, 6.0)
	_add_animation(frames, ANIM_CAST, attack, false, 7.0)
	_add_animation(frames, ANIM_DEFEND, idle, false, 8.0)
	return frames


func _player_textures(anim: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in 4:
		var tex: Texture2D = PixelSprites.iso_character_texture(RunState.character_id, anim, PixelSprites.DIR_RIGHT, i)
		if tex == null:
			tex = PixelSprites.iso_character_texture(RunState.character_id, "idle", PixelSprites.DIR_RIGHT, i)
		if tex != null:
			out.append(tex)
	return out


func _enemy_textures(enemy_key: String, dir: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in 4:
		var tex: Texture2D = PixelSprites.iso_enemy_texture(enemy_key, dir, i)
		if tex == null and not enemy_key.begins_with("boss_"):
			tex = PixelSprites.texture(enemy_key, PixelSprites.DIR_DOWN, i)
		if tex != null:
			out.append(tex)
	if out.is_empty():
		var fallback: Texture2D = PixelSprites.iso_enemy_texture("hu_diao", PixelSprites.DIR_DOWN, 0)
		if fallback != null:
			out.append(fallback)
	return out


func _first_frame_only(textures: Array[Texture2D]) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if not textures.is_empty() and textures[0] != null:
		out.append(textures[0])
	return out


func _add_animation(frames: SpriteFrames, name: String, textures: Array[Texture2D], loop: bool, speed: float) -> void:
	frames.add_animation(name)
	frames.set_animation_loop(name, loop)
	frames.set_animation_speed(name, speed)
	for tex in textures:
		frames.add_frame(name, tex)


func _refresh_layout() -> void:
	var area := size
	if area.x <= 0 or area.y <= 0:
		area = Vector2(900, 280)
	var baseline_y: float = area.y * 0.72
	if _player_sprite != null:
		_player_sprite.position = _player_home_pos(area, baseline_y)
		_player_sprite.scale = Vector2.ONE * _sprite_scale(area, false)
	var enemies: Array = _enemy_sprites.keys()
	enemies.sort_custom(func(a, b): return str(a.name) < str(b.name))
	for i in enemies.size():
		var enemy: BattleEnemy = enemies[i]
		var sprite: AnimatedSprite2D = _enemy_sprites[enemy]
		sprite.position = _enemy_home_pos(area, baseline_y, i, enemies.size())
		sprite.scale = Vector2.ONE * _sprite_scale(area, enemy.data != null and enemy.data.is_boss)


func _player_home_pos(area: Vector2, baseline_y: float) -> Vector2:
	return Vector2(area.x * 0.25, baseline_y)


func _enemy_home_pos(area: Vector2, baseline_y: float, index: int, count: int) -> Vector2:
	var spread: float = 96.0 * clampf(area.x / 1280.0, 0.65, 1.2)
	var centered_index: float = float(index) - float(maxi(0, count - 1)) * 0.5
	return Vector2(area.x * 0.72 + centered_index * spread, baseline_y)


func _sprite_scale(area: Vector2, boss: bool) -> float:
	var base: float = clampf(minf(area.x / 1280.0, area.y / 360.0), 0.55, 1.15)
	return base * (1.12 if boss else 0.92)


func _on_card_played(card: Card, target: BattleEnemy) -> void:
	if _player_sprite == null:
		return
	var anim := ANIM_CAST
	var has_block := false
	for eff in card.effects:
		if eff.kind == CardEffect.Kind.DAMAGE:
			anim = ANIM_ATTACK
		elif eff.kind == CardEffect.Kind.BLOCK:
			has_block = true
	if has_block and anim != ANIM_ATTACK:
		anim = ANIM_DEFEND
	_play_once(_player_sprite, anim)
	if anim == ANIM_ATTACK:
		_lunge_sprite(_player_sprite, _attack_destination_for_player(target))
	elif anim == ANIM_DEFEND:
		_defend_sprite(_player_sprite)
	else:
		_pulse_sprite(_player_sprite, Vector2(0, -8))
	if target != null:
		_play_enemy_hit_later.call_deferred(target)


func _play_enemy_hit_later(target: BattleEnemy) -> void:
	if _enemy_sprites.has(target) and not target.is_dead():
		_play_once(_enemy_sprites[target], ANIM_HIT)
		_pulse_sprite(_enemy_sprites[target], Vector2(10, -2))


func _on_enemy_hp_changed(hp: int, _max_hp: int, enemy: BattleEnemy) -> void:
	if not _enemy_sprites.has(enemy):
		return
	var sprite: AnimatedSprite2D = _enemy_sprites[enemy]
	var previous: int = int(_enemy_last_hp.get(enemy, hp))
	var delta: int = hp - previous
	_enemy_last_hp[enemy] = hp
	if delta < 0:
		_float_text("-%d" % abs(delta), sprite.position + Vector2(0, -92), Color(1.0, 0.42, 0.34))
	if enemy.is_dead():
		_play_once(sprite, ANIM_DEATH)
		sprite.modulate = Color(0.55, 0.55, 0.6, 0.75)
	else:
		_play_once(sprite, ANIM_HIT)
		_pulse_sprite(sprite, Vector2(10, -2))
	_refresh_layout()


func _on_enemy_block_changed(amount: int, enemy: BattleEnemy) -> void:
	if not _enemy_sprites.has(enemy):
		_enemy_last_block[enemy] = amount
		return
	var previous: int = int(_enemy_last_block.get(enemy, amount))
	var delta: int = amount - previous
	_enemy_last_block[enemy] = amount
	if delta > 0:
		var sprite: AnimatedSprite2D = _enemy_sprites[enemy]
		_play_once(sprite, ANIM_DEFEND)
		_defend_sprite(sprite)
		_float_text("+%d 护盾" % delta, sprite.position + Vector2(0, -92), Color(0.6, 0.95, 1.0))


func _on_enemy_acted(kind: int, enemy: BattleEnemy) -> void:
	if not _enemy_sprites.has(enemy):
		return
	var sprite: AnimatedSprite2D = _enemy_sprites[enemy]
	if kind == EnemyData.IntentKind.ATTACK:
		_play_once(sprite, ANIM_ATTACK)
		_lunge_sprite(sprite, _attack_destination_for_enemy(enemy))
	elif kind == EnemyData.IntentKind.BLOCK:
		_play_once(sprite, ANIM_DEFEND)
		_defend_sprite(sprite)
	else:
		_play_once(sprite, ANIM_CAST)
		_pulse_sprite(sprite, Vector2(0, -8))


func _on_player_damaged(amount: int) -> void:
	if _player_sprite == null:
		return
	_play_once(_player_sprite, ANIM_HIT)
	_pulse_sprite(_player_sprite, Vector2(-10, 0))
	_float_text("-%d" % amount, _player_sprite.position + Vector2(0, -110), Color(1.0, 0.42, 0.34))
	_refresh_layout()


func _on_player_block_changed(amount: int) -> void:
	if _player_sprite == null:
		_player_last_block = amount
		return
	var delta: int = amount - _player_last_block
	_player_last_block = amount
	if delta > 0:
		_play_once(_player_sprite, ANIM_DEFEND)
		_defend_sprite(_player_sprite)
		_float_text("+%d 护盾" % delta, _player_sprite.position + Vector2(0, -110), Color(0.6, 0.95, 1.0))


func _play_idle(sprite: AnimatedSprite2D) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	sprite.play(ANIM_IDLE)
	sprite.set_frame_and_progress(0, 0.0)


func _play_once(sprite: AnimatedSprite2D, anim: String) -> void:
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim):
		return
	sprite.play(anim)
	sprite.set_frame_and_progress(0, 0.0)


func _pulse_sprite(sprite: AnimatedSprite2D, offset: Vector2) -> void:
	if sprite == null:
		return
	_kill_tween(sprite)
	var origin := sprite.position
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tweens[sprite] = tw
	tw.tween_property(sprite, "position", origin + offset, 0.08)
	tw.tween_property(sprite, "position", origin, 0.12)


func _lunge_sprite(sprite: AnimatedSprite2D, destination: Vector2) -> void:
	if sprite == null:
		return
	_kill_tween(sprite)
	var origin := sprite.position
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tweens[sprite] = tw
	tw.tween_property(sprite, "position", destination, 0.13)
	tw.tween_property(sprite, "position", origin, 0.18).set_delay(0.04)


func _defend_sprite(sprite: AnimatedSprite2D) -> void:
	if sprite == null:
		return
	_kill_tween(sprite)
	var origin_scale := sprite.scale
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tweens[sprite] = tw
	tw.tween_property(sprite, "scale", origin_scale * Vector2(1.08, 0.94), 0.09)
	tw.tween_property(sprite, "scale", origin_scale, 0.14)


func _kill_tween(sprite: AnimatedSprite2D) -> void:
	if _tweens.has(sprite):
		var old: Tween = _tweens[sprite]
		if old != null:
			old.kill()


func _attack_destination_for_player(target: BattleEnemy) -> Vector2:
	if target != null and _enemy_sprites.has(target):
		return (_enemy_sprites[target] as AnimatedSprite2D).position + Vector2(-92, 0)
	var area := size
	return Vector2(area.x * 0.62, area.y * 0.64)


func _attack_destination_for_enemy(enemy: BattleEnemy) -> Vector2:
	if _player_sprite == null:
		return (_enemy_sprites[enemy] as AnimatedSprite2D).position + Vector2(-80, 0)
	return _player_sprite.position + Vector2(92, 0)


func _float_text(text: String, pos: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.position = pos - Vector2(90, 0)
	label.size = Vector2(180, 34)
	add_child(label)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "position", label.position + Vector2(0, -44), 0.65)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.65)
	tw.finished.connect(label.queue_free)


func _sprite_key_for_enemy(enemy: BattleEnemy) -> String:
	var enemy_id: String = enemy.data.id
	match enemy_id:
		"elite_qiongqi":
			return "elite"
		"boss_bifang_weak":
			return "boss_weak"
		"boss_bifang":
			return "boss_mid"
		"boss_bifang_strong":
			return "boss_hard"
		"elite":
			return "elite"
		"elite_yingzhao":
			return "elite_yingzhao"
		"elite_xiangliu_shadow":
			return "elite_xiangliu_shadow"
		"elite_yinglong_young":
			return "elite_yinglong_young"
		"elite_ji_meng":
			return "elite_ji_meng"
	if enemy_id.begins_with("boss_"):
		return enemy_id
	return enemy_id


func animation_coverage_ok() -> bool:
	var sprites: Array[AnimatedSprite2D] = []
	if _player_sprite != null:
		sprites.append(_player_sprite)
	for s in _enemy_sprites.values():
		if s is AnimatedSprite2D:
			sprites.append(s)
	for sprite in sprites:
		for anim in REQUIRED_ANIMS:
			if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim):
				return false
			if sprite.sprite_frames.get_frame_count(anim) <= 0:
				return false
		if not sprite.sprite_frames.get_animation_loop(ANIM_IDLE):
			return false
		for one_shot in [ANIM_ATTACK, ANIM_HIT, ANIM_DEATH, ANIM_CAST, ANIM_DEFEND]:
			if sprite.sprite_frames.get_animation_loop(one_shot):
				return false
	return true

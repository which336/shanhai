## AudioEngine: 完全程序生成的 8-bit 风格音频系统（Autoload 单例）
## - play_sfx(name): 用 AudioStreamWAV 即时合成短音效
## - play_bgm(theme): 用 AudioStreamGenerator + push_frame 实时合成简单循环旋律
## 不依赖任何外部音频文件，开箱即用。
extends Node

const SAMPLE_RATE: float = 22050.0
const SFX_POLYPHONY: int = 8

var _sfx_players: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer = null
var _bgm_playback: AudioStreamGeneratorPlayback = null
var _current_theme: String = ""
var _bgm_t: float = 0.0
## 同名 SFX 节流（避免一秒内重复多次，听起来刺耳）
var _sfx_last_play_time: Dictionary = {}
const SFX_THROTTLE: Dictionary = {
	"attack": 0.18,
	"hit":    0.30,
	"step":   0.20,
	"click":  0.05,
	"pickup": 0.10,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# SFX 池
	for i in SFX_POLYPHONY:
		var p := AudioStreamPlayer.new()
		p.volume_db = -14.0   # SFX 整体降到 -14dB（柔和不刺耳）
		add_child(p)
		_sfx_players.append(p)
	# BGM 实时合成
	_bgm_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.2
	_bgm_player.stream = gen
	_bgm_player.volume_db = -22.0   # BGM 降到 -22dB（背景音应当低于动作音）
	add_child(_bgm_player)


# ====================== SFX ======================

func play_sfx(name: String) -> void:
	# 节流：同名 SFX 在间隔内只放一次
	var now: float = Time.get_ticks_msec() / 1000.0
	if SFX_THROTTLE.has(name):
		var last: float = float(_sfx_last_play_time.get(name, -100.0))
		if now - last < float(SFX_THROTTLE[name]):
			return
		_sfx_last_play_time[name] = now
	var stream := _generate_sfx(name)
	if stream == null:
		return
	var p: AudioStreamPlayer = _free_sfx_player()
	p.stream = stream
	p.play()


func _free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			return p
	return _sfx_players[0]


func _generate_sfx(name: String) -> AudioStreamWAV:
	var duration: float = 0.15
	var freq: float = 440.0
	var wave: String = "triangle"
	var attack: float = 0.01
	var amp: float = 0.30

	match name:
		"click":         duration = 0.05; freq = 660.0;  wave = "triangle"; amp = 0.18
		"step":          duration = 0.03; freq = 180.0;  wave = "triangle"; amp = 0.08
		"attack":        duration = 0.08; freq = 320.0;  wave = "triangle"; amp = 0.16
		"hit":           duration = 0.10; freq = 130.0;  wave = "triangle"; amp = 0.20
		"pickup":        duration = 0.18; freq = 660.0;  wave = "sweep_up"; amp = 0.18
		"shop_buy":      duration = 0.20; freq = 523.25; wave = "arpeggio"; amp = 0.22
		"levelup":       duration = 0.55; freq = 392.00; wave = "arpeggio"; amp = 0.28
		"battle_start":  duration = 0.30; freq = 196.00; wave = "sweep_up"; amp = 0.22
		"battle_win":    duration = 0.65; freq = 392.00; wave = "arpeggio"; amp = 0.30
		"die":           duration = 0.55; freq = 330.00; wave = "sweep_down"; amp = 0.28
		"card_play":     duration = 0.07; freq = 587.33; wave = "triangle"; amp = 0.18
		"card_exhaust":  duration = 0.18; freq = 261.63; wave = "sweep_down"; amp = 0.22
		_:               duration = 0.10; freq = 440.0;  wave = "triangle"

	var total_samples: int = int(SAMPLE_RATE * duration)
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(total_samples * 2)

	var phase: float = 0.0
	for i in total_samples:
		var t: float = float(i) / SAMPLE_RATE
		# 包络 ADSR 简化
		var env: float = 1.0
		if t < attack:
			env = t / attack
		else:
			env = 1.0 - (t - attack) / max(0.001, duration - attack)
		env = clampf(env, 0.0, 1.0)

		var sample: float = 0.0
		match wave:
			"square":
				phase += freq / SAMPLE_RATE
				sample = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"triangle":
				phase += freq / SAMPLE_RATE
				var p: float = fmod(phase, 1.0)
				sample = 4.0 * abs(p - 0.5) - 1.0   # -1..+1 三角
			"sin":
				phase += freq / SAMPLE_RATE
				sample = sin(phase * TAU)
			"noise":
				sample = randf_range(-1.0, 1.0) * 0.5   # 噪声整体降幅
			"sweep_up":
				var f: float = freq * (1.0 + t * 3.0)
				phase += f / SAMPLE_RATE
				var p2: float = fmod(phase, 1.0)
				sample = 4.0 * abs(p2 - 0.5) - 1.0
			"sweep_down":
				var f2: float = max(80.0, freq * (1.0 - t * 1.2))
				phase += f2 / SAMPLE_RATE
				var p3: float = fmod(phase, 1.0)
				sample = 4.0 * abs(p3 - 0.5) - 1.0
			"arpeggio":
				var notes: Array = [392.00, 523.25, 659.25, 783.99]   # G C E G（柔和大三和弦）
				var step: int = int(t * 8.0) % notes.size()
				phase += notes[step] / SAMPLE_RATE
				var p4: float = fmod(phase, 1.0)
				sample = 4.0 * abs(p4 - 0.5) - 1.0

		sample *= env * amp
		var int_sample: int = clampi(int(sample * 32767), -32768, 32767)
		samples[i * 2] = int_sample & 0xff
		samples[i * 2 + 1] = (int_sample >> 8) & 0xff

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(SAMPLE_RATE)
	stream.stereo = false
	stream.data = samples
	return stream


# ====================== BGM ======================

func play_bgm(theme: String) -> void:
	if theme == _current_theme and _bgm_player.playing:
		return
	_current_theme = theme
	_bgm_t = 0.0
	if _bgm_player.playing:
		_bgm_player.stop()
	if theme == "":
		_bgm_playback = null
		return
	_bgm_player.play()
	_bgm_playback = _bgm_player.get_stream_playback()


func stop_bgm() -> void:
	_current_theme = ""
	_bgm_playback = null
	if _bgm_player.playing:
		_bgm_player.stop()


func _process(_delta: float) -> void:
	if _bgm_playback == null or _current_theme == "":
		return
	var melody: Array = _melody(_current_theme)
	var bass: Array = _bass(_current_theme)
	if melody.is_empty():
		return
	var tempo: float = _tempo(_current_theme)
	var frames: int = _bgm_playback.get_frames_available()
	for i in frames:
		_bgm_t += 1.0 / SAMPLE_RATE
		var step_idx: int = int(_bgm_t / tempo) % melody.size()
		var note_t: float = fmod(_bgm_t, tempo) / tempo
		var freq: float = melody[step_idx]
		var bf: float = bass[int(_bgm_t / (tempo * 2.0)) % bass.size()] if not bass.is_empty() else 0.0
		# 旋律：三角波 + 软攻击衰减包络（前 5% 渐起，后 20% 衰减）
		var lead_env: float = 1.0
		if note_t < 0.05:
			lead_env = note_t / 0.05
		elif note_t > 0.7:
			lead_env = clampf(1.0 - (note_t - 0.7) / 0.3, 0.0, 1.0)
		var lead_sample: float = 0.0
		if freq > 0.1:
			var p: float = fmod(_bgm_t * freq, 1.0)
			lead_sample = (4.0 * abs(p - 0.5) - 1.0) * 0.10 * lead_env
		# 低音：正弦（最柔和）
		var bass_sample: float = 0.0
		if bf > 0.1:
			bass_sample = sin(_bgm_t * bf * TAU) * 0.06
		var s: float = lead_sample + bass_sample
		_bgm_playback.push_frame(Vector2(s, s))


func _tempo(theme: String) -> float:
	match theme:
		"menu":   return 0.32
		"map":    return 0.28
		"battle": return 0.20
	return 0.25


## 8 个音符的小循环 melody（频率 Hz；0 表示静音）
func _melody(theme: String) -> Array:
	match theme:
		"menu":
			# 平和 C 调
			return [261.63, 329.63, 392.00, 329.63, 261.63, 196.00, 261.63, 329.63]
		"map":
			# A 小调，悠远
			return [220.00, 261.63, 329.63, 261.63, 220.00, 196.00, 174.61, 220.00]
		"battle":
			# 紧张感
			return [110.00, 0, 138.59, 110.00, 130.81, 0, 130.81, 164.81]
	return []


func _bass(theme: String) -> Array:
	match theme:
		"menu":   return [130.81, 196.00]
		"map":    return [110.00, 146.83]
		"battle": return [55.00, 73.42]
	return []

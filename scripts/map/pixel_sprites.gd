## 像素 sprite 数据（8x8 每像素 = 6 实像素，绘制后 48x48 正好填一格）
## 支持 4 方向（down/up/left/right）x 2 帧动画
class_name PixelSprites


const PIXEL: int = 6
const SIZE: int = 8
const TILE_SIZE: int = PIXEL * SIZE  # 48


## 方向常量
const DIR_DOWN: String = "down"
const DIR_UP: String = "up"
const DIR_LEFT: String = "left"
const DIR_RIGHT: String = "right"


## 字符 -> 颜色（透明用 ' '）
static func palette() -> Dictionary:
	return {
		" ": Color(0, 0, 0, 0),

		# 通用阴影 / 描边
		"K": Color("#0a0a12"),
		"k": Color("#1c1c28"),

		# 玩家
		"H": Color("#1f3a6a"),    # 头巾深蓝
		"h": Color("#3658a0"),    # 头巾亮蓝
		"F": Color("#f4caa1"),    # 肤色
		"f": Color("#c9986b"),    # 肤色暗
		"Y": Color("#f6c948"),    # 衣黄
		"y": Color("#caa12d"),    # 衣黄暗
		"L": Color("#412816"),    # 裤腿
		"E": Color("#0a0a12"),    # 眼
		"A": Color("#7a5a30"),    # 鞋/腰带

		# 小怪 - 狐
		"R": Color("#9d2526"),    # 深红
		"r": Color("#d6453d"),    # 亮红
		"W": Color("#f5e8c4"),    # 米白
		"w": Color("#5a1012"),    # 耳内深

		# 小怪 - 鹿蜀（白头马身）
		"M": Color("#e8d8b0"),    # 白头
		"m": Color("#a07e5a"),    # 马身棕
		"b": Color("#5a3a22"),    # 鬃毛深褐
		"X": Color("#b1322b"),    # 红尾
		"z": Color("#3a2212"),    # 蹄黑

		# 小怪 - 从从（六足犬）
		"G": Color("#5a4a32"),    # 犬深棕
		"g": Color("#8a6f48"),    # 犬棕

		# 小怪 - 类（似狸）
		"T": Color("#6a4a25"),    # 狸深褐
		"t": Color("#a87b4a"),    # 狸棕

		# 精英 - 穷奇
		"O": Color("#dc6b21"),    # 刺橙亮
		"o": Color("#9b3f10"),    # 刺橙深
		"P": Color("#7a2a14"),    # 主体暗红棕

		# BOSS - 毕方
		"D": Color("#5a1a72"),    # 紫深
		"d": Color("#9230b0"),    # 紫亮
		"Q": Color("#e8501a"),    # 火羽橙
		"q": Color("#ffae3a"),    # 火羽金
		"S": Color("#ffe06a"),    # 高光金
		"V": Color("#c61f50"),    # 强 BOSS 玫红
		"v": Color("#ff5a8a"),    # 强 BOSS 亮玫
		"B": Color("#f5e8d0"),    # 嘴/爪米白

		# 商铺
		"C": Color("#287a72"),    # 屋檐
		"c": Color("#46b0a4"),    # 招牌青
		"N": Color("#fff2c4"),    # 招牌纸

		# 驿站
		"U": Color("#3c4a82"),    # 帐篷蓝
		"u": Color("#7080c4"),    # 帐篷亮

		# 宝箱
		"i": Color("#5a3a18"),    # 木箱浅棕
		"j": Color("#ffe05a"),    # 高光金
		"#": Color("#3a2210"),    # 木箱深棕
		"$": Color("#d4a23a"),    # 金黄镶边

		# 事件卷轴
		"@": Color("#5a3018"),    # 卷轴深褐边
		"!": Color("#a06434"),    # 卷轴浅边
		"n": Color("#f0d8a8"),    # 米色纸
		"Z": Color("#1c1410"),    # 墨黑

		# 文化片段（光点）
		"p": Color("#fff0a0"),    # 柔白光
		"s": Color("#f5d860"),    # 暖金
	}


## 把 facing Vector2i 转为方向字符串
static func facing_to_dir(facing: Vector2i) -> String:
	if facing.x > 0:
		return DIR_RIGHT
	if facing.x < 0:
		return DIR_LEFT
	if facing.y > 0:
		return DIR_DOWN
	if facing.y < 0:
		return DIR_UP
	return DIR_DOWN


## 获取动画精灵（kind, facing, frame）
## 如无对应方向则 fallback 到 down；无对应帧则 fallback 到 0
static func sprite_animated(kind: String, facing: String = DIR_DOWN, frame: int = 0) -> PackedStringArray:
	var data: Dictionary = _animated_data()
	if not data.has(kind):
		return PackedStringArray()
	var dirs: Dictionary = data[kind]
	if not dirs.has(facing):
		facing = DIR_DOWN
	var frames: Array = dirs[facing]
	if frame < 0 or frame >= frames.size():
		frame = 0
	return frames[frame]


## 旧版兼容：返回 default（down_f0）精灵
static func sprite(kind: String) -> PackedStringArray:
	return sprite_animated(kind, DIR_DOWN, 0)


# ============== 全部动画精灵数据 ==============

static func _animated_data() -> Dictionary:
	return {
		# ==================== 玩家 ====================
		"player": {
			DIR_DOWN: [
				PackedStringArray([
					"  HHHH  ",
					" HHHHHH ",
					"hFfFFfFh",
					" FEEEF  ",
					" YYYYY  ",
					"yYYYYYy ",
					" L   L  ",
					" A   A  ",
				]),
				PackedStringArray([
					"  HHHH  ",
					" HHHHHH ",
					"hFfFFfFh",
					" FEEEF  ",
					" YYYYY  ",
					"yYYYYYy ",
					"  L A   ",
					" A   A  ",
				]),
			],
			DIR_UP: [
				PackedStringArray([
					"  HHHH  ",
					" HHHHHH ",
					"hHfFfHh ",
					" YYYYY  ",
					" YYYYY  ",
					"yYYYYYy ",
					" L   L  ",
					" A   A  ",
				]),
				PackedStringArray([
					"  HHHH  ",
					" HHHHHH ",
					"hHfFfHh ",
					" YYYYY  ",
					" YYYYY  ",
					"yYYYYYy ",
					"  L A   ",
					" A   A  ",
				]),
			],
			DIR_RIGHT: [
				PackedStringArray([
					"  HH    ",
					" HHHh   ",
					" FfFf   ",
					"  EEF   ",
					" YYYY   ",
					"yYYYY   ",
					" L   L  ",
					" A   A  ",
				]),
				PackedStringArray([
					"  HH    ",
					" HHHh   ",
					" FfFf   ",
					"  EEF   ",
					" YYYY   ",
					"yYYYY   ",
					"  L A   ",
					" A   A  ",
				]),
			],
			DIR_LEFT: [
				PackedStringArray([
					"    HH  ",
					"   hHHH ",
					"   fFfF ",
					"   FEE  ",
					"   YYYY ",
					"   YYYy ",
					" L   L  ",
					" A   A  ",
				]),
				PackedStringArray([
					"    HH  ",
					"   hHHH ",
					"   fFfF ",
					"   FEE  ",
					"   YYYY ",
					"   YYYy ",
					" A   L  ",
					" A   A  ",
				]),
			],
		},

		# ==================== 小怪 - 狐 ====================
		"enemy.hu_diao": {
			DIR_DOWN: [
				PackedStringArray([
					" w   w  ",
					"R R R R ",
					"RRrrrRR ",
					" rEKKEr ",
					" rrrrrr ",
					"  rWr   ",
					"   r    ",
					"  k  k  ",
				]),
				PackedStringArray([
					" w   w  ",
					"R R R R ",
					"RRrrrRR ",
					" rEKKEr ",
					" rrrrrr ",
					"  rWr   ",
					"   r    ",
					" k    k ",
				]),
			],
			DIR_UP: [
				PackedStringArray([
					" w   w  ",
					"R R R R ",
					" RrrrR  ",
					" rrrrr  ",
					" rrrrr  ",
					"  rWr   ",
					"   r    ",
					"  k  k  ",
				]),
				PackedStringArray([
					" w   w  ",
					"R R R R ",
					" RrrrR  ",
					" rrrrr  ",
					" rrrrr  ",
					"  rWr   ",
					"   r    ",
					" k    k ",
				]),
			],
			DIR_RIGHT: [
				PackedStringArray([
					"   w    ",
					"  RrR   ",
					" RrrrR  ",
					" rEKKr  ",
					" rrrrr  ",
					"  rWr   ",
					"   r    ",
					"  k  k  ",
				]),
				PackedStringArray([
					"   w    ",
					"  RrR   ",
					" RrrrR  ",
					" rEKKr  ",
					" rrrrr  ",
					"  rWr   ",
					"   r    ",
					" k    k ",
				]),
			],
			DIR_LEFT: [
				PackedStringArray([
					"    w   ",
					"   RrR  ",
					"  RrrrR ",
					"  rKKE  ",
					"  rrrrr ",
					"   rWr  ",
					"   r    ",
					"  k  k  ",
				]),
				PackedStringArray([
					"    w   ",
					"   RrR  ",
					"  RrrrR ",
					"  rKKE  ",
					"  rrrrr ",
					"   rWr  ",
					"   r    ",
					" k    k ",
				]),
			],
		},

		# ==================== 小怪 - 鹿蜀 ====================
		"enemy.lu_shu": {
			DIR_DOWN: [
				PackedStringArray([
					"   MM   ",
					"  MmMM  ",
					" MMMMM  ",
					" mmmmmX ",
					"mmbmmmmX",
					" m m mX ",
					" z   z  ",
					"        ",
				]),
				PackedStringArray([
					"   MM   ",
					"  MmMM  ",
					" MMMMM  ",
					" mmmmmX ",
					"mmbmmmmX",
					"  m m   ",
					" z   z  ",
					"        ",
				]),
			],
			DIR_UP: [
				PackedStringArray([
					"   MM   ",
					"  MmMM  ",
					" mmmmm  ",
					" mmmmm  ",
					"mmmmmmX ",
					" m m m  ",
					" z   z  ",
					"        ",
				]),
				PackedStringArray([
					"   MM   ",
					"  MmMM  ",
					" mmmmm  ",
					" mmmmm  ",
					"mmmmmmX ",
					"  m m   ",
					" z   z  ",
					"        ",
				]),
			],
			DIR_RIGHT: [
				PackedStringArray([
					"   MM   ",
					"  MMMm  ",
					" Mmmmm  ",
					" mmmmmX ",
					"mmm mmm ",
					" m   m  ",
					" z   z  ",
					"        ",
				]),
				PackedStringArray([
					"   MM   ",
					"  MMMm  ",
					" Mmmmm  ",
					" mmmmmX ",
					"mmm mmm ",
					"  m m   ",
					" z   z  ",
					"        ",
				]),
			],
			DIR_LEFT: [
				PackedStringArray([
					"   MM   ",
					"  mMMM  ",
					"  mmmmM ",
					" Xmmmmm ",
					" mmm mmm",
					" m   m  ",
					" z   z  ",
					"        ",
				]),
				PackedStringArray([
					"   MM   ",
					"  mMMM  ",
					"  mmmmM ",
					" Xmmmmm ",
					" mmm mmm",
					"  m m   ",
					" z   z  ",
					"        ",
				]),
			],
		},

		# ==================== 小怪 - 从从（六足犬）= ====================
		"enemy.cong_cong": {
			DIR_DOWN: [
				PackedStringArray([
					"        ",
					"  GggG  ",
					" GgggGg ",
					" GEggEg ",
					"gGgggggG",
					" g g g g",
					" k k k k",
					"        ",
				]),
				PackedStringArray([
					"        ",
					"  GggG  ",
					" GgggGg ",
					" GEggEg ",
					"gGgggggG",
					" k k k k",
					"  k k   ",
					"        ",
				]),
			],
			DIR_UP: [
				PackedStringArray([
					"        ",
					"  GggG  ",
					" GgggGg ",
					" ggEggE ",
					"GgggggGg",
					" g g g g",
					" k k k k",
					"        ",
				]),
				PackedStringArray([
					"        ",
					"  GggG  ",
					" GgggGg ",
					" ggEggE ",
					"GgggggGg",
					" k k k k",
					"  k k   ",
					"        ",
				]),
			],
			DIR_RIGHT: [
				PackedStringArray([
					"        ",
					" Ggg    ",
					"Ggggg   ",
					"G EggGg ",
					"Gggg Gg ",
					" g g  g ",
					" k k  k ",
					"        ",
				]),
				PackedStringArray([
					"        ",
					" Ggg    ",
					"Ggggg   ",
					"G EggGg ",
					"Gggg Gg ",
					" g   g  ",
					" k k k  ",
					"        ",
				]),
			],
			DIR_LEFT: [
				PackedStringArray([
					"        ",
					"    ggG ",
					"   gggG ",
					" gGggE G",
					" gG gggG",
					" g  g g ",
					" k  k k ",
					"        ",
				]),
				PackedStringArray([
					"        ",
					"    ggG ",
					"   gggG ",
					" gGggE G",
					" gG gggG",
					" g   g  ",
					"  k k k ",
					"        ",
				]),
			],
		},

		# ==================== 小怪 - 类（似狸）= ====================
		"enemy.lei_beast": {
			DIR_DOWN: [
				PackedStringArray([
					"  Tt T  ",
					" TtTtTt ",
					" tEttEt ",
					" tttttt ",
					"tTttttTt",
					"  tttt  ",
					"  k  k  ",
					"        ",
				]),
				PackedStringArray([
					"  Tt T  ",
					" TtTtTt ",
					" tEttEt ",
					" tttttt ",
					"tTttttTt",
					"  tttt  ",
					"  k  k  ",
					" k    k ",
				]),
			],
			DIR_UP: [
				PackedStringArray([
					"  Tt T  ",
					" TtTtTt ",
					" tttt t ",
					" tttttt ",
					"TtttttTt",
					"  tttt  ",
					"  k  k  ",
					"        ",
				]),
				PackedStringArray([
					"  Tt T  ",
					" TtTtTt ",
					" tttt t ",
					" tttttt ",
					"TtttttTt",
					"  tttt  ",
					"  k  k  ",
					" k    k ",
				]),
			],
			DIR_RIGHT: [
				PackedStringArray([
					"  Tt    ",
					" TtTtT  ",
					" tEttt  ",
					" ttttt  ",
					"tTtttTt ",
					"  ttt   ",
					"  k  k  ",
					"        ",
				]),
				PackedStringArray([
					"  Tt    ",
					" TtTtT  ",
					" tEttt  ",
					" ttttt  ",
					"tTtttTt ",
					"  ttt   ",
					" k    k ",
					"        ",
				]),
			],
			DIR_LEFT: [
				PackedStringArray([
					"    tT  ",
					"  TtTtT ",
					"  tttE  ",
					"  ttttt ",
					" tTtttTt",
					"   ttt  ",
					"  k  k  ",
					"        ",
				]),
				PackedStringArray([
					"    tT  ",
					"  TtTtT ",
					"  tttE  ",
					"  ttttt ",
					" tTtttTt",
					"   ttt  ",
					" k    k ",
					"        ",
				]),
			],
		},

		# ==================== 精英 - 穷奇 ====================
		"elite": {
			DIR_DOWN: [
				PackedStringArray([
					"o  oo  o",
					" oOOOOo ",
					"oOPPPPOo",
					"oPPOPPOo",
					"oPPKKPPo",
					" oPoPo  ",
					"  o  o  ",
					"  K  K  ",
				]),
				PackedStringArray([
					"o  oo  o",
					" oOOOOo ",
					"oOPPPPOo",
					"oPPOPPOo",
					"oPPKKPPo",
					" oPoPo  ",
					" o    o ",
					" K    K ",
				]),
			],
			DIR_UP: [
				PackedStringArray([
					"o  oo  o",
					" oOOOOo ",
					"oOPPPPOo",
					"oPoPoPo ",
					"oP OKOo ",
					" oPoP   ",
					"  o  o  ",
					"  K  K  ",
				]),
				PackedStringArray([
					"o  oo  o",
					" oOOOOo ",
					"oOPPPPOo",
					"oPoPoPo ",
					"oP OKOo ",
					" oPoP   ",
					" o    o ",
					" K    K ",
				]),
			],
			DIR_RIGHT: [
				PackedStringArray([
					" o o    ",
					"ooOOo   ",
					"oOPPPo  ",
					"oPPOPo  ",
					" PPKKo  ",
					"  PoP   ",
					"  o  o  ",
					"  K  K  ",
				]),
				PackedStringArray([
					" o o    ",
					"ooOOo   ",
					"oOPPPo  ",
					"oPPOPo  ",
					" PPKKo  ",
					"  PoP   ",
					" o    o ",
					" K    K ",
				]),
			],
			DIR_LEFT: [
				PackedStringArray([
					"    o o ",
					"   oOOoo",
					"  oPPPOo",
					"  oPOPPo",
					"  oKKPP ",
					"   PoP  ",
					"  o  o  ",
					"  K  K  ",
				]),
				PackedStringArray([
					"    o o ",
					"   oOOoo",
					"  oPPPOo",
					"  oPOPPo",
					"  oKKPP ",
					"   PoP  ",
					" o    o ",
					" K    K ",
				]),
			],
		},

		# ==================== BOSS - 毕方 ====================
		"boss_weak": {
			DIR_DOWN: [
				PackedStringArray([
					"   QQ   ",
					"  QqqQ  ",
					" QqSSqQ ",
					"QqqEEqqQ",
					" QqqqqQ ",
					"  QQQQ  ",
					"   SS   ",
					"   KK   ",
				]),
				PackedStringArray([
					"   QQ   ",
					"  QqqQ  ",
					" QqSSqQ ",
					"QqqEEqqQ",
					" QqqqqQ ",
					"  QQQQ  ",
					"  S  S  ",
					"  K  K  ",
				]),
			],
			DIR_UP: [
				PackedStringArray([
					"   QQ   ",
					"  QqqQ  ",
					" QqqqQ  ",
					"QqEEqqQ ",
					" QqqqqQ ",
					"  QQQQ  ",
					"   SS   ",
					"   KK   ",
				]),
				PackedStringArray([
					"   QQ   ",
					"  QqqQ  ",
					" QqqqQ  ",
					"QqEEqqQ ",
					" QqqqqQ ",
					"  QQQQ  ",
					"  S  S  ",
					"  K  K  ",
				]),
			],
			DIR_RIGHT: [
				PackedStringArray([
					"   QQ   ",
					"  QqqQ  ",
					" qSqQ   ",
					"qqEEqQ  ",
					" qqqqQ  ",
					"  QQQ   ",
					"   SS   ",
					"   KK   ",
				]),
				PackedStringArray([
					"   QQ   ",
					"  QqqQ  ",
					" qSqQ   ",
					"qqEEqQ  ",
					" qqqqQ  ",
					"  QQQ   ",
					"  S  S  ",
					"  K  K  ",
				]),
			],
			DIR_LEFT: [
				PackedStringArray([
					"   QQ   ",
					"  QqqQ  ",
					"  Q qSq ",
					" QqEEqq ",
					" Qqqqq  ",
					"   QQQ  ",
					"   SS   ",
					"   KK   ",
				]),
				PackedStringArray([
					"   QQ   ",
					"  QqqQ  ",
					"  Q qSq ",
					" QqEEqq ",
					" Qqqqq  ",
					"   QQQ  ",
					"  S  S  ",
					"  K  K  ",
				]),
			],
		},
		"boss_mid": {
			DIR_DOWN: [
				PackedStringArray([
					"   DD   ",
					"  DddD  ",
					" QDddDQ ",
					"qDqEEqDq",
					" QDddDQ ",
					"  DDDD  ",
					"   SS   ",
					"  S  S  ",
				]),
				PackedStringArray([
					"   DD   ",
					"  DddD  ",
					" QDddDQ ",
					"qDqEEqDq",
					" QDddDQ ",
					"  DDDD  ",
					"  S  S  ",
					" S    S ",
				]),
			],
			DIR_UP: [
				PackedStringArray([
					"   DD   ",
					"  DddD  ",
					" DdDQ Q ",
					" DqEqDq ",
					"  DdddD ",
					"  DDDD  ",
					"   SS   ",
					"  S  S  ",
				]),
				PackedStringArray([
					"   DD   ",
					"  DddD  ",
					" DdDQ Q ",
					" DqEqDq ",
					"  DdddD ",
					"  DDDD  ",
					"  S  S  ",
					" S    S ",
				]),
			],
			DIR_RIGHT: [
				PackedStringArray([
					"    DD  ",
					"   DddD ",
					"  DDddQ ",
					"qDqEqD  ",
					"  DdddD ",
					"   DDD  ",
					"    SS  ",
					"   S  S ",
				]),
				PackedStringArray([
					"    DD  ",
					"   DddD ",
					"  DDddQ ",
					"qDqEqD  ",
					"  DdddD ",
					"   DDD  ",
					"   S  S ",
					"  S    S",
				]),
			],
			DIR_LEFT: [
				PackedStringArray([
					"  DD    ",
					" DddD   ",
					" QddDD  ",
					"  DqEqDq",
					" DdddD  ",
					"  DDD   ",
					"  SS    ",
					" S  S   ",
				]),
				PackedStringArray([
					"  DD    ",
					" DddD   ",
					" QddDD  ",
					"  DqEqDq",
					" DdddD  ",
					"  DDD   ",
					" S  S   ",
					"S    S  ",
				]),
			],
		},
		"boss_hard": {
			DIR_DOWN: [
				PackedStringArray([
					"V VVVV V",
					"VVVQQVVV",
					" VQqqQV ",
					"VqqEEqqV",
					" VqSSqV ",
					"  VQQV  ",
					"  vSSv  ",
					" K    K ",
				]),
				PackedStringArray([
					"V VVVV V",
					"VVVQQVVV",
					" VQqqQV ",
					"VqqEEqqV",
					" VqSSqV ",
					"  VQQV  ",
					" v    v ",
					"K      K",
				]),
			],
			DIR_UP: [
				PackedStringArray([
					"V VVVV V",
					"VVVQQVVV",
					" VQqqQV ",
					" VqEEqV ",
					"  VqqQV ",
					"  VQQV  ",
					"  vSSv  ",
					" K    K ",
				]),
				PackedStringArray([
					"V VVVV V",
					"VVVQQVVV",
					" VQqqQV ",
					" VqEEqV ",
					"  VqqQV ",
					"  VQQV  ",
					" v    v ",
					"K      K",
				]),
			],
			DIR_RIGHT: [
				PackedStringArray([
					" VVVV V ",
					" VVQQVV ",
					" QVqqQV ",
					"qqVEEqV ",
					" VqSSq  ",
					"  VQQV  ",
					"  vSSv  ",
					" K    K ",
				]),
				PackedStringArray([
					" VVVV V ",
					" VVQQVV ",
					" QVqqQV ",
					"qqVEEqV ",
					" VqSSq  ",
					"  VQQV  ",
					" v    v ",
					"K      K",
				]),
			],
			DIR_LEFT: [
				PackedStringArray([
					" V VVVV ",
					" VVQQVV ",
					" VqqQVQ ",
					" VqEEVqq",
					"  qSSqV ",
					"  VQQV  ",
					"  vSSv  ",
					" K    K ",
				]),
				PackedStringArray([
					" V VVVV ",
					" VVQQVV ",
					" VqqQVQ ",
					" VqEEVqq",
					"  qSSqV ",
					"  VQQV  ",
					" v    v ",
					"K      K",
				]),
			],
		},

		# ==================== 设施（无方向动画，兼容） ====================
		"shop": _static_frames(PackedStringArray([
			"  CCCC  ",
			" CCCCCC ",
			"CCCCCCCC",
			" cNNNNc ",
			" cNNNNc ",
			"  cccc  ",
			"  c  c  ",
			"  K  K  ",
		])),
		"rest": _static_frames(PackedStringArray([
			"   uu   ",
			"  uUUu  ",
			" uUUUUu ",
			"uUUUUUUu",
			"U      U",
			"U      U",
			"U      U",
			"KKKKKKKK",
		])),
		"treasure": _static_frames(PackedStringArray([
			"  ####  ",
			" #$$$$# ",
			"#$jjjj$#",
			"#$$jj$$#",
			"#iiiiii#",
			"#$j$$j$#",
			"#iiiiii#",
			"KKKKKKKK",
		])),
		"event": _static_frames(PackedStringArray([
			" @!!!!@ ",
			"@!nnnn!@",
			"@!nZZn!@",
			"@!nZZn!@",
			"@!nZZn!@",
			"@!nnnn!@",
			" @!!!!@ ",
			"   @@   ",
		])),
		"fragment": _static_frames(PackedStringArray([
			"   pp   ",
			"  pssp  ",
			" psssssp",
			"psssssss",
			"psssssss",
			" psssssp",
			"  pssp  ",
			"   pp   ",
		])),
	}


## 静态设施：所有方向/帧共用同一张 sprite
static func _static_frames(base: PackedStringArray) -> Dictionary:
	var f := [base, base.duplicate()]
	return {
		DIR_DOWN: f,
		DIR_UP: f,
		DIR_LEFT: f,
		DIR_RIGHT: f,
	}


# ============== 纹理系统（从 SVG 文件加载） ==============

static var _tex_cache: Dictionary = {}
static var _tex_loaded: bool = false


## 批量加载纹理（优先加载真实贴图，SVG 作为 fallback）
static func _load_textures() -> void:
	if _tex_loaded:
		return
	_tex_loaded = true
	
	_tex_cache["__atlas"] = {}  # 贴图集缓存（sheet_name -> texture）
	
	# ---- 玩家：Julia 步行动画贴图 ----
	var player_walk_sets := {
		"player": {
			DIR_DOWN:  "res://assets/textures/player/walk_down.png",
			DIR_UP:    "res://assets/textures/player/walk_up.png",
			DIR_LEFT:  "res://assets/textures/player/walk_left.png",
			DIR_RIGHT: "res://assets/textures/player/walk_right.png",
		},
		"player_ali": {
			DIR_DOWN:  "res://assets/textures/player/ali_walk_down.png",
			DIR_UP:    "res://assets/textures/player/ali_walk_up.png",
			DIR_LEFT:  "res://assets/textures/player/ali_walk_left.png",
			DIR_RIGHT: "res://assets/textures/player/ali_walk_right.png",
		},
		"player_luoling": {
			DIR_DOWN:  "res://assets/textures/player/luoling_walk_down.png",
			DIR_UP:    "res://assets/textures/player/luoling_walk_up.png",
			DIR_LEFT:  "res://assets/textures/player/luoling_walk_left.png",
			DIR_RIGHT: "res://assets/textures/player/luoling_walk_right.png",
		},
		"player_sangqi": {
			DIR_DOWN:  "res://assets/textures/player/sangqi_walk_down.png",
			DIR_UP:    "res://assets/textures/player/sangqi_walk_up.png",
			DIR_LEFT:  "res://assets/textures/player/sangqi_walk_left.png",
			DIR_RIGHT: "res://assets/textures/player/sangqi_walk_right.png",
		},
	}
	for player_key in player_walk_sets:
		var player_walk_sheets: Dictionary = player_walk_sets[player_key]
		for facing in player_walk_sheets:
			var sheet: Texture2D = _try_load(player_walk_sheets[facing])
			if sheet != null:
				for f in 4:
					var region := Rect2(f * 64, 0, 64, 64)
					_tex_cache[_tex_key(player_key, facing, f)] = _atlas_tex(sheet, region)

	# ---- 地图方块贴图 ----
	var tile_sheets := {
		"grass":         "res://assets/textures/tiles/grass_tilesheet.png",
			"dirt":          "res://assets/textures/tiles/dirt_tilesheet.png",
			"stone_wall":    "res://assets/textures/tiles/wall_stone_tilesheet.png",
			"stone_floor":   "res://assets/textures/tiles/stonefloor_tilesheet.png",
			"brick_wall":    "res://assets/textures/tiles/wall_brick_tilesheet.png",
	}
	# 每个 tilesheet 6行x8列=48个tile，每个 64x64，取中心 48x48
	for tname in tile_sheets:
		var sheet: Texture2D = _try_load(tile_sheets[tname])
		if sheet != null:
			_tex_cache["tile|%s|0" % tname] = {"tex": sheet, "grid": Vector2i(8, 6), "tile_size": 64}
			_tex_cache["tile|%s|sheet" % tname] = sheet

	# ---- 等距素材（2DPIXX） ----
	# Warrior: 步行/空闲/攻击, 512x640, 4dir x 4frames, 每帧 128x160
	var iso_dirs_standard := [DIR_DOWN, DIR_RIGHT, DIR_LEFT, DIR_UP]
	var iso_dirs_left_right_swapped := [DIR_DOWN, DIR_LEFT, DIR_RIGHT, DIR_UP]
	var iso_player_row_dirs := {
		"player": iso_dirs_left_right_swapped,
		"player_ali": iso_dirs_left_right_swapped,
		"player_luoling": iso_dirs_standard,
		"player_sangqi": iso_dirs_left_right_swapped,
	}
	var iso_enemy_row_dirs := {
		"lu_shu": iso_dirs_left_right_swapped,
		"cong_cong": iso_dirs_left_right_swapped,
		"zheng_beast": iso_dirs_left_right_swapped,
		"xuan_gui": iso_dirs_left_right_swapped,
		"he_luo_fish": iso_dirs_left_right_swapped,
		"xiao_beast": iso_dirs_left_right_swapped,
		"qiu_yu": iso_dirs_left_right_swapped,
		"zhu_ru": iso_dirs_left_right_swapped,
		"tu_lou": iso_dirs_left_right_swapped,
		"elite_ji_meng": iso_dirs_left_right_swapped,
	}
	var iso_player_sets := {
		"player": {
			"walk":  "res://assets/textures/iso/warrior_walk.png",
			"idle":  "res://assets/textures/iso/warrior_idle.png",
			"attack":"res://assets/textures/iso/warrior_attack.png",
		},
		"player_ali": {
			"walk":  "res://assets/textures/iso/ali_walk.png",
			"idle":  "res://assets/textures/iso/ali_idle.png",
			"attack":"res://assets/textures/iso/ali_attack.png",
		},
		"player_luoling": {
			"walk":  "res://assets/textures/iso/luoling_walk.png",
			"idle":  "res://assets/textures/iso/luoling_idle.png",
			"attack":"res://assets/textures/iso/luoling_attack.png",
		},
		"player_sangqi": {
			"walk":  "res://assets/textures/iso/sangqi_walk.png",
			"idle":  "res://assets/textures/iso/sangqi_idle.png",
			"attack":"res://assets/textures/iso/sangqi_attack.png",
		},
	}
	for player_key in iso_player_sets:
		var iso_player_sheets: Dictionary = iso_player_sets[player_key]
		var dirs_for_player: Array = iso_player_row_dirs.get(player_key, iso_dirs_left_right_swapped)
		for anim in iso_player_sheets:
			var sheet: Texture2D = _try_load(iso_player_sheets[anim])
			if sheet != null:
				for dir_idx in 4:
					for f_idx in 4:
						var source_dir_idx := dir_idx
						var source_frame_idx := f_idx
						if player_key == "player_sangqi" and anim == "attack":
							source_dir_idx = 0
							source_frame_idx = 0
						var region := Rect2(source_frame_idx * 128, source_dir_idx * 160, 128, 160)
						var atlas := _atlas_tex(sheet, region)
						_tex_cache["iso_player|%s|%s|%s|%d" % [player_key, anim, dirs_for_player[dir_idx], f_idx]] = atlas
						if player_key == "player":
							_tex_cache["iso_player|%s|%s|%d" % [anim, dirs_for_player[dir_idx], f_idx]] = atlas

	var iso_enemy_sheets := {
		"hu_diao": "res://assets/textures/iso/enemies/hu_diao_walk.png",
		"lu_shu": "res://assets/textures/iso/enemies/lu_shu_walk.png",
		"cong_cong": "res://assets/textures/iso/enemies/cong_cong_walk.png",
		"lei_beast": "res://assets/textures/iso/enemies/lei_beast_walk.png",
		"zheng_beast": "res://assets/textures/iso/enemies/zheng_beast_walk.png",
		"tian_gou": "res://assets/textures/iso/enemies/tian_gou_walk.png",
		"xuan_gui": "res://assets/textures/iso/enemies/xuan_gui_walk.png",
		"gu_diao": "res://assets/textures/iso/enemies/gu_diao_walk.png",
		"he_luo_fish": "res://assets/textures/iso/enemies/he_luo_fish_walk.png",
		"fei_yi": "res://assets/textures/iso/enemies/fei_yi_walk.png",
		"zhuhuai": "res://assets/textures/iso/enemies/zhuhuai_walk.png",
		"xiao_beast": "res://assets/textures/iso/enemies/xiao_beast_walk.png",
		"dang_kang": "res://assets/textures/iso/enemies/dang_kang_walk.png",
		"qiu_yu": "res://assets/textures/iso/enemies/qiu_yu_walk.png",
		"ling_ling": "res://assets/textures/iso/enemies/ling_ling_walk.png",
		"zhu_ru": "res://assets/textures/iso/enemies/zhu_ru_walk.png",
		"kui": "res://assets/textures/iso/enemies/kui_walk.png",
		"tu_lou": "res://assets/textures/iso/enemies/tu_lou_walk.png",
		"jiao_beast": "res://assets/textures/iso/enemies/jiao_beast_walk.png",
		"wen_lin": "res://assets/textures/iso/enemies/wen_lin_walk.png",
		"elite": "res://assets/textures/iso/entities/elite_walk.png",
		"elite_qiongqi": "res://assets/textures/iso/entities/elite_walk.png",
		"elite_yingzhao": "res://assets/textures/iso/entities/elite_yingzhao_walk.png",
		"elite_xiangliu_shadow": "res://assets/textures/iso/entities/elite_xiangliu_shadow_walk.png",
		"elite_yinglong_young": "res://assets/textures/iso/entities/elite_yinglong_young_walk.png",
		"elite_ji_meng": "res://assets/textures/iso/entities/elite_ji_meng_walk.png",
		"boss_weak": "res://assets/textures/iso/entities/boss_weak_walk.png",
		"boss_mid": "res://assets/textures/iso/entities/boss_mid_walk.png",
		"boss_hard": "res://assets/textures/iso/entities/boss_hard_walk.png",
		"boss_luwu_weak": "res://assets/textures/iso/entities/boss_luwu_weak_walk.png",
		"boss_luwu": "res://assets/textures/iso/entities/boss_luwu_walk.png",
		"boss_luwu_strong": "res://assets/textures/iso/entities/boss_luwu_strong_walk.png",
		"boss_zhulong_weak": "res://assets/textures/iso/entities/boss_zhulong_weak_walk.png",
		"boss_zhulong": "res://assets/textures/iso/entities/boss_zhulong_walk.png",
		"boss_zhulong_strong": "res://assets/textures/iso/entities/boss_zhulong_strong_walk.png",
		"boss_qinglong_weak": "res://assets/textures/iso/entities/boss_qinglong_weak_walk.png",
		"boss_qinglong": "res://assets/textures/iso/entities/boss_qinglong_walk.png",
		"boss_qinglong_strong": "res://assets/textures/iso/entities/boss_qinglong_strong_walk.png",
		"boss_qilin_weak": "res://assets/textures/iso/entities/boss_qilin_weak_walk.png",
		"boss_qilin": "res://assets/textures/iso/entities/boss_qilin_walk.png",
		"boss_qilin_strong": "res://assets/textures/iso/entities/boss_qilin_strong_walk.png",
		"treasure": "res://assets/textures/iso/entities/treasure_idle.png",
		"shop": "res://assets/textures/iso/entities/shop_idle.png",
		"rest": "res://assets/textures/iso/entities/rest_idle.png",
		"event": "res://assets/textures/iso/entities/event_idle.png",
		"fragment": "res://assets/textures/iso/entities/fragment_idle.png",
	}
	for e_name in iso_enemy_sheets:
		var sheet_enemy: Texture2D = _try_load(iso_enemy_sheets[e_name])
		if sheet_enemy != null:
			var dirs_for_enemy: Array = iso_enemy_row_dirs.get(e_name, iso_dirs_standard)
			for dir_idx in 4:
				for f_idx in 4:
					var region_enemy := Rect2(f_idx * 128, dir_idx * 128, 128, 128)
					var frame_key_enemy := "iso_enemy|%s|%s|%d" % [e_name, dirs_for_enemy[dir_idx], f_idx]
					_tex_cache[frame_key_enemy] = _atlas_tex(sheet_enemy, region_enemy)

	# 等距瓦片集 (128x128 网格)
	var iso_tile_sheets := {
		"dungeon": "res://assets/textures/iso/tilesheet_dungeon.png",
		"forest":  "res://assets/textures/iso/tilesheet_forest.png",
		"village": "res://assets/textures/iso/tilesheet_village.png",
	}
	for tname in iso_tile_sheets:
		var sheet: Texture2D = _try_load(iso_tile_sheets[tname])
		if sheet != null:
			# 每个 tilesheet 是 NxN 的 128x128 方块网格
			var cols := int(floor(sheet.get_width() / 128.0))
			var rows := int(floor(sheet.get_height() / 128.0))
			_tex_cache["iso_tile|%s|sheet" % tname] = sheet
			_tex_cache["iso_tile|%s|info" % tname] = {"tex": sheet, "cols": cols, "rows": rows, "ts": 128}

	# ---- 玩家攻击动画帧（SVG 剑击帧） ----
	for f in [0, 1]:
		var p := "res://assets/sprites/player/player_attack_f%d.svg" % f
		var tex: Texture2D = _try_load(p)
		if tex != null:
			for facing in [DIR_DOWN, DIR_UP, DIR_LEFT, DIR_RIGHT]:
				_tex_cache[_tex_key("player", facing, 4 + f)] = tex

	# ---- SVG fallback 精灵（玩家用 SVG 优先于 Julia 贴图） ----
	for d in [DIR_DOWN, DIR_UP, DIR_LEFT, DIR_RIGHT]:
		for f in [0, 1]:
			var p := "res://assets/sprites/player/player_%s_f%d.svg" % [d, f]
			var tex := _try_load(p)
			# 不覆盖已存在的 Julia 纹理
			var key := _tex_key("player", d, f)
			if tex != null and not _tex_cache.has(key):
				_tex_cache[key] = tex

	# 小怪（SVG）
	for e_name in ["hu_diao", "lu_shu", "cong_cong", "lei_beast"]:
		for f in [0, 1]:
			var p := "res://assets/sprites/enemy/%s_f%d.svg" % [e_name, f]
			var tex: Texture2D = _try_load(p)
			if tex != null:
				for facing in [DIR_DOWN, DIR_UP, DIR_LEFT, DIR_RIGHT]:
					_tex_cache[_tex_key("enemy." + e_name, facing, f)] = tex

	# 精英
	for f in [0, 1]:
		var tex := _try_load("res://assets/sprites/elite/elite_f%d.svg" % [f])
		if tex != null:
			for facing in [DIR_DOWN, DIR_UP, DIR_LEFT, DIR_RIGHT]:
				_tex_cache[_tex_key("elite", facing, f)] = tex

	# BOSS
	for boss_name in ["boss_weak", "boss_mid", "boss_hard"]:
		for f in [0, 1]:
			var tex := _try_load("res://assets/sprites/boss/%s_f%d.svg" % [boss_name, f])
			if tex != null:
				for facing in [DIR_DOWN, DIR_UP, DIR_LEFT, DIR_RIGHT]:
					_tex_cache[_tex_key(boss_name, facing, f)] = tex

	# 设施
	for fac_name in ["shop", "rest", "treasure", "event", "fragment"]:
		var tex := _try_load("res://assets/sprites/facility/%s.svg" % fac_name)
		if tex != null:
			for facing in [DIR_DOWN, DIR_UP, DIR_LEFT, DIR_RIGHT]:
				for f in [0, 1]:
					_tex_cache[_tex_key(fac_name, facing, f)] = tex


## 创建 AtlasTexture 从贴图集
	var top_entity_sheets := {
		"enemy.hu_diao": "res://assets/textures/top/entities/hu_diao.png",
		"enemy.lu_shu": "res://assets/textures/top/entities/lu_shu.png",
		"enemy.cong_cong": "res://assets/textures/top/entities/cong_cong.png",
		"enemy.lei_beast": "res://assets/textures/top/entities/lei_beast.png",
		"enemy.zheng_beast": "res://assets/textures/top/entities/zheng_beast.png",
		"enemy.tian_gou": "res://assets/textures/top/entities/tian_gou.png",
		"enemy.xuan_gui": "res://assets/textures/top/entities/xuan_gui.png",
		"enemy.gu_diao": "res://assets/textures/top/entities/gu_diao.png",
		"enemy.he_luo_fish": "res://assets/textures/top/entities/he_luo_fish.png",
		"enemy.fei_yi": "res://assets/textures/top/entities/fei_yi.png",
		"enemy.zhuhuai": "res://assets/textures/top/entities/zhuhuai.png",
		"enemy.xiao_beast": "res://assets/textures/top/entities/xiao_beast.png",
		"enemy.dang_kang": "res://assets/textures/top/entities/dang_kang.png",
		"enemy.qiu_yu": "res://assets/textures/top/entities/qiu_yu.png",
		"enemy.ling_ling": "res://assets/textures/top/entities/ling_ling.png",
		"enemy.zhu_ru": "res://assets/textures/top/entities/zhu_ru.png",
		"enemy.kui": "res://assets/textures/top/entities/kui.png",
		"enemy.tu_lou": "res://assets/textures/top/entities/tu_lou.png",
		"enemy.jiao_beast": "res://assets/textures/top/entities/jiao_beast.png",
		"enemy.wen_lin": "res://assets/textures/top/entities/wen_lin.png",
		"elite": "res://assets/textures/top/entities/elite.png",
		"elite_qiongqi": "res://assets/textures/top/entities/elite.png",
		"elite_yingzhao": "res://assets/textures/top/entities/elite_yingzhao.png",
		"elite_xiangliu_shadow": "res://assets/textures/top/entities/elite_xiangliu_shadow.png",
		"elite_yinglong_young": "res://assets/textures/top/entities/elite_yinglong_young.png",
		"elite_ji_meng": "res://assets/textures/top/entities/elite_ji_meng.png",
		"boss_weak": "res://assets/textures/top/entities/boss_weak.png",
		"boss_mid": "res://assets/textures/top/entities/boss_mid.png",
		"boss_hard": "res://assets/textures/top/entities/boss_hard.png",
		"boss_luwu_weak": "res://assets/textures/top/entities/boss_luwu_weak.png",
		"boss_luwu": "res://assets/textures/top/entities/boss_luwu.png",
		"boss_luwu_strong": "res://assets/textures/top/entities/boss_luwu_strong.png",
		"boss_zhulong_weak": "res://assets/textures/top/entities/boss_zhulong_weak.png",
		"boss_zhulong": "res://assets/textures/top/entities/boss_zhulong.png",
		"boss_zhulong_strong": "res://assets/textures/top/entities/boss_zhulong_strong.png",
		"boss_qinglong_weak": "res://assets/textures/top/entities/boss_qinglong_weak.png",
		"boss_qinglong": "res://assets/textures/top/entities/boss_qinglong.png",
		"boss_qinglong_strong": "res://assets/textures/top/entities/boss_qinglong_strong.png",
		"boss_qilin_weak": "res://assets/textures/top/entities/boss_qilin_weak.png",
		"boss_qilin": "res://assets/textures/top/entities/boss_qilin.png",
		"boss_qilin_strong": "res://assets/textures/top/entities/boss_qilin_strong.png",
		"treasure": "res://assets/textures/top/entities/treasure.png",
		"shop": "res://assets/textures/top/entities/shop.png",
		"rest": "res://assets/textures/top/entities/rest.png",
		"event": "res://assets/textures/top/entities/event.png",
		"fragment": "res://assets/textures/top/entities/fragment.png",
	}
	var top_entity_row_dirs := {
		"enemy.lu_shu": iso_dirs_left_right_swapped,
		"enemy.xuan_gui": iso_dirs_left_right_swapped,
		"enemy.zheng_beast": iso_dirs_left_right_swapped,
		"enemy.zhuhuai": iso_dirs_left_right_swapped,
		"enemy.he_luo_fish": iso_dirs_left_right_swapped,
		"enemy.xiao_beast": iso_dirs_left_right_swapped,
		"enemy.zhu_ru": iso_dirs_left_right_swapped,
		"enemy.qiu_yu": iso_dirs_left_right_swapped,
		"enemy.tu_lou": iso_dirs_left_right_swapped,
		"elite_yingzhao": iso_dirs_left_right_swapped,
	}
	for top_kind in top_entity_sheets:
		var top_sheet: Texture2D = _try_load(top_entity_sheets[top_kind])
		if top_sheet != null:
			var dirs_for_top_entity: Array = top_entity_row_dirs.get(top_kind, iso_dirs_standard)
			for dir_idx in 4:
				for f_idx in 4:
					var top_region := Rect2(f_idx * TILE_SIZE, dir_idx * TILE_SIZE, TILE_SIZE, TILE_SIZE)
					_tex_cache[_tex_key(top_kind, dirs_for_top_entity[dir_idx], f_idx)] = _atlas_tex(top_sheet, top_region)


static func _atlas_tex(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = region
	at.filter_clip = true
	return at


static func _tex_key(kind: String, facing: String, frame: int) -> String:
	return "%s|%s|%d" % [kind, facing, frame]


static func _try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var texture := ResourceLoader.load(path, "Texture2D")
		if texture is Texture2D:
			return texture
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)
	return null


## 获取方块纹理（返回 {tex, region_rect} 或 null）
static func tile_texture(name: String) -> Dictionary:
	_load_textures()
	var data = _tex_cache.get("tile|%s|0" % name, null)
	if data is Dictionary and data.has("tex"):
		# 从 tilesheet 提取第1个 tile 的中心 48x48 区域
		var ts := int(data.get("tile_size", 64))
		var margin := (ts - TILE_SIZE) / 2
		return {"tex": data["tex"], "region": Rect2(margin, margin, TILE_SIZE, TILE_SIZE)}
	# SVG fallback
	var svg_tex: Texture2D = _tex_cache.get("tile|%s|0" % name, null) as Texture2D
	if svg_tex is Texture2D:
		return {"tex": svg_tex, "region": Rect2(0, 0, TILE_SIZE, TILE_SIZE)}
	return {}

## 获取贴图集纹理
static func tile_sheet(name: String) -> Texture2D:
	_load_textures()
	var data = _tex_cache.get("tile|%s|0" % name, null)
	if data is Dictionary and data.has("tex"):
		return data["tex"]
	return _tex_cache.get("tile|%s|sheet" % name, null)

## 获取等距精灵纹理 (anim: walk/idle/attack, facing, frame)
static func iso_player_texture(anim: String, facing: String, frame: int = 0) -> Texture2D:
	_load_textures()
	return _tex_cache.get("iso_player|%s|%s|%d" % [anim, facing, frame], null)


static func player_sprite_key(character_id: String) -> String:
	match character_id:
		"ali":
			return "player_ali"
		"luo_ling":
			return "player_luoling"
		"sang_qi":
			return "player_sangqi"
		_:
			return "player"


static func iso_character_texture(character_id: String, anim: String, facing: String, frame: int = 0) -> Texture2D:
	_load_textures()
	var key := player_sprite_key(character_id)
	var tex: Texture2D = _tex_cache.get("iso_player|%s|%s|%s|%d" % [key, anim, facing, frame], null)
	if tex != null:
		return tex
	return iso_player_texture(anim, facing, frame)


static func iso_enemy_texture(enemy_id: String, facing: String, frame: int = 0) -> Texture2D:
	_load_textures()
	return _tex_cache.get("iso_enemy|%s|%s|%d" % [enemy_id, facing, frame % 4], null)

## 获取等距瓦片纹理 (tilesheet_name: dungeon/forest/village)
static func iso_tile_texture(sheet_name: String) -> Dictionary:
	_load_textures()
	var info = _tex_cache.get("iso_tile|%s|info" % sheet_name, null)
	if info is Dictionary and info.has("tex"):
		return info
	return {}

## 获取等距瓦片集的某一格 (tile_index: Vector2i)
static func iso_tile_region(sheet_name: String, tile_index: Vector2i) -> Dictionary:
	var info: Dictionary = iso_tile_texture(sheet_name)
	if info.is_empty():
		return {}
	var ts := int(info.get("ts", 128))
	return {
		"tex": info["tex"],
		"region": Rect2(tile_index.x * ts, tile_index.y * ts, ts, ts)
	}

## 获取精灵纹理（kind + facing + frame），无纹理时返回 null
static func texture(kind: String, facing: String = DIR_DOWN, frame: int = 0) -> Texture2D:
	_load_textures()
	# 精确匹配
	var key := _tex_key(kind, facing, frame)
	if _tex_cache.has(key):
		return _tex_cache[key]
	# 降级：同 kind 任意朝向
	key = _tex_key(kind, DIR_DOWN, frame % 2)
	if _tex_cache.has(key):
		return _tex_cache[key]
	# 降级：同 kind 取 frame 0
	key = _tex_key(kind, DIR_DOWN, 0)
	if _tex_cache.has(key):
		return _tex_cache[key]
	return null

## CardEffect: 卡牌效果原子。一张卡可叠加多个效果，按顺序结算。
## 通过组合代替写死，方便后续扩展和数据驱动。
class_name CardEffect extends Resource

enum Kind {
	DAMAGE,         # 对目标造成伤害
	BLOCK,          # 给玩家施加护盾
	HEAL,           # 玩家回血
	DRAW,           # 抽 amount 张牌
	GAIN_ENERGY,    # 当回合获得 amount 灵韵
	APPLY_STATUS,   # 给目标施加状态（status_id 见 StatusEffect）
	SELF_STATUS,    # 给自己施加状态
	DISCARD_RANDOM, # 随机弃 amount 张
	EXHAUST_HAND,   # 消耗本回合所有手牌
	SUMMON_ALLY,    # 唤醒同伴（占位，预留）
}

enum Target {
	NONE,           # 无需目标（自我效果）
	SINGLE,         # 单个敌人
	ALL_ENEMIES,    # 全体敌人
	SELF,           # 玩家自己
}

@export var kind: Kind = Kind.DAMAGE
@export var amount: int = 0
@export var target: Target = Target.SINGLE

## 当 kind == APPLY_STATUS / SELF_STATUS 时使用
@export var status_id: String = ""
## 状态层数 / 持续回合
@export var status_stack: int = 0


func describe() -> String:
	match kind:
		Kind.DAMAGE: return "造成 %d 点伤害" % amount
		Kind.BLOCK: return "获得 %d 点护盾" % amount
		Kind.HEAL: return "恢复 %d 点生命" % amount
		Kind.DRAW: return "抽 %d 张牌" % amount
		Kind.GAIN_ENERGY: return "获得 %d 点灵韵" % amount
		Kind.APPLY_STATUS: return "施加 [%s] x %d" % [status_id, status_stack]
		Kind.SELF_STATUS: return "自身获得 [%s] x %d" % [status_id, status_stack]
		Kind.DISCARD_RANDOM: return "随机弃 %d 张" % amount
		Kind.EXHAUST_HAND: return "消耗手牌"
		Kind.SUMMON_ALLY: return "唤醒同伴 [%s]" % status_id
	return "未知效果"

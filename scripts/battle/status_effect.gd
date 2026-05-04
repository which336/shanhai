## StatusEffect: 战斗中的状态/buff/debuff
## 简单实现：以 dictionary{status_id -> stack} 存在 Player/Enemy 上即可
class_name StatusEffect extends RefCounted

## 已知状态 ID（约定，加新状态时在此追加）
const ID_STRENGTHEN: String = "strengthen"   # 强化：攻击 +stack
const ID_VULNERABLE: String = "vulnerable"   # 易伤：受伤 *1.5
const ID_BURN: String = "burn"               # 灼焰：回合开始掉血 = stack
const ID_WET: String = "wet"                 # 湿润：受伤 +1
const ID_ROOT: String = "root"               # 根脉：回合开始获得护盾 = stack
const ID_RESONANCE_SHAN: String = "resonance_shan"  # 山经共鸣
const ID_RESONANCE_HAI: String = "resonance_hai"
const ID_RESONANCE_HUANG: String = "resonance_huang"
const ID_SCHOLAR: String = "scholar"         # 学子心：预留成长效果


static func display_name(id: String) -> String:
	match id:
		ID_STRENGTHEN: return "强化"
		ID_VULNERABLE: return "易伤"
		ID_BURN: return "灼焰"
		ID_WET: return "湿润"
		ID_ROOT: return "根脉"
		ID_RESONANCE_SHAN: return "山经共鸣"
		ID_RESONANCE_HAI: return "海经共鸣"
		ID_RESONANCE_HUANG: return "荒经共鸣"
		ID_SCHOLAR: return "学子心"
	return id


## 计算最终造成的伤害（来源攻击力 + 易伤等修正）
static func calc_damage_modifier(source_status: Dictionary, target_status: Dictionary, base: int) -> int:
	var dmg: float = base
	dmg += source_status.get(ID_STRENGTHEN, 0)
	if target_status.has(ID_VULNERABLE):
		dmg *= 1.5
	if target_status.has(ID_WET):
		dmg += 1
	return int(round(dmg))

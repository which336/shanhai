## CodexEntry: 山海图鉴一条记录（Resource）
## 一张卡 / 一只异兽 / 一件神器都可对应一条图鉴
class_name CodexEntry extends Resource

enum Kind { CARD, BEAST, RELIC, EVENT }

@export var id: String = ""
@export var kind: Kind = Kind.CARD
@export var title: String = ""

@export_multiline var classic_quote: String = ""
@export_multiline var translation: String = ""
@export_multiline var research_note: String = ""    # 考据 / 出处篇目
@export_multiline var alive_today: String = ""      # "今天活在哪里"

@export var art: Texture2D = null

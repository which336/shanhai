## Deck: 战斗中的牌堆管理（抽牌堆 / 手牌 / 弃牌堆 / 消耗堆）
class_name Deck extends RefCounted

signal hand_changed()
signal piles_changed()

var draw_pile: Array[Card] = []
var hand: Array[Card] = []
var discard_pile: Array[Card] = []
var exhaust_pile: Array[Card] = []

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func init_from_deck(deck_cards: Array[Card], seed_value: int = 0) -> void:
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	for c in deck_cards:
		var card_copy: Card = c.duplicate(true) as Card
		if card_copy != null:
			draw_pile.append(card_copy)
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	shuffle_draw()
	hand_changed.emit()
	piles_changed.emit()


func shuffle_draw() -> void:
	for i in range(draw_pile.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Card = draw_pile[i]
		draw_pile[i] = draw_pile[j]
		draw_pile[j] = tmp


## 抽 amount 张到手牌；若抽牌堆不够则把弃牌堆洗回
func draw(amount: int) -> Array[Card]:
	var drawn: Array[Card] = []
	for i in amount:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile.append_array(discard_pile)
			discard_pile.clear()
			shuffle_draw()
		var c: Card = draw_pile.pop_back()
		hand.append(c)
		drawn.append(c)
	hand_changed.emit()
	piles_changed.emit()
	return drawn


func discard_card(card: Card) -> bool:
	var idx: int = hand.find(card)
	if idx < 0:
		return false
	hand.remove_at(idx)
	discard_pile.append(card)
	hand_changed.emit()
	piles_changed.emit()
	return true


func exhaust_card(card: Card) -> bool:
	var idx: int = hand.find(card)
	if idx < 0:
		return false
	hand.remove_at(idx)
	exhaust_pile.append(card)
	hand_changed.emit()
	piles_changed.emit()
	return true


## 按手牌下标移除一张牌，避免多张同名卡共享同一个 Card Resource 时删错。
## 注意：这里只负责从 hand 移走并放入弃牌/消耗堆；调用方应先保存 card 引用用于结算效果。
func move_hand_card_to_pile(index: int, exhaust: bool) -> Card:
	if index < 0 or index >= hand.size():
		return null
	var c: Card = hand[index]
	hand.remove_at(index)
	if exhaust:
		exhaust_pile.append(c)
	else:
		discard_pile.append(c)
	hand_changed.emit()
	piles_changed.emit()
	return c


func discard_all_hand() -> void:
	for c in hand:
		discard_pile.append(c)
	hand.clear()
	hand_changed.emit()
	piles_changed.emit()


func discard_random(amount: int) -> Array[Card]:
	var dropped: Array[Card] = []
	for i in amount:
		if hand.is_empty():
			break
		var idx: int = rng.randi_range(0, hand.size() - 1)
		var c: Card = hand[idx]
		hand.remove_at(idx)
		discard_pile.append(c)
		dropped.append(c)
	hand_changed.emit()
	piles_changed.emit()
	return dropped


func size_total() -> int:
	return draw_pile.size() + hand.size() + discard_pile.size() + exhaust_pile.size()

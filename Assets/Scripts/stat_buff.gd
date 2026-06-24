extends Resource
class_name StatBuff

enum BuffType {
	MULTIPLY,
	ADD,
}

enum Rarity {
	COMMON,
	RARE,
	EPIC
}

@export var stat: Stats.BuffableStats
@export var buff_amount: float
@export var buff_type: BuffType
@export var rarity: Rarity = Rarity.COMMON
@export var min_level: int = 1
@export var display_name: String = ""



func _init(_stat: Stats.BuffableStats = Stats.BuffableStats.MAX_HEALTH, _buff_ammount: float =1.0, 
_buff_type: StatBuff.BuffType = BuffType.MULTIPLY, _rarity: Rarity = Rarity.COMMON, _min_level: int = 1, _display_name: String = "") -> void:
		stat = _stat
		buff_type= _buff_type
		buff_amount = _buff_ammount
		rarity = _rarity
		min_level = _min_level
		display_name = _display_name
	

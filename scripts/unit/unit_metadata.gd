extends Resource
class_name UnitMetaData

enum Fraction {
	RADIANT,
	DIRE
}

@export var is_building: bool = false
@export var is_hero: bool = false
@export var fraction: Fraction = Fraction.RADIANT

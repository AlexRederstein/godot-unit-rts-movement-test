class_name UnitStats
extends Resource

@export_group("Base")
@export var max_health: int = 100
@export var max_mana: float = 0.0

@export var health: int = 100
@export var mana: float = 0.0

@export_group("Combat")
@export var damage: int = 10
@export var attack_range: float = 40.0
@export var attak_delay: float = 1.0

@export_group("Movement")
@export var speed: int = 100 # Скорость юнита

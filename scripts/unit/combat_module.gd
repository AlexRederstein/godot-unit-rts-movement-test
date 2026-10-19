extends Node
class_name UnitCombat

signal attack_performed(target: Node2D)

var _attack_timer: float = 0.0
var _stats: UnitStats

func setup(stats: UnitStats) -> void:
	_stats = stats
	
func _process(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer -= delta
		

func try_attack(target: Node2D) -> bool:
	if _attack_timer > 0.0 or not is_instance_valid(target):
		return false
		
	_attack_timer = _stats.attak_delay
	attack_performed.emit(target)
	
	if target.has_method("take_damage"):
		target.take_damage(_stats.damage)
		
	return true
	

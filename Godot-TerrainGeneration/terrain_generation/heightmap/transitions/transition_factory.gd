class_name TransitionFactory extends RefCounted

enum TransitionType { CLIFF, BEACH, ROCKY }

var _seed: int

func _init(seed_value: int = 0):
	_seed = seed_value if seed_value > 0 else randi()

func create_transition(type: TransitionType) -> TransitionStrategy:
	match type:
		TransitionType.CLIFF:
			return CliffTransition.new(_seed)
		TransitionType.BEACH:
			return BeachTransition.new(_seed)
		#TransitionType.ROCKY:
			#return RockyTransition.new(_seed)
		_:
			push_error("Unknown transition type")
			return null

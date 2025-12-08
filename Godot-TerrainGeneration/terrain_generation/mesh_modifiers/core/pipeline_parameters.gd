class_name PipelineParameters extends Resource
@export var mesh_params: MeshGenerationParameters = MeshGenerationParameters.new()
@export var agent_specific_params: Dictionary = {}

func get_agent_param(key: String, default = null):
	return agent_specific_params.get(key, default)
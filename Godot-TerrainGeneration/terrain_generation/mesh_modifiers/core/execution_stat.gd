class_name ExecutionStat extends RefCounted
var agent_name: String
var success: bool
var elapsed_ms: float
var message: String

func _init(p_agent_name:String, p_success: bool, p_elapsed_ms: float, p_message: String):
	agent_name = p_agent_name
	success = p_success
	elapsed_ms = p_elapsed_ms
	message = p_message
